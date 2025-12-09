import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/booking.dart';
import '../../services/auth_service.dart';
import '../../services/repository_factory.dart';
import '../../services/user_service.dart';
import '../../models/student.dart';

/// Màn hình lịch sử bookings cho Tutor
class TutorBookingHistoryScreen extends StatefulWidget {
  static const routeName = '/tutor-booking-history';
  const TutorBookingHistoryScreen({super.key});

  @override
  State<TutorBookingHistoryScreen> createState() => _TutorBookingHistoryScreenState();
}

class _TutorBookingHistoryScreenState extends State<TutorBookingHistoryScreen> {
  String _selectedFilter = 'all'; // 'all', 'pending', 'accepted', 'completed', 'cancelled'

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    if (user == null || (user.role != UserRole.tutor && user.role != UserRole.admin)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lịch sử dạy học')),
        body: const Center(child: Text('Chỉ dành cho gia sư')),
      );
    }

    final bookingRepo = RepoFactory.booking();
    final tutorId = user.id;
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử dạy học'),
      ),
      body: Column(
        children: [
          // Filter tabs
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 2,
                ),
              ],
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  _FilterChip(
                    label: 'Tất cả',
                    isSelected: _selectedFilter == 'all',
                    onTap: () => setState(() => _selectedFilter = 'all'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Chờ xác nhận',
                    isSelected: _selectedFilter == 'pending',
                    onTap: () => setState(() => _selectedFilter = 'pending'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Đã chấp nhận',
                    isSelected: _selectedFilter == 'accepted',
                    onTap: () => setState(() => _selectedFilter = 'accepted'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Đã hoàn thành',
                    isSelected: _selectedFilter == 'completed',
                    onTap: () => setState(() => _selectedFilter = 'completed'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Đã hủy',
                    isSelected: _selectedFilter == 'cancelled',
                    onTap: () => setState(() => _selectedFilter = 'cancelled'),
                  ),
                ],
              ),
            ),
          ),
          // Bookings list
          Expanded(
            child: StreamBuilder<List<Booking>>(
              stream: bookingRepo.streamForTutor(tutorId),
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
                      ],
                    ),
                  );
                }

                final bookings = snapshot.data ?? [];
                
                // Filter bookings
                List<Booking> filteredBookings;
                switch (_selectedFilter) {
                  case 'pending':
                    filteredBookings = bookings.where((b) => !b.accepted && !b.cancelled && b.rejectReason == null).toList();
                    break;
                  case 'accepted':
                    filteredBookings = bookings.where((b) => b.accepted && !b.completed && !b.cancelled).toList();
                    break;
                  case 'completed':
                    filteredBookings = bookings.where((b) => b.completed && !b.cancelled).toList();
                    break;
                  case 'cancelled':
                    filteredBookings = bookings.where((b) => b.cancelled || b.rejectReason != null).toList();
                    break;
                  default:
                    filteredBookings = bookings;
                }

                // Sort by date (newest first)
                filteredBookings.sort((a, b) => b.dateTime.compareTo(a.dateTime));

                if (filteredBookings.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _getEmptyIcon(),
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _getEmptyMessage(),
                          style: const TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() {});
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredBookings.length,
                    itemBuilder: (context, index) {
                      final booking = filteredBookings[index];
                      return _BookingCard(
                        booking: booking,
                        dateFormat: dateFormat,
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  IconData _getEmptyIcon() {
    switch (_selectedFilter) {
      case 'pending':
        return Icons.schedule;
      case 'accepted':
        return Icons.check_circle_outline;
      case 'completed':
        return Icons.done_all;
      case 'cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.event_note;
    }
  }

  String _getEmptyMessage() {
    switch (_selectedFilter) {
      case 'pending':
        return 'Chưa có lịch dạy nào đang chờ xác nhận';
      case 'accepted':
        return 'Chưa có lịch dạy nào đã được chấp nhận';
      case 'completed':
        return 'Chưa có lịch dạy nào đã hoàn thành';
      case 'cancelled':
        return 'Chưa có lịch dạy nào bị hủy';
      default:
        return 'Chưa có lịch dạy nào';
    }
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
      checkmarkColor: Theme.of(context).primaryColor,
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Booking booking;
  final DateFormat dateFormat;

  const _BookingCard({
    required this.booking,
    required this.dateFormat,
  });

  Color _getStatusColor() {
    if (booking.cancelled) return Colors.red;
    if (booking.rejectReason != null) return Colors.red;
    if (booking.completed) return Colors.green;
    if (booking.accepted) return Colors.blue;
    return Colors.orange;
  }

  String _getStatusText() {
    if (booking.cancelled) return 'Đã hủy';
    if (booking.rejectReason != null) return 'Đã từ chối';
    if (booking.completed) return 'Đã hoàn thành';
    if (booking.accepted) return 'Đã chấp nhận';
    return 'Chờ xác nhận';
  }

  IconData _getStatusIcon() {
    if (booking.cancelled) return Icons.cancel;
    if (booking.rejectReason != null) return Icons.close;
    if (booking.completed) return Icons.check_circle;
    if (booking.accepted) return Icons.check;
    return Icons.schedule;
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();
    final statusText = _getStatusText();
    final statusIcon = _getStatusIcon();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.2),
          child: Icon(statusIcon, color: statusColor),
        ),
        title: Text(dateFormat.format(booking.dateTime)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
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
                  label: 'Thời lượng',
                  value: '${booking.durationMinutes} phút',
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  label: 'Số buổi',
                  value: '${booking.completedSessions}/${booking.totalSessions} buổi',
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  label: 'Giá',
                  value: '${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(booking.priceTotal)}',
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  label: 'Thanh toán',
                  value: booking.paid ? 'Đã thanh toán' : 'Chưa thanh toán',
                ),
                if (booking.note.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _InfoRow(
                    label: 'Ghi chú',
                    value: booking.note,
                  ),
                ],
                if (booking.cancelReason != null) ...[
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


