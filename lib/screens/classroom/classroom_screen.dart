import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/booking.dart';
import '../../models/tutor.dart';
import '../../services/auth_service.dart';
import '../../services/repository_factory.dart';
import '../video/video_room_screen.dart';
import '../chat/chat_screen.dart';
import '../material/material_list_screen.dart';
import '../assignment/assignment_list_screen.dart';
import '../../services/notification_service.dart';
import '../notification/notification_screen.dart';

/// Màn hình Phòng học - hiển thị danh sách các phòng học đã thanh toán và được chấp nhận
class ClassroomScreen extends StatefulWidget {
  static const routeName = '/classroom';
  const ClassroomScreen({super.key});

  @override
  State<ClassroomScreen> createState() => _ClassroomScreenState();
}

class _ClassroomScreenState extends State<ClassroomScreen> with AutomaticKeepAliveClientMixin {
  List<Booking>? _cachedBookings;
  
  @override
  bool get wantKeepAlive => true;

  // Helper widget để hiển thị icon thông báo
  Widget _buildNotificationIcon(String userId) {
    return StreamBuilder<int>(
      stream: NotificationService().unreadCount(userId),
      builder: (context, snap) {
        final unreadCount = snap.data ?? 0;
        return Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () {
                Navigator.pushNamed(context, NotificationScreen.routeName);
              },
            ),
            if (unreadCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    unreadCount > 9 ? '9+' : '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Cần gọi để AutomaticKeepAliveClientMixin hoạt động
    final user = context.watch<AuthService>().currentUser;
    final bookingRepo = RepoFactory.booking();

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Phòng học'),
          actions: [
            // Icon thông báo
            Builder(
              builder: (context) {
                final currentUser = context.watch<AuthService>().currentUser;
                if (currentUser == null) return const SizedBox.shrink();
                return StreamBuilder<int>(
                  stream: NotificationService().unreadCount(currentUser.id),
                  builder: (context, snap) {
                    final unreadCount = snap.data ?? 0;
                    return Stack(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.notifications_outlined),
                          onPressed: () {
                            Navigator.pushNamed(context, NotificationScreen.routeName);
                          },
                        ),
                        if (unreadCount > 0)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Text(
                                unreadCount > 9 ? '9+' : '$unreadCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
        body: const Center(child: Text('Vui lòng đăng nhập')),
      );
    }

    return StreamBuilder<List<Booking>>(
      stream: bookingRepo.streamForStudent(user.id),
      builder: (context, snap) {
        // Cập nhật cache khi có dữ liệu
        if (snap.hasData && snap.data != null) {
          _cachedBookings = snap.data;
        }
        
        // Hiển thị dữ liệu cũ nếu có, không chờ loading
        if (snap.connectionState == ConnectionState.waiting && snap.hasData) {
          final bookings = snap.data!;
          final acceptedBookings = bookings.where((b) => b.accepted && !b.cancelled).toList();
          if (acceptedBookings.isEmpty) {
            return Scaffold(
              appBar: AppBar(
                title: const Text('Phòng học'),
                actions: [_buildNotificationIcon(user.id)],
              ),
              body: _buildEmptyState(),
            );
          }
          acceptedBookings.sort((a, b) => b.dateTime.compareTo(a.dateTime));
          return _buildClassroomList(context, acceptedBookings);
        }
        
        if (snap.connectionState == ConnectionState.waiting) {
          // Nếu có cache, hiển thị cache ngay
          if (_cachedBookings != null && _cachedBookings!.isNotEmpty) {
            final acceptedBookings = _cachedBookings!.where((b) => b.accepted && !b.cancelled).toList();
            if (acceptedBookings.isNotEmpty) {
              acceptedBookings.sort((a, b) => b.dateTime.compareTo(a.dateTime));
              return _buildClassroomList(context, acceptedBookings);
            }
          }
          
          // Hiển thị loading với timeout để tránh xoay mãi
          return Scaffold(
            appBar: AppBar(
              title: const Text('Phòng học'),
              actions: [_buildNotificationIcon(user.id)],
            ),
            body: FutureBuilder(
              future: Future.delayed(const Duration(seconds: 3)),
              builder: (context, timeoutSnap) {
                if (timeoutSnap.connectionState == ConnectionState.done) {
                  // Sau 3 giây vẫn chưa có dữ liệu, hiển thị empty state
                  return _buildEmptyState();
                }
                return const Center(child: CircularProgressIndicator());
              },
            ),
          );
        }
        
        if (snap.hasError) {
          // Nếu có lỗi nhưng có cache, vẫn hiển thị cache
          if (_cachedBookings != null && _cachedBookings!.isNotEmpty) {
            final acceptedBookings = _cachedBookings!.where((b) => b.accepted && !b.cancelled).toList();
            if (acceptedBookings.isNotEmpty) {
              acceptedBookings.sort((a, b) => b.dateTime.compareTo(a.dateTime));
              return _buildClassroomList(context, acceptedBookings);
            }
          }
          
          return Scaffold(
            appBar: AppBar(
              title: const Text('Phòng học'),
              actions: [_buildNotificationIcon(user.id)],
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Lỗi: ${snap.error}'),
                  const SizedBox(height: 16),
                  const Text(
                    'Vui lòng thử lại sau',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }
        
        final bookings = snap.data ?? _cachedBookings ?? [];
        // Sau khi gia sư xác nhận, học viên có thể vào phòng học (chỉ cần accepted, không cần paid)
        final acceptedBookings = bookings.where((b) => b.accepted && !b.cancelled).toList();
        
        if (acceptedBookings.isEmpty) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Phòng học'),
              actions: [_buildNotificationIcon(user.id)],
            ),
            body: _buildEmptyState(),
          );
        }

        // Sắp xếp theo thời gian (mới nhất trước)
        acceptedBookings.sort((a, b) => b.dateTime.compareTo(a.dateTime));

        return _buildClassroomList(context, acceptedBookings);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.meeting_room_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Chưa có phòng học',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Phòng học chỉ hiển thị sau khi gia sư đã chấp nhận lịch học của bạn.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassroomList(BuildContext context, List<Booking> acceptedBookings) {
    final user = context.read<AuthService>().currentUser;
    final groupBookings = acceptedBookings.where((b) => b.isGroupClass).toList();
    final hasGroupClass = groupBookings.isNotEmpty;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Phòng học'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Force refresh by rebuilding
          setState(() {});
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
          for (final b in acceptedBookings)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: StreamBuilder<Tutor?>(
                stream: RepoFactory.tutor().streamById(b.tutorId),
                builder: (context, tutorSnap) {
                  final tutor = tutorSnap.data;
                  final tutorName = tutor?.name ?? 'Gia sư';
                  
                  return ListTile(
                    leading: const Icon(Icons.video_call, color: Colors.blue),
                    title: Text(
                      tutorName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          '${DateFormat('dd/MM/yyyy HH:mm').format(b.dateTime)}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                        ),
                        Text('Thời lượng: ${b.durationMinutes} phút'),
                        Text('Số buổi: ${b.completedSessions}/${b.totalSessions}'),
                        if (b.completed)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '✅ Đã hoàn thành',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.green.shade800,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        if (b.isGroupClass)
                          Text('Học nhóm (${b.groupSize} học viên)'),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chat, color: Colors.green),
                          tooltip: 'Chat với gia sư',
                          onPressed: () {
                            // Tạo room ID với sorted IDs để đảm bảo consistency
                            final ids = [b.tutorId, user!.id]..sort();
                            final roomId = '${ids[0]}-${ids[1]}';
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  roomId: roomId,
                                  title: 'Chat với $tutorName',
                                ),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.folder, color: Colors.orange),
                          tooltip: 'Tài liệu',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MaterialListScreen(
                                  booking: b,
                                  isTutor: false,
                                ),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.assignment, color: Colors.purple),
                          tooltip: 'Bài tập',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AssignmentListScreen(
                                  booking: b,
                                  isTutor: false,
                                ),
                              ),
                            );
                          },
                        ),
                        const Icon(Icons.arrow_forward_ios, size: 16),
                      ],
                    ),
                    onTap: () {
                      final roomId = '${b.tutorId}-${b.studentId}-${b.id}';
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VideoRoomScreen(
                            roomId: roomId,
                            title: 'Phòng học với $tutorName',
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
        ],
        ),
      ),
      floatingActionButton: user != null && acceptedBookings.isNotEmpty && hasGroupClass
          ? FloatingActionButton(
              heroTag: 'group-chat-student',
              onPressed: () {
                final firstGroupBooking = groupBookings.first;
                final groupRoomId = 'group-${firstGroupBooking.id}';
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      roomId: groupRoomId,
                      title: 'Chat nhóm học - ${DateFormat('dd/MM/yyyy').format(firstGroupBooking.dateTime)}',
                    ),
                  ),
                );
              },
              backgroundColor: Colors.lightBlue,
              child: const Icon(Icons.chat_bubble_outline, color: Colors.white),
            )
          : null,
    );
  }
}

