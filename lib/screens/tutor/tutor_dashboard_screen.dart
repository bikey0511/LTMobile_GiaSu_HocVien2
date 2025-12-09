import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Trang Gia sư: stream lịch dạy từ Firestore theo tutorId
import 'package:provider/provider.dart';
import '../../services/repository_factory.dart';
import '../../services/auth_service.dart';
import '../../services/wallet_service.dart';
import '../../services/notification_service.dart';
import '../../models/notification.dart';
import '../../models/booking.dart';
import '../../services/class_service.dart';
import 'create_class_screen.dart';
import 'tutor_profile_setup_screen.dart';
import '../../models/tutor.dart';
import '../../models/student.dart';
import '../auth/login_screen.dart';
import '../notification/notification_screen.dart';
import '../material/material_upload_screen.dart';
import '../assignment/assignment_list_screen.dart';
import '../chat/chat_screen.dart';
import '../chat/chat_list_screen.dart';
import '../../services/chat_service.dart';
import '../../services/firestore_refs.dart';
import '../../services/review_service.dart';
import '../../models/review.dart';
import '../video/video_room_screen.dart';
import '../material/material_list_screen.dart';
import 'tutor_booking_history_screen.dart';

class TutorDashboardScreen extends StatelessWidget {
  static const routeName = '/tutor';
  const TutorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    final tutorId = user?.id ?? '';
    final isAdmin = user?.role == UserRole.admin;

    // Nếu là admin, hiển thị thông báo hoặc redirect
    if (isAdmin) {
    return Scaffold(
        appBar: AppBar(title: const Text('Bảng điều khiển Gia sư')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline, size: 64, color: Colors.blue),
              SizedBox(height: 16),
              Text('Bạn đang đăng nhập với tài khoản Admin'),
              SizedBox(height: 8),
              Text('Vui lòng đăng nhập với tài khoản Gia sư để sử dụng tính năng này',
                   style: TextStyle(color: Colors.grey),
                   textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Bảng điều khiển Gia sư'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Tổng quan', icon: Icon(Icons.dashboard)),
              Tab(text: 'Phòng học', icon: Icon(Icons.video_call)),
              Tab(text: 'Lịch dạy theo tháng', icon: Icon(Icons.calendar_month)),
            ],
          ),
        actions: [
          // Icon thông báo
          StreamBuilder<int>(
            stream: NotificationService().unreadCount(tutorId),
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
          ),
          IconButton(
            tooltip: 'Sửa hồ sơ',
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TutorProfileSetupScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await context.read<AuthService>().logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: TabBarView(
        children: [
          // Tab 1: Tổng quan
          _OverviewTab(tutorId: tutorId, user: user),
          // Tab 2: Phòng học
          _ClassroomTab(tutorId: tutorId),
          // Tab 3: Lịch dạy theo tháng
          _MonthlyScheduleTab(tutorId: tutorId),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildFloatingActionButtons(context, tutorId),
          const SizedBox(height: 12),
          // Nút Tin nhắn (riêng biệt, luôn hiển thị) - giống học viên với badge số tin nhắn chưa đọc
          StreamBuilder<int>(
            stream: tutorId.isEmpty 
                ? Stream.value(0) 
                : ChatService().unreadMessageCount(tutorId),
            builder: (context, snap) {
              // Nếu đang loading và chưa có data, hiển thị 0
              final unreadCount = snap.data ?? 0;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  FloatingActionButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ChatListScreen()),
                      );
                    },
                    heroTag: 'chat-list-tutor',
                    elevation: 4,
                    tooltip: 'Tin nhắn',
                    child: const Icon(Icons.chat),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 20,
                          minHeight: 20,
                        ),
                        child: Text(
                          unreadCount > 9 ? '9+' : '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildFloatingActionButtons(BuildContext context, String tutorId) {
    // Chỉ hiển thị nút chat với Admin với badge số tin nhắn chưa đọc
    // Cần lấy adminId trước để tạo roomId cho stream
    return FutureBuilder<String?>(
      future: _getAdminId(),
      builder: (context, adminSnap) {
        if (!adminSnap.hasData) {
          // Nếu chưa có adminId, vẫn hiển thị nút nhưng không có badge
          return FloatingActionButton(
            heroTag: 'chat-admin-tutor',
            onPressed: () async {
              final adminId = await _getAdminId();
              if (context.mounted && adminId != null) {
                final roomId = '$adminId-$tutorId';
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      roomId: roomId,
                      title: 'Chat với Admin',
                    ),
                  ),
                );
              }
            },
            backgroundColor: Colors.orange,
            child: const Icon(Icons.support_agent),
          );
        }
        
        final adminId = adminSnap.data;
        if (adminId == null || tutorId.isEmpty) {
          // Nếu không có adminId hoặc tutorId rỗng, hiển thị nút không có badge
          return FloatingActionButton(
            heroTag: 'chat-admin-tutor',
            onPressed: () async {
              final adminId = await _getAdminId();
              if (context.mounted && adminId != null && tutorId.isNotEmpty) {
                final roomId = '$adminId-$tutorId';
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      roomId: roomId,
                      title: 'Chat với Admin',
                    ),
                  ),
                );
              }
            },
            backgroundColor: Colors.orange,
            child: const Icon(Icons.support_agent),
          );
        }
        
        final roomId = '$adminId-$tutorId';
        
        return StreamBuilder<int>(
          stream: ChatService().unreadMessageCountForRoom(roomId, tutorId),
          builder: (context, snap) {
            // Nếu đang loading và chưa có data, hiển thị 0
            final unreadCount = snap.data ?? 0;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                FloatingActionButton(
                  heroTag: 'chat-admin-tutor',
                  onPressed: () async {
                    if (context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            roomId: roomId,
                            title: 'Chat với Admin',
                          ),
                        ),
                      );
                    }
                  },
                  backgroundColor: Colors.orange,
                  child: const Icon(Icons.support_agent),
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 20,
                        minHeight: 20,
                      ),
                      child: Text(
                        unreadCount > 9 ? '9+' : '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
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
    );
  }
  
  Future<String?> _getAdminId() async {
    try {
      // Thêm timeout để tránh treo
      final usersSnapshot = await FirestoreRefs.users()
          .where('email', isEqualTo: 'admin@giasu.app')
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 5), onTimeout: () {
        throw TimeoutException('Timeout getting admin ID');
      });
      if (usersSnapshot.docs.isNotEmpty) {
        return usersSnapshot.docs.first.id;
      } else {
        final adminSnapshot = await FirestoreRefs.users()
            .where('role', isEqualTo: 'admin')
            .limit(1)
            .get()
            .timeout(const Duration(seconds: 5), onTimeout: () {
          throw TimeoutException('Timeout getting admin ID');
        });
        if (adminSnapshot.docs.isNotEmpty) {
          return adminSnapshot.docs.first.id;
        }
      }
    } catch (e) {
      print('Error getting admin ID: $e');
      // Trả về null thay vì fallback để UI xử lý
      return null;
    }
    return null;
  }
}

