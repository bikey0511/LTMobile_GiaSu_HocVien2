import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

import '../../models/booking.dart';
import '../../services/assignment_service.dart';
import '../../services/auth_service.dart';

/// Màn hình tạo bài tập mới
class AssignmentCreateScreen extends StatefulWidget {
  final Booking booking;
  const AssignmentCreateScreen({super.key, required this.booking});

  @override
  State<AssignmentCreateScreen> createState() => _AssignmentCreateScreenState();
}

class _AssignmentCreateScreenState extends State<AssignmentCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _maxScoreCtrl = TextEditingController(text: '100');
  final _assignmentService = AssignmentService();
  
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));
  List<File> _attachmentFiles = [];
  bool _isCreating = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _maxScoreCtrl.dispose();
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

  Future<void> _selectDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_dueDate),
      );
      if (time != null) {
        setState(() {
          _dueDate = DateTime(
            picked.year,
            picked.month,
            picked.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _createAssignment() async {
    if (!_formKey.currentState!.validate()) return;

    final user = context.read<AuthService>().currentUser;
    if (user == null) return;

    setState(() => _isCreating = true);

    try {
      // Upload attachments nếu có
      List<String> attachmentUrls = [];
      for (var file in _attachmentFiles) {
        final fileName = file.path.split('/').last;
        final url = await _assignmentService.uploadAttachment(
          file,
          DateTime.now().millisecondsSinceEpoch.toString(),
          fileName,
        );
        attachmentUrls.add(url);
      }

      await _assignmentService.createAssignment(
        bookingId: widget.booking.id,
        tutorId: user.id,
        title: _titleCtrl.text.trim(),
        description: _descriptionCtrl.text.trim(),
        dueDate: _dueDate,
        attachments: attachmentUrls,
        maxScore: int.tryParse(_maxScoreCtrl.text.trim()) ?? 100,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tạo bài tập thành công!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tạo bài tập: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tạo bài tập'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tiêu đề bài tập *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập tiêu đề';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nội dung bài tập *',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập nội dung';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _maxScoreCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Điểm tối đa',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          final score = int.tryParse(value);
                          if (score == null || score <= 0) {
                            return 'Điểm phải là số dương';
                          }
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _selectDueDate,
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        'Hạn nộp: ${_dueDate.day}/${_dueDate.month}/${_dueDate.year} ${_dueDate.hour}:${_dueDate.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isCreating ? null : _createAssignment,
                child: _isCreating
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Tạo bài tập'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


