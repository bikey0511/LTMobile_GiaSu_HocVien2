import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import '../../models/student.dart';
import '../admin/admin_dashboard_screen.dart';
import '../tutor/tutor_dashboard_screen.dart';
import '../wallet/wallet_screen.dart';
import '../booking/booking_history_screen.dart';
import '../../services/notification_service.dart';
import '../notification/notification_screen.dart';
import '../../services/repository_factory.dart';
import 'edit_profile_screen.dart';
import 'change_password_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ'),
        actions: [
          // Icon thông báo
          if (user != null)
            StreamBuilder<int>(
              stream: NotificationService().unreadCount(user.id),
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
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (user != null) ...[
              Row(
                children: [
                  CircleAvatar(radius: 36, backgroundImage: NetworkImage(user.avatarUrl)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.fullName, style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 6),
                        Text(user.email, style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      Navigator.pushNamed(context, EditProfileScreen.routeName);
                    },
                    tooltip: 'Chỉnh sửa hồ sơ',
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
            ListTile(
              leading: const Icon(Icons.account_balance_wallet),
              title: const Text('Ví điện tử'),
              onTap: () => Navigator.pushNamed(context, WalletScreen.routeName),
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Lịch sử đặt lịch'),
              onTap: () {
                Navigator.pushNamed(context, BookingHistoryScreen.routeName);
              },
            ),
            ListTile(
              leading: const Icon(Icons.lock),
              title: const Text('Đổi mật khẩu'),
              onTap: () {
                Navigator.pushNamed(context, ChangePasswordScreen.routeName);
              },
            ),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('Trợ giúp'),
              onTap: () {},
            ),
            const Divider(height: 32),
            // Hiển thị trạng thái đồng bộ Firebase
            Card(
              color: RepoFactory.useFirebase ? Colors.green.shade50 : Colors.orange.shade50,
              child: ListTile(
                leading: Icon(
                  RepoFactory.useFirebase ? Icons.cloud_done : Icons.cloud_off,
                  color: RepoFactory.useFirebase ? Colors.green : Colors.orange,
                ),
                title: Text(
                  RepoFactory.useFirebase ? 'Đã kết nối Firebase' : 'Chế độ offline',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: RepoFactory.useFirebase ? Colors.green.shade900 : Colors.orange.shade900,
                  ),
                ),
                subtitle: Text(
                  RepoFactory.useFirebase 
                      ? 'Dữ liệu đang được đồng bộ với Firebase'
                      : 'Đang dùng dữ liệu mock (offline)',
                  style: TextStyle(
                    fontSize: 12,
                    color: RepoFactory.useFirebase ? Colors.green.shade700 : Colors.orange.shade700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Khu vực quản trị', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (user?.role == UserRole.admin)
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, AdminDashboardScreen.routeName),
                    icon: const Icon(Icons.admin_panel_settings),
                    label: const Text('Trang Admin'),
                  ),
                if (user?.role == UserRole.tutor)
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, TutorDashboardScreen.routeName),
                    icon: const Icon(Icons.school),
                    label: const Text('Trang Gia sư'),
                  ),
              ],
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () async {
                  await context.read<AuthService>().logout();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                },
                child: const Text('Đăng xuất'),
              ),
            )
          ],
        ),
      ),
    );
  }
}
