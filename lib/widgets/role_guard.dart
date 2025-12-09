import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../models/student.dart';
import '../screens/auth/login_screen.dart';
import '../screens/tutor/tutor_dashboard_screen.dart';
import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/home/home_screen.dart';

/// RoleGuard: chặn truy cập trái phép theo vai trò
class RoleGuard extends StatelessWidget {
  final List<UserRole> allowed;
  final WidgetBuilder builder;

  const RoleGuard({super.key, required this.allowed, required this.builder});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    if (!auth.isLoggedIn) return const LoginScreen();
    final role = auth.currentUser?.role;
    if (role != null && allowed.contains(role)) {
      return builder(context);
    }
    // Không có quyền: hiển thị trang báo và nút quay lại trang phù hợp
    return Scaffold(
      appBar: AppBar(title: const Text('Không có quyền truy cập')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Bạn không có quyền vào trang này.'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                switch (role) {
                  case UserRole.admin:
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
                    );
                    break;
                  case UserRole.tutor:
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const TutorDashboardScreen()),
                    );
                    break;
                  case UserRole.student:
                  default:
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const HomeScreen()),
                    );
                }
              },
              child: const Text('Về trang phù hợp'),
            )
          ],
        ),
      ),
    );
  }
}



