import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

import '../../models/assignment.dart';
import '../../models/booking.dart';
import '../../services/assignment_service.dart';
import '../../services/auth_service.dart';

/// Màn hình chi tiết bài tập
class AssignmentDetailScreen extends StatefulWidget {
  final Assignment assignment;
  final Booking booking;
  final bool isTutor;

  const AssignmentDetailScreen({
    super.key,
    required this.assignment,
    required this.booking,
    this.isTutor = false,
  });

  @override
  State<AssignmentDetailScreen> createState() => _AssignmentDetailScreenState();
}

class _AssignmentDetailScreenState extends State<AssignmentDetailScreen> {
  final _assignmentService = AssignmentService();
  final _contentCtrl = TextEditingController();
  List<File> _attachmentFiles = [];
  bool _isSubmitting = false;

  @override
  void dispose() {
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          for (var file in result.files) {
            if (file.path != null) {
              _attachmentFiles.add(File(file.path!));
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi chọn file: $e')),
        );
      }
    }
  }

  Future<void> _submitAssignment() async {
    final user = context.read<AuthService>().currentUser;
    if (user == null) return;

    setState(() => _isSubmitting = true);

    try {
      // Upload attachments nếu có
      List<String> attachmentUrls = [];
      for (var file in _attachmentFiles) {
        final fileName = file.path.split('/').last;
        final submissionId = DateTime.now().millisecondsSinceEpoch.toString();
        final url = await _assignmentService.uploadSubmissionFile(
          file,
          submissionId,
          fileName,
        );
        attachmentUrls.add(url);
      }

      await _assignmentService.submitAssignment(
        assignmentId: widget.assignment.id,
        studentId: user.id,
        content: _contentCtrl.text.trim().isEmpty
            ? null
            : _contentCtrl.text.trim(),
        attachments: attachmentUrls,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nộp bài thành công!'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _contentCtrl.clear();
          _attachmentFiles.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi nộp bài: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthService>().currentUser;
    final isOverdue = widget.assignment.dueDate.isBefore(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.assignment.title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thông tin bài tập
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.assignment.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(widget.assignment.description),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: isOverdue ? Colors.red : Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Hạn nộp: ${DateFormat('dd/MM/yyyy HH:mm').format(widget.assignment.dueDate)}',
                          style: TextStyle(
                            color: isOverdue ? Colors.red : Colors.grey[600],
                            fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.star, size: 16, color: Colors.orange),
                        const SizedBox(width: 4),
                        Text('Điểm tối đa: ${widget.assignment.maxScore}'),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // File đính kèm của bài tập
            if (widget.assignment.attachments.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'File đính kèm',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...widget.assignment.attachments.map((url) => Card(
                child: ListTile(
                  leading: const Icon(Icons.insert_drive_file),
                  title: Text(url.split('/').last),
                  trailing: IconButton(
                    icon: const Icon(Icons.download),
                    onPressed: () async {
                      final uri = Uri.parse(url);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                ),
              )),
            ],

            // Phần nộp bài (chỉ cho học viên)
            if (!widget.isTutor && user != null) ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                'Nộp bài tập',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              StreamBuilder<Submission?>(
                stream: _assignmentService.streamSubmission(
                  widget.assignment.id,
                  user.id,
                ),
                builder: (context, snap) {
                  final submission = snap.data;

                  if (submission != null) {
                    // Đã nộp bài
                    return Card(
                      color: Colors.green.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.check_circle, color: Colors.green),
                                const SizedBox(width: 8),
                                const Text(
                                  'Đã nộp bài',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Nộp lúc: ${DateFormat('dd/MM/yyyy HH:mm').format(submission.submittedAt)}',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                            if (submission.content != null) ...[
                              const SizedBox(height: 8),
                              Text(submission.content!),
                            ],
                            if (submission.attachments.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              const Text('File đính kèm:'),
                              ...submission.attachments.map((url) => ListTile(
                                dense: true,
                                leading: const Icon(Icons.insert_drive_file, size: 16),
                                title: Text(
                                  url.split('/').last,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.download, size: 16),
                                  onPressed: () async {
                                    final uri = Uri.parse(url);
                                    if (await canLaunchUrl(uri)) {
                                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                                    }
                                  },
                                ),
                              )),
                            ],
                            if (submission.score != null) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.grade, color: Colors.blue),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Điểm: ${submission.score}/${widget.assignment.maxScore}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (submission.feedback != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Nhận xét: ${submission.feedback}',
                                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                              ),
                            ],
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _contentCtrl.text = submission.content ?? '';
                                });
                              },
                              child: const Text('Nộp lại'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  // Chưa nộp bài
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _contentCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nội dung bài làm (tùy chọn)',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                        maxLines: 5,
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _pickFiles,
                        icon: const Icon(Icons.attach_file),
                        label: const Text('Thêm file đính kèm'),
                      ),
                      if (_attachmentFiles.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ..._attachmentFiles.map((file) => Card(
                          child: ListTile(
                            leading: const Icon(Icons.insert_drive_file),
                            title: Text(file.path.split('/').last),
                            trailing: IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                setState(() => _attachmentFiles.remove(file));
                              },
                            ),
                          ),
                        )),
                      ],
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _isSubmitting || isOverdue ? null : _submitAssignment,
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(isOverdue ? 'Đã quá hạn nộp' : 'Nộp bài'),
                      ),
                    ],
                  );
                },
              ),
            ],

            // Phần xem bài nộp (chỉ cho gia sư)
            if (widget.isTutor) ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                'Bài nộp của học viên',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              StreamBuilder<List<Submission>>(
                stream: _assignmentService.streamSubmissionsForAssignment(
                  widget.assignment.id,
                ),
                builder: (context, snap) {
                  final submissions = snap.data ?? [];

                  if (submissions.isEmpty) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Chưa có học viên nào nộp bài'),
                      ),
                    );
                  }

                  return Column(
                    children: submissions.map((submission) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ExpansionTile(
                          title: Text('Học viên: ${submission.studentId}'),
                          subtitle: Text(
                            'Nộp lúc: ${DateFormat('dd/MM/yyyy HH:mm').format(submission.submittedAt)}',
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (submission.content != null)
                                    Text(submission.content!),
                                  if (submission.attachments.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    const Text('File đính kèm:'),
                                    ...submission.attachments.map((url) => ListTile(
                                      dense: true,
                                      leading: const Icon(Icons.insert_drive_file),
                                      title: Text(url.split('/').last),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.download),
                                        onPressed: () async {
                                          final uri = Uri.parse(url);
                                          if (await canLaunchUrl(uri)) {
                                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                                          }
                                        },
                                      ),
                                    )),
                                  ],
                                  const SizedBox(height: 8),
                                  if (submission.score != null)
                                    Text(
                                      'Điểm: ${submission.score}/${widget.assignment.maxScore}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                    )
                                  else
                                    _GradeSubmissionWidget(
                                      submission: submission,
                                      maxScore: widget.assignment.maxScore,
                                    ),
                                  if (submission.feedback != null) ...[
                                    const SizedBox(height: 8),
                                    Text('Nhận xét: ${submission.feedback}'),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Widget để gia sư chấm điểm
class _GradeSubmissionWidget extends StatefulWidget {
  final Submission submission;
  final int maxScore;

  const _GradeSubmissionWidget({
    required this.submission,
    required this.maxScore,
  });

  @override
  State<_GradeSubmissionWidget> createState() => _GradeSubmissionWidgetState();
}

class _GradeSubmissionWidgetState extends State<_GradeSubmissionWidget> {
  final _scoreCtrl = TextEditingController();
  final _feedbackCtrl = TextEditingController();
  final _assignmentService = AssignmentService();
  bool _isGrading = false;

  @override
  void dispose() {
    _scoreCtrl.dispose();
    _feedbackCtrl.dispose();
    super.dispose();
  }

  Future<void> _grade() async {
    final score = int.tryParse(_scoreCtrl.text.trim());
    if (score == null || score < 0 || score > widget.maxScore) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Điểm phải từ 0 đến ${widget.maxScore}')),
      );
      return;
    }

    setState(() => _isGrading = true);

    try {
      await _assignmentService.gradeSubmission(
        submissionId: widget.submission.id,
        score: score,
        feedback: _feedbackCtrl.text.trim().isEmpty
            ? null
            : _feedbackCtrl.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chấm điểm thành công!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi chấm điểm: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGrading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _scoreCtrl,
                decoration: InputDecoration(
                  labelText: 'Điểm (0-${widget.maxScore})',
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _isGrading ? null : _grade,
              child: _isGrading
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Chấm điểm'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _feedbackCtrl,
          decoration: const InputDecoration(
            labelText: 'Nhận xét (tùy chọn)',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
      ],
    );
  }
}


