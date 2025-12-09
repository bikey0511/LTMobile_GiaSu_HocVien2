import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

/// Service để upload ảnh lên Firebase Storage
class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload ảnh đại diện của gia sư
  Future<String> uploadTutorAvatar(File imageFile, String tutorId) async {
    try {
      final ref = _storage.ref().child('tutors/$tutorId/avatar.jpg');
      await ref.putFile(imageFile);
      return await ref.getDownloadURL();
    } catch (e) {
      throw Exception('Không thể upload ảnh đại diện: $e');
    }
  }

  /// Xóa ảnh cũ (nếu có)
  Future<void> deleteOldImage(String imageUrl) async {
    try {
      if (imageUrl.isEmpty || !imageUrl.contains('firebasestorage')) {
        return; // Không phải ảnh từ Firebase Storage, không cần xóa
      }
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } catch (e) {
      // Bỏ qua lỗi nếu không xóa được (có thể ảnh không tồn tại)
    }
  }

  /// Upload tài liệu khóa học
  Future<String> uploadCourseMaterial(File file, String bookingId, String tutorId, String fileName) async {
    try {
      // Tạo đường dẫn: course-materials/{bookingId}/{fileName}
      final ref = _storage.ref().child('course-materials/$bookingId/$fileName');
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      throw Exception('Không thể upload tài liệu: $e');
    }
  }

  /// Xóa tài liệu
  Future<void> deleteCourseMaterial(String fileUrl) async {
    try {
      if (fileUrl.isEmpty || !fileUrl.contains('firebasestorage')) {
        return;
      }
      final ref = _storage.refFromURL(fileUrl);
      await ref.delete();
    } catch (e) {
      // Bỏ qua lỗi
    }
  }
}