// Tab Tổng quan
class _OverviewTab extends StatelessWidget {
  final String tutorId;
  final dynamic user;
  
  const _OverviewTab({required this.tutorId, required this.user});

  @override
  Widget build(BuildContext context) {
    final repo = RepoFactory.booking();
    final classService = ClassService();
    final df = DateFormat('dd/MM');

    return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (user != null)
            Row(
              children: [
                CircleAvatar(radius: 32, backgroundImage: NetworkImage(user.avatarUrl)),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.fullName, style: Theme.of(context).textTheme.titleMedium),
                    Text('Gia sư', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[700])),
                  ],
                )
              ],
            ),
          const SizedBox(height: 16),
          // Trạng thái duyệt hồ sơ - dùng Stream để tự động cập nhật
          if (tutorId.isNotEmpty)
            StreamBuilder<Tutor?>(
              stream: RepoFactory.tutor().streamById(tutorId),
              builder: (context, snap) {
                final t = snap.data;
                if (t == null) {
                  return Card(
                    color: Colors.amber[50],
                    child: ListTile(
                      leading: const Icon(Icons.info_outline, color: Colors.orange),
                      title: const Text('Chưa có hồ sơ gia sư'),
                      subtitle: const Text('Vui lòng hoàn thiện hồ sơ để Admin duyệt.'),
                      trailing: TextButton(onPressed: () {
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TutorProfileSetupScreen()));
                      }, child: const Text('Hoàn thiện')),
                    ),
                  );
                }
                if (!t.approved) {
                  return Card(
                    color: Colors.amber[50],
                    child: ListTile(
                      leading: const Icon(Icons.hourglass_top, color: Colors.orange),
                      title: const Text('Hồ sơ đang chờ Admin duyệt'),
                      subtitle: const Text('Khi được duyệt, bạn sẽ xuất hiện bên Học viên.'),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const TutorProfileSetupScreen()),
                          );
                        },
                        tooltip: 'Chỉnh sửa hồ sơ',
                      ),
                    ),
                  );
                }
                // Nếu đã được duyệt, hiển thị nút chỉnh sửa
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.person, color: Colors.blue),
                    title: Text('Hồ sơ: ${t.name}'),
                    subtitle: Text('${t.subject} • ${t.hourlyRate.toStringAsFixed(0)} đ/giờ'),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const TutorProfileSetupScreen()),
                        );
                      },
                      tooltip: 'Chỉnh sửa hồ sơ',
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 8),
          // Thống kê chi tiết: tính theo booking hiện có (mock/Firestore)
          if (tutorId.isNotEmpty)
            StreamBuilder<List<Booking>>(
              stream: repo.streamForTutor(tutorId),
              builder: (context, snap) {
                final items = snap.data ?? [];
                // Lọc bỏ các booking đã bị hủy khi tính thống kê
                final validBookings = items.where((b) => !b.cancelled).toList();
                final now = DateTime.now();
                
                // Thu nhập tháng này
                final monthIncome = validBookings
                    .where((b) => b.dateTime.year == now.year && b.dateTime.month == now.month && b.paid)
                    .fold<double>(0, (sum, b) => sum + b.priceTotal);
                
                // Số buổi trong 7 ngày
                final weekCount = validBookings
                    .where((b) => b.dateTime.isAfter(now.subtract(const Duration(days: 7))))
                    .length;
                
                // Tổng số buổi đã hoàn thành
                final totalCompleted = validBookings
                    .where((b) => b.completed)
                    .fold<int>(0, (sum, b) => sum + b.completedSessions);
                
                // Tổng thu nhập
                final totalIncome = validBookings
                    .where((b) => b.paid)
                    .fold<double>(0, (sum, b) => sum + b.priceTotal);
                
                // Số học viên đang học
                final activeStudents = validBookings
                    .where((b) => b.accepted && !b.completed && !b.cancelled)
                    .map((b) => b.studentId)
                    .toSet()
                    .length;
                
                // Đánh giá trung bình từ reviews
                return StreamBuilder<List<Review>>(
                  stream: ReviewService().streamForTutor(tutorId),
                  builder: (context, reviewSnap) {
                    final reviews = reviewSnap.data ?? [];
                    final avgRating = reviews.isNotEmpty
                        ? reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length
                        : 0.0;
                    
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _Stat(label: 'Buổi/7 ngày', value: '$weekCount'),
                        _Stat(
                          label: 'Đánh giá',
                          value: avgRating > 0 ? '${avgRating.toStringAsFixed(1)} ⭐ (${reviews.length})' : 'Chưa có',
                        ),
                        _Stat(label: 'Thu nhập (tháng)', value: '${monthIncome.toStringAsFixed(0)}đ'),
                        _Stat(label: 'Tổng buổi học', value: '$totalCompleted'),
                        _Stat(label: 'Tổng thu nhập', value: '${totalIncome.toStringAsFixed(0)}đ'),
                        _Stat(label: 'Học viên đang học', value: '$activeStudents'),
                      ],
                    );
                  },
                );
              },
            ),
          const SizedBox(height: 24),
          // Nút xem lịch sử
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Lịch dạy sắp tới', style: Theme.of(context).textTheme.titleMedium),
              TextButton.icon(
                icon: const Icon(Icons.history, size: 18),
                label: const Text('Xem lịch sử'),
                onPressed: () {
                  Navigator.pushNamed(context, TutorBookingHistoryScreen.routeName);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (tutorId.isNotEmpty)
            Builder(
              builder: (context) {
                // Debug: log tutorId
                print('Loading bookings for tutorId: $tutorId');
                return StreamBuilder<List<Booking>>(
                  stream: repo.streamForTutor(tutorId),
                  builder: (context, snap) {
                    // Debug logs
                    if (snap.hasData) {
                      print('Tutor $tutorId có ${snap.data?.length ?? 0} bookings (tổng), ${snap.data?.where((b) => !b.cancelled).length ?? 0} bookings hợp lệ');
                    }
                    if (snap.hasError) {
                      print('Lỗi khi load bookings cho tutor $tutorId: ${snap.error}');
                    }
                    
                    // Hiển thị dữ liệu cũ nếu có, không chờ loading
                    if (snap.connectionState == ConnectionState.waiting && snap.hasData) {
                      final items = snap.data!;
                      final validBookings = items.where((b) => !b.cancelled).toList();
                      if (validBookings.isEmpty) return const Text('Chưa có lịch dạy');
                  return Column(
                    children: [
                      for (final b in validBookings)
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.schedule, color: Color(0xFF1E88E5)),
                            title: Text(df.format(b.dateTime)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      b.isGroupClass ? Icons.group : Icons.person,
                                      size: 14,
                                      color: b.isGroupClass ? Colors.blue : Colors.grey,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      b.isGroupClass ? 'Học nhóm (${b.groupSize} học viên)' : 'Học 1-1',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: b.isGroupClass ? Colors.blue : Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                                Text('Thời lượng: ${b.durationMinutes} phút'),
                                Text('Thanh toán: ${b.paid ? 'Đã thanh toán' : 'Chưa'}'),
                                Text('Số buổi học: ${b.completedSessions}/${b.totalSessions} buổi'),
                                if (b.cancelled)
                                  Text(
                                    '❌ Đã bị hủy${b.cancelReason != null && b.cancelReason!.isNotEmpty ? ': ${b.cancelReason}' : ''}',
                                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                                  ),
                                if (b.completed && !b.cancelled)
                                  const Text('✅ Đã hoàn thành khóa học', style: TextStyle(color: Colors.green)),
                              ],
                            ),
                            trailing: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (!b.accepted && !b.cancelled) ...[
                                      IconButton(
                                        tooltip: 'Chấp nhận',
                                        icon: const Icon(Icons.check_circle, color: Colors.green),
                                        onPressed: () async {
                                          await RepoFactory.booking().updateAccepted(b.id, true);
                                          try {
                                            final tutor = await RepoFactory.tutor().getById(tutorId);
                                            final notificationService = NotificationService();
                                            // Sau khi gia sư chấp nhận, học viên có thể vào phòng học ngay
                                              await notificationService.create(NotificationModel(
                                                id: DateTime.now().millisecondsSinceEpoch.toString(),
                                                userId: b.studentId,
                                                title: 'Lịch học được chấp nhận',
                                              message: 'Gia sư ${tutor?.name ?? 'Gia sư'} đã chấp nhận lịch học. Phòng học của bạn đã sẵn sàng! Bạn có thể vào phòng học, xem tài liệu và làm bài tập.',
                                                type: 'booking',
                                                createdAt: DateTime.now(),
                                                data: {'bookingId': b.id, 'action': 'classroom'},
                                              ));
                                          } catch (e) {}
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Đã chấp nhận. Học viên có thể vào phòng học, xem tài liệu và làm bài tập ngay.'),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                      IconButton(
                                        tooltip: 'Từ chối',
                                        icon: const Icon(Icons.cancel, color: Colors.redAccent),
                                        onPressed: () async {
                                          final ctrl = TextEditingController();
                                          final ok = await showDialog<bool>(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: const Text('Lý do từ chối'),
                                              content: TextField(
                                                controller: ctrl,
                                                decoration: const InputDecoration(hintText: 'Nhập lý do...'),
                                              ),
                                              actions: [
                                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
                                                FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xác nhận')),
                                              ],
                                            ),
                                          );
                                          if (ok == true) {
                                            final reason = ctrl.text.trim();
                                            await RepoFactory.booking().updateAccepted(b.id, false, reason: reason);
                                            if (b.paid && b.priceTotal > 0) {
                                              try {
                                                final walletService = WalletService();
                                                final refundError = await walletService.refundBooking(
                                                  studentId: b.studentId,
                                                  bookingId: b.id,
                                                  amount: b.priceTotal,
                                                  reason: reason,
                                                );
                                                
                                                if (refundError != null && context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text('Đã từ chối nhưng hoàn tiền thất bại: $refundError'),
                                                      backgroundColor: Colors.orange,
                                                      duration: const Duration(seconds: 5),
                                                    ),
                                                  );
                                                }
                                              } catch (e) {
                                                if (context.mounted) {
                                                  final errorStr = e.toString();
                                                  String errorMsg = 'Đã từ chối nhưng lỗi hoàn tiền. Vui lòng thử lại.';
                                                  
                                                  if (errorStr.contains('network') || errorStr.contains('timeout') || errorStr.contains('unavailable')) {
                                                    errorMsg = 'Đã từ chối nhưng lỗi kết nối mạng khi hoàn tiền. Vui lòng kiểm tra kết nối và thử lại.';
                                                  } else if (errorStr.contains('permission-denied')) {
                                                    errorMsg = 'Đã từ chối nhưng không có quyền hoàn tiền. Vui lòng liên hệ admin.';
                                                  }
                                                  
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text(errorMsg),
                                                      backgroundColor: Colors.orange,
                                                      duration: const Duration(seconds: 5),
                                                    ),
                                                  );
                                                }
                                              }
                                            }
                                            try {
                                              final tutor = await RepoFactory.tutor().getById(tutorId);
                                              final notificationService = NotificationService();
                                              await notificationService.notifyBookingRejected(
                                                b.studentId,
                                                b.id,
                                                tutor?.name ?? 'Gia sư',
                                                reason,
                                              );
                                            } catch (e) {}
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text(b.paid ? 'Đã từ chối và hoàn tiền ${b.priceTotal.toStringAsFixed(0)}₫ cho học viên' : 'Đã từ chối lịch học'),
                                                  backgroundColor: b.paid ? Colors.green : Colors.orange,
                                                ),
                                              );
                                            }
                                          }
                                        },
                                      ),
                                    ],
                                    if (b.cancelled)
                                      const Tooltip(
                                        message: 'Đã bị hủy',
                                        child: Icon(Icons.cancel, color: Colors.red),
                                      ),
                                    if (b.accepted && !b.cancelled)
                                      const Icon(Icons.verified, color: Colors.green),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                }
                
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snap.hasError) {
                  return Column(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(height: 8),
                      Text('Lỗi: ${snap.error}'),
                      const SizedBox(height: 8),
                      const Text('Vui lòng thử lại sau', style: TextStyle(color: Colors.grey)),
                    ],
                  );
                }
                
                final items = snap.data ?? [];
                // Lọc bỏ các booking đã bị hủy
                final validBookings = items.where((b) => !b.cancelled).toList();
                if (validBookings.isEmpty) return const Text('Chưa có lịch dạy');
                return Column(
                  children: [
                    for (final b in validBookings)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.schedule, color: Color(0xFF1E88E5)),
                          title: Text(df.format(b.dateTime)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    b.isGroupClass ? Icons.group : Icons.person,
                                    size: 14,
                                    color: b.isGroupClass ? Colors.blue : Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    b.isGroupClass ? 'Học nhóm (${b.groupSize} học viên)' : 'Học 1-1',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: b.isGroupClass ? Colors.blue : Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                              Text('Thời lượng: ${b.durationMinutes} phút'),
                              Text('Thanh toán: ${b.paid ? 'Đã thanh toán' : 'Chưa'}'),
                              Text('Số buổi học: ${b.completedSessions}/${b.totalSessions} buổi'),
                              if (b.cancelled)
                                Text(
                                  '❌ Đã bị hủy${b.cancelReason != null && b.cancelReason!.isNotEmpty ? ': ${b.cancelReason}' : ''}',
                                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                                ),
                              if (b.completed && !b.cancelled)
                                const Text('✅ Đã hoàn thành khóa học', style: TextStyle(color: Colors.green)),
                            ],
                          ),
                          trailing: SizedBox(
                            width: 140,
                            child: Column(
                            mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                                Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  alignment: WrapAlignment.end,
                                children: [
                                  if (!b.accepted && !b.cancelled) ...[
                                    IconButton(
                                      tooltip: 'Chấp nhận',
                                      icon: const Icon(Icons.check_circle, color: Colors.green, size: 20),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () async {
                                        await RepoFactory.booking().updateAccepted(b.id, true);
                                        // Gửi thông báo cho học viên
                                        try {
                                          final tutor = await RepoFactory.tutor().getById(tutorId);
                                          final notificationService = NotificationService();
                                          
                                          // Sau khi gia sư chấp nhận, học viên có thể vào phòng học ngay
                                            await notificationService.create(NotificationModel(
                                              id: DateTime.now().millisecondsSinceEpoch.toString(),
                                              userId: b.studentId,
                                              title: 'Lịch học được chấp nhận',
                                            message: 'Gia sư ${tutor?.name ?? 'Gia sư'} đã chấp nhận lịch học. Phòng học của bạn đã sẵn sàng! Bạn có thể vào phòng học, xem tài liệu và làm bài tập.',
                                              type: 'booking',
                                              createdAt: DateTime.now(),
                                              data: {'bookingId': b.id, 'action': 'classroom'},
                                            ));
                                        } catch (e) {
                                          // Bỏ qua lỗi thông báo
                                        }
                                        
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Đã chấp nhận. Học viên có thể vào phòng học, xem tài liệu và làm bài tập ngay.'),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                    IconButton(
                                      tooltip: 'Từ chối',
                                      icon: const Icon(Icons.cancel, color: Colors.redAccent, size: 20),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () async {
                                        final ctrl = TextEditingController();
                                        final ok = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('Lý do từ chối'),
                                            content: TextField(
                                              controller: ctrl,
                                              decoration: const InputDecoration(hintText: 'Nhập lý do...'),
                                            ),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
                                              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xác nhận')),
                                            ],
                                          ),
                                        );
                                        if (ok == true) {
                                          final reason = ctrl.text.trim();
                                          await RepoFactory.booking().updateAccepted(b.id, false, reason: reason);
                                          
                                          // Nếu học viên đã thanh toán, hoàn tiền lại
                                          bool refundSuccess = false;
                                          if (b.paid && b.priceTotal > 0) {
                                            try {
                                              final walletService = WalletService();
                                              final refundError = await walletService.refundBooking(
                                                studentId: b.studentId,
                                                bookingId: b.id,
                                                amount: b.priceTotal,
                                                reason: reason,
                                              );
                                              
                                              if (refundError == null) {
                                                refundSuccess = true;
                                              } else {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text('Đã từ chối nhưng hoàn tiền thất bại: $refundError'),
                                                    backgroundColor: Colors.orange,
                                                  ),
                                                );
                                              }
                                            } catch (e) {
                                              // Bỏ qua lỗi hoàn tiền nhưng vẫn tiếp tục
                                              final errorStr = e.toString();
                                              String errorMsg = 'Đã từ chối nhưng lỗi hoàn tiền. Vui lòng thử lại.';
                                              
                                              // Parse error message để hiển thị rõ ràng hơn
                                              if (errorStr.contains('Dart exception thrown from converted Future')) {
                                                // Nếu là lỗi từ Future, lấy error message thực sự
                                                if (errorStr.contains('Lỗi hoàn tiền:')) {
                                                  // Nếu đã có error message từ refundBooking, dùng nó
                                                  final match = RegExp(r'Lỗi hoàn tiền: (.+)').firstMatch(errorStr);
                                                  if (match != null) {
                                                    errorMsg = 'Đã từ chối nhưng hoàn tiền thất bại: ${match.group(1)}';
                                                  }
                                                } else {
                                                  errorMsg = 'Đã từ chối nhưng lỗi hoàn tiền. Vui lòng thử lại sau vài giây.';
                                                }
                                              } else if (errorStr.contains('network') || errorStr.contains('timeout') || errorStr.contains('unavailable')) {
                                                errorMsg = 'Đã từ chối nhưng lỗi kết nối mạng khi hoàn tiền. Vui lòng kiểm tra kết nối và thử lại.';
                                              } else if (errorStr.contains('permission-denied')) {
                                                errorMsg = 'Đã từ chối nhưng không có quyền hoàn tiền. Vui lòng liên hệ admin.';
                                              }
                                              
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text(errorMsg),
                                                  backgroundColor: Colors.orange,
                                                  duration: const Duration(seconds: 5),
                                                ),
                                              );
                                            }
                                          }
                                          
                                          // Gửi thông báo cho học viên
                                          try {
                                            final tutor = await RepoFactory.tutor().getById(tutorId);
                                            final notificationService = NotificationService();
                                            await notificationService.notifyBookingRejected(
                                              b.studentId,
                                              b.id,
                                              tutor?.name ?? 'Gia sư',
                                              reason,
                                            );
                                            
                                            // Nếu đã hoàn tiền thành công, gửi thông báo riêng về hoàn tiền
                                            if (refundSuccess) {
                                              await notificationService.notifyRefund(
                                                b.studentId,
                                                b.id,
                                                b.priceTotal,
                                                reason,
                                              );
                                            }
                                          } catch (e) {
                                            // Bỏ qua lỗi thông báo
                                          }
                                          
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                b.paid 
                                                    ? 'Đã từ chối và hoàn tiền ${b.priceTotal.toStringAsFixed(0)}₫ cho học viên'
                                                    : 'Đã từ chối lịch học',
                                              ),
                                              backgroundColor: b.paid ? Colors.green : Colors.orange,
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                  ],
                                  if (b.cancelled)
                                    const Tooltip(
                                      message: 'Đã bị hủy',
                                        child: Icon(Icons.cancel, color: Colors.red, size: 20),
                                    ),
                                  if (b.accepted && !b.cancelled)
                                      const Icon(Icons.verified, color: Colors.green, size: 20),
                                    // Sau khi gia sư xác nhận, có thể gửi tài liệu và bài tập ngay
                                    if (b.accepted && !b.cancelled) ...[
                                    IconButton(
                                      tooltip: 'Thêm tài liệu',
                                        icon: const Icon(Icons.upload_file, color: Colors.orange, size: 20),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => MaterialUploadScreen(booking: b),
                                          ),
                                        );
                                      },
                                    ),
                                    IconButton(
                                      tooltip: 'Quản lý bài tập',
                                        icon: const Icon(Icons.assignment, color: Colors.purple, size: 20),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => AssignmentListScreen(
                                              booking: b,
                                              isTutor: true,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ],
                              ),
                                // Nút hoàn thành buổi học (chỉ hiển thị khi đã chấp nhận và chưa hoàn thành hết)
                                if (b.accepted && !b.completed && b.completedSessions < b.totalSessions)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Xác nhận'),
                                          content: Text(
                                            'Bạn đã hoàn thành buổi học ${b.completedSessions + 1}/${b.totalSessions}?',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context, false),
                                              child: const Text('Hủy'),
                                            ),
                                            FilledButton(
                                              onPressed: () => Navigator.pop(context, true),
                                              child: const Text('Xác nhận'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                          final newCompletedSessions = b.completedSessions + 1;
                                          await RepoFactory.booking().updateCompletedSessions(b.id, newCompletedSessions);
                                        
                                        // Tính tiền cho buổi học này
                                        // Nếu học nhóm: priceTotal là giá của 1 học viên, cần nhân với số học viên
                                        // Nếu học 1-1: priceTotal là giá đầy đủ
                                        final pricePerSession = b.isGroupClass 
                                            ? (b.priceTotal * b.groupSize) / b.totalSessions  // Tổng giá nhóm / số buổi
                                            : b.priceTotal / b.totalSessions;  // Giá 1-1 / số buổi
                                        
                                        // Cộng tiền vào ví gia sư
                                        final walletService = WalletService();
                                        final tutorId = context.read<AuthService>().currentUser?.id;
                                        if (tutorId != null) {
                                          await walletService.addEarning(
                                            tutorId: tutorId,
                                            bookingId: b.id,
                                            studentId: b.studentId,
                                            amount: pricePerSession,
                                          );
                                        }
                                          
                                          // Nếu đã hoàn thành khóa học, gửi thông báo cho học viên
                                          if (newCompletedSessions >= b.totalSessions) {
                                            try {
                                              final tutor = await RepoFactory.tutor().getById(tutorId ?? '');
                                              final notificationService = NotificationService();
                                              await notificationService.create(NotificationModel(
                                                id: DateTime.now().millisecondsSinceEpoch.toString(),
                                                userId: b.studentId,
                                                title: 'Khóa học đã hoàn thành',
                                                message: 'Chúc mừng! Bạn đã hoàn thành khóa học với gia sư ${tutor?.name ?? 'Gia sư'}. Hãy đánh giá để giúp chúng tôi cải thiện dịch vụ!',
                                                type: 'booking',
                                                createdAt: DateTime.now(),
                                                data: {'bookingId': b.id, 'action': 'review'},
                                              ));
                                            } catch (e) {
                                              // Bỏ qua lỗi thông báo
                                            }
                                        }
                                        
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                newCompletedSessions >= b.totalSessions
                                                    ? 'Chúc mừng! Khóa học đã hoàn thành. Học viên có thể đánh giá khóa học.'
                                                    : 'Đã đánh dấu hoàn thành buổi học ${newCompletedSessions}/${b.totalSessions}. Tiền đã được cộng vào ví.',
                                            ),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      }
                                    },
                                      icon: const Icon(Icons.check_circle_outline, size: 14),
                                      label: Text('Buổi ${b.completedSessions + 1}', style: const TextStyle(fontSize: 12)),
                                    style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                        minimumSize: const Size(0, 28),
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                ),
                            ],
                            ),
                          ),
                          isThreeLine: true,
                        ),
                      ),
                  ],
                );
                  },
                );
              },
            )
          else
            const Text('Vui lòng đăng nhập'),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Lớp của tôi', style: Theme.of(context).textTheme.titleMedium),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateClassScreen()),
                ),
                child: const Text('Tạo lớp'),
              )
            ],
          ),
          const SizedBox(height: 8),
          for (final c in classService.getForTutor(tutorId))
            Card(
              child: ListTile(
                title: Text(c.title),
                subtitle: Text('${c.subject} • ${c.hourlyRate.toStringAsFixed(0)} đ/giờ'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    classService.delete(c.id);
                    (context as Element).markNeedsBuild();
                  },
                ),
              ),
            ),
          const SizedBox(height: 32),
          // Nút đăng xuất ở cuối trang
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                await context.read<AuthService>().logout();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
              icon: const Icon(Icons.logout),
              label: const Text('Đăng xuất'),
            ),
          ),
        ],
      );
  }
}

