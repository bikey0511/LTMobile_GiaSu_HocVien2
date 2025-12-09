import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../models/student.dart';
import '../../widgets/input_field.dart';
import '../../widgets/primary_button.dart';

class RegisterScreen extends StatefulWidget {
  static const routeName = '/register';
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  UserRole _role = UserRole.student;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() { _error = null; });
    final auth = context.read<AuthService>();
    // Kiểm tra nhanh ở client: độ dài tối thiểu
    if (_email.text.trim().length < AuthService.minAccountLength) {
      setState(() { _error = 'Email phải có ít nhất ${AuthService.minAccountLength} ký tự.'; });
      return;
    }
    if (_password.text.length < AuthService.minPasswordLength) {
      setState(() { _error = 'Mật khẩu phải có ít nhất ${AuthService.minPasswordLength} ký tự.'; });
      return;
    }
    final err = await auth.register(
      name: _name.text.trim(),
      email: _email.text.trim(),
      password: _password.text,
      role: _role,
    );
    if (err != null) {
      setState(() { _error = err; });
      return;
    }
    if (!mounted) return;
    if (_role == UserRole.tutor) {
      // Gia sư: yêu cầu hoàn thiện hồ sơ (đặt approved=false, chờ Admin duyệt)
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tạo tài khoản thành công. Vui lòng hoàn thiện hồ sơ gia sư.')));
      Navigator.of(context).pushNamedAndRemoveUntil('/tutor-setup', (route) => false);
      return;
    }
    // Học viên: vào trang chủ ngay
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đăng ký thành công')));
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng ký')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            InputField(controller: _name, label: 'Họ và tên'),
            const SizedBox(height: 12),
            InputField(controller: _email, label: 'Email', keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 12),
            InputField(controller: _password, label: 'Mật khẩu', obscure: true),
            const SizedBox(height: 12),
            DropdownButtonFormField<UserRole>(
              initialValue: _role,
              items: const [
                DropdownMenuItem(value: UserRole.student, child: Text('Học viên')),
                DropdownMenuItem(value: UserRole.tutor, child: Text('Gia sư')),
              ],
              onChanged: (v) => setState(() => _role = v ?? UserRole.student),
              decoration: const InputDecoration(labelText: 'Vai trò'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 16),
            PrimaryButton(label: 'Tạo tài khoản', onPressed: _submit),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Đã có tài khoản? Đăng nhập'),
            ),
          ],
        ),
      ),
    );
  }
}
