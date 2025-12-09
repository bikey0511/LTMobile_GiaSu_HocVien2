import '../models/booking.dart';

class BookingService {
  final List<Booking> _bookings = [];

  List<Booking> getBookingsForStudent(String studentId) {
    return _bookings.where((b) => b.studentId == studentId).toList();
  }

  List<Booking> getAll() => List.unmodifiable(_bookings);

  void addBooking(Booking booking) {
    _bookings.add(booking);
  }

  void updateAccepted(String id, bool accepted, {String? reason}) {
    final idx = _bookings.indexWhere((b) => b.id == id);
    if (idx >= 0) {
      final b = _bookings[idx];
      _bookings[idx] = Booking(
        id: b.id,
        tutorId: b.tutorId,
        studentId: b.studentId,
        dateTime: b.dateTime,
        durationMinutes: b.durationMinutes,
        priceTotal: b.priceTotal,
        note: b.note,
        paid: b.paid,
        accepted: accepted,
        rejectReason: reason ?? b.rejectReason,
        totalSessions: b.totalSessions,
        completedSessions: b.completedSessions,
        completed: b.completed,
        isGroupClass: b.isGroupClass,
        groupSize: b.groupSize,
      );
    }
  }

  void updatePaid(String id, bool paid) {
    final idx = _bookings.indexWhere((b) => b.id == id);
    if (idx >= 0) {
      final b = _bookings[idx];
      _bookings[idx] = Booking(
        id: b.id,
        tutorId: b.tutorId,
        studentId: b.studentId,
        dateTime: b.dateTime,
        durationMinutes: b.durationMinutes,
        priceTotal: b.priceTotal,
        note: b.note,
        paid: paid,
        accepted: b.accepted,
        rejectReason: b.rejectReason,
        totalSessions: b.totalSessions,
        completedSessions: b.completedSessions,
        completed: b.completed,
        isGroupClass: b.isGroupClass,
        groupSize: b.groupSize,
      );
    }
  }

  void updateCompletedSessions(String id, int completedSessions) {
    final idx = _bookings.indexWhere((b) => b.id == id);
    if (idx >= 0) {
      final b = _bookings[idx];
      final completed = completedSessions >= b.totalSessions;
      _bookings[idx] = Booking(
        id: b.id,
        tutorId: b.tutorId,
        studentId: b.studentId,
        dateTime: b.dateTime,
        durationMinutes: b.durationMinutes,
        priceTotal: b.priceTotal,
        note: b.note,
        paid: b.paid,
        accepted: b.accepted,
        rejectReason: b.rejectReason,
        totalSessions: b.totalSessions,
        completedSessions: completedSessions,
        completed: completed,
        isGroupClass: b.isGroupClass,
        groupSize: b.groupSize,
      );
    }
  }

  void cancel(String id, {String? reason}) {
    final idx = _bookings.indexWhere((b) => b.id == id);
    if (idx >= 0) {
      final b = _bookings[idx];
      _bookings[idx] = Booking(
        id: b.id,
        tutorId: b.tutorId,
        studentId: b.studentId,
        dateTime: b.dateTime,
        durationMinutes: b.durationMinutes,
        priceTotal: b.priceTotal,
        note: b.note,
        paid: b.paid,
        accepted: b.accepted,
        rejectReason: b.rejectReason,
        totalSessions: b.totalSessions,
        completedSessions: b.completedSessions,
        completed: b.completed,
        isGroupClass: b.isGroupClass,
        groupSize: b.groupSize,
        cancelled: true,
        cancelReason: reason,
      );
    }
  }
}
