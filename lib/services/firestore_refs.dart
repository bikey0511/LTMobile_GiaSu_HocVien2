import 'package:cloud_firestore/cloud_firestore.dart';

/// Các collection sử dụng trong hệ thống
class FirestoreRefs {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// users: lưu hồ sơ người dùng (admin/tutor/student)
  static CollectionReference<Map<String, dynamic>> users() => _db.collection('users');

  /// tutors: lưu thông tin hồ sơ gia sư
  static CollectionReference<Map<String, dynamic>> tutors() => _db.collection('tutors');

  /// bookings: lưu lịch đặt học
  static CollectionReference<Map<String, dynamic>> bookings() => _db.collection('bookings');

  /// wallets: lưu số dư ví của user
  static CollectionReference<Map<String, dynamic>> wallets() => _db.collection('wallets');

  /// transactions: lưu lịch sử giao dịch
  static CollectionReference<Map<String, dynamic>> transactions() => _db.collection('transactions');

  /// notifications: lưu thông báo cho users
  static CollectionReference<Map<String, dynamic>> notifications() => _db.collection('notifications');

  /// materials: lưu tài liệu khóa học
  static CollectionReference<Map<String, dynamic>> materials() => _db.collection('materials');

  /// assignments: lưu bài tập
  static CollectionReference<Map<String, dynamic>> assignments() => _db.collection('assignments');

  /// submissions: lưu bài nộp của học viên
  static CollectionReference<Map<String, dynamic>> submissions() => _db.collection('submissions');

  /// messages: lưu tin nhắn chat
  static CollectionReference<Map<String, dynamic>> messages() => _db.collection('messages');

  /// reviews: lưu đánh giá của học viên cho gia sư
  static CollectionReference<Map<String, dynamic>> reviews() => _db.collection('reviews');
}

