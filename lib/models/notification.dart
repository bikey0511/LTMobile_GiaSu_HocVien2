class NotificationModel {
  final String id;
  final String userId; // ID của người nhận thông báo
  final String title;
  final String message;
  final String type; // 'booking', 'payment', 'approval', 'system', etc.
  final bool read;
  final DateTime createdAt;
  final Map<String, dynamic>? data; // Dữ liệu bổ sung (bookingId, tutorId, etc.)

  const NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    this.read = false,
    required this.createdAt,
    this.data,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'message': message,
      'type': type,
      'read': read,
      'createdAt': createdAt.toIso8601String(),
      'data': data,
    };
  }

  factory NotificationModel.fromMap(String id, Map<String, dynamic> data) {
    DateTime parsedDate;
    final rawDate = data['createdAt'];
    if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else if (rawDate != null && rawDate.runtimeType.toString() == 'Timestamp') {
      try {
        parsedDate = (rawDate as dynamic).toDate() as DateTime;
      } catch (_) {
        parsedDate = DateTime.now();
      }
    } else {
      parsedDate = DateTime.now();
    }

    return NotificationModel(
      id: id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      type: data['type'] ?? 'system',
      read: (data['read'] ?? false) as bool,
      createdAt: parsedDate,
      data: data['data'] as Map<String, dynamic>?,
    );
  }

  NotificationModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? message,
    String? type,
    bool? read,
    DateTime? createdAt,
    Map<String, dynamic>? data,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      read: read ?? this.read,
      createdAt: createdAt ?? this.createdAt,
      data: data ?? this.data,
    );
  }
}


