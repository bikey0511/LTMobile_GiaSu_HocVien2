import '../models/tutor_class.dart';

class ClassService {
  final List<TutorClass> _classes = [];

  List<TutorClass> getForTutor(String tutorId) => _classes.where((c) => c.tutorId == tutorId).toList();

  List<TutorClass> getAll() => List.unmodifiable(_classes);

  void create(TutorClass c) {
    _classes.add(c);
  }

  void delete(String id) {
    _classes.removeWhere((c) => c.id == id);
  }
}

