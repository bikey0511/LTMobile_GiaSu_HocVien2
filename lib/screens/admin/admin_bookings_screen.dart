import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/repository_factory.dart';
import '../../services/wallet_service.dart';
import '../../models/booking.dart';
import '../../models/student.dart';
import '../../services/user_service.dart';
import '../../services/firestore_refs.dart';
import '../../models/tutor.dart';

/// Màn hình quản lý bookings cho Admin
class AdminBookingsScreen extends StatelessWidget {
  static const routeName = '/admin-bookings';
  const AdminBookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bookingRepo = RepoFactory.booking();
    final walletService = WalletService();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Bookings'),
      ),
      body: StreamBuilder<List<Booking>>(
        stream: _getAllBookings(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Lỗi: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Quay lại'),
                  ),
                ],
              ),
            );
          }

          final bookings = snapshot.data ?? [];
          
          if (bookings.isEmpty) {
            return const Center(
              child: Text('Chưa có booking nào'),
            );
          }

          // Sắp xếp theo thời gian (mới nhất trước)
          bookings.sort((a, b) => b.dateTime.compareTo(a.dateTime));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              final booking = bookings[index];
              return _BookingCard(
                booking: booking,
                onCancel: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Xác nhận hủy booking'),
                      content: Text(
                        'Bạn có chắc muốn hủy booking này? '
                        'Nếu đã thanh toán, tiền sẽ được hoàn lại cho học viên.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Hủy'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: FilledButton.styleFrom(backgroundColor: Colors.red),
                          child: const Text('Xác nhận hủy'),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true) {
                    try {
                      await bookingRepo.cancel(booking.id, reason: 'Hủy bởi Admin');
                      
                      // Nếu đã thanh toán, hoàn tiền
                      if (booking.paid) {
                        try {
                          await walletService.refundBooking(
                            studentId: booking.studentId,
                            bookingId: booking.id,
                            amount: booking.priceTotal,
                          );
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Đã hủy booking nhưng lỗi hoàn tiền: $e'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                        }
                      }

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đã hủy booking thành công'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Lỗi khi hủy booking: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  }
                },
              );
            },
          );
        },
      ),
    );
  }

  /// Lấy tất cả bookings từ tất cả tutors và students
  Stream<List<Booking>> _getAllBookings() {
    // Lấy tất cả bookings bằng cách stream từ Firestore trực tiếp
    return FirestoreRefs.bookings()
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        try {
          return Booking.fromMap(doc.id, doc.data());
        } catch (e) {
          print('Error parsing booking ${doc.id}: $e');
          return null;
        }
      }).where((b) => b != null).cast<Booking>().toList();
    }).handleError((error) {
      print('Stream error for bookings: $error');
      return <Booking>[];
    });
  }
}

class _BookingCard extends StatelessWidget {
  final Booking booking;
  final VoidCallback onCancel;

  const _BookingCard({
    required this.booking,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final dateStr = dateFormat.format(booking.dateTime);
    
    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (booking.cancelled) {
      statusColor = Colors.grey;
      statusText = 'Đã hủy';
      statusIcon = Icons.cancel;
    } else if (booking.rejectReason != null) {
      statusColor = Colors.red;
      statusText = 'Đã từ chối';
      statusIcon = Icons.close;
    } else if (booking.completed) {
      statusColor = Colors.green;
      statusText = 'Đã hoàn thành';
      statusIcon = Icons.check_circle;
    } else if (booking.accepted) {
      statusColor = Colors.blue;
      statusText = 'Đã chấp nhận';
      statusIcon = Icons.check;
    } else {
      statusColor = Colors.orange;
      statusText = 'Chờ xác nhận';
      statusIcon = Icons.pending;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.2),
          child: Icon(statusIcon, color: statusColor),
        ),
        title: Text('Booking #${booking.id.substring(0, 8)}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Thời gian: $dateStr'),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (booking.paid) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Đã thanh toán',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(
                  label: 'Học viên',
                  value: booking.studentId,
                  stream: UserService().streamById(booking.studentId),
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  label: 'Gia sư',
                  value: booking.tutorId,
                  stream: RepoFactory.tutor().streamById(booking.tutorId),
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  label: 'Số buổi',
                  value: '${booking.totalSessions} buổi',
                ),
                if (booking.completedSessions > 0) ...[
                  const SizedBox(height: 8),
                  _InfoRow(
                    label: 'Đã hoàn thành',
                    value: '${booking.completedSessions} buổi',
                  ),
                ],
                const SizedBox(height: 8),
                _InfoRow(
                  label: 'Giá',
                  value: '${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(booking.priceTotal)}',
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  label: 'Thời lượng',
                  value: '${booking.durationMinutes} phút',
                ),
                if (booking.note.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _InfoRow(
                    label: 'Ghi chú',
                    value: booking.note,
                  ),
                ],
                if (booking.cancelled && booking.cancelReason != null) ...[
                  const SizedBox(height: 8),
                  _InfoRow(
                    label: 'Lý do hủy',
                    value: booking.cancelReason!,
                  ),
                ],
                if (booking.rejectReason != null) ...[
                  const SizedBox(height: 8),
                  _InfoRow(
                    label: 'Lý do từ chối',
                    value: booking.rejectReason!,
                  ),
                ],
                if (!booking.cancelled && booking.rejectReason == null) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.cancel),
                      label: const Text('Hủy booking'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                      onPressed: onCancel,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Stream<dynamic>? stream;

  const _InfoRow({
    required this.label,
    required this.value,
    this.stream,
  });

  @override
  Widget build(BuildContext context) {
    if (stream != null) {
      return StreamBuilder(
        stream: stream,
        builder: (context, snapshot) {
          String displayValue = value;
          
          if (snapshot.hasData && snapshot.data != null) {
            final data = snapshot.data;
            if (data is StudentProfile) {
              displayValue = data.fullName;
            } else if (data is Tutor) {
              displayValue = data.name;
            }
          }
          
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 100,
                child: Text(
                  '$label:',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: Text(displayValue),
              ),
            ],
          );
        },
      );
    }
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: Text(value),
        ),
      ],
    );
  }
}
