/// Model cho bài tập
class Assignment {
  final String id;
  final String bookingId; // ID của booking/khóa học
  final String tutorId; // ID của gia sư
  final String title; // Tiêu đề bài tập
  final String description; // Mô tả/nội dung bài tập
  final DateTime dueDate; // Hạn nộp bài
  final DateTime createdAt; // Thời gian tạo
  final List<String> attachments; // Danh sách URL file đính kèm (nếu có)
  final int maxScore; // Điểm tối đa (mặc định 100)

  const Assignment({
    required this.id,
    required this.bookingId,
    required this.tutorId,
    required this.title,
    required this.description,
    required this.dueDate,
    required this.createdAt,
    this.attachments = const [],
    this.maxScore = 100,
  });

  Map<String, dynamic> toMap() {
    return {
      'bookingId': bookingId,
      'tutorId': tutorId,
      'title': title,
      'description': description,
      'dueDate': dueDate.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'attachments': attachments,
      'maxScore': maxScore,
    };
  }

  factory Assignment.fromMap(String id, Map<String, dynamic> data) {
    DateTime parseDate(dynamic rawDate) {
      if (rawDate is String) {
        return DateTime.tryParse(rawDate) ?? DateTime.now();
      } else if (rawDate != null) {
        try {
          return (rawDate as dynamic).toDate() as DateTime;
        } catch (_) {
          return DateTime.now();
        }
      }
      return DateTime.now();
    }

    return Assignment(
      id: id,
      bookingId: data['bookingId'] ?? '',
      tutorId: data['tutorId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      dueDate: parseDate(data['dueDate']),
      createdAt: parseDate(data['createdAt']),
      attachments: data['attachments'] is List
          ? List<String>.from(data['attachments'])
          : [],
      maxScore: (data['maxScore'] ?? 100) as int,
    );
  }
}

/// Model cho bài nộp của học viên
class Submission {
  final String id;
  final String assignmentId; // ID của bài tập
  final String studentId; // ID của học viên
  final String? content; // Nội dung bài nộp (text)
  final List<String> attachments; // Danh sách URL file đính kèm
  final DateTime submittedAt; // Thời gian nộp bài
  final int? score; // Điểm (null nếu chưa chấm)
  final String? feedback; // Nhận xét của gia sư
  final DateTime? gradedAt; // Thời gian chấm điểm

  const Submission({
    required this.id,
    required this.assignmentId,
    required this.studentId,
    required this.submittedAt,
    this.content,
    this.attachments = const [],
    this.score,
    this.feedback,
    this.gradedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'assignmentId': assignmentId,
      'studentId': studentId,
      'content': content,
      'attachments': attachments,
      'submittedAt': submittedAt.toIso8601String(),
      'score': score,
      'feedback': feedback,
      'gradedAt': gradedAt?.toIso8601String(),
    };
  }

  factory Submission.fromMap(String id, Map<String, dynamic> data) {
    DateTime parseDate(dynamic rawDate) {
      if (rawDate is String) {
        return DateTime.tryParse(rawDate) ?? DateTime.now();
      } else if (rawDate != null) {
        try {
          return (rawDate as dynamic).toDate() as DateTime;
        } catch (_) {
          return DateTime.now();
        }
      }
      return DateTime.now();
    }

    return Submission(
      id: id,
      assignmentId: data['assignmentId'] ?? '',
      studentId: data['studentId'] ?? '',
      content: data['content'] as String?,
      attachments: data['attachments'] is List
          ? List<String>.from(data['attachments'])
          : [],
      submittedAt: parseDate(data['submittedAt']),
      score: data['score'] as int?,
      feedback: data['feedback'] as String?,
      gradedAt: data['gradedAt'] != null ? parseDate(data['gradedAt']) : null,
    );
  }
}


