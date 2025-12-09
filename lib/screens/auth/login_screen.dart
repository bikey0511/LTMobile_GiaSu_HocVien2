import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../models/student.dart';
import '../../widgets/input_field.dart';
import '../../widgets/primary_button.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  static const routeName = '/login';
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    final auth = context.read<AuthService>();
    final err = await auth.login(email: _email.text.trim(), password: _password.text);
    setState(() => _loading = false);
    if (err != null) {
      setState(() {
        _error = err;
      });
      return;
    }
    // Không điều hướng thủ công; AuthGate ở cấp cao sẽ tự chuyển đến trang đúng vai trò
    if (!mounted) return;
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    final auth = context.read<AuthService>();
    var err = await auth.signInWithGoogle();
    setState(() => _loading = false);
    
    if (err != null) {
      // Nếu cần chọn vai trò, hiển thị dialog
      if (err == 'NEED_ROLE_SELECTION') {
        if (!mounted) return;
        
        // Bước 1: Chọn vai trò
        final role = await showDialog<UserRole>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Chọn vai trò'),
            content: const Text('Bạn muốn đăng nhập với vai trò gì?\n\nLưu ý: Vai trò này chỉ được chọn 1 lần duy nhất.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, UserRole.student),
                child: const Text('Học viên'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, UserRole.tutor),
                child: const Text('Gia sư'),
              ),
            ],
          ),
        );
        
        if (role == null) {
          // User hủy chọn vai trò
          return;
        }
        
        // Bước 2: Xác nhận vai trò đã chọn
        if (!mounted) return;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Xác nhận vai trò'),
            content: Text(
              'Bạn chắc chắn muốn đăng nhập với vai trò "${role == UserRole.student ? 'Học viên' : 'Gia sư'}"?\n\n'
              'Vai trò này sẽ được lưu vĩnh viễn và không thể thay đổi sau này.',
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
        
        if (confirmed != true) {
          // User hủy xác nhận, quay lại chọn vai trò (không gọi lại _signInWithGoogle để tránh vòng lặp)
          // Chỉ cần return, user có thể bấm lại nút Google Sign-In nếu muốn
          return;
        }
        
        // Bước 3: Đăng nhập với vai trò đã chọn và xác nhận
        setState(() => _loading = true);
        err = await auth.signInWithGoogle(selectedRole: role);
        setState(() => _loading = false);
        if (err != null) {
          setState(() {
            _error = err;
          });
          return;
        }
        // Đăng nhập thành công, AuthGate sẽ tự động điều hướng
      } else {
        setState(() {
          _error = err;
        });
        return;
      }
    }
    if (!mounted) return;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng nhập')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            InputField(
              controller: _email,
              label: 'Email',
              keyboardType: TextInputType.emailAddress,
              enabled: !_loading,
            ),
            const SizedBox(height: 12),
            InputField(
              controller: _password,
              label: 'Mật khẩu',
              obscure: true,
              enabled: !_loading,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _loading
                    ? null
                    : () => Navigator.pushNamed(context, ForgotPasswordScreen.routeName),
                child: const Text('Quên mật khẩu?'),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 16),
            PrimaryButton(
              label: _loading ? 'Đang xử lý...' : 'Đăng nhập',
              onPressed: _loading ? null : _submit,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: Divider(color: Colors.grey[400])),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Hoặc', style: TextStyle(color: Colors.grey[600])),
                ),
                Expanded(child: Divider(color: Colors.grey[400])),
              ],
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _loading ? null : _signInWithGoogle,
              icon: const Icon(Icons.g_mobiledata, size: 20),
              label: const Text('Đăng nhập bằng Google'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _loading
                  ? null
                  : () => Navigator.pushNamed(context, RegisterScreen.routeName),
              child: const Text('Chưa có tài khoản? Đăng ký'),
            ),
          ],
        ),
      ),
    );
  }
}
