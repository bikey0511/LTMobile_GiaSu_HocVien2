import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification.dart';
import 'firestore_refs.dart';

class NotificationService {
  final _col = FirestoreRefs.notifications();

  /// Tạo thông báo mới
  Future<void> create(NotificationModel notification) async {
    final data = notification.toMap();
    data['createdAt'] = Timestamp.fromDate(notification.createdAt);
    await _col.doc(notification.id).set(data);
  }

  /// Stream thông báo cho một user
  Stream<List<NotificationModel>> streamForUser(String userId) {
    // Tạo stream với timeout và fallback
    final stream = _col
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          try {
            return snapshot.docs
                .map((doc) {
                  try {
                    return NotificationModel.fromMap(doc.id, doc.data());
                  } catch (e) {
                    // Bỏ qua document lỗi
                    return null;
                  }
                })
                .whereType<NotificationModel>()
                .toList();
          } catch (e) {
            return <NotificationModel>[];
          }
        })
        .handleError((error) {
      // Trả về danh sách rỗng nếu có lỗi, không crash app
      return <NotificationModel>[];
    });
    
    // Tạo StreamController để đảm bảo emit ngay lập tức
    final controller = StreamController<List<NotificationModel>>.broadcast();
    
    // Emit empty list ngay lập tức
    controller.add(<NotificationModel>[]);
    
    // Listen to original stream và forward events
    stream.listen(
      (data) => controller.add(data),
      onError: (error) => controller.add(<NotificationModel>[]),
      onDone: () => controller.close(),
      cancelOnError: false,
    );
    
    // Thêm timeout
    return controller.stream.timeout(
      const Duration(seconds: 10),
      onTimeout: (sink) {
        sink.add(<NotificationModel>[]);
      },
    );
  }

  /// Đánh dấu thông báo đã đọc
  Future<void> markAsRead(String notificationId) async {
    await _col.doc(notificationId).update({'read': true});
  }

  /// Đánh dấu tất cả thông báo đã đọc
  Future<void> markAllAsRead(String userId) async {
    final snapshot = await _col.where('userId', isEqualTo: userId).where('read', isEqualTo: false).get();
    final batch = FirebaseFirestore.instance.batch();
    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  /// Đếm số thông báo chưa đọc
  Stream<int> unreadCount(String userId) {
    return _col
        .where('userId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length)
        .handleError((error) {
      // Trả về 0 nếu có lỗi
      return 0;
    });
  }

  /// Xóa thông báo
  Future<void> delete(String notificationId) async {
    await _col.doc(notificationId).delete();
  }

  /// Xóa tất cả thông báo của một user
  Future<void> deleteAll(String userId) async {
    final snapshot = await _col.where('userId', isEqualTo: userId).get();
    final batch = FirebaseFirestore.instance.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  /// Gửi thông báo cho học viên khi booking được chấp nhận
  Future<void> notifyBookingAccepted(String studentId, String bookingId, String tutorName) async {
    await create(NotificationModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: studentId,
      title: 'Lịch học được chấp nhận',
      message: 'Gia sư $tutorName đã chấp nhận lịch học của bạn. Vui lòng thanh toán để bắt đầu học.',
      type: 'booking',
      createdAt: DateTime.now(),
      data: {'bookingId': bookingId, 'action': 'payment'},
    ));
  }

  /// Gửi thông báo cho học viên khi booking bị từ chối
  Future<void> notifyBookingRejected(String studentId, String bookingId, String tutorName, String reason) async {
    await create(NotificationModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: studentId,
      title: 'Lịch học bị từ chối',
      message: 'Gia sư $tutorName đã từ chối lịch học của bạn. Lý do: $reason',
      type: 'booking',
      createdAt: DateTime.now(),
      data: {'bookingId': bookingId},
    ));
  }

  /// Gửi thông báo cho gia sư khi có booking mới
  Future<void> notifyNewBooking(String tutorId, String bookingId, String studentName) async {
    await create(NotificationModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: tutorId,
      title: 'Có lịch học mới',
      message: 'Học viên $studentName đã đặt lịch học với bạn. Vui lòng xác nhận.',
      type: 'booking',
      createdAt: DateTime.now(),
      data: {'bookingId': bookingId, 'action': 'review'},
    ));
  }

  /// Gửi thông báo cho gia sư khi hồ sơ được duyệt
  Future<void> notifyTutorApproved(String tutorId) async {
    await create(NotificationModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: tutorId,
      title: 'Hồ sơ được duyệt',
      message: 'Hồ sơ gia sư của bạn đã được duyệt. Bạn có thể bắt đầu nhận lịch học.',
      type: 'approval',
      createdAt: DateTime.now(),
    ));
  }

  /// Gửi thông báo cho học viên khi thanh toán thành công
  Future<void> notifyPaymentSuccess(String studentId, String bookingId, double amount) async {
    await create(NotificationModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: studentId,
      title: 'Thanh toán thành công',
      message: 'Bạn đã thanh toán ${amount.toStringAsFixed(0)}₫ cho lịch học. Bạn có thể vào phòng học.',
      type: 'payment',
      createdAt: DateTime.now(),
      data: {'bookingId': bookingId, 'amount': amount},
    ));
  }

  /// Gửi thông báo cho gia sư khi có yêu cầu rút tiền
  Future<void> notifyWithdrawalRequest(String adminId, String transactionId, String tutorName, double amount) async {
    await create(NotificationModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: adminId,
      title: 'Yêu cầu rút tiền mới',
      message: 'Gia sư $tutorName yêu cầu rút ${amount.toStringAsFixed(0)}₫. Vui lòng xem xét.',
      type: 'withdrawal',
      createdAt: DateTime.now(),
      data: {'transactionId': transactionId},
    ));
  }

  /// Gửi thông báo cho học viên khi được hoàn tiền do gia sư từ chối
  Future<void> notifyRefund(String studentId, String bookingId, double amount, String reason) async {
    await create(NotificationModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: studentId,
      title: 'Đã hoàn tiền',
      message: 'Bạn đã được hoàn ${amount.toStringAsFixed(0)}₫ do gia sư từ chối lịch học. Lý do: $reason',
      type: 'refund',
      createdAt: DateTime.now(),
      data: {'bookingId': bookingId, 'amount': amount},
    ));
  }

  /// Gửi thông báo cho học viên khi đặt lịch thành công
  Future<void> notifyBookingCreated(String studentId, String bookingId, String tutorName, String dateTime) async {
    await create(NotificationModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: studentId,
      title: 'Đặt lịch thành công',
      message: 'Bạn đã đặt lịch học với gia sư $tutorName vào $dateTime. Vui lòng chờ gia sư xác nhận.',
      type: 'booking',
      createdAt: DateTime.now(),
      data: {'bookingId': bookingId, 'action': 'view'},
    ));
  }

  /// Gửi thông báo cho gia sư khi học viên hủy lịch
  Future<void> notifyBookingCancelled(String tutorId, String bookingId, String studentName, String? reason) async {
    await create(NotificationModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: tutorId,
      title: 'Lịch học bị hủy',
      message: 'Học viên $studentName đã hủy lịch học.${reason != null && reason.isNotEmpty ? ' Lý do: $reason' : ''}',
      type: 'booking',
      createdAt: DateTime.now(),
      data: {'bookingId': bookingId},
    ));
  }

  /// Gửi thông báo nhắc nhở lịch học hôm nay (chỉ 1 lần trong ngày)
  Future<void> notifyTodayBookingReminder(String studentId, String bookingId, String tutorName, String time) async {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    
    try {
      // Kiểm tra xem đã gửi reminder "trong ngày" cho booking này chưa
      final existing = await _col
          .where('userId', isEqualTo: studentId)
          .where('type', isEqualTo: 'reminder')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
          .where('createdAt', isLessThan: Timestamp.fromDate(todayEnd))
          .get();
      
      // Kiểm tra xem đã có reminder "today" cho booking này chưa
      bool alreadyExists = false;
      for (var doc in existing.docs) {
        final data = doc.data();
        if (data['data'] is Map) {
          final notificationData = data['data'] as Map;
          if (notificationData['bookingId'] == bookingId && 
              notificationData['reminderType'] == 'today') {
            alreadyExists = true;
            break;
          }
        }
      }
      
      // Nếu chưa có thông báo nhắc nhở "trong ngày", tạo mới
      if (!alreadyExists) {
        await create(NotificationModel(
          id: 'reminder-today-${bookingId}-${DateTime.now().millisecondsSinceEpoch}',
          userId: studentId,
          title: 'Nhắc nhở: Lịch học hôm nay',
          message: 'Bạn có lịch học với gia sư $tutorName lúc $time hôm nay. Vui lòng chuẩn bị sẵn sàng!',
          type: 'reminder',
          createdAt: DateTime.now(),
          data: {'bookingId': bookingId, 'action': 'view', 'reminderType': 'today'},
        ));
      }
    } catch (e) {
      // Nếu có lỗi, vẫn tạo thông báo (tránh mất thông báo quan trọng)
      await create(NotificationModel(
        id: 'reminder-today-${bookingId}-${DateTime.now().millisecondsSinceEpoch}',
        userId: studentId,
        title: 'Nhắc nhở: Lịch học hôm nay',
        message: 'Bạn có lịch học với gia sư $tutorName lúc $time hôm nay. Vui lòng chuẩn bị sẵn sàng!',
        type: 'reminder',
        createdAt: DateTime.now(),
        data: {'bookingId': bookingId, 'action': 'view', 'reminderType': 'today'},
      ));
    }
  }

  /// Gửi thông báo nhắc nhở trước 1 tiếng khi lịch học bắt đầu (chỉ 1 lần)
  Future<void> notifyOneHourBeforeBooking(String studentId, String bookingId, String tutorName, String time) async {
    try {
      // Kiểm tra xem đã gửi reminder "trước 1 tiếng" cho booking này chưa
      final existing = await _col
          .where('userId', isEqualTo: studentId)
          .where('type', isEqualTo: 'reminder')
          .get();
      
      // Kiểm tra xem đã có reminder "oneHourBefore" cho booking này chưa
      bool alreadyExists = false;
      for (var doc in existing.docs) {
        final data = doc.data();
        if (data['data'] is Map) {
          final notificationData = data['data'] as Map;
          if (notificationData['bookingId'] == bookingId && 
              notificationData['reminderType'] == 'oneHourBefore') {
            alreadyExists = true;
            break;
          }
        }
      }
      
      // Nếu chưa có thông báo nhắc nhở "trước 1 tiếng", tạo mới
      if (!alreadyExists) {
        await create(NotificationModel(
          id: 'reminder-1h-${bookingId}-${DateTime.now().millisecondsSinceEpoch}',
          userId: studentId,
          title: 'Nhắc nhở: Lịch học sắp bắt đầu',
          message: 'Lịch học với gia sư $tutorName lúc $time sẽ bắt đầu sau 1 giờ. Vui lòng chuẩn bị!',
          type: 'reminder',
          createdAt: DateTime.now(),
          data: {'bookingId': bookingId, 'action': 'view', 'reminderType': 'oneHourBefore'},
        ));
      }
    } catch (e) {
      // Nếu có lỗi, vẫn tạo thông báo (tránh mất thông báo quan trọng)
      await create(NotificationModel(
        id: 'reminder-1h-${bookingId}-${DateTime.now().millisecondsSinceEpoch}',
        userId: studentId,
        title: 'Nhắc nhở: Lịch học sắp bắt đầu',
        message: 'Lịch học với gia sư $tutorName lúc $time sẽ bắt đầu sau 1 giờ. Vui lòng chuẩn bị!',
        type: 'reminder',
        createdAt: DateTime.now(),
        data: {'bookingId': bookingId, 'action': 'view', 'reminderType': 'oneHourBefore'},
      ));
    }
  }
}

