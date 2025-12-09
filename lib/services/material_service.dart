import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/course_material.dart';
import 'firestore_refs.dart';
import 'storage_service.dart';

/// Service để quản lý tài liệu khóa học
class MaterialService {
  final _col = FirestoreRefs.materials();
  final _storageService = StorageService();

  /// Upload tài liệu cho khóa học
  Future<CourseMaterial> uploadMaterial({
    required String bookingId,
    required String tutorId,
    required File file,
    String? description,
  }) async {
    try {
      // Lấy tên file
      final fileName = file.path.split('/').last;
      
      // Xác định loại file
      final extension = fileName.split('.').last.toLowerCase();
      final fileType = _getFileType(extension);
      
      // Upload file lên Firebase Storage
      final fileUrl = await _storageService.uploadCourseMaterial(
        file,
        bookingId,
        tutorId,
        fileName,
      );
      
      // Lấy kích thước file
      final fileSize = await file.length();
      
      // Tạo document trong Firestore
      final material = CourseMaterial(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        bookingId: bookingId,
        tutorId: tutorId,
        fileName: fileName,
        fileUrl: fileUrl,
        fileType: fileType,
        fileSize: fileSize,
        description: description,
        uploadedAt: DateTime.now(),
      );
      
      final data = material.toMap();
      data['uploadedAt'] = Timestamp.fromDate(material.uploadedAt);
      
      await _col.doc(material.id).set(data);
      
      return material;
    } catch (e) {
      throw Exception('Không thể upload tài liệu: $e');
    }
  }

  /// Lấy danh sách tài liệu của một booking
  Stream<List<CourseMaterial>> streamMaterialsForBooking(String bookingId) {
    return _col
        .where('bookingId', isEqualTo: bookingId)
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => CourseMaterial.fromMap(doc.id, doc.data()))
          .toList();
    }).handleError((error) {
      return <CourseMaterial>[];
    });
  }

  /// Xóa tài liệu
  Future<void> deleteMaterial(CourseMaterial material) async {
    try {
      // Xóa file từ Storage
      await _storageService.deleteCourseMaterial(material.fileUrl);
      
      // Xóa document từ Firestore
      await _col.doc(material.id).delete();
    } catch (e) {
      throw Exception('Không thể xóa tài liệu: $e');
    }
  }

  /// Xác định loại file
  String _getFileType(String extension) {
    switch (extension) {
      case 'pdf':
        return 'pdf';
      case 'doc':
      case 'docx':
        return 'doc';
      case 'ppt':
      case 'pptx':
        return 'ppt';
      case 'xls':
      case 'xlsx':
        return 'excel';
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return 'image';
      case 'txt':
        return 'text';
      case 'zip':
      case 'rar':
        return 'archive';
      default:
        return 'other';
    }
  }

  /// Lấy icon cho loại file
  static String getFileIcon(String fileType) {
    switch (fileType) {
      case 'pdf':
        return '📄';
      case 'doc':
        return '📝';
      case 'ppt':
        return '📊';
      case 'excel':
        return '📈';
      case 'image':
        return '🖼️';
      case 'text':
        return '📃';
      case 'archive':
        return '📦';
      default:
        return '📎';
    }
  }

  /// Format kích thước file
  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }
}

