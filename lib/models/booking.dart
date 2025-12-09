class Booking {
  final String id;
  final String tutorId;
  final String studentId;
  final DateTime dateTime;
  final int durationMinutes;
  final double priceTotal;
  final String note;
  final bool paid; // thanh toán giả lập
  final bool accepted; // gia sư đã chấp nhận
  final String? rejectReason; // lý do từ chối (nếu có)
  final bool cancelled; // đã hủy bởi học viên
  final String? cancelReason; // lý do hủy (nếu có)
  final int totalSessions; // tổng số buổi học của khóa học
  final int completedSessions; // số buổi đã hoàn thành
  final bool completed; // đã hoàn thành khóa học chưa
  final bool isGroupClass; // học nhóm hay học 1-1
  final int groupSize; // số lượng học viên trong nhóm (1 = học 1-1, 2+ = học nhóm)
  final List<String> studentIds; // danh sách ID của tất cả học viên trong nhóm

  const Booking({
    required this.id,
    required this.tutorId,
    required this.studentId,
    required this.dateTime,
    required this.durationMinutes,
    required this.priceTotal,
    required this.note,
    this.paid = false,
    this.accepted = false,
    this.rejectReason,
    this.cancelled = false,
    this.cancelReason,
    this.totalSessions = 1, // mặc định 1 buổi
    this.completedSessions = 0,
    this.completed = false,
    this.isGroupClass = false, // mặc định học 1-1
    this.groupSize = 1, // mặc định 1 người
    this.studentIds = const [], // mặc định chỉ có người đặt
  });

  // Map để lưu Firestore
  Map<String, dynamic> toMap() {
    return {
      'tutorId': tutorId,
      'studentId': studentId,
      // Lưu dạng ISO khi dùng mock; Repository Firestore sẽ chuyển sang Timestamp
      'dateTime': dateTime.toIso8601String(),
      'durationMinutes': durationMinutes,
      'priceTotal': priceTotal,
      'note': note,
      'paid': paid,
      'accepted': accepted,
      'rejectReason': rejectReason,
      'cancelled': cancelled,
      'cancelReason': cancelReason,
      'totalSessions': totalSessions,
      'completedSessions': completedSessions,
      'completed': completed,
      'isGroupClass': isGroupClass,
      'groupSize': groupSize,
      'studentIds': studentIds, // danh sách ID của tất cả học viên
    };
  }

  factory Booking.fromMap(String id, Map<String, dynamic> data) {
    // Hỗ trợ cả kiểu String ISO và Timestamp của Firestore
    DateTime parsedDate;
    final rawDate = data['dateTime'];
    if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else if (rawDate != null && rawDate.runtimeType.toString() == 'Timestamp') {
      // Tránh import cloud_firestore trong model để không siết phụ thuộc
      // Timestamp có toDate(); fallback an toàn nếu không có
      try {
        // ignore: invalid_use_of_internal_member
        parsedDate = (rawDate as dynamic).toDate() as DateTime;
      } catch (_) {
        parsedDate = DateTime.now();
      }
    } else {
      parsedDate = DateTime.now();
    }
    // Xử lý studentIds: có thể là List<String> hoặc null
    List<String> parsedStudentIds = [];
    if (data['studentIds'] != null) {
      if (data['studentIds'] is List) {
        parsedStudentIds = List<String>.from(data['studentIds']);
      }
    }
    // Nếu không có studentIds, mặc định là [studentId] (người đặt)
    if (parsedStudentIds.isEmpty) {
      parsedStudentIds = [data['studentId'] ?? ''];
    }
    
    // Helper function để parse boolean an toàn từ Firestore
    bool parseBool(dynamic value, bool defaultValue) {
      if (value == null) return defaultValue;
      if (value is bool) return value;
      if (value is int) return value != 0;
      if (value is String) {
        return value.toLowerCase() == 'true' || value == '1';
      }
      return defaultValue;
    }
    
    return Booking(
      id: id,
      tutorId: data['tutorId'] ?? '',
      studentId: data['studentId'] ?? '',
      dateTime: parsedDate,
      durationMinutes: (data['durationMinutes'] ?? 0) as int,
      priceTotal: (data['priceTotal'] ?? 0).toDouble(),
      note: data['note'] ?? '',
      paid: parseBool(data['paid'], false),
      accepted: parseBool(data['accepted'], false),
      rejectReason: data['rejectReason'] as String?,
      cancelled: parseBool(data['cancelled'], false),
      cancelReason: data['cancelReason'] as String?,
      totalSessions: (data['totalSessions'] ?? 1) as int,
      completedSessions: (data['completedSessions'] ?? 0) as int,
      completed: parseBool(data['completed'], false),
      isGroupClass: parseBool(data['isGroupClass'], false),
      groupSize: (data['groupSize'] ?? 1) as int,
      studentIds: parsedStudentIds,
    );
  }
}
