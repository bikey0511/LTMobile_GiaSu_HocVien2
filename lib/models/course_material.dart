/// Model cho tài liệu khóa học
class CourseMaterial {
  final String id;
  final String bookingId; // ID của booking/khóa học
  final String tutorId; // ID của gia sư
  final String fileName; // Tên file
  final String fileUrl; // URL file trên Firebase Storage
  final String fileType; // Loại file: pdf, doc, docx, ppt, pptx, image, etc.
  final int fileSize; // Kích thước file (bytes)
  final String? description; // Mô tả tài liệu
  final DateTime uploadedAt; // Thời gian upload

  const CourseMaterial({
    required this.id,
    required this.bookingId,
    required this.tutorId,
    required this.fileName,
    required this.fileUrl,
    required this.fileType,
    required this.fileSize,
    this.description,
    required this.uploadedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'bookingId': bookingId,
      'tutorId': tutorId,
      'fileName': fileName,
      'fileUrl': fileUrl,
      'fileType': fileType,
      'fileSize': fileSize,
      'description': description,
      'uploadedAt': uploadedAt.toIso8601String(),
    };
  }

  factory CourseMaterial.fromMap(String id, Map<String, dynamic> data) {
    DateTime parsedDate;
    final rawDate = data['uploadedAt'];
    if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else if (rawDate != null) {
      try {
        parsedDate = (rawDate as dynamic).toDate() as DateTime;
      } catch (_) {
        parsedDate = DateTime.now();
      }
    } else {
      parsedDate = DateTime.now();
    }

    return CourseMaterial(
      id: id,
      bookingId: data['bookingId'] ?? '',
      tutorId: data['tutorId'] ?? '',
      fileName: data['fileName'] ?? '',
      fileUrl: data['fileUrl'] ?? '',
      fileType: data['fileType'] ?? 'pdf',
      fileSize: (data['fileSize'] ?? 0) as int,
      description: data['description'] as String?,
      uploadedAt: parsedDate,
    );
  }
}


