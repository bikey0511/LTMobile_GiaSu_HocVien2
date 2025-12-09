import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../services/repository_factory.dart';
import '../../services/user_service.dart';
import '../../models/chat_room.dart';
import '../../models/message.dart';
import '../../models/booking.dart';
import '../../models/student.dart';
import 'chat_screen.dart';
import 'chat_ai_screen.dart';

/// Màn hình danh sách chat - hiển thị tất cả cuộc trò chuyện như Messenger
class ChatListScreen extends StatefulWidget {
  static const routeName = '/chat-list';
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> with AutomaticKeepAliveClientMixin {
  final _chatService = ChatService();
  final _bookingRepo = RepoFactory.booking();
  bool _hasMarkedAllAsRead = false;
  // Cache danh sách chat rooms để không bị mất khi quay lại
  List<ChatRoom>? _cachedChatRooms;
  bool _showLoadingTimeout = false;
  
  @override
  bool get wantKeepAlive => true; // Giữ state khi navigate away
  
  @override
  void initState() {
    super.initState();
    // Đánh dấu tất cả tin nhắn là đã đọc khi vào màn hình danh sách chat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _markAllAsRead();
      }
    });
    
    // Sau 3 giây, nếu vẫn chưa có dữ liệu, hiển thị empty state thay vì loading
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _showLoadingTimeout) {
        setState(() {
          _showLoadingTimeout = false;
        });
      }
    });
  }
  

  Future<void> _markAllAsRead() async {
    if (_hasMarkedAllAsRead) return;
    if (!mounted) return;
    
    final user = context.read<AuthService>().currentUser;
    if (user == null) return;
    
    _hasMarkedAllAsRead = true;
    try {
      print('🔄 Marking all messages as read for user ${user.id}...');
      await _chatService.markAllAsRead(user.id);
      print('✅ Finished marking all messages as read');
      // Force rebuild sau khi đánh dấu
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('❌ Error marking all as read: $e');
    }
  }
  
  // Stream để lấy tin nhắn cuối từ Firestore (realtime)
  Stream<ChatMessage?> _streamLastMessage(String roomId) {
    return _chatService.streamLastMessage(roomId);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Cần gọi để AutomaticKeepAliveClientMixin hoạt động
    final user = context.watch<AuthService>().currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tin nhắn')),
        body: const Center(child: Text('Vui lòng đăng nhập')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tin nhắn'),
      ),
      body: StreamBuilder<List<Booking>>(
        stream: user.role == UserRole.tutor 
            ? _bookingRepo.streamForTutor(user.id)
            : _bookingRepo.streamForStudent(user.id),
        builder: (context, bookingSnap) {
          // Nếu có cache, hiển thị ngay để không bị lag
          if (_cachedChatRooms != null && _cachedChatRooms!.isNotEmpty && 
              bookingSnap.connectionState == ConnectionState.waiting && !bookingSnap.hasData) {
            // Hiển thị cache ngay, không cần chờ loading
            return _buildChatRoomsList(_cachedChatRooms!, user);
          }
          
          // Nếu đang chờ dữ liệu lần đầu và chưa hết timeout
          if (bookingSnap.connectionState == ConnectionState.waiting && !bookingSnap.hasData && !_showLoadingTimeout) {
            // Bật flag để sau 3 giây sẽ hiển thị empty state
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _showLoadingTimeout = true;
                });
              }
            });
            // Nếu có cache, hiển thị cache thay vì loading
            if (_cachedChatRooms != null && _cachedChatRooms!.isNotEmpty) {
              return _buildChatRoomsList(_cachedChatRooms!, user);
            }
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          
          // Nếu có lỗi
          if (bookingSnap.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Lỗi: ${bookingSnap.error}'),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      setState(() {});
                    },
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            );
          }
          
          // Lấy danh sách bookings để tạo chat rooms
          final bookings = bookingSnap.data ?? [];
          // Cho phép chat ngay sau khi đặt lịch, không cần chờ accepted
          // Chỉ loại trừ các booking đã bị cancelled hoặc rejected
          final validBookings = bookings.where((b) => !b.cancelled && b.rejectReason == null).toList();
          
          // Debug: In ra để kiểm tra
          if (user.role == UserRole.tutor) {
            print('📊 Tutor ${user.id}: Total bookings: ${bookings.length}, Valid: ${validBookings.length}');
          } else {
            print('📊 Student ${user.id}: Total bookings: ${bookings.length}, Valid: ${validBookings.length}');
          }
          
          // Tạo danh sách chat rooms từ bookings
          List<ChatRoom> chatRooms = [];
          
          // Thêm chat với AI (mỗi user có roomId riêng) - luôn có
          final aiRoomId = 'ai-assistant-${user.id}';
          chatRooms.add(ChatRoom(
            id: aiRoomId,
            type: 'ai',
            participantIds: [user.id, 'ai'],
            lastMessage: null, // Sẽ được cập nhật từ StreamBuilder
            lastMessageTime: null,
            lastSenderId: null,
          ));
          
          // Nếu có bookings, thêm chat rooms từ bookings
          if (validBookings.isNotEmpty) {
            if (user.role == UserRole.tutor) {
            // Gia sư: Thêm chat với các học viên (từ bookings)
            final studentIds = <String>{};
            for (final booking in validBookings) {
              if (!studentIds.contains(booking.studentId)) {
                studentIds.add(booking.studentId);
                // Tạo room ID nhất quán bằng cách sắp xếp IDs
                final ids = [user.id, booking.studentId]..sort();
                final roomId = '${ids[0]}-${ids[1]}';
                
                print('📝 Adding chat room for tutor: $roomId with student ${booking.studentId}');
                
                chatRooms.add(ChatRoom(
                  id: roomId,
                  type: 'student',
                  studentId: booking.studentId,
                  participantIds: [user.id, booking.studentId],
                  lastMessage: null, // Sẽ được cập nhật từ StreamBuilder
                  lastMessageTime: null,
                  lastSenderId: null,
                ));
              }
            }
            
            print('📋 Total chat rooms for tutor: ${chatRooms.length}');

            // Thêm chat nhóm học
            final groupBookings = validBookings.where((b) => b.isGroupClass).toList();
            for (final booking in groupBookings) {
              final roomId = 'group-${booking.id}';
              
              chatRooms.add(ChatRoom(
                id: roomId,
                type: 'group',
                groupBookingId: booking.id,
                participantIds: booking.studentIds,
                lastMessage: null, // Sẽ được cập nhật từ StreamBuilder
                lastMessageTime: null,
                lastSenderId: null,
              ));
            }
          } else {
            // Học viên: Thêm chat với các gia sư (từ bookings)
            final tutorIds = <String>{};
            for (final booking in validBookings) {
              if (!tutorIds.contains(booking.tutorId)) {
                tutorIds.add(booking.tutorId);
                // Tạo room ID nhất quán bằng cách sắp xếp IDs
                final ids = [booking.tutorId, user.id]..sort();
                final roomId = '${ids[0]}-${ids[1]}';
                
                chatRooms.add(ChatRoom(
                  id: roomId,
                  type: 'tutor',
                  tutorId: booking.tutorId,
                  participantIds: [user.id, booking.tutorId],
                  lastMessage: null, // Sẽ được cập nhật từ StreamBuilder
                  lastMessageTime: null,
                  lastSenderId: null,
                ));
              }
            }

            // Thêm chat nhóm học
            final groupBookings = validBookings.where((b) => b.isGroupClass).toList();
            for (final booking in groupBookings) {
              final roomId = 'group-${booking.id}';
              
              chatRooms.add(ChatRoom(
                id: roomId,
                type: 'group',
                groupBookingId: booking.id,
                participantIds: booking.studentIds,
                lastMessage: null, // Sẽ được cập nhật từ StreamBuilder
                lastMessageTime: null,
                lastSenderId: null,
              ));
            }
          }
          }

          // Luôn cập nhật cache khi có chat rooms mới
          if (chatRooms.isNotEmpty) {
            _cachedChatRooms = chatRooms;
          } else if (_cachedChatRooms != null && _cachedChatRooms!.isNotEmpty) {
            // Nếu không có chat rooms mới nhưng có cache, dùng cache để không mất dữ liệu
            print('📦 Using cached chat rooms: ${_cachedChatRooms!.length} rooms');
            chatRooms = _cachedChatRooms!;
          }

          // Không sắp xếp ở đây vì sẽ sắp xếp sau khi có tin nhắn cuối từ StreamBuilder

          // Chat rooms luôn có ít nhất AI room, nên không cần kiểm tra empty
          if (chatRooms.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'Chưa có cuộc trò chuyện',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user.role == UserRole.tutor
                        ? 'Bắt đầu trò chuyện với AI hoặc học viên của bạn'
                        : 'Bắt đầu trò chuyện với AI hoặc gia sư của bạn',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return _buildChatRoomsList(chatRooms, user);
        },
      ),
    );
  }
  
  Widget _buildChatRoomsList(List<ChatRoom> chatRooms, dynamic user) {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: chatRooms.length,
      itemBuilder: (context, index) {
        final room = chatRooms[index];
        // Dùng StreamBuilder để cập nhật tin nhắn cuối realtime và unread count
        return StreamBuilder<ChatMessage?>(
          stream: _streamLastMessage(room.id),
          builder: (context, msgSnap) {
            final lastMsg = msgSnap.data;
            // Stream unread count cho room này
            return StreamBuilder<int>(
              stream: _chatService.unreadMessageCountForRoom(room.id, user.id),
              builder: (context, unreadSnap) {
                final unreadCount = unreadSnap.data ?? 0;
                // Tạo ChatRoom mới với tin nhắn cuối và unread count được cập nhật
                final updatedRoom = ChatRoom(
                  id: room.id,
                  type: room.type,
                  tutorId: room.tutorId,
                  studentId: room.studentId,
                  groupBookingId: room.groupBookingId,
                  participantIds: room.participantIds,
                  lastMessage: lastMsg?.text ?? (room.type == 'ai' ? 'Xin chào! Tôi có thể giúp gì cho bạn?' : null),
                  lastMessageTime: lastMsg?.sentAt ?? (room.type == 'ai' ? DateTime.now() : null),
                  lastSenderId: lastMsg?.senderId ?? (room.type == 'ai' ? 'ai' : null),
                  unreadCount: unreadCount,
                );
                return _buildChatRoomItem(context, updatedRoom, user.id);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildChatRoomItem(BuildContext context, ChatRoom room, String currentUserId) {
    // Nếu là AI hoặc group, hiển thị ngay
    if (room.type == 'ai') {
      return _buildRoomItemContent(context, room, currentUserId, _RoomInfo(title: 'Chat với AI', avatarUrl: null));
    }
    if (room.type == 'group') {
      return _buildRoomItemContent(context, room, currentUserId, _RoomInfo(title: 'Nhóm học', avatarUrl: null));
    }
    
    // Nếu có tutorId, fetch tên gia sư từ database
    if (room.tutorId != null) {
      final tutorRepo = RepoFactory.tutor();
      return StreamBuilder(
        stream: tutorRepo.streamById(room.tutorId!),
        builder: (context, tutorSnap) {
          final tutor = tutorSnap.data;
          final title = tutor?.name ?? 'Gia sư';
          final avatarUrl = tutor?.avatarUrl;
          return _buildRoomItemContent(context, room, currentUserId, _RoomInfo(title: title, avatarUrl: avatarUrl));
        },
      );
    }
    
    // Nếu có studentId, fetch tên học viên từ database
    if (room.studentId != null) {
      final userService = UserService();
      return StreamBuilder<StudentProfile?>(
        stream: userService.streamById(room.studentId!),
        builder: (context, userSnap) {
          final user = userSnap.data;
          final title = user?.fullName ?? 'Học viên';
          final avatarUrl = user?.avatarUrl;
          return _buildRoomItemContent(context, room, currentUserId, _RoomInfo(title: title, avatarUrl: avatarUrl));
        },
      );
    }
    
    // Fallback
    return _buildRoomItemContent(context, room, currentUserId, _RoomInfo(title: room.type == 'student' ? 'Học viên' : 'Gia sư', avatarUrl: null));
  }
  
  Widget _buildRoomItemContent(BuildContext context, ChatRoom room, String currentUserId, _RoomInfo roomInfo) {
    final isUnread = room.unreadCount > 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      // Làm nổi bật background nếu có tin nhắn chưa đọc
      color: isUnread ? Colors.blue.shade50 : null,
      elevation: isUnread ? 2 : 1,
      child: ListTile(
            leading: CircleAvatar(
              radius: 28,
              backgroundColor: room.type == 'ai'
                  ? Colors.blue.shade100
                  : (room.type == 'group' ? Colors.green.shade100 : Colors.blue.shade100),
              child: room.type == 'ai'
                  ? const Icon(Icons.smart_toy, color: Colors.blue)
                  : (room.type == 'group'
                      ? const Icon(Icons.group, color: Colors.green)
                      : (roomInfo.avatarUrl != null
                          ? CircleAvatar(
                              backgroundImage: NetworkImage(roomInfo.avatarUrl!),
                              radius: 28,
                            )
                          : const Icon(Icons.person, color: Colors.blue))),
            ),
            title: Text(
              roomInfo.title,
              style: TextStyle(
                fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                fontSize: isUnread ? 16 : 15,
                color: isUnread ? Colors.blue.shade900 : Colors.black87,
              ),
            ),
            subtitle: Text(
              room.lastMessage ?? 'Chưa có tin nhắn',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isUnread ? Colors.black87 : Colors.grey[600],
                fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
                fontSize: isUnread ? 14 : 13,
              ),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (room.lastMessageTime != null)
                  Text(
                    _formatTime(room.lastMessageTime!),
                    style: TextStyle(
                      fontSize: 12,
                      color: isUnread ? Colors.blue.shade700 : Colors.grey[600],
                      fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                if (isUnread)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade700,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${room.unreadCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            onTap: () async {
              // Đánh dấu room này là đã đọc ngay khi bấm vào
              final user = context.read<AuthService>().currentUser;
              if (user != null) {
                // Đánh dấu room chat là đã đọc ngay lập tức (kể cả AI)
                await _chatService.markRoomAsRead(room.id, user.id).catchError((e) {
                  print('Error marking room as read: $e');
                });
                // Đợi một chút để Firestore cập nhật và stream emit lại
                await Future.delayed(const Duration(milliseconds: 300));
                // Force rebuild để cập nhật UI ngay
                if (mounted) {
                  setState(() {});
                }
              }
              
              if (room.type == 'ai') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChatAIScreen()),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      roomId: room.id,
                      title: roomInfo.title,
                    ),
                  ),
                );
              }
            },
          ),
        );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays == 0) {
      return DateFormat('HH:mm').format(time);
    } else if (difference.inDays == 1) {
      return 'Hôm qua';
    } else if (difference.inDays < 7) {
      return DateFormat('EEEE', 'vi').format(time);
    } else {
      return DateFormat('dd/MM/yyyy').format(time);
    }
  }
}

class _RoomInfo {
  final String title;
  final String? avatarUrl;

  _RoomInfo({required this.title, this.avatarUrl});
}

