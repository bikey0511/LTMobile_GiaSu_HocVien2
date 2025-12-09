import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../services/storage_service.dart';
import '../../models/student.dart';

class EditProfileScreen extends StatefulWidget {
  static const routeName = '/edit-profile';
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _avatarUrlController = TextEditingController();
  final _storageService = StorageService();
  final _imagePicker = ImagePicker();
  final _userService = UserService();
  
  File? _avatarFile;
  bool _loading = false;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = context.read<AuthService>().currentUser;
    if (user == null) return;
    
    _nameController.text = user.fullName;
    _emailController.text = user.email;
    _avatarUrlController.text = user.avatarUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _avatarUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _avatarFile = File(image.path);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi chọn ảnh: $e')),
      );
    }
  }

  Future<void> _save() async {
    final user = context.read<AuthService>().currentUser;
    if (user == null) return;

    if (_loading || _uploading) return;

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập tên')),
      );
      return;
    }

    setState(() {
      _loading = true;
      _uploading = _avatarFile != null;
    });

    try {
      String avatarUrl = _avatarUrlController.text.trim();
      
      // Upload ảnh mới nếu có
      if (_avatarFile != null) {
        try {
          // Dùng uploadTutorAvatar cho tất cả users (hoặc có thể tạo method riêng)
          final uploadedUrl = await _storageService.uploadTutorAvatar(
            _avatarFile!,
            user.id,
          );
          avatarUrl = uploadedUrl;
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi upload ảnh: $e')),
          );
          setState(() {
            _loading = false;
            _uploading = false;
          });
          return;
        }
      }

      // Cập nhật profile
      final updatedProfile = StudentProfile(
        id: user.id,
        fullName: name,
        email: _emailController.text.trim(),
        avatarUrl: avatarUrl,
        role: user.role,
      );

      await _userService.upsertUser(updatedProfile);
      
      // Cập nhật trong AuthService
      context.read<AuthService>().updateCurrentUser(updatedProfile);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cập nhật hồ sơ thành công!'),
          backgroundColor: Colors.green,
        ),
      );
      
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _uploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chỉnh sửa hồ sơ'),
        actions: [
          if (_uploading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Avatar
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundImage: _avatarFile != null
                        ? FileImage(_avatarFile!)
                        : (_avatarUrlController.text.isNotEmpty
                            ? NetworkImage(_avatarUrlController.text)
                            : null) as ImageProvider?,
                    child: _avatarFile == null && _avatarUrlController.text.isEmpty
                        ? const Icon(Icons.person, size: 60)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: Theme.of(context).primaryColor,
                      child: IconButton(
                        icon: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
                        onPressed: _pickAvatar,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Tên
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Họ và tên',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              enabled: !_loading,
            ),
            const SizedBox(height: 16),
            
            // Email (read-only)
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              enabled: false,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Email không thể thay đổi',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            
            // URL Avatar (tùy chọn)
            TextField(
              controller: _avatarUrlController,
              decoration: const InputDecoration(
                labelText: 'URL ảnh đại diện (tùy chọn)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.image),
                helperText: 'Hoặc nhập URL ảnh thay vì chọn từ thiết bị',
              ),
              enabled: !_loading,
            ),
            const SizedBox(height: 32),
            
            // Nút lưu
            FilledButton(
              onPressed: _loading ? null : _save,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Lưu thay đổi'),
            ),
          ],
        ),
      ),
    );
  }
}

