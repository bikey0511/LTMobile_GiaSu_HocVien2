class Tutor {
  final String id;
  final String name;
  final String avatarUrl;
  final String subject;
  final String bio;
  final double hourlyRate;
  final double rating; // 0..5
  final int reviewCount;
  final bool approved; // Admin duyệt hồ sơ gia sư

  const Tutor({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.subject,
    required this.bio,
    required this.hourlyRate,
    required this.rating,
    required this.reviewCount,
    this.approved = true,
  });

  // Chuyển đổi sang Map để lưu Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'avatarUrl': avatarUrl,
      'subject': subject,
      'bio': bio,
      'hourlyRate': hourlyRate,
      'rating': rating,
      'reviewCount': reviewCount,
      'approved': approved,
    };
  }

  // Tạo đối tượng từ Firestore
  factory Tutor.fromMap(String id, Map<String, dynamic> data) {
    return Tutor(
      id: id,
      name: data['name'] ?? '',
      avatarUrl: data['avatarUrl'] ?? '',
      subject: data['subject'] ?? '',
      bio: data['bio'] ?? '',
      hourlyRate: (data['hourlyRate'] ?? 0).toDouble(),
      rating: (data['rating'] ?? 0).toDouble(),
      reviewCount: (data['reviewCount'] ?? 0) as int,
      approved: (data['approved'] ?? true) as bool,
    );
  }
}
