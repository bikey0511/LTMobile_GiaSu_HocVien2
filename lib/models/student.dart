enum UserRole { admin, tutor, student }

class StudentProfile {
  final String id;
  final String fullName;
  final String email;
  final String avatarUrl;
  final UserRole role;

  const StudentProfile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.avatarUrl,
    required this.role,
  });

  // Map để lưu Firestore
  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'email': email,
      'avatarUrl': avatarUrl,
      'role': role.name,
    };
  }

  factory StudentProfile.fromMap(String id, Map<String, dynamic> data) {
    final roleStr = data['role'] as String? ?? 'student';
    return StudentProfile(
      id: id,
      fullName: data['fullName'] ?? '',
      email: data['email'] ?? '',
      avatarUrl: data['avatarUrl'] ?? '',
      role: UserRole.values.firstWhere(
        (r) => r.name == roleStr,
        orElse: () => UserRole.student,
      ),
    );
  }
}
