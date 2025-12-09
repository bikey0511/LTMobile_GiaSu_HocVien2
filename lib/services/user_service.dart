import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/student.dart';
import 'firestore_refs.dart';

class UserService {
  final _users = FirestoreRefs.users();

  /// Tạo hoặc cập nhật hồ sơ người dùng sau khi đăng nhập/đăng ký
  Future<void> upsertUser(StudentProfile profile) async {
    await _users.doc(profile.id).set(profile.toMap(), SetOptions(merge: true));
  }

  /// Lấy hồ sơ người dùng theo id
  Future<StudentProfile?> getUser(String id) async {
    final doc = await _users.doc(id).get();
    if (!doc.exists) return null;
    return StudentProfile.fromMap(doc.id, doc.data() ?? {});
  }

  /// Stream hồ sơ người dùng theo id (realtime)
  Stream<StudentProfile?> streamById(String id) {
    return _users.doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      try {
        return StudentProfile.fromMap(doc.id, doc.data() ?? {});
      } catch (e) {
        print('Error parsing user ${doc.id}: $e');
        return null;
      }
    }).handleError((error) {
      print('Stream error for user $id: $error');
      return null;
    });
  }

  /// Xóa tài khoản người dùng (admin only)
  Future<void> deleteUser(String id) async {
    await _users.doc(id).delete();
  }
}

