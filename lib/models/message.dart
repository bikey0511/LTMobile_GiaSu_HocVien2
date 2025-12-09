class ChatMessage {
  final String id;
  final String roomId; // combined tutorId-studentId hoặc group-{bookingId}
  final String senderId;
  final String text;
  final DateTime sentAt;
  final List<String> readBy; // Danh sách userId đã đọc tin nhắn này

  const ChatMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.text,
    required this.sentAt,
    this.readBy = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'roomId': roomId,
      'senderId': senderId,
      'text': text,
      'sentAt': sentAt.toIso8601String(),
      'readBy': readBy,
    };
  }

  factory ChatMessage.fromMap(String id, Map<String, dynamic> data) {
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

    // Parse readBy list
    List<String> parsedReadBy = [];
    if (data['readBy'] != null && data['readBy'] is List) {
      parsedReadBy = List<String>.from(data['readBy']);
    }

    return ChatMessage(
      id: id,
      roomId: data['roomId'] ?? '',
      senderId: data['senderId'] ?? '',
      text: data['text'] ?? '',
      sentAt: parseDate(data['sentAt']),
      readBy: parsedReadBy,
    );
  }
}

