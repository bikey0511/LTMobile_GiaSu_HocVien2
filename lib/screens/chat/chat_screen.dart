import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/chat_service.dart';
import '../../services/auth_service.dart';
import '../../models/message.dart';

class ChatScreen extends StatefulWidget {
  static const routeName = '/chat';
  final String roomId; // e.g., tutorId-studentId
  final String title;
  const ChatScreen({super.key, required this.roomId, required this.title});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with AutomaticKeepAliveClientMixin {
  final _chat = ChatService();
  final _ctrl = TextEditingController();
  bool _showLoadingTimeout = false;
  String? _pendingMessage; // Lưu tin nhắn đang chờ gửi lại
  List<ChatMessage>? _cachedMessages; // Cache messages để hiển thị ngay
  
  @override
  bool get wantKeepAlive => true; // Giữ state khi navigate away

  @override
  void initState() {
    super.initState();
    
    // Khôi phục cache từ ChatService ngay khi init để không bị mất dữ liệu
    final cachedMessages = _chat.roomToMessages[widget.roomId];
    if (cachedMessages != null && cachedMessages.isNotEmpty) {
      _cachedMessages = cachedMessages;
      print('📦 Restored ${cachedMessages.length} cached messages for room ${widget.roomId}');
    }
    
    // Đánh dấu room là đã đọc khi mở màn hình
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markAsRead();
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Mark as read ngay khi màn hình được hiển thị lại (khi quay lại từ màn hình khác)
    // Điều này đảm bảo badge được cập nhật khi quay lại
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markAsRead();
    });
  }

  Future<void> _markAsRead() async {
    final me = context.read<AuthService>().currentUser;
    if (me == null) return;
    
    // Luôn mark as read, không check flag để đảm bảo cập nhật khi quay lại
    try {
      await _chat.markRoomAsRead(widget.roomId, me.id);
      print('✅ Marked room ${widget.roomId} as read for user ${me.id}');
      // Đợi một chút để Firestore cập nhật và stream emit lại
      await Future.delayed(const Duration(milliseconds: 300));
    } catch (e) {
      print('❌ Error marking room as read: $e');
    }
  }

  Future<void> _sendMessageRetry(String text, String senderId) async {
    try {
      await _chat.sendMessage(widget.roomId, senderId, text);
      _pendingMessage = null; // Clear pending message on success
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
    } catch (e) {
      // Vẫn giữ pending message để có thể thử lại
      if (mounted) {
        String errorMsg = 'Không thể gửi tin nhắn. Vui lòng thử lại.';
        final errorStr = e.toString();
        
        // Parse error message để hiển thị chi tiết hơn - ưu tiên message từ service
        if (errorStr.contains('Lỗi kết nối Firestore')) {
          errorMsg = 'Lỗi kết nối Firestore. Vui lòng thử lại sau vài giây.';
        } else if (errorStr.contains('Lỗi kết nối mạng')) {
          errorMsg = 'Lỗi kết nối mạng. Vui lòng kiểm tra kết nối và thử lại.';
        } else if (errorStr.contains('Không có quyền') || errorStr.contains('permission-denied')) {
          errorMsg = 'Không có quyền gửi tin nhắn. Vui lòng kiểm tra quyền truy cập.';
        } else if (errorStr.contains('INTERNAL ASSERTION FAILED') || 
            errorStr.contains('Unexpected state') ||
            errorStr.contains('Dart exception thrown from converted Future')) {
          errorMsg = 'Lỗi kết nối Firestore. Vui lòng thử lại sau vài giây.';
        } else if (errorStr.contains('network') || errorStr.contains('timeout') || 
                   errorStr.contains('unavailable')) {
          errorMsg = 'Lỗi kết nối mạng. Vui lòng kiểm tra kết nối và thử lại.';
        } else if (errorStr.contains('Timeout')) {
          errorMsg = 'Timeout khi gửi tin nhắn. Vui lòng kiểm tra kết nối mạng.';
        }
        
        print('❌ Error in _sendMessageRetry: $errorStr');
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Thử lại',
              textColor: Colors.white,
              onPressed: () {
                // Thử gửi lại tin nhắn đã lưu
                if (_pendingMessage != null) {
                  _sendMessageRetry(_pendingMessage!, senderId);
                }
              },
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    // KHÔNG clear cache khi dispose - giữ lại để khi quay lại vẫn có dữ liệu
    // Cache sẽ được giữ trong ChatService._roomToMessages
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Cần gọi để AutomaticKeepAliveClientMixin hoạt động
    final me = context.read<AuthService>().currentUser;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _chat.streamRoom(widget.roomId),
              builder: (context, snap) {
                // Debug
                print('🔄 StreamBuilder state: ${snap.connectionState}, hasData: ${snap.hasData}, hasError: ${snap.hasError}');
                if (snap.hasError) {
                  print('❌ Stream error: ${snap.error}');
                }
                
                // Hiển thị ngay, không chờ loading
                final items = snap.data ?? [];
                print('📊 Current items count: ${items.length}');
                
                // Merge với cache để đảm bảo có tin nhắn mới nhất
                // (tin nhắn mới có thể đã được thêm vào _cachedMessages trước khi stream emit)
                List<ChatMessage> displayItems = items;
                if (_cachedMessages != null && _cachedMessages!.isNotEmpty) {
                  // Merge items từ stream với _cachedMessages
                  final merged = <ChatMessage>[];
                  final messageIds = <String>{};
                  
                  // Thêm tất cả messages từ stream
                  for (final msg in items) {
                    if (!messageIds.contains(msg.id)) {
                      merged.add(msg);
                      messageIds.add(msg.id);
                    }
                  }
                  
                  // Thêm messages từ cache mà chưa có trong stream
                  // (có thể là tin nhắn vừa gửi chưa được Firestore sync)
                  for (final msg in _cachedMessages!) {
                    if (!messageIds.contains(msg.id)) {
                      merged.add(msg);
                      messageIds.add(msg.id);
                    }
                  }
                  
                  // Sort lại sau khi merge
                  merged.sort((a, b) => a.sentAt.compareTo(b.sentAt));
                  displayItems = merged;
                }
                
                // Cập nhật cache khi có dữ liệu từ stream
                if (items.isNotEmpty) {
                  // Kiểm tra xem có tin nhắn mới từ người khác không
                  final me = context.read<AuthService>().currentUser;
                  if (me != null) {
                    final hasNewMessages = items.any((msg) => 
                      msg.senderId != me.id && 
                      !msg.readBy.contains(me.id)
                    );
                    
                    // Nếu có tin nhắn mới, mark as read ngay
                    if (hasNewMessages) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _markAsRead();
                      });
                    }
                  }
                  
                  _cachedMessages = items;
                  // Đồng bộ cache với ChatService để giữ lại khi quay lại
                  _chat.roomToMessages[widget.roomId] = items;
                  // Tắt loading timeout
                  if (_showLoadingTimeout) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() {
                          _showLoadingTimeout = false;
                        });
                      }
                    });
                  }
                } else if (_cachedMessages != null && _cachedMessages!.isNotEmpty) {
                  // Nếu stream trả về empty nhưng có cache, giữ cache trong ChatService
                  _chat.roomToMessages[widget.roomId] = _cachedMessages!;
                }
                
                // Nếu có lỗi, log nhưng vẫn hiển thị data nếu có
                if (snap.hasError) {
                  print('⚠️ Stream error in ChatScreen: ${snap.error}');
                  // Không hiển thị error UI nữa vì stream không throw error
                  // Stream sẽ emit cache hoặc empty list, user vẫn có thể xem tin nhắn cũ
                }
                
                // Nếu đang chờ dữ liệu lần đầu và chưa hết timeout
                if (displayItems.isEmpty && snap.connectionState == ConnectionState.waiting && !_showLoadingTimeout) {
                  // Nếu có cache, hiển thị cache ngay để không bị lag
                  if (_cachedMessages != null && _cachedMessages!.isNotEmpty) {
                    return _buildMessagesList(_cachedMessages!, me);
                  }
                  
                  // Bật flag để sau 3 giây sẽ hiển thị empty state
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        _showLoadingTimeout = true;
                      });
                    }
                  });
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }
                
                // Nếu đã hết timeout hoặc có dữ liệu rỗng, hiển thị empty state
                if (displayItems.isEmpty) {
                  // Nếu có cache, vẫn hiển thị cache
                  if (_cachedMessages != null && _cachedMessages!.isNotEmpty) {
                    return _buildMessagesList(_cachedMessages!, me);
                  }
                  
                  return const Center(
                    child: Text(
                      'Chưa có tin nhắn\nBắt đầu trò chuyện!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }
                
                return _buildMessagesList(displayItems, me);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    decoration: const InputDecoration(hintText: 'Nhắn tin...'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () async {
                    if (me == null || _ctrl.text.trim().isEmpty) return;
                    
                    final textToSend = _ctrl.text.trim();
                    // Xóa text ngay để user có thể gõ tiếp
                    _ctrl.clear();
                    _pendingMessage = null; // Clear pending message
                    
                    // Optimistic update: Thêm tin nhắn vào cache ngay để hiển thị ngay
                    // Không cần chờ Firestore emit snapshot
                    final optimisticMessage = ChatMessage(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      roomId: widget.roomId,
                      senderId: me.id,
                      text: textToSend,
                      sentAt: DateTime.now(),
                    );
                    
                    // Cập nhật cache và rebuild UI ngay
                    if (_cachedMessages == null) {
                      _cachedMessages = [];
                    }
                    // Kiểm tra xem tin nhắn đã có chưa (tránh duplicate)
                    if (!_cachedMessages!.any((m) => m.id == optimisticMessage.id)) {
                      _cachedMessages!.add(optimisticMessage);
                      // Sort lại theo sentAt
                      _cachedMessages!.sort((a, b) => a.sentAt.compareTo(b.sentAt));
                      // Rebuild UI ngay để hiển thị tin nhắn
                      if (mounted) {
                        setState(() {});
                      }
                    }
                    
                    try {
                      await _chat.sendMessage(widget.roomId, me.id, textToSend);
                      // Sau khi gửi thành công, cập nhật lại cache từ service
                      // để đảm bảo có đúng ID và timestamp từ Firestore
                      final updatedCache = _chat.roomToMessages[widget.roomId];
                      if (updatedCache != null && updatedCache.isNotEmpty) {
                        _cachedMessages = List.from(updatedCache);
                        if (mounted) {
                          setState(() {});
                        }
                      }
                    } catch (e) {
                      // Nếu lỗi, lưu lại tin nhắn để có thể thử lại
                      _pendingMessage = textToSend;
                      
                      if (mounted) {
                        String errorMsg = 'Không thể gửi tin nhắn. Vui lòng thử lại.';
                        final errorStr = e.toString();
                        
                        // Parse error message từ exception - ưu tiên message từ service
                        if (errorStr.contains('Lỗi kết nối Firestore')) {
                          errorMsg = 'Lỗi kết nối Firestore. Vui lòng thử lại sau vài giây.';
                        } else if (errorStr.contains('Lỗi kết nối mạng')) {
                          errorMsg = 'Lỗi kết nối mạng. Vui lòng kiểm tra kết nối và thử lại.';
                        } else if (errorStr.contains('Không có quyền') || errorStr.contains('permission-denied')) {
                          errorMsg = 'Không có quyền gửi tin nhắn. Vui lòng kiểm tra quyền truy cập.';
                        } else if (errorStr.contains('INTERNAL ASSERTION FAILED') || 
                            errorStr.contains('Unexpected state') ||
                            errorStr.contains('Dart exception thrown from converted Future')) {
                          errorMsg = 'Lỗi kết nối Firestore. Vui lòng thử lại sau vài giây.';
                        } else if (errorStr.contains('network') || errorStr.contains('timeout') || errorStr.contains('unavailable')) {
                          errorMsg = 'Lỗi kết nối mạng. Vui lòng kiểm tra kết nối và thử lại.';
                        } else if (errorStr.contains('Timeout')) {
                          errorMsg = 'Timeout khi gửi tin nhắn. Vui lòng kiểm tra kết nối mạng.';
                        }
                        
                        print('❌ Error sending message: $errorStr');
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(errorMsg),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 5),
                            action: SnackBarAction(
                              label: 'Thử lại',
                              textColor: Colors.white,
                              onPressed: () {
                                // Thử gửi lại tin nhắn đã lưu
                                final currentUser = context.read<AuthService>().currentUser;
                                if (_pendingMessage != null && currentUser != null) {
                                  _sendMessageRetry(_pendingMessage!, currentUser.id);
                                }
                              },
                            ),
                          ),
                        );
                      }
                    }
                  },
                )
              ],
            ),
          )
        ],
      ),
    );
  }
  
  Widget _buildMessagesList(List<ChatMessage> items, dynamic me) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final m = items[i];
        final isMe = m.senderId == me?.id;
        return Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isMe ? const Color(0xFF1E88E5) : Colors.grey[300],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              m.text,
              style: TextStyle(color: isMe ? Colors.white : Colors.black87),
            ),
          ),
        );
      },
    );
  }
}

