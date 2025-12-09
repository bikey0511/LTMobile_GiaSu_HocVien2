import 'dart:async';

import '../models/student.dart';

class UserRegistry {
  static final UserRegistry _instance = UserRegistry._internal();
  factory UserRegistry() => _instance;
  UserRegistry._internal();

  final List<StudentProfile> _users = [];
  final Set<String> _emails = {};
  final StreamController<int> _studentCount = StreamController.broadcast();
  final StreamController<int> _tutorCount = StreamController.broadcast();

  void addOrUpdate(StudentProfile user) {
    final idx = _users.indexWhere((u) => u.id == user.id);
    if (idx >= 0) {
      _users[idx] = user;
    } else {
      _users.add(user);
      _emails.add(user.email.toLowerCase());
      _emit();
    }
  }

  bool emailExists(String email) => _emails.contains(email.toLowerCase());

  int countByRole(UserRole role) => _users.where((u) => u.role == role).length;

  Stream<int> studentCountStream() => _studentCount.stream;
  Stream<int> tutorCountStream() => _tutorCount.stream;

  void _emit() {
    _studentCount.add(countByRole(UserRole.student));
    _tutorCount.add(countByRole(UserRole.tutor));
  }
}
