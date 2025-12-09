/// Model cho phòng chat
class ChatRoom {
  final String id; // roomId
  final String type; // 'tutor', 'student', 'group', 'ai'
  final String? tutorId; // null nếu là group hoặc ai
  final String? studentId; // null nếu là group hoặc ai
  final String? groupBookingId; // null nếu không phải group
  final List<String> participantIds; // Danh sách ID người tham gia
  final String? lastMessage; // Tin nhắn cuối cùng
  final DateTime? lastMessageTime; // Thời gian tin nhắn cuối
  final String? lastSenderId; // ID người gửi tin nhắn cuối
  final int unreadCount; // Số tin nhắn chưa đọc

  const ChatRoom({
    required this.id,
    required this.type,
    this.tutorId,
    this.studentId,
    this.groupBookingId,
    required this.participantIds,
    this.lastMessage,
    this.lastMessageTime,
    this.lastSenderId,
    this.unreadCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'tutorId': tutorId,
      'studentId': studentId,
      'groupBookingId': groupBookingId,
      'participantIds': participantIds,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime?.toIso8601String(),
      'lastSenderId': lastSenderId,
      'unreadCount': unreadCount,
    };
  }

  factory ChatRoom.fromMap(String id, Map<String, dynamic> data) {
    DateTime? parsedDate;
    final rawDate = data['lastMessageTime'];
    if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate);
    } else if (rawDate != null) {
      try {
        parsedDate = (rawDate as dynamic).toDate() as DateTime;
      } catch (_) {
        parsedDate = null;
      }
    }

    return ChatRoom(
      id: id,
      type: data['type'] ?? 'tutor',
      tutorId: data['tutorId'] as String?,
      studentId: data['studentId'] as String?,
      groupBookingId: data['groupBookingId'] as String?,
      participantIds: data['participantIds'] is List
          ? List<String>.from(data['participantIds'])
          : [],
      lastMessage: data['lastMessage'] as String?,
      lastMessageTime: parsedDate,
      lastSenderId: data['lastSenderId'] as String?,
      unreadCount: (data['unreadCount'] ?? 0) as int,
    );
  }
}


