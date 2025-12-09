import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/booking.dart';
import '../../models/tutor.dart';
import '../../services/auth_service.dart';
// Trang đặt lịch: ghi/đọc Firestore
import '../../services/repository_factory.dart';
import '../../services/wallet_service.dart';
import '../../services/notification_service.dart';
import '../../services/user_service.dart';
import '../../services/firestore_refs.dart';
import '../wallet/wallet_screen.dart';
import '../../widgets/primary_button.dart';
import '../notification/notification_screen.dart';
import '../review/review_dialog.dart';
import '../../services/review_repository.dart';
import '../../models/review.dart';

class BookingScreen extends StatefulWidget {
  final Tutor? initialTutor;
  const BookingScreen({super.key, this.initialTutor});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _bookingRepo = RepoFactory.booking();
  final _tutorRepo = RepoFactory.tutor();
  final _walletService = WalletService();

  Tutor? _selectedTutor;
  DateTime _selectedDateTime = DateTime.now().add(const Duration(days: 1));
  int _durationMinutes = 60;
  int _totalSessions = 1; // Số buổi học của khóa học
  bool _isGroupClass = false; // Học nhóm hay học 1-1
  int _groupSize = 1; // Số lượng học viên trong nhóm
  final _noteCtrl = TextEditingController();
  final List<TextEditingController> _friendEmailControllers = []; // Danh sách email bạn bè

  @override
  void initState() {
    super.initState();
    // Prefill gia sư nếu được truyền từ màn chi tiết
    _selectedTutor = widget.initialTutor;
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    for (var ctrl in _friendEmailControllers) {
      ctrl.dispose();
    }
    super.dispose();
  }

  // Helper để hiển thị icon trạng thái
  Widget _getStatusIcon(Booking b) {
    if (b.cancelled) {
      return const Icon(Icons.cancel, color: Colors.red);
    } else if (b.rejectReason != null) {
      return const Icon(Icons.cancel, color: Colors.red);
    } else if (b.paid && b.accepted) {
      return const Icon(Icons.check_circle, color: Colors.green);
    } else if (b.accepted) {
      return const Icon(Icons.pending, color: Colors.orange);
    } else {
      return const Icon(Icons.schedule, color: Colors.blue);
    }
  }

