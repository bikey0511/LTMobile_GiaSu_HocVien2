import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/tutor.dart';
import 'firestore_refs.dart';

class TutorRepository {
  final _col = FirestoreRefs.tutors();

  /// Stream danh sách gia sư đã được duyệt
  /// Stream này tự động cập nhật realtime khi có thay đổi trong Firestore
  /// Khi Admin duyệt gia sư trên app → Firestore cập nhật → Stream tự động emit → UI tự động cập nhật
  /// Khi thao tác trên Firebase Console → Stream tự động emit → UI tự động cập nhật
  Stream<List<Tutor>> streamApprovedTutors() {
    return _col
        .where('approved', isEqualTo: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) {
              try {
                return Tutor.fromMap(d.id, d.data());
              } catch (e) {
                // Bỏ qua documents không hợp lệ
                return null;
              }
            })
            .where((t) => t != null)
            .cast<Tutor>()
            .toList())
        .handleError((error) {
      // Log error nhưng không crash app
      print('Error in streamApprovedTutors: $error');
      return <Tutor>[];
    });
  }

  /// Stream danh sách gia sư chờ duyệt
  /// Stream này tự động cập nhật realtime khi có thay đổi trong Firestore
  /// Khi gia sư đăng ký hoặc Admin thao tác → Firestore cập nhật → Stream tự động emit → UI tự động cập nhật
  Stream<List<Tutor>> streamPendingTutors() {
    // Query documents có approved = false hoặc không có field approved (mặc định false)
    // Firestore query chỉ match documents có field, nên cần lấy tất cả rồi filter
    // Nhưng đảm bảo khi tạo tutor luôn set approved: false
    // Sử dụng snapshots() để listen realtime changes
    return _col.snapshots().map((s) => s.docs
        .map((d) {
          try {
            final data = d.data();
            // Nếu không có field approved, mặc định là false (chờ duyệt)
            if (!data.containsKey('approved')) {
              return Tutor.fromMap(d.id, {...data, 'approved': false});
            }
            return Tutor.fromMap(d.id, data);
          } catch (e) {
            // Bỏ qua documents không hợp lệ
            return null;
          }
        })
        .where((t) => t != null && !t.approved)
        .cast<Tutor>()
        .toList())
        .handleError((error) {
      // Log error nhưng không crash app
      print('Error in streamPendingTutors: $error');
      return <Tutor>[];
    });
  }

  /// Lấy chi tiết gia sư theo id
  Future<Tutor?> getById(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return Tutor.fromMap(doc.id, doc.data() ?? {});
  }

  /// Admin duyệt hoặc từ chối hồ sơ gia sư
  Future<void> setApproved(String id, bool approved) async {
    // Dùng set với merge để đảm bảo field được cập nhật đúng, không ghi đè dữ liệu khác
    await _col.doc(id).set({'approved': approved}, SetOptions(merge: true));
    // Firestore sẽ tự động emit snapshot mới, stream sẽ tự động cập nhật
  }

  /// Tạo/cập nhật hồ sơ gia sư
  /// Sử dụng set với merge để đảm bảo atomic operation và tránh race conditions
  Future<void> upsert(Tutor tutor) async {
    try {
      // Sử dụng set với merge: true là cách an toàn nhất cho upsert
      // Nó sẽ tạo document nếu chưa tồn tại, hoặc merge với document hiện có
      await _col.doc(tutor.id).set(tutor.toMap(), SetOptions(merge: true));
    } on FirebaseException catch (e) {
      // Nếu có lỗi permission, throw lại để UI xử lý
      if (e.code == 'permission-denied') {
        rethrow;
      }
      // Với các lỗi khác, có thể là lỗi tạm thời, throw lại để retry logic xử lý
      rethrow;
    } catch (e) {
      // Với các lỗi không phải FirebaseException, throw lại
      rethrow;
    }
  }

  /// Stream hồ sơ gia sư theo id (để tự động cập nhật khi Admin duyệt)
  /// Stream này tự động cập nhật realtime khi có thay đổi trong Firestore
  /// Khi Admin duyệt/từ chối → Firestore cập nhật → Stream tự động emit → UI tự động cập nhật
  /// Khi thao tác trên Firebase Console → Stream tự động emit → UI tự động cập nhật
  Stream<Tutor?> streamById(String id) {
    // Nếu id rỗng, trả về stream null ngay lập tức
    if (id.isEmpty) {
      return Stream.value(null);
    }
    
    return _col.doc(id).snapshots().map((doc) {
      try {
        return doc.exists ? Tutor.fromMap(doc.id, doc.data()!) : null;
      } catch (e) {
        print('Error parsing tutor document: $e');
        return null;
      }
    }).handleError((error) {
      print('Error in streamById: $error');
      return null;
    });
  }

  /// Xóa hồ sơ gia sư (khi Admin từ chối)
  Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }
}
