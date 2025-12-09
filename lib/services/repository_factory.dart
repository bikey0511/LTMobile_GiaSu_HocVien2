import 'dart:async';

import '../models/booking.dart';
import '../models/tutor.dart';
import 'booking_repository.dart';
import 'tutor_repository.dart';
import 'booking_service.dart';
import 'tutor_service.dart';

/// Bật/tắt Firebase. Nếu false, dùng dữ liệu mock chạy offline
/// 
/// Khi useFirebase = true:
/// - Tất cả thao tác trên app sẽ tự động ghi vào Firestore
/// - Firestore snapshots() sẽ tự động emit khi có thay đổi
/// - UI sẽ tự động cập nhật realtime khi Firestore thay đổi
/// - Đồng bộ hai chiều: App ↔ Firebase
class RepoFactory {
  static bool useFirebase = false;

  static TutorRepo tutor() => useFirebase ? _FirestoreTutorRepo() : _MockTutorRepo();
  static BookingRepo booking() => useFirebase ? _FirestoreBookingRepo() : _MockBookingRepo();
}

/// Interfaces (tối thiểu) dùng bởi UI
abstract class TutorRepo {
  Stream<List<Tutor>> streamApprovedTutors();
  Stream<List<Tutor>> streamPendingTutors();
  Future<Tutor?> getById(String id);
  Stream<Tutor?> streamById(String id); // Stream để tự động cập nhật khi Admin duyệt
  Future<void> setApproved(String id, bool approved);
  Future<void> delete(String id); // Xóa hồ sơ khi Admin từ chối
}

abstract class BookingRepo {
  Future<void> create(Booking b);
  Stream<List<Booking>> streamForStudent(String studentId);
  Stream<List<Booking>> streamForTutor(String tutorId);
  Future<List<Booking>> getTutorBookings(String tutorId); // Lấy bookings của tutor (sync, để check trùng lịch)
  Future<void> updateAccepted(String id, bool accepted, {String? reason});
  Future<void> updatePaid(String id, bool paid);
  Future<void> updateCompletedSessions(String id, int completedSessions); // Cập nhật số buổi đã hoàn thành
  Future<void> cancel(String id, {String? reason}); // Hủy booking
}

/// Firestore adapters
class _FirestoreTutorRepo implements TutorRepo {
  final _inner = TutorRepository();
  @override
  Stream<List<Tutor>> streamApprovedTutors() => _inner.streamApprovedTutors();
  @override
  Stream<List<Tutor>> streamPendingTutors() => _inner.streamPendingTutors();
  @override
  Future<Tutor?> getById(String id) => _inner.getById(id);
  @override
  Stream<Tutor?> streamById(String id) => _inner.streamById(id);
  @override
  Future<void> setApproved(String id, bool approved) => _inner.setApproved(id, approved);
  @override
  Future<void> delete(String id) => _inner.delete(id);
}

class _FirestoreBookingRepo implements BookingRepo {
  final _inner = BookingRepository();
  @override
  Future<void> create(Booking b) => _inner.create(b);
  @override
  Stream<List<Booking>> streamForStudent(String studentId) => _inner.streamForStudent(studentId);
  @override
  Stream<List<Booking>> streamForTutor(String tutorId) => _inner.streamForTutor(tutorId);
  @override
  Future<List<Booking>> getTutorBookings(String tutorId) => _inner.getTutorBookings(tutorId);
  @override
  Future<void> updateAccepted(String id, bool accepted, {String? reason}) => _inner.updateAccepted(id, accepted, reason: reason);
  @override
  Future<void> updatePaid(String id, bool paid) => _inner.updatePaid(id, paid);
  @override
  Future<void> updateCompletedSessions(String id, int completedSessions) => _inner.updateCompletedSessions(id, completedSessions);
  @override
  Future<void> cancel(String id, {String? reason}) => _inner.cancel(id, reason: reason);
}

/// Mock adapters (offline)
class _MockTutorRepo implements TutorRepo {
  final _service = TutorService();
  @override
  Future<Tutor?> getById(String id) async => _service.getTutorById(id);
  @override
  Stream<Tutor?> streamById(String id) => _service.streamAll().map((list) {
    try {
      return list.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  });
  @override
  Stream<List<Tutor>> streamApprovedTutors() => _service.streamAll().map((list) => list.where((t) => t.approved).toList());
  @override
  Stream<List<Tutor>> streamPendingTutors() => _service.streamAll().map((list) => list.where((t) => !t.approved).toList());
  @override
  Future<void> setApproved(String id, bool approved) async {
    _service.setApproved(id, approved);
  }
  @override
  Future<void> delete(String id) async {
    _service.delete(id);
  }
}

class _MockBookingRepo implements BookingRepo {
  final _service = BookingService();
  final _controllerAll = StreamController<List<Booking>>.broadcast();

  _MockBookingRepo();

  void _emitAll() {
    _controllerAll.add(_service.getAll());
  }

  @override
  Future<void> create(Booking b) async {
    _service.addBooking(b);
    _emitAll();
  }

  @override
  Stream<List<Booking>> streamForStudent(String studentId) {
    // phát ngay lần đầu
    Future.microtask(() => _emitAll());
    return _controllerAll.stream.map((list) => list.where((b) => b.studentId == studentId).toList());
  }

  @override
  Stream<List<Booking>> streamForTutor(String tutorId) {
    // phát ngay lần đầu
    Future.microtask(() => _emitAll());
    // Lọc tạm thời theo tutorId từ tất cả bookings của controller
    return _controllerAll.stream.map((list) => list.where((b) => b.tutorId == tutorId).toList());
  }

  @override
  Future<void> updateAccepted(String id, bool accepted, {String? reason}) async {
    _service.updateAccepted(id, accepted, reason: reason);
    _emitAll();
  }

  @override
  Future<void> updatePaid(String id, bool paid) async {
    _service.updatePaid(id, paid);
    _emitAll();
  }

  @override
  Future<void> updateCompletedSessions(String id, int completedSessions) async {
    _service.updateCompletedSessions(id, completedSessions);
    _emitAll();
  }

  @override
  Future<List<Booking>> getTutorBookings(String tutorId) async {
    return _service.getAll().where((b) => b.tutorId == tutorId).toList();
  }

  @override
  Future<void> cancel(String id, {String? reason}) async {
    _service.cancel(id, reason: reason);
    _emitAll();
  }
}


