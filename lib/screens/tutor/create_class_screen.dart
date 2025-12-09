import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/class_service.dart';
import '../../services/auth_service.dart';
import '../../models/tutor_class.dart';

class CreateClassScreen extends StatefulWidget {
  static const routeName = '/tutor-create-class';
  const CreateClassScreen({super.key});

  @override
  State<CreateClassScreen> createState() => _CreateClassScreenState();
}

class _CreateClassScreenState extends State<CreateClassScreen> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _subject = TextEditingController();
  final _rate = TextEditingController(text: '200000');
  final _service = ClassService();

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _subject.dispose();
    _rate.dispose();
    super.dispose();
  }

  void _submit() {
    final me = context.read<AuthService>().currentUser;
    if (me == null) return;
    final c = TutorClass(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      tutorId: me.id,
      title: _title.text,
      description: _desc.text,
      subject: _subject.text,
      hourlyRate: double.tryParse(_rate.text) ?? 0,
    );
    _service.create(c);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tạo lớp học')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'Tiêu đề')), 
          const SizedBox(height: 12),
          TextField(controller: _subject, decoration: const InputDecoration(labelText: 'Môn học')), 
          const SizedBox(height: 12),
          TextField(controller: _desc, decoration: const InputDecoration(labelText: 'Mô tả'), maxLines: 3),
          const SizedBox(height: 12),
          TextField(controller: _rate, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Giá/giờ (đ)')),
          const SizedBox(height: 16),
          FilledButton(onPressed: _submit, child: const Text('Tạo lớp')),
        ],
      ),
    );
  }
}

