import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/assignment.dart';
import '../../models/booking.dart';
import '../../services/assignment_service.dart';
import 'assignment_detail_screen.dart';
import 'assignment_create_screen.dart';

/// Màn hình danh sách bài tập
class AssignmentListScreen extends StatelessWidget {
  final Booking booking;
  final bool isTutor; // true nếu là gia sư, false nếu là học viên

  const AssignmentListScreen({
    super.key,
    required this.booking,
    this.isTutor = false,
  });

  @override
  Widget build(BuildContext context) {
    final assignmentService = AssignmentService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bài tập'),
        actions: [
          if (isTutor)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Tạo bài tập mới',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AssignmentCreateScreen(booking: booking),
                  ),
                );
              },
            ),
        ],
      ),
      body: StreamBuilder<List<Assignment>>(
        stream: assignmentService.streamAssignmentsForBooking(booking.id),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snap.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Lỗi: ${snap.error}'),
                ],
              ),
            );
          }

          final assignments = snap.data ?? [];

          if (assignments.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.assignment_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'Chưa có bài tập',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isTutor
                        ? 'Tạo bài tập mới cho khóa học này'
                        : 'Gia sư sẽ thêm bài tập cho khóa học này',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: assignments.length,
            itemBuilder: (context, index) {
              final assignment = assignments[index];
              final isOverdue = assignment.dueDate.isBefore(DateTime.now());

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isOverdue
                        ? Colors.red.shade100
                        : Colors.blue.shade100,
                    child: Icon(
                      isOverdue ? Icons.warning : Icons.assignment,
                      color: isOverdue ? Colors.red : Colors.blue,
                    ),
                  ),
                  title: Text(
                    assignment.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        assignment.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Hạn nộp: ${DateFormat('dd/MM/yyyy HH:mm').format(assignment.dueDate)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isOverdue ? Colors.red : Colors.grey[600],
                          fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      if (assignment.attachments.isNotEmpty)
                        Text(
                          '${assignment.attachments.length} file đính kèm',
                          style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                        ),
                    ],
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AssignmentDetailScreen(
                          assignment: assignment,
                          booking: booking,
                          isTutor: isTutor,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

