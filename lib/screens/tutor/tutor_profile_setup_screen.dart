import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/tutor.dart';
import '../../services/auth_service.dart';
import '../../services/repository_factory.dart';
import '../../services/tutor_repository.dart';
import '../../services/tutor_service.dart';
import '../../services/storage_service.dart';
import 'tutor_dashboard_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TutorProfileSetupScreen extends StatefulWidget {
  static const routeName = '/tutor-setup';
  const TutorProfileSetupScreen({super.key});

  @override
  State<TutorProfileSetupScreen> createState() => _TutorProfileSetupScreenState();
}

class _TutorProfileSetupScreenState extends State<TutorProfileSetupScreen> {
  final _name = TextEditingController();
  final _subject = TextEditingController();
  final _bio = TextEditingController();
  final _rate = TextEditingController(text: '200000');
  final _avatar = TextEditingController(text: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?q=80&w=600&auto=format&fit=crop');
  
  final _storageService = StorageService();
  final _imagePicker = ImagePicker();
  
  File? _avatarFile;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    // Prefill nền: không chặn UI
    Future.microtask(() async {
      final me = context.read<AuthService>().currentUser;
      if (me == null) return;
      final repo = RepoFactory.tutor();
      final t = await repo.getById(me.id);
      if (t != null) {
        _name.text = t.name;
        _subject.text = t.subject;
        _bio.text = t.bio;
        _rate.text = t.hourlyRate.toStringAsFixed(0);
        _avatar.text = t.avatarUrl;
        if (mounted) setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _subject.dispose();
    _bio.dispose();
    _rate.dispose();
    _avatar.dispose();
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
    final me = context.read<AuthService>().currentUser;
    if (me == null) return;

    if (_uploading) return; // Tránh double submit

    setState(() => _uploading = true);

    String? avatarUrl = _avatar.text;

    try {
      // Upload ảnh đại diện nếu có file mới
      if (_avatarFile != null) {
        if (RepoFactory.useFirebase) {
          try {
            // Xóa ảnh cũ nếu có
            if (avatarUrl.isNotEmpty && avatarUrl.contains('firebasestorage')) {
              await _storageService.deleteOldImage(avatarUrl).timeout(const Duration(seconds: 5));
            }
            avatarUrl = await _storageService.uploadTutorAvatar(_avatarFile!, me.id).timeout(const Duration(seconds: 15));
          } catch (e) {
            if (!mounted) return;
            setState(() => _uploading = false);
            String uploadError = 'Không thể upload ảnh đại diện.';
            if (e is FirebaseException) {
              if (e.code == 'permission-denied') {
                uploadError = 'Không có quyền upload ảnh. Vui lòng kiểm tra quyền truy cập Firebase Storage.';
              } else {
                uploadError = 'Lỗi upload ảnh: ${e.code}';
              }
            } else if (e is TimeoutException) {
              uploadError = 'Upload ảnh quá lâu. Vui lòng thử lại.';
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(uploadError), backgroundColor: Colors.orange),
            );
            return;
          }
        } else {
          // Mock: giữ nguyên file path (không upload)
          avatarUrl = _avatarFile!.path;
        }
      }

      final tutor = Tutor(
        id: me.id,
        name: _name.text.isEmpty ? me.fullName : _name.text,
        avatarUrl: avatarUrl,
        subject: _subject.text,
        bio: _bio.text,
        hourlyRate: double.tryParse(_rate.text) ?? 0,
        rating: 5,
        reviewCount: 0,
        approved: false, // cần Admin duyệt mới hiển thị cho Học viên
      );

      if (RepoFactory.useFirebase) {
        // Tránh treo UI nếu mạng/rules lỗi
        // Retry logic để xử lý Firestore internal assertion errors
        int retries = 0;
        const maxRetries = 2;
        while (retries <= maxRetries) {
          try {
            await TutorRepository().upsert(tutor).timeout(const Duration(seconds: 10));
            break; // Thành công, thoát khỏi vòng lặp
          } catch (e) {
            if (retries < maxRetries && 
                (e.toString().contains('INTERNAL ASSERTION FAILED') || 
                 e.toString().contains('Unexpected state'))) {
              // Đợi một chút trước khi retry
              await Future.delayed(Duration(milliseconds: 500 * (retries + 1)));
              retries++;
            } else {
              rethrow; // Nếu không phải lỗi assertion hoặc đã hết retry, throw lại
            }
          }
        }
      } else {
        TutorService().addOrUpdate(tutor);
      }
      
      if (!mounted) return;
      setState(() => _uploading = false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu hồ sơ. Chờ Admin duyệt.')),
      );
      // Về trang Gia sư
      Navigator.of(context).pushNamedAndRemoveUntil(TutorDashboardScreen.routeName, (route) => false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      String msg = 'Không thể lưu hồ sơ. Vui lòng kiểm tra mạng/rules.';
      if (e is FirebaseException) {
        if (e.code == 'permission-denied') {
          msg = 'Không có quyền lưu hồ sơ. Vui lòng kiểm tra quyền truy cập.';
        } else {
          msg = 'Lưu thất bại: ${e.code} - ${e.message ?? ""}';
        }
      } else if (e is TimeoutException) {
        msg = 'Lưu hồ sơ quá lâu. Vui lòng kiểm tra kết nối mạng và thử lại.';
      } else {
        msg = 'Lỗi: ${e.toString()}';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthService>().currentUser;
    _name.text = _name.text.isEmpty ? (me?.fullName ?? '') : _name.text;
    return Scaffold(
      appBar: AppBar(title: const Text('Hoàn thiện hồ sơ gia sư')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Họ và tên')),
          const SizedBox(height: 12),
          TextField(controller: _subject, decoration: const InputDecoration(labelText: 'Môn dạy')),
          const SizedBox(height: 12),
          TextField(controller: _rate, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Giá/giờ (đ)')),
          const SizedBox(height: 12),
          
          // Ảnh đại diện
          const Text('Ảnh đại diện', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              GestureDetector(
                onTap: _pickAvatar,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[400]!),
                  ),
                  child: _avatarFile != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(_avatarFile!, fit: BoxFit.cover),
                        )
                      : _avatar.text.isNotEmpty && !_avatar.text.startsWith('/')
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(_avatar.text, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 50)),
                            )
                          : const Icon(Icons.person, size: 50, color: Colors.grey),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickAvatar,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Chọn ảnh từ máy'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          TextField(controller: _bio, decoration: const InputDecoration(labelText: 'Giới thiệu'), maxLines: 4),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _uploading ? null : _save,
            child: _uploading
                ? const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 8),
                      Text('Đang tải lên...'),
                    ],
                  )
                : const Text('Lưu hồ sơ'),
          ),
        ],
      ),
    );
  }
}