  // Helper để hiển thị chip trạng thái
  Widget _buildStatusChip(Booking b) {
    String statusText;
    Color statusColor;
    IconData statusIcon;

    if (b.cancelled) {
      statusText = 'Đã hủy';
      statusColor = Colors.red;
      statusIcon = Icons.cancel;
    } else if (b.rejectReason != null) {
      statusText = 'Bị từ chối: ${b.rejectReason}';
      statusColor = Colors.red;
      statusIcon = Icons.cancel;
    } else if (b.accepted) {
      statusText = 'Đã được gia sư chấp nhận';
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else {
      statusText = 'Chờ gia sư xác nhận';
      statusColor = Colors.orange;
      statusIcon = Icons.schedule;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, size: 16, color: statusColor),
          const SizedBox(width: 4),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Tính giá với logic tính thêm theo số thành viên khi học nhóm
  // Giá nhóm = giá gốc (người đầu tiên) + (số thành viên - 1) × giá phụ thu mỗi thành viên
  double _calculateGroupPrice(double basePrice, int groupSize) {
    if (groupSize == 1) {
      return basePrice; // Học 1-1: giá đầy đủ
    } else {
      // Giá phụ thu cho mỗi thành viên thêm = 70% giá gốc
      // Ví dụ: giá gốc 200k, nhóm 3 người = 200k + 2 × 140k = 480k
      final additionalMemberPrice = basePrice * 0.7;
      return basePrice + (groupSize - 1) * additionalMemberPrice;
    }
  }

  // Tính giá với logic giảm giá khi đặt nhiều buổi
  double _calculateSessionDiscount(double basePrice, int totalSessions) {
    if (totalSessions == 8) {
      return basePrice * 0.85; // Đặt 8 buổi: giảm 15%
    }
    return basePrice; // Các số buổi khác: giá đầy đủ
  }

  // Helper để hiển thị chip thanh toán
  Widget _buildPaymentChip(Booking b) {
    final isPaid = b.paid;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isPaid ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPaid ? Colors.green.withOpacity(0.3) : Colors.orange.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPaid ? Icons.payments : Icons.payment_outlined,
            size: 16,
            color: isPaid ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 4),
          Text(
            isPaid ? 'Đã thanh toán' : 'Chưa thanh toán',
            style: TextStyle(
              color: isPaid ? Colors.green : Colors.orange,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Kiểm tra xem khung giờ có trùng với booking nào của tutor không
  bool _isTimeSlotOccupied(DateTime dateTime, int durationMinutes, List<Booking> tutorBookings) {
    final newStart = dateTime;
    final newEnd = dateTime.add(Duration(minutes: durationMinutes));

    for (final booking in tutorBookings) {
      // Bỏ qua các booking đã bị hủy hoặc bị từ chối
      // NHƯNG vẫn kiểm tra các booking đang chờ xác nhận (chưa accepted) để tránh trùng lịch
      if (booking.cancelled || booking.rejectReason != null) continue;

      final bookingStart = booking.dateTime;
      final bookingEnd = booking.dateTime.add(Duration(minutes: booking.durationMinutes));

      // Kiểm tra trùng lịch: nếu có overlap
      // Trùng nếu: newStart < bookingEnd VÀ newEnd > bookingStart
      if (newStart.isBefore(bookingEnd) && newEnd.isAfter(bookingStart)) {
        return true;
      }
    }
    return false;
  }

  Future<void> _pickDateTime() async {
    // Bước 1: Chọn ngày
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: _selectedDateTime,
    );
    if (date == null) return;
    if (!mounted) return;

    // Bước 2: Lấy bookings của tutor để kiểm tra trùng lịch
    List<Booking> tutorBookings = [];
    if (_selectedTutor != null) {
      try {
        tutorBookings = await _bookingRepo.getTutorBookings(_selectedTutor!.id);
      } catch (e) {
        // Nếu lỗi, log nhưng vẫn tiếp tục (không chặn chọn thời gian)
        // Lỗi sẽ được kiểm tra lại khi submit
        print('⚠️ Error loading tutor bookings when selecting time: $e');
      }
    }

    // Bước 3: Chọn giờ với danh sách khung giờ
    final selectedTime = await showDialog<TimeOfDay>(
      context: context,
      builder: (context) => _TimeSlotPicker(
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
        durationMinutes: _durationMinutes,
        selectedDate: date,
        tutorBookings: tutorBookings,
      ),
    );
    if (selectedTime == null) return;
    if (!mounted) return;

    final newDateTime = DateTime(date.year, date.month, date.day, selectedTime.hour, selectedTime.minute);
    
    // Kiểm tra lại trùng lịch trước khi set
    if (_isTimeSlotOccupied(newDateTime, _durationMinutes, tutorBookings)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Khung giờ này đã được đặt. Vui lòng chọn khung giờ khác.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _selectedDateTime = newDateTime;
    });
  }

  void _submit() async {
    final user = context.read<AuthService>().currentUser;
    if (user == null || _selectedTutor == null) return;

    // Kiểm tra trùng lịch trước khi submit
    // getTutorBookings() không bao giờ throw error, luôn trả về danh sách (có thể rỗng)
    try {
      final tutorBookings = await _bookingRepo.getTutorBookings(_selectedTutor!.id);
      if (_isTimeSlotOccupied(_selectedDateTime, _durationMinutes, tutorBookings)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Khung giờ này đã được đặt. Vui lòng chọn khung giờ khác.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      // Nếu không trùng lịch, tiếp tục đặt lịch
    } catch (e) {
      // Nếu có lỗi không mong đợi (không nên xảy ra vì getTutorBookings không throw),
      // vẫn cho phép đặt lịch với cảnh báo
      print('⚠️ Unexpected error checking schedule conflict: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể kiểm tra trùng lịch. Vẫn tiếp tục đặt lịch...'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      // Không return, tiếp tục đặt lịch
    }

    // Tính giá cơ bản mỗi buổi
    final basePricePerSession = (_durationMinutes / 60.0) * _selectedTutor!.hourlyRate;
    // Tính giá nhóm (tăng theo số thành viên)
    final groupPricePerSession = _calculateGroupPrice(basePricePerSession, _groupSize);
    // Áp dụng giảm giá nếu đặt nhiều buổi (8 buổi)
    final finalGroupPricePerSession = _calculateSessionDiscount(groupPricePerSession, _totalSessions);
    // Tổng giá: Nếu học nhóm, người đặt thanh toán TỔNG GIÁ NHÓM, không phải giá mỗi người
    // Nếu học 1-1, thanh toán giá đầy đủ
    final totalPrice = finalGroupPricePerSession * _totalSessions;
    
    // Tìm user ID từ email của các bạn bè (nếu học nhóm)
    List<String> studentIds = [user.id]; // Bắt đầu với người đặt
    if (_isGroupClass && _groupSize > 1) {
      final usersRef = FirestoreRefs.users();
      
      for (var emailCtrl in _friendEmailControllers) {
        final email = emailCtrl.text.trim();
        if (email.isNotEmpty) {
          try {
            // Tìm user theo email trong Firestore
            final querySnapshot = await usersRef
                .where('email', isEqualTo: email)
                .limit(1)
                .get();
            
            if (querySnapshot.docs.isNotEmpty) {
              final friendId = querySnapshot.docs.first.id;
              if (!studentIds.contains(friendId)) {
                studentIds.add(friendId);
              }
            } else {
              // Nếu không tìm thấy, vẫn tiếp tục nhưng hiển thị cảnh báo
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Không tìm thấy tài khoản với email: $email. Bạn bè cần đăng ký tài khoản trước.'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          } catch (e) {
            // Lỗi khi tìm user, bỏ qua
          }
        }
      }
    }
    
    final newBooking = Booking(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      tutorId: _selectedTutor!.id,
      studentId: user.id,
      dateTime: _selectedDateTime,
      durationMinutes: _durationMinutes,
      priceTotal: totalPrice,
      note: _noteCtrl.text,
      paid: false,
      totalSessions: _totalSessions,
      completedSessions: 0,
      completed: false,
      isGroupClass: _isGroupClass,
      groupSize: _groupSize,
      studentIds: studentIds, // Danh sách tất cả học viên
    );
    
    try {
      await _bookingRepo.create(newBooking);
      // Gửi thông báo cho gia sư
      try {
        final userService = UserService();
        final student = await userService.getUser(user.id);
        final notificationService = NotificationService();
        await notificationService.notifyNewBooking(
          _selectedTutor!.id,
          newBooking.id,
          student?.fullName ?? 'Học viên',
        );
      } catch (e) {
        // Bỏ qua lỗi thông báo
        print('⚠️ Error sending notification to tutor: $e');
      }
      
      // Gửi thông báo cho học viên khi đặt lịch thành công
      try {
        final notificationService = NotificationService();
        final tutorName = _selectedTutor!.name;
        final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(_selectedDateTime);
        await notificationService.notifyBookingCreated(
          user.id,
          newBooking.id,
          tutorName,
          dateStr,
        );
      } catch (e) {
        // Bỏ qua lỗi thông báo
        print('⚠️ Error sending notification to student: $e');
      }
      
      setState(() {
        _noteCtrl.clear();
      });
      if (!mounted) return;
      
      // Hiển thị SnackBar thông báo đặt lịch thành công
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Đặt lịch thành công! Lịch học đã được tạo và chờ gia sư xác nhận.',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
      
      // Kiểm tra số dư ví - chỉ cho phép thanh toán ngay
      final wallet = await _walletService.getWallet(user.id);
      final balance = wallet?.balance ?? 0;
      final canPay = balance >= totalPrice;
      
      if (!canPay) {
        // Không đủ tiền - yêu cầu nạp tiền
        final neededAmount = totalPrice - balance;
        final shouldDeposit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Số dư không đủ'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bạn cần thanh toán: ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(totalPrice)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('Số dư hiện tại: ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(balance)}'),
                const SizedBox(height: 8),
                Text(
                  'Cần nạp thêm: ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(neededAmount)}',
                  style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text('Vui lòng nạp tiền để hoàn tất việc đặt lịch.'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Nạp tiền'),
              ),
            ],
          ),
        );
        
        if (shouldDeposit == true && mounted) {
          // Chuyển đến màn hình nạp tiền, sau đó quay lại để thanh toán
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => WalletScreen(),
            ),
          );
          
          // Sau khi nạp tiền xong, quay lại và thanh toán ngay
          if (mounted) {
            // Kiểm tra lại số dư
            final updatedWallet = await _walletService.getWallet(user.id);
            final updatedBalance = updatedWallet?.balance ?? 0;
            
            if (updatedBalance >= totalPrice) {
              // Đủ tiền rồi, thanh toán ngay
              await _processPayment(context, user.id, newBooking.id, totalPrice);
            } else {
              // Vẫn chưa đủ tiền
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Số dư vẫn chưa đủ. Vui lòng nạp thêm ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(totalPrice - updatedBalance)}.'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            }
          }
        }
        return;
      }
      
      // Đủ tiền - hiển thị dialog xác nhận thanh toán ngay
      final shouldPayNow = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Xác nhận thanh toán'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bạn có muốn thanh toán ngay không?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              if (_isGroupClass) ...[
                Text(
                  'Tổng giá nhóm: ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(totalPrice)}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  '(Bạn sẽ thanh toán cho cả nhóm ${_groupSize} người)',
                  style: TextStyle(fontSize: 12, color: Colors.orange[700], fontStyle: FontStyle.italic),
                ),
              ] else ...[
                Text(
                  'Tổng tiền: ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(totalPrice)}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
              const SizedBox(height: 12),
              Text('Số dư ví: ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(balance)}'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Bạn có đủ tiền trong ví để thanh toán.',
                        style: TextStyle(color: Colors.green[900], fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Thanh toán ngay'),
            ),
          ],
        ),
      );
      
      if (shouldPayNow == true && mounted) {
        // Người dùng xác nhận thanh toán ngay
        await _processPayment(context, user.id, newBooking.id, totalPrice);
      } else if (mounted) {
        // Người dùng đóng dialog - chuyển sang tab "Lịch đã đặt"
        Future.microtask(() {
          if (mounted) {
            DefaultTabController.of(context).animateTo(1);
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      
      String errorMsg = 'Không thể đặt lịch. Vui lòng thử lại.';
      final errorStr = e.toString();
      
      // Parse error message từ exception - ưu tiên message từ repository
      if (errorStr.contains('Lỗi kết nối Firestore')) {
        errorMsg = 'Lỗi kết nối Firestore. Vui lòng thử lại sau vài giây.';
      } else if (errorStr.contains('Lỗi kết nối mạng')) {
        errorMsg = 'Lỗi kết nối mạng. Vui lòng kiểm tra kết nối và thử lại.';
      } else if (errorStr.contains('Không có quyền') || errorStr.contains('permission-denied')) {
        errorMsg = 'Không có quyền đặt lịch. Vui lòng kiểm tra quyền truy cập.';
      } else if (errorStr.contains('INTERNAL ASSERTION FAILED') || 
          errorStr.contains('Unexpected state') ||
          errorStr.contains('Dart exception thrown from converted Future')) {
        errorMsg = 'Lỗi kết nối Firestore. Vui lòng thử lại sau vài giây.';
      } else if (errorStr.contains('network') || errorStr.contains('timeout') || errorStr.contains('unavailable')) {
        errorMsg = 'Lỗi kết nối mạng. Vui lòng kiểm tra kết nối và thử lại.';
      } else if (errorStr.contains('Timeout')) {
        errorMsg = 'Timeout khi đặt lịch. Vui lòng kiểm tra kết nối và thử lại.';
      }
      
      print('❌ Error in _submit: $errorStr');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Thử lại',
            textColor: Colors.white,
            onPressed: () {
              // Thử đặt lịch lại
              _submit();
            },
          ),
        ),
      );
    }
  }
  