// Tab Phòng học
class _ClassroomTab extends StatelessWidget {
  final String tutorId;
  
  const _ClassroomTab({required this.tutorId});

  @override
  Widget build(BuildContext context) {
    final repo = RepoFactory.booking();
    final df = DateFormat('dd/MM/yyyy HH:mm');
    
    return StreamBuilder<List<Booking>>(
      stream: repo.streamForTutor(tutorId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final bookings = snap.data ?? [];
        // Chỉ hiển thị các booking đã được chấp nhận và chưa bị hủy
        final acceptedBookings = bookings.where((b) => b.accepted && !b.cancelled).toList();
        
        if (acceptedBookings.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.video_call_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('Chưa có phòng học nào', style: TextStyle(fontSize: 16, color: Colors.grey)),
                SizedBox(height: 8),
                Text('Phòng học sẽ hiển thị sau khi bạn chấp nhận lịch học', 
                     style: TextStyle(fontSize: 14, color: Colors.grey),
                     textAlign: TextAlign.center),
              ],
            ),
          );
        }
        
        acceptedBookings.sort((a, b) => b.dateTime.compareTo(a.dateTime));
        
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final b in acceptedBookings)
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const Icon(Icons.video_call, color: Colors.blue),
                  title: Text(
                    'Phòng học - ${df.format(b.dateTime)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('Thời lượng: ${b.durationMinutes} phút'),
                      Text('Số buổi: ${b.completedSessions}/${b.totalSessions}'),
                      if (b.isGroupClass)
                        Text('Học nhóm (${b.groupSize} học viên)'),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.folder, color: Colors.orange),
                        tooltip: 'Tài liệu',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MaterialListScreen(
                                booking: b,
                                isTutor: true,
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
                                isTutor: true,
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
                          title: 'Phòng học với học viên',
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

// Tab Lịch dạy theo tháng
class _MonthlyScheduleTab extends StatefulWidget {
  final String tutorId;
  
  const _MonthlyScheduleTab({required this.tutorId});

  @override
  State<_MonthlyScheduleTab> createState() => _MonthlyScheduleTabState();
}

class _MonthlyScheduleTabState extends State<_MonthlyScheduleTab> {
  DateTime _selectedMonth = DateTime.now();
  final dfMonth = DateFormat('MM/yyyy');

  @override
  Widget build(BuildContext context) {
    final repo = RepoFactory.booking();
    
    return Column(
      children: [
        // Header với nút chọn tháng
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  setState(() {
                    _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
                  });
                },
              ),
              Text(
                dfMonth.format(_selectedMonth),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  setState(() {
                    _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
                  });
                },
              ),
            ],
          ),
        ),
        // Danh sách lịch dạy trong tháng
        Expanded(
          child: StreamBuilder<List<Booking>>(
            stream: repo.streamForTutor(widget.tutorId),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              
              final bookings = snap.data ?? [];
              // Lọc bookings trong tháng đã chọn
              final monthBookings = bookings.where((b) {
                return b.dateTime.year == _selectedMonth.year &&
                       b.dateTime.month == _selectedMonth.month &&
                       !b.cancelled;
              }).toList();
              
              if (monthBookings.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text('Không có lịch dạy trong tháng ${dfMonth.format(_selectedMonth)}', 
                           style: const TextStyle(fontSize: 16, color: Colors.grey)),
                    ],
                  ),
                );
              }
              
              // Sắp xếp theo ngày
              monthBookings.sort((a, b) => a.dateTime.compareTo(b.dateTime));
              
              // Nhóm theo ngày
              final Map<int, List<Booking>> bookingsByDay = {};
              for (final b in monthBookings) {
                final day = b.dateTime.day;
                if (!bookingsByDay.containsKey(day)) {
                  bookingsByDay[day] = [];
                }
                bookingsByDay[day]!.add(b);
              }
              
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final entry in bookingsByDay.entries)
                    Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(12),
                                topRight: Radius.circular(12),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today, size: 20, color: Colors.blue),
                                const SizedBox(width: 8),
                                Text(
                                  'Ngày ${entry.key}/${_selectedMonth.month}/${_selectedMonth.year}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${entry.value.length} buổi',
                                  style: TextStyle(
                                    color: Colors.blue[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ...entry.value.map((b) => ListTile(
                            leading: Icon(
                              b.isGroupClass ? Icons.group : Icons.person,
                              color: b.isGroupClass ? Colors.blue : Colors.grey,
                            ),
                            title: Text(DateFormat('HH:mm').format(b.dateTime)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(b.isGroupClass ? 'Học nhóm (${b.groupSize} học viên)' : 'Học 1-1'),
                                Text('Thời lượng: ${b.durationMinutes} phút'),
                                Row(
                                  children: [
                                    if (b.accepted)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.green[50],
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text('Đã chấp nhận', 
                                            style: TextStyle(fontSize: 11, color: Colors.green)),
                                      ),
                                    if (b.paid) ...[
                                      const SizedBox(width: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.blue[50],
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text('Đã thanh toán', 
                                            style: TextStyle(fontSize: 11, color: Colors.blue)),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                            trailing: b.accepted && !b.cancelled
                                ? const Icon(Icons.check_circle, color: Colors.green)
                                : b.cancelled
                                    ? const Icon(Icons.cancel, color: Colors.red)
                                    : const Icon(Icons.pending, color: Colors.orange),
                          )),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      width: 180,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[700])),
          const SizedBox(height: 6),
          Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: const Color(0xFF1E88E5))),
        ],
      ),
    );
  }
}
