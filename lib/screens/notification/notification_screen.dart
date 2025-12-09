import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/notification.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';

class NotificationScreen extends StatefulWidget {
  static const routeName = '/notifications';
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> with AutomaticKeepAliveClientMixin {
  List<NotificationModel>? _cachedNotifications;
  
  @override
  bool get wantKeepAlive => true;

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'booking':
        return Icons.event;
      case 'payment':
        return Icons.payment;
      case 'approval':
        return Icons.check_circle;
      case 'withdrawal':
        return Icons.account_balance_wallet;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'booking':
        return Colors.blue;
      case 'payment':
        return Colors.green;
      case 'approval':
        return Colors.green;
      case 'withdrawal':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Cần gọi để AutomaticKeepAliveClientMixin hoạt động
    final user = context.watch<AuthService>().currentUser;
    final notificationService = NotificationService();

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Thông báo')),
        body: const Center(child: Text('Vui lòng đăng nhập')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
        actions: [
          // Nút xóa tất cả thông báo
          StreamBuilder<List<NotificationModel>>(
            stream: notificationService.streamForUser(user.id),
            builder: (context, snap) {
              final notifications = snap.data ?? [];
              if (notifications.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.delete_sweep),
                tooltip: 'Xóa tất cả thông báo',
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Xóa tất cả thông báo'),
                      content: Text('Bạn có chắc muốn xóa tất cả ${notifications.length} thông báo? Hành động này không thể hoàn tác.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Hủy'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: FilledButton.styleFrom(backgroundColor: Colors.red),
                          child: const Text('Xóa tất cả'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await notificationService.deleteAll(user.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Đã xóa tất cả thông báo'),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  }
                },
              );
            },
          ),
          // Nút đánh dấu tất cả đã đọc
          StreamBuilder<int>(
            stream: notificationService.unreadCount(user.id),
            builder: (context, snap) {
              final unreadCount = snap.data ?? 0;
              if (unreadCount == 0) return const SizedBox.shrink();
              return TextButton(
                onPressed: () async {
                  await notificationService.markAllAsRead(user.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đã đánh dấu tất cả đã đọc')),
                    );
                  }
                },
                child: const Text('Đánh dấu tất cả đã đọc'),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: notificationService.streamForUser(user.id),
        builder: (context, snap) {
          // Cập nhật cache khi có dữ liệu
          if (snap.hasData && snap.data != null) {
            _cachedNotifications = snap.data;
          }
          
          // Nếu có lỗi, hiển thị cache nếu có
          if (snap.hasError) {
            if (_cachedNotifications != null && _cachedNotifications!.isNotEmpty) {
              return _buildNotificationList(context, _cachedNotifications!, notificationService);
            }
            
            return Center(
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
            );
          }
          
          // Nếu có dữ liệu, hiển thị ngay (dù đang loading hay không)
          if (snap.hasData) {
            final notifications = snap.data!;
            if (notifications.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'Chưa có thông báo',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  ],
                ),
              );
            }
            return _buildNotificationList(context, notifications, notificationService);
          }
          
          // Nếu đang loading, hiển thị cache nếu có
          if (snap.connectionState == ConnectionState.waiting) {
            if (_cachedNotifications != null && _cachedNotifications!.isNotEmpty) {
              return _buildNotificationList(context, _cachedNotifications!, notificationService);
            }
            
            // Sau 3 giây, hiển thị empty state thay vì loading
            return FutureBuilder(
              future: Future.delayed(const Duration(seconds: 3)),
              builder: (context, futureSnap) {
                if (futureSnap.connectionState == ConnectionState.done) {
                  // Sau 3 giây, hiển thị empty state
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text(
                          'Chưa có thông báo',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }
                return const Center(child: CircularProgressIndicator());
              },
            );
          }
          
          // Fallback: hiển thị empty state
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'Chưa có thông báo',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildNotificationList(BuildContext context, List<NotificationModel> notifications, NotificationService notificationService) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: notifications.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final notif = notifications[index];
        return Card(
          color: notif.read ? null : Colors.blue[50],
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getNotificationColor(notif.type).withOpacity(0.1),
              child: Icon(
                _getNotificationIcon(notif.type),
                color: _getNotificationColor(notif.type),
              ),
            ),
            title: Text(
              notif.title,
              style: TextStyle(
                fontWeight: notif.read ? FontWeight.normal : FontWeight.bold,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(notif.message),
                const SizedBox(height: 4),
                Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(notif.createdAt),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!notif.read)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'Xóa thông báo',
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Xóa thông báo'),
                        content: const Text('Bạn có chắc muốn xóa thông báo này?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Hủy'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: FilledButton.styleFrom(backgroundColor: Colors.red),
                            child: const Text('Xóa'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await notificationService.delete(notif.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đã xóa thông báo'),
                            backgroundColor: Colors.green,
                            duration: Duration(seconds: 1),
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
            onTap: () async {
              if (!notif.read) {
                await notificationService.markAsRead(notif.id);
              }
              // Có thể thêm navigation dựa trên data
              if (notif.data != null && notif.data!['bookingId'] != null) {
                // Navigate to booking detail if needed
              }
            },
          ),
        );
      },
    );
  }
}

