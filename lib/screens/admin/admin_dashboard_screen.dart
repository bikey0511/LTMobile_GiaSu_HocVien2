import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Trang admin: danh sách gia sư từ Firestore với nút duyệt/từ chối + quản lý tài khoản
import '../../services/repository_factory.dart';
import '../../models/tutor.dart';
import '../../services/firestore_refs.dart';
import '../../services/user_registry.dart';
import '../../models/student.dart';
import '../../services/auth_service.dart';
import '../../services/wallet_service.dart';
import '../../services/notification_service.dart';
import '../../models/wallet.dart' as wallet_models;
import '../../services/user_service.dart';
import 'package:intl/intl.dart';
import '../auth/login_screen.dart';
import '../notification/notification_screen.dart';
import 'admin_chat_list_screen.dart';
import 'admin_bookings_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  static const routeName = '/admin';
  const AdminDashboardScreen({super.key});
  
  Widget _buildStatisticsSection(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _StatCard(
          icon: Icons.school,
          label: 'Gia sư đã duyệt',
          stream: RepoFactory.tutor().streamApprovedTutors().map((t) => t.length),
          color: Colors.blue,
        ),
        _StatCard(
          icon: Icons.pending,
          label: 'Chờ duyệt',
          stream: RepoFactory.tutor().streamPendingTutors().map((t) => t.length),
          color: Colors.orange,
        ),
        _StatCard(
          icon: Icons.person,
          label: 'Tổng học viên',
          stream: RepoFactory.useFirebase
              ? FirestoreRefs
                  .users()
                  .where('role', isEqualTo: UserRole.student.name)
                  .snapshots()
                  .map((s) => s.size)
              : UserRegistry().studentCountStream(),
          color: Colors.green,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = RepoFactory.tutor();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bảng điều khiển Admin'),
        actions: [
          // Icon nhắn tin hỗ trợ
          IconButton(
            icon: const Icon(Icons.chat),
            tooltip: 'Hỗ trợ người dùng',
            onPressed: () {
              Navigator.pushNamed(context, AdminChatListScreen.routeName);
            },
          ),
          // Icon thông báo
          Builder(
            builder: (context) {
              final adminId = context.watch<AuthService>().currentUser?.id ?? '';
              if (adminId.isEmpty) return const SizedBox.shrink();
              return StreamBuilder<int>(
                stream: NotificationService().unreadCount(adminId),
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Thống kê tổng quan
          Text('Thống kê tổng quan', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          _buildStatisticsSection(context),
          const SizedBox(height: 24),
          Text('Quản lý hệ thống', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.event_note),
            title: const Text('Quản lý Bookings'),
            subtitle: const Text('Xem và quản lý tất cả bookings'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.pushNamed(context, AdminBookingsScreen.routeName);
            },
          ),
          const Divider(),
          const SizedBox(height: 24),
          Text('Gia sư chờ duyệt', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          StreamBuilder<List<Tutor>>(
            stream: RepoFactory.tutor().streamPendingTutors(),
            builder: (context, snap) {
              final tutors = snap.data ?? [];
              if (tutors.isEmpty) return const Text('Không có hồ sơ chờ duyệt');
              return Column(
                children: [
                  for (final t in tutors)
                    Card(
                      child: ListTile(
                        leading: CircleAvatar(backgroundImage: NetworkImage(t.avatarUrl)),
                        title: Text(t.name),
                        subtitle: Text(t.subject),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Duyệt',
                              icon: const Icon(Icons.check_circle, color: Colors.green),
                              onPressed: () async {
                                try {
                                  await RepoFactory.tutor().setApproved(t.id, true);
                                  // Gửi thông báo cho gia sư
                                  try {
                                    final notificationService = NotificationService();
                                    await notificationService.notifyTutorApproved(t.id);
                                  } catch (e) {
                                    // Bỏ qua lỗi thông báo
                                  }
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Đã duyệt hồ sơ của ${t.name}')),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Lỗi: $e')),
                                    );
                                  }
                                }
                              },
                            ),
                            IconButton(
                              tooltip: 'Từ chối',
                              icon: const Icon(Icons.cancel, color: Colors.redAccent),
                              onPressed: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Xác nhận từ chối'),
                                    content: Text('Bạn có chắc muốn từ chối hồ sơ của ${t.name}? Hồ sơ sẽ bị xóa vĩnh viễn.'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: const Text('Hủy'),
                                      ),
                                      FilledButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                        child: const Text('Từ chối'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true) {
                                  await RepoFactory.tutor().delete(t.id);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Đã từ chối hồ sơ của ${t.name}')),
                                    );
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Text('Danh sách Gia sư', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          StreamBuilder<List<Tutor>>(
            stream: repo.streamApprovedTutors(),
            builder: (context, snap) {
              final tutors = snap.data ?? [];
              if (tutors.isEmpty) {
                return const Text('Chưa có gia sư');
              }
              return Column(
                children: [
                  for (final t in tutors)
                    Card(
                      child: ListTile(
                        leading: CircleAvatar(backgroundImage: NetworkImage(t.avatarUrl)),
                        title: Text(t.name),
                        subtitle: Text('${t.subject} • ${t.hourlyRate.toStringAsFixed(0)} đ/giờ'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Bỏ duyệt',
                              icon: const Icon(Icons.block),
                              onPressed: () => repo.setApproved(t.id, false),
                            ),
                            IconButton(
                              tooltip: 'Duyệt',
                              icon: const Icon(Icons.check_circle, color: Colors.green),
                              onPressed: () => repo.setApproved(t.id, true),
                            ),
                            IconButton(
                              tooltip: 'Xóa gia sư',
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Xác nhận xóa'),
                                    content: Text('Bạn có chắc muốn xóa gia sư ${t.name}? Hành động này không thể hoàn tác.'),
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
                                  try {
                                    await repo.delete(t.id);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Đã xóa gia sư ${t.name}'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Lỗi khi xóa: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Text('Danh sách Học viên', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          // Hiển thị danh sách học viên (chỉ khả dụng khi bật Firebase)
          if (RepoFactory.useFirebase)
            StreamBuilder<List<StudentProfile>>(
              stream: FirestoreRefs
                  .users()
                  .where('role', isEqualTo: UserRole.student.name)
                  .snapshots()
                  .map((s) => s.docs.map((d) => StudentProfile.fromMap(d.id, d.data())).toList()),
              builder: (context, snap) {
                final students = snap.data ?? [];
                if (students.isEmpty) return const Text('Chưa có học viên');
                return Column(
                  children: [
                    for (final u in students)
                      Card(
                        child: ListTile(
                          leading: CircleAvatar(backgroundImage: NetworkImage(u.avatarUrl)),
                          title: Text(u.fullName),
                          subtitle: Text(u.email),
                          trailing: IconButton(
                            tooltip: 'Xóa học viên',
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Xác nhận xóa'),
                                  content: Text('Bạn có chắc muốn xóa học viên ${u.fullName}? Hành động này không thể hoàn tác.'),
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
                                try {
                                  final userService = UserService();
                                  await userService.deleteUser(u.id);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Đã xóa học viên ${u.fullName}'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Lỗi khi xóa: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              }
                            },
                          ),
                        ),
                      ),
                  ],
                );
              },
            )
          else
            const Text('Danh sách học viên chỉ khả dụng khi bật Firebase'),
          const SizedBox(height: 24),
          Text('Yêu cầu rút tiền', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          // Danh sách yêu cầu rút tiền chờ duyệt
          if (RepoFactory.useFirebase)
            _WithdrawalRequestsSection()
          else
            const Text('Chức năng này chỉ khả dụng khi bật Firebase'),
          const SizedBox(height: 24),
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
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Stream<int> stream;
  final Color color;
  
  const _StatCard({
    required this.icon,
    required this.label,
    required this.stream,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: stream,
      builder: (context, snap) {
        final value = snap.data ?? 0;
        return Card(
          elevation: 2,
          child: Container(
            width: 150,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 32),
                const SizedBox(height: 8),
                Text(
                  '$value',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}



class _WithdrawalRequestsSection extends StatelessWidget {
  const _WithdrawalRequestsSection();

  @override
  Widget build(BuildContext context) {
    final walletService = WalletService();
    
    return StreamBuilder<List<wallet_models.Transaction>>(
      stream: FirestoreRefs
          .transactions()
          .where('type', isEqualTo: wallet_models.TransactionType.withdrawal.name)
          .where('status', isEqualTo: wallet_models.TransactionStatus.pending.name)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snap) => snap.docs
              .map((doc) => wallet_models.Transaction.fromMap(doc.id, doc.data()))
              .toList()),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data ?? [];
        if (requests.isEmpty) {
          return const Text('Không có yêu cầu rút tiền nào đang chờ duyệt');
        }

        return Column(
          children: [
            for (final transaction in requests)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Column(
                  children: [
                    ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.orange,
                        child: Icon(Icons.account_balance_wallet, color: Colors.white),
                      ),
                      title: FutureBuilder<StudentProfile?>(
                        future: _getUserInfo(transaction.userId),
                        builder: (context, userSnap) {
                          final user = userSnap.data;
                          return Text(
                            user?.fullName ?? 'User ID: ${transaction.userId}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          );
                        },
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(transaction.description),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('dd/MM/yyyy HH:mm').format(transaction.createdAt),
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                      trailing: Text(
                        NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(transaction.amount),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      isThreeLine: true,
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Từ chối yêu cầu rút tiền'),
                                  content: Text(
                                    'Bạn có chắc muốn từ chối yêu cầu rút tiền này? Tiền sẽ được hoàn lại vào ví của người dùng.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('Hủy'),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                      child: const Text('Từ chối'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true) {
                                final err = await walletService.rejectWithdrawal(transaction.id);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(err ?? 'Đã từ chối yêu cầu rút tiền'),
                                      backgroundColor: err != null ? Colors.red : Colors.orange,
                                    ),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.cancel, color: Colors.red),
                            label: const Text('Từ chối'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Duyệt yêu cầu rút tiền'),
                                  content: Text(
                                    'Bạn có chắc muốn duyệt yêu cầu rút tiền ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(transaction.amount)}?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('Hủy'),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text('Duyệt'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true) {
                                final err = await walletService.approveWithdrawal(transaction.id);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(err ?? 'Đã duyệt yêu cầu rút tiền'),
                                      backgroundColor: err != null ? Colors.red : Colors.green,
                                    ),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.check_circle),
                            label: const Text('Duyệt'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Future<StudentProfile?> _getUserInfo(String userId) async {
    try {
      final doc = await FirestoreRefs.users().doc(userId).get();
      if (!doc.exists) return null;
      return StudentProfile.fromMap(doc.id, doc.data()!);
    } catch (_) {
      return null;
    }
  }
}