  /// Xử lý thanh toán
  Future<void> _processPayment(BuildContext context, String userId, String bookingId, double amount) async {
    final user = context.read<AuthService>().currentUser;
    if (user == null) return;
    
    // Hiển thị loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    
    try {
      // Thanh toán
      final err = await _walletService.payBooking(
        studentId: userId,
        tutorId: _selectedTutor!.id,
        bookingId: bookingId,
        amount: amount,
      );
      
      if (!mounted) return;
      Navigator.pop(context); // Đóng loading dialog
      
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi thanh toán: $err'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }
      
      // Cập nhật trạng thái paid ngay lập tức sau khi thanh toán thành công
      bool paidUpdated = false;
      try {
        // Đợi một chút để đảm bảo booking đã được tạo trong Firestore
        await Future.delayed(const Duration(milliseconds: 500));
        await _bookingRepo.updatePaid(bookingId, true);
        paidUpdated = true;
        print('✅ Đã cập nhật trạng thái paid = true cho booking $bookingId');
        // Firestore snapshots() sẽ tự động emit khi có thay đổi
      } catch (e) {
        print('❌ Lỗi khi cập nhật trạng thái thanh toán: $e');
        // Nếu updatePaid thất bại, thử lại một lần nữa
        try {
          await Future.delayed(const Duration(milliseconds: 1000));
          await _bookingRepo.updatePaid(bookingId, true);
          paidUpdated = true;
          print('✅ Đã cập nhật trạng thái paid = true sau lần thử lại');
        } catch (e2) {
          print('❌ Lỗi khi cập nhật trạng thái thanh toán (lần 2): $e2');
          // Nếu vẫn thất bại, hiển thị cảnh báo nhưng không chặn
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Thanh toán thành công nhưng cập nhật trạng thái thất bại. Vui lòng kiểm tra lại hoặc liên hệ hỗ trợ.\nLỗi: ${e2.toString()}'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 6),
              ),
            );
          }
        }
      }
      
      // Gửi thông báo cho học viên (không chặn UI)
      Future.microtask(() async {
        try {
          final notificationService = NotificationService();
          await notificationService.notifyPaymentSuccess(
            userId,
            bookingId,
            amount,
          );
        } catch (e) {
          // Bỏ qua lỗi thông báo
          print('Lỗi khi gửi thông báo: $e');
        }
      });
      
      // Chỉ hiển thị thông báo thành công nếu cả thanh toán và updatePaid đều thành công
      if (paidUpdated && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thanh toán thành công!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        
        // Tự động chuyển sang tab "Lịch đã đặt" ngay lập tức
        // Stream sẽ tự động cập nhật khi Firestore emit thay đổi
        Future.microtask(() {
          if (mounted) {
            DefaultTabController.of(context).animateTo(1);
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Đóng loading dialog nếu có lỗi
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi thanh toán: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    final tutorsStream = _tutorRepo.streamApprovedTutors();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Đặt lịch học'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Đặt lịch'),
              Tab(text: 'Lịch đã đặt'),
              Tab(text: 'Lịch tháng'),
            ],
          ),
          actions: [
            // Icon thông báo
            Builder(
              builder: (context) {
                final user = context.watch<AuthService>().currentUser;
                if (user == null) return const SizedBox.shrink();
                return StreamBuilder<int>(
                  stream: NotificationService().unreadCount(user.id),
                  builder: (context, snap) {
                    final unreadCount = snap.data ?? 0;
                    return Stack(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.notifications_outlined),
                          onPressed: () {
                            Navigator.pushNamed(context, NotificationScreen.routeName);
                          },
                        ),
                        if (unreadCount > 0)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Text(
                                unreadCount > 9 ? '9+' : '$unreadCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
        body: TabBarView(
          children: [
            // Tab 1: Đặt lịch
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Tạo lịch mới', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                // Nếu đã có gia sư được chọn từ trang chủ, hiển thị thông tin gia sư (read-only)
                // Nếu không, hiển thị dropdown để chọn gia sư
                widget.initialTutor != null
                    ? TextFormField(
                        readOnly: true,
                        initialValue: '${widget.initialTutor!.name} - ${widget.initialTutor!.subject}',
                        decoration: const InputDecoration(
                          labelText: 'Gia sư đã chọn',
                          helperText: 'Gia sư đã được chọn từ trang chủ',
                          prefixIcon: Icon(Icons.person),
                        ),
                      )
                    : StreamBuilder<List<Tutor>>(
                        stream: tutorsStream,
                        builder: (context, snap) {
                          final tutors = snap.data ?? [];
                          // Đồng bộ _selectedTutor với danh sách hiện tại để tránh lỗi Dropdown
                          if (tutors.isNotEmpty) {
                            if (_selectedTutor != null) {
                              final match = tutors
                                  .where((t) => t.id == _selectedTutor!.id)
                                  .toList();
                              _selectedTutor =
                                  match.isNotEmpty ? match.first : tutors.first;
                            } else {
                              _selectedTutor = tutors.first;
                            }
                          } else {
                            _selectedTutor = null;
                          }
                          return DropdownButtonFormField<Tutor>(
                            value: _selectedTutor,
                            items: [
                              for (final t in tutors)
                                DropdownMenuItem(value: t, child: Text('${t.name} - ${t.subject}')),
                            ],
                            onChanged: (v) => setState(() => _selectedTutor = v),
                            decoration: const InputDecoration(labelText: 'Chọn gia sư'),
                          );
                        },
                      ),
                const SizedBox(height: 12),
                TextFormField(
                  readOnly: true,
                  onTap: _pickDateTime,
                  decoration: InputDecoration(
                    labelText: 'Thời gian',
                    suffixIcon: const Icon(Icons.schedule),
                    hintText: DateFormat('dd/MM/yyyy HH:mm').format(_selectedDateTime),
                  ),
                  controller: TextEditingController(text: DateFormat('dd/MM/yyyy HH:mm').format(_selectedDateTime)),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _durationMinutes,
                  items: const [60, 90, 120]
                      .map((m) => DropdownMenuItem(value: m, child: Text('$m phút')))
                      .toList(),
                  onChanged: (v) => setState(() => _durationMinutes = v ?? 60),
                  decoration: const InputDecoration(labelText: 'Thời lượng mỗi buổi'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: _totalSessions,
                  items: const [1, 2, 3, 8]
                      .map((s) => DropdownMenuItem(
                        value: s,
                        child: Row(
                          children: [
                            Text('$s buổi'),
                            if (s == 8) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Giảm 15%',
                                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ))
                      .toList(),
                  onChanged: (v) => setState(() => _totalSessions = v ?? 1),
                  decoration: const InputDecoration(
                    labelText: 'Số buổi học',
                    helperText: 'Đặt 8 buổi sẽ được giảm 15%',
                  ),
                ),
                const SizedBox(height: 16),
                // Chọn loại học
                const Text('Loại học', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Học 1-1'),
                        selected: !_isGroupClass,
                        onSelected: (selected) {
                          setState(() {
                            _isGroupClass = false;
                            _groupSize = 1;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Học nhóm'),
                        selected: _isGroupClass,
                        onSelected: (selected) {
                          setState(() {
                            _isGroupClass = selected;
                            if (selected) {
                              _groupSize = 2; // Mặc định 2 người khi chọn học nhóm
                            } else {
                              _groupSize = 1;
                            }
                          });
                        },
                      ),
                    ),
                  ],
                ),
                if (_isGroupClass) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: _groupSize,
                    items: const [2, 3, 4, 5, 6]
                        .map((s) => DropdownMenuItem(value: s, child: Text('$s học viên')))
                        .toList(),
                    onChanged: (v) {
                      setState(() {
                        _groupSize = v ?? 2;
                        // Điều chỉnh số lượng ô nhập email theo số học viên
                        final targetCount = _groupSize - 1; // Trừ đi người đặt
                        while (_friendEmailControllers.length < targetCount) {
                          _friendEmailControllers.add(TextEditingController());
                        }
                        while (_friendEmailControllers.length > targetCount) {
                          _friendEmailControllers.removeLast().dispose();
                        }
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'Số lượng học viên trong nhóm',
                      helperText: 'Bao gồm bạn và các bạn bè',
                    ),
                  ),
                  if (_groupSize > 1) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Thông tin bạn bè (email)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Nhập email của các bạn bè để họ có thể vào phòng học. Các bạn bè cần có tài khoản trong hệ thống.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    ...List.generate(_groupSize - 1, (index) {
                      // Đảm bảo có đủ controller
                      if (index >= _friendEmailControllers.length) {
                        _friendEmailControllers.add(TextEditingController());
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: TextField(
                          controller: _friendEmailControllers[index],
                          decoration: InputDecoration(
                            labelText: 'Email bạn bè ${index + 1}',
                            hintText: 'example@email.com',
                            prefixIcon: const Icon(Icons.email),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                      );
                    }),
                  ],
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _noteCtrl,
                  decoration: const InputDecoration(labelText: 'Ghi chú (tuỳ chọn)'),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                // Hiển thị giá
                Card(
                  color: Colors.blue[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.payments_outlined, color: Colors.blue),
                            const SizedBox(width: 8),
                            const Text(
                              'Thông tin thanh toán',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Builder(
                          builder: (context) {
                            // Tính giá để hiển thị
                            final basePricePerSession = (_durationMinutes / 60.0) * (_selectedTutor?.hourlyRate ?? 0);
                            final groupPricePerSession = _calculateGroupPrice(basePricePerSession, _groupSize);
                            final finalGroupPricePerSession = _calculateSessionDiscount(groupPricePerSession, _totalSessions);
                            final pricePerStudent = finalGroupPricePerSession / _groupSize; // Giá mỗi học viên (chỉ để hiển thị)
                            // Tổng giá: người đặt thanh toán tổng giá nhóm (nếu học nhóm) hoặc giá 1-1
                            final totalPrice = finalGroupPricePerSession * _totalSessions;
                            
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_isGroupClass) ...[
                                  Text(
                                    'Loại: Học nhóm (${_groupSize} học viên)',
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Giá gốc (1 người): ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(basePricePerSession)}',
                                    style: TextStyle(color: Colors.grey[700]),
                                  ),
                                  Text(
                                    'Giá phụ thu mỗi thành viên thêm: ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(basePricePerSession * 0.7)}',
                                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Tổng giá nhóm mỗi buổi: ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(groupPricePerSession)}',
                                    style: TextStyle(color: Colors.blue[700], fontWeight: FontWeight.w500),
                                  ),
                                  if (_totalSessions == 8) ...[
                                    Text(
                                      'Giá sau giảm 8 buổi: ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(finalGroupPricePerSession)}',
                                      style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                  const SizedBox(height: 4),
                                  Text(
                                    'Giá mỗi học viên/buổi: ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(pricePerStudent)}',
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                ] else ...[
                                  Text(
                                    'Loại: Học 1-1',
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 4),
                                  if (_totalSessions == 8) ...[
                                    Text(
                                      'Giá gốc mỗi buổi: ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(basePricePerSession)}',
                                      style: TextStyle(color: Colors.grey[700]),
                                    ),
                                    Text(
                                      'Giá sau giảm 8 buổi: ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(_calculateSessionDiscount(basePricePerSession, _totalSessions))}',
                                      style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.w500),
                                    ),
                                  ] else ...[
                                    Text(
                                      'Giá mỗi buổi: ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(basePricePerSession)}',
                                      style: const TextStyle(fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ],
                        const Divider(height: 24),
                        if (_isGroupClass) ...[
                          Text(
                            'Giá mỗi học viên (${_totalSessions} buổi): ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(pricePerStudent * _totalSessions)}',
                            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                          ),
                          const SizedBox(height: 4),
                        ],
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _isGroupClass 
                                        ? 'Tổng giá nhóm (${_totalSessions} buổi):'
                                        : 'Tổng ${_totalSessions} buổi:',
                                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(totalPrice),
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                                  ),
                                  if (_isGroupClass)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        '(Bạn sẽ thanh toán cho cả nhóm)',
                                        style: TextStyle(fontSize: 12, color: Colors.orange[700], fontStyle: FontStyle.italic),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (_totalSessions == 8)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Đã giảm 15%',
                                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Thanh toán qua ví điện tử trong app',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                PrimaryButton(label: 'Đặt lịch', onPressed: _submit),
              ],
            ),
            // Tab 2: Lịch đã đặt
            if (user != null)
              _BookingsListTab(
                bookingRepo: _bookingRepo,
                userId: user.id,
                buildBookingsList: _buildBookingsList,
              )
            else
              const Center(child: Text('Vui lòng đăng nhập')),
            // Tab 3: Lịch tháng
            if (user != null)
              _MonthlyCalendarView(
                userId: user.id,
                bookingRepo: _bookingRepo,
                getStatusIcon: _getStatusIcon,
                buildStatusChip: _buildStatusChip,
                buildPaymentChip: _buildPaymentChip,
              )
            else
              const Center(child: Text('Vui lòng đăng nhập')),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingsList(List<Booking> sortedBookings) {
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
        for (final b in sortedBookings)
                        Card(
                          child: ListTile(
              leading: _getStatusIcon(b),
                            title: Text(DateFormat('dd/MM/yyyy HH:mm').format(b.dateTime)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        b.isGroupClass ? Icons.group : Icons.person,
                        size: 16,
                        color: b.isGroupClass ? Colors.blue : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        b.isGroupClass ? 'Học nhóm (${b.groupSize} học viên)' : 'Học 1-1',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: b.isGroupClass ? Colors.blue : Colors.grey[700],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Thời lượng mỗi buổi: ${b.durationMinutes} phút'),
                  Text('Số buổi học: ${b.completedSessions}/${b.totalSessions} buổi'),
                  Text('Tổng tiền: ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(b.priceTotal)}'),
                  if (b.completed)
                    const SizedBox(height: 4),
                  if (b.completed)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, size: 16, color: Colors.green),
                          SizedBox(width: 4),
                          Text(
                            'Đã hoàn thành khóa học',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Nút đánh giá (chỉ hiển thị khi đã hoàn thành khóa học)
                  if (b.completed && !b.cancelled) ...[
                    const SizedBox(height: 8),
                    Builder(
                      builder: (context) {
                        final currentUser = context.read<AuthService>().currentUser;
                        if (currentUser == null) return const SizedBox.shrink();
                        return FutureBuilder<bool>(
                          future: ReviewRepository().hasReviewed(currentUser.id, b.tutorId),
                          builder: (context, snap) {
                            final hasReviewed = snap.data ?? false;
                            return SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: () async {
                                  try {
                                    // Mở dialog ngay, không cần query trước (tránh lỗi permission)
                                    // ReviewDialog sẽ tự kiểm tra existing review nếu cần
                                    if (!mounted) return;
                                    
                                    // Lấy existing review trong dialog để tránh lỗi permission ở đây
                                    Review? existingReview;
                                    try {
                                      final reviewRepo = ReviewRepository();
                                      existingReview = await reviewRepo.getReviewByStudentAndTutor(currentUser.id, b.tutorId);
                                    } catch (e) {
                                      // Nếu có lỗi khi lấy existing review, vẫn cho phép mở dialog
                                      // (có thể là review mới hoặc lỗi permission)
                                      print('⚠️ Could not fetch existing review: $e');
                                    }
                                    
                                    if (!mounted) return;
                                    
                                    final result = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => ReviewDialog(
                                        tutorId: b.tutorId,
                                        bookingId: b.id,
                                        existingReview: existingReview,
                                      ),
                                    );
                                    
                                    if (result == true && mounted) {
                                      // Refresh để cập nhật trạng thái đã đánh giá
                                      setState(() {});
                                    }
                                  } catch (e) {
                                    print('❌ Error opening review dialog: $e');
                                    if (mounted) {
                                      String errorMsg = 'Lỗi khi mở form đánh giá';
                                      final errorStr = e.toString();
                                      
                                      if (errorStr.contains('permission-denied')) {
                                        errorMsg = 'Không có quyền truy cập. Vui lòng kiểm tra Firestore rules hoặc đăng nhập lại.';
                                      } else if (errorStr.contains('network') || errorStr.contains('timeout')) {
                                        errorMsg = 'Lỗi kết nối mạng. Vui lòng kiểm tra kết nối và thử lại.';
                                      } else {
                                        errorMsg = 'Lỗi: $e';
                                      }
                                      
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(errorMsg),
                                          backgroundColor: Colors.red,
                                          duration: const Duration(seconds: 4),
                                        ),
                                      );
                                    }
                                  }
                                },
                                icon: Icon(hasReviewed ? Icons.edit : Icons.star),
                                label: Text(hasReviewed ? 'Chỉnh sửa đánh giá' : 'Đánh giá khóa học'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.amber,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 4),
                  if (b.note.isNotEmpty) ...[
                    Text('Ghi chú: ${b.note}'),
                    const SizedBox(height: 4),
                  ],
                  _buildStatusChip(b),
                  const SizedBox(height: 4),
                  _buildPaymentChip(b),
                  // Nút hủy/xóa lịch (chỉ hiển thị khi chưa hoàn thành và chưa bị hủy)
                  if (!b.completed && !b.cancelled && b.rejectReason == null) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _showCancelDialog(context, b),
                        icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                        label: const Text('Hủy lịch học', style: TextStyle(color: Colors.red)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                        ),
                      ),
                    ),
                  ],
                  // Hiển thị trạng thái đã hủy
                  if (b.cancelled) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.cancel, size: 16, color: Colors.red),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Đã hủy${b.cancelReason != null && b.cancelReason!.isNotEmpty ? ': ${b.cancelReason}' : ''}',
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  // Nút hoàn thành buổi học (chỉ hiển thị khi đã chấp nhận, đã thanh toán, và chưa hoàn thành hết)
                  if (b.accepted && b.paid && !b.completed && !b.cancelled && b.completedSessions < b.totalSessions) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Xác nhận'),
                              content: Text(
                                'Bạn đã hoàn thành buổi học ${b.completedSessions + 1}/${b.totalSessions}?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Hủy'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Xác nhận'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await _bookingRepo.updateCompletedSessions(b.id, b.completedSessions + 1);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  b.completedSessions + 1 >= b.totalSessions
                                      ? 'Chúc mừng! Bạn đã hoàn thành khóa học. Bây giờ bạn có thể đánh giá gia sư.'
                                      : 'Đã đánh dấu hoàn thành buổi học ${b.completedSessions + 1}/${b.totalSessions}',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.check_circle_outline),
                        label: Text('Hoàn thành buổi ${b.completedSessions + 1}'),
                      ),
                    ),
                  ],
                ],
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${b.priceTotal.toStringAsFixed(0)} đ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              isThreeLine: true,
            ),
          ),
      ],
    );
  }

  Future<void> _showCancelDialog(BuildContext context, Booking b) async {
    final user = context.read<AuthService>().currentUser;
    if (user == null) return;

    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hủy lịch học'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bạn có chắc chắn muốn hủy lịch học này?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text('Thời gian: ${DateFormat('dd/MM/yyyy HH:mm').format(b.dateTime)}'),
            Text('Tổng tiền: ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(b.priceTotal)}'),
            if (b.paid) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.orange),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Bạn đã thanh toán. Số tiền sẽ được hoàn lại vào ví.',
                        style: TextStyle(fontSize: 12, color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Lý do hủy (tùy chọn)',
                hintText: 'Nhập lý do hủy lịch học...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Không'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hủy lịch'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      reasonCtrl.dispose();
      return;
    }

    // Xử lý hủy lịch
    try {
      // Đánh dấu booking là đã hủy
      await _bookingRepo.cancel(b.id, reason: reasonCtrl.text.trim());

      // Nếu đã thanh toán, hoàn tiền
      if (b.paid && b.priceTotal > 0) {
        try {
          final walletService = WalletService();
          final refundError = await walletService.refundBooking(
            studentId: user.id,
            bookingId: b.id,
            amount: b.priceTotal,
            reason: reasonCtrl.text.trim().isNotEmpty 
                ? 'Hủy lịch học. Lý do: ${reasonCtrl.text.trim()}'
                : 'Hủy lịch học',
          );

          if (refundError != null) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Đã hủy lịch nhưng hoàn tiền thất bại: $refundError'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          }
        } catch (e) {
          if (context.mounted) {
            final errorStr = e.toString();
            String errorMsg = 'Đã hủy lịch nhưng lỗi hoàn tiền. Vui lòng thử lại.';
            
            // Parse error message để hiển thị rõ ràng hơn
            if (errorStr.contains('Dart exception thrown from converted Future')) {
              // Nếu là lỗi từ Future, lấy error message thực sự
              if (errorStr.contains('Lỗi hoàn tiền:')) {
                final match = RegExp(r'Lỗi hoàn tiền: (.+)').firstMatch(errorStr);
                if (match != null) {
                  errorMsg = 'Đã hủy lịch nhưng hoàn tiền thất bại: ${match.group(1)}';
                }
              } else {
                errorMsg = 'Đã hủy lịch nhưng lỗi hoàn tiền. Vui lòng thử lại sau vài giây.';
              }
            } else if (errorStr.contains('network') || errorStr.contains('timeout') || errorStr.contains('unavailable')) {
              errorMsg = 'Đã hủy lịch nhưng lỗi kết nối mạng khi hoàn tiền. Vui lòng kiểm tra kết nối và thử lại.';
            } else if (errorStr.contains('permission-denied')) {
              errorMsg = 'Đã hủy lịch nhưng không có quyền hoàn tiền. Vui lòng liên hệ admin.';
            }
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMsg),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        }
      }

      // Gửi thông báo cho gia sư
      try {
        final notificationService = NotificationService();
        await notificationService.notifyBookingCancelled(
          b.tutorId,
          b.id,
          user.fullName,
          reasonCtrl.text.trim(),
        );
      } catch (e) {
        // Bỏ qua lỗi thông báo
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              b.paid
                  ? 'Đã hủy lịch học. ${b.priceTotal.toStringAsFixed(0)}₫ đã được hoàn lại vào ví.'
                  : 'Đã hủy lịch học.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi hủy lịch: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      reasonCtrl.dispose();
    }
  }
}

// Widget chọn khung giờ với danh sách các giờ trong ngày
class _TimeSlotPicker extends StatefulWidget {
  final TimeOfDay initialTime;
  final int durationMinutes;
  final DateTime selectedDate;
  final List<Booking> tutorBookings;

  const _TimeSlotPicker({
    required this.initialTime,
    required this.durationMinutes,
    required this.selectedDate,
    required this.tutorBookings,
  });

  @override
  State<_TimeSlotPicker> createState() => _TimeSlotPickerState();
}

class _TimeSlotPickerState extends State<_TimeSlotPicker> {
  TimeOfDay? _selectedTime;

  @override
  void initState() {
    super.initState();
    _selectedTime = widget.initialTime;
  }

  // Kiểm tra xem khung giờ có bị chiếm không
  bool _isSlotOccupied(TimeOfDay time) {
    final slotStart = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      widget.selectedDate.day,
      time.hour,
      time.minute,
    );
    final slotEnd = slotStart.add(Duration(minutes: widget.durationMinutes));

    for (final booking in widget.tutorBookings) {
      if (booking.rejectReason != null) continue; // Bỏ qua booking bị từ chối

      final bookingDate = booking.dateTime;
      // Chỉ kiểm tra bookings trong cùng ngày
      if (bookingDate.year != widget.selectedDate.year ||
          bookingDate.month != widget.selectedDate.month ||
          bookingDate.day != widget.selectedDate.day) {
        continue;
      }

      final bookingStart = bookingDate;
      final bookingEnd = bookingDate.add(Duration(minutes: booking.durationMinutes));

      // Kiểm tra overlap
      if (slotStart.isBefore(bookingEnd) && slotEnd.isAfter(bookingStart)) {
        return true;
      }
    }
    return false;
  }

  // Tạo danh sách khung giờ từ 7h đến 22h, mỗi 30 phút
  List<TimeOfDay> _generateTimeSlots() {
    final slots = <TimeOfDay>[];
    for (int hour = 7; hour < 22; hour++) {
      slots.add(TimeOfDay(hour: hour, minute: 0));
      slots.add(TimeOfDay(hour: hour, minute: 30));
    }
    return slots;
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final timeSlots = _generateTimeSlots();

    return AlertDialog(
      title: const Text('Chọn khung giờ'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: timeSlots.map((time) {
              final isOccupied = _isSlotOccupied(time);
              final isSelected = _selectedTime?.hour == time.hour && _selectedTime?.minute == time.minute;

              return InkWell(
                onTap: isOccupied ? null : () => setState(() => _selectedTime = time),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isOccupied
                        ? Colors.grey[300]
                        : isSelected
                            ? Theme.of(context).primaryColor
                            : Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).primaryColor
                          : Colors.grey[300]!,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    _formatTime(time),
                    style: TextStyle(
                      color: isOccupied
                          ? Colors.grey[600]
                          : isSelected
                              ? Colors.white
                              : Colors.black87,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _selectedTime == null || _isSlotOccupied(_selectedTime!)
              ? null
              : () => Navigator.pop(context, _selectedTime),
          child: const Text('Chọn'),
        ),
      ],
    );
  }
}

/// Widget hiển thị lịch tháng với các ngày có lịch học
class _MonthlyCalendarView extends StatefulWidget {
  final String userId;
  final dynamic bookingRepo;
  final Widget Function(Booking) getStatusIcon;
  final Widget Function(Booking) buildStatusChip;
  final Widget Function(Booking) buildPaymentChip;

  const _MonthlyCalendarView({
    required this.userId,
    required this.bookingRepo,
    required this.getStatusIcon,
    required this.buildStatusChip,
    required this.buildPaymentChip,
  });

  @override
  State<_MonthlyCalendarView> createState() => _MonthlyCalendarViewState();
}

class _MonthlyCalendarViewState extends State<_MonthlyCalendarView> {
  DateTime _selectedMonth = DateTime.now();
  DateTime? _selectedDate;
  List<Booking> _bookings = [];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Booking>>(
      stream: widget.bookingRepo.streamForStudent(widget.userId),
      builder: (context, snap) {
        // Cập nhật danh sách bookings
        if (snap.hasData) {
          _bookings = snap.data ?? [];
        }

        // Hiển thị loading nếu đang tải
        if (snap.connectionState == ConnectionState.waiting && _bookings.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        // Hiển thị lỗi nếu có
        if (snap.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Lỗi: ${snap.error}'),
                const SizedBox(height: 16),
                const Text('Vui lòng thử lại sau'),
              ],
            ),
          );
        }

        // Lấy các ngày có lịch học (dùng String để so sánh dễ hơn)
        final datesWithBookings = _bookings
            .map((b) => '${b.dateTime.year}-${b.dateTime.month}-${b.dateTime.day}')
            .toSet();

        return Column(
          children: [
            // Header với nút chuyển tháng
            Container(
                    padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                              onPressed: () {
                      setState(() {
                        _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
                        _selectedDate = null;
                      });
                    },
                  ),
                  Text(
                    DateFormat('MMMM yyyy').format(_selectedMonth),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () {
                      setState(() {
                        _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
                        _selectedDate = null;
                      });
                    },
                  ),
                ],
              ),
            ),
            // Calendar grid
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildCalendarGrid(_selectedMonth, datesWithBookings),
                    if (_selectedDate != null) ...[
                      const Divider(),
                      _buildBookingsForDate(_selectedDate!),
                    ],
                  ],
                ),
                          ),
                        ),
                    ],
                  );
                },
    );
  }

  Widget _buildCalendarGrid(DateTime month, Set<String> datesWithBookings) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final firstDayOfWeek = firstDay.weekday; // 1 = Monday, 7 = Sunday
    final daysInMonth = lastDay.day;

    // Tên các ngày trong tuần
    final weekDays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header với tên các ngày
          Row(
            children: weekDays.map((day) => Expanded(
              child: Center(
                child: Text(
                  day,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            )).toList(),
          ),
          const SizedBox(height: 8),
          // Grid các ngày
          ...List.generate((firstDayOfWeek - 1 + daysInMonth + 6) ~/ 7, (weekIndex) {
            return Row(
              children: List.generate(7, (dayIndex) {
                final dayNumber = weekIndex * 7 + dayIndex - (firstDayOfWeek - 1) + 1;
                
                if (dayNumber < 1 || dayNumber > daysInMonth) {
                  return const Expanded(child: SizedBox());
                }

                final date = DateTime(month.year, month.month, dayNumber);
                final dateKey = '${date.year}-${date.month}-${date.day}';
                final hasBooking = datesWithBookings.contains(dateKey);
                final isSelected = _selectedDate != null &&
                    _selectedDate!.year == date.year &&
                    _selectedDate!.month == date.month &&
                    _selectedDate!.day == date.day;
                final isToday = date.year == DateTime.now().year &&
                    date.month == DateTime.now().month &&
                    date.day == DateTime.now().day;

                return Expanded(
                  child: GestureDetector(
                    onTap: hasBooking ? () {
                      setState(() {
                        _selectedDate = date;
                      });
                    } : null,
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(context).primaryColor
                            : hasBooking
                                ? Colors.blue[100]
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: isToday
                            ? Border.all(color: Colors.orange, width: 2)
                            : null,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            dayNumber.toString(),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal,
                              color: isSelected
                                  ? Colors.white
                                  : hasBooking
                                      ? Colors.blue[900]
                                      : Colors.black87,
                            ),
                          ),
                          if (hasBooking)
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white : Colors.blue[700],
                                shape: BoxShape.circle,
                              ),
                            ),
                          const SizedBox(height: 4),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBookingsForDate(DateTime date) {
    final bookingsForDate = _bookings.where((b) {
      final bookingDate = DateTime(b.dateTime.year, b.dateTime.month, b.dateTime.day);
      return bookingDate.year == date.year &&
          bookingDate.month == date.month &&
          bookingDate.day == date.day;
    }).toList();

    if (bookingsForDate.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Không có lịch học trong ngày này'),
      );
    }

    bookingsForDate.sort((a, b) => a.dateTime.compareTo(b.dateTime));

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lịch học ngày ${DateFormat('dd/MM/yyyy').format(date)}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...bookingsForDate.map((b) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: widget.getStatusIcon(b),
              title: Text(DateFormat('HH:mm').format(b.dateTime)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text('Thời lượng: ${b.durationMinutes} phút'),
                  Text('Số buổi: ${b.completedSessions}/${b.totalSessions}'),
                  const SizedBox(height: 4),
                  widget.buildStatusChip(b),
                  const SizedBox(height: 4),
                  widget.buildPaymentChip(b),
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }
}

// Widget riêng để quản lý tab "Lịch đã đặt" với khả năng giữ lại dữ liệu cũ khi stream reconnect
class _BookingsListTab extends StatefulWidget {
  final dynamic bookingRepo;
  final String userId;
  final Widget Function(List<Booking>) buildBookingsList;

  const _BookingsListTab({
    required this.bookingRepo,
    required this.userId,
    required this.buildBookingsList,
  });

  @override
  State<_BookingsListTab> createState() => _BookingsListTabState();
}

class _BookingsListTabState extends State<_BookingsListTab> {
  List<Booking> _cachedBookings = [];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Booking>>(
      stream: widget.bookingRepo.streamForStudent(widget.userId),
      builder: (context, snap) {
        // Nếu có lỗi
        if (snap.hasError) {
          // Nếu có dữ liệu cũ, vẫn hiển thị dữ liệu cũ
          if (_cachedBookings.isNotEmpty) {
            final sortedBookings = List<Booking>.from(_cachedBookings);
            sortedBookings.sort((a, b) => b.dateTime.compareTo(a.dateTime));
            return widget.buildBookingsList(sortedBookings);
          }
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Lỗi: ${snap.error}'),
                const SizedBox(height: 16),
                const Text('Vui lòng thử lại sau'),
              ],
            ),
          );
        }

        // Nếu có data mới, cập nhật cache và hiển thị
        if (snap.hasData) {
          final bookings = snap.data ?? [];
          // Chỉ cập nhật cache nếu có dữ liệu hợp lệ (không phải empty list do lỗi)
          // Nếu bookings rỗng nhưng có cache, giữ lại cache
          if (bookings.isNotEmpty) {
            // Lọc bỏ các booking đã hủy
            final validBookings = bookings.where((b) => !b.cancelled).toList();
            
            // Cập nhật cache
            _cachedBookings = validBookings;
            
            if (validBookings.isEmpty) {
              return const Center(child: Text('Chưa có lịch'));
            }
            
            final sortedBookings = List<Booking>.from(validBookings);
            sortedBookings.sort((a, b) => b.dateTime.compareTo(a.dateTime));
            return widget.buildBookingsList(sortedBookings);
          } else if (_cachedBookings.isNotEmpty) {
            // Nếu stream emit empty list nhưng có cache, giữ lại cache
            final sortedBookings = List<Booking>.from(_cachedBookings);
            sortedBookings.sort((a, b) => b.dateTime.compareTo(a.dateTime));
            return widget.buildBookingsList(sortedBookings);
          }
        }

        // Nếu đang loading và có dữ liệu cũ, hiển thị dữ liệu cũ
        if (snap.connectionState == ConnectionState.waiting) {
          if (_cachedBookings.isNotEmpty) {
            // Hiển thị dữ liệu cũ trong khi đang load
            final sortedBookings = List<Booking>.from(_cachedBookings);
            sortedBookings.sort((a, b) => b.dateTime.compareTo(a.dateTime));
            return widget.buildBookingsList(sortedBookings);
          }
          
          // Nếu chưa có dữ liệu cũ, hiển thị loading
          return FutureBuilder(
            future: Future.delayed(const Duration(seconds: 2)),
            builder: (context, timeoutSnap) {
              if (timeoutSnap.connectionState == ConnectionState.done) {
                // Sau 2 giây vẫn chưa có dữ liệu, hiển thị empty state
                return const Center(child: Text('Chưa có lịch'));
              }
              return const Center(child: CircularProgressIndicator());
            },
          );
        }

        // Fallback: nếu có dữ liệu cũ, hiển thị dữ liệu cũ
        if (_cachedBookings.isNotEmpty) {
          final sortedBookings = List<Booking>.from(_cachedBookings);
          sortedBookings.sort((a, b) => b.dateTime.compareTo(a.dateTime));
          return widget.buildBookingsList(sortedBookings);
        }

        // Fallback: hiển thị empty state
        return const Center(child: Text('Chưa có lịch'));
      },
    );
  }
}
