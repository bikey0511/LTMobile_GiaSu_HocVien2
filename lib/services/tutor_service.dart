import 'dart:async';
import '../models/tutor.dart';

class TutorService {
  static final List<Tutor> _mockTutors = [
    const Tutor(
      id: 't1',
      name: 'Trần Minh Khoa',
      avatarUrl: 'https://images.unsplash.com/photo-1603415526960-f7e0328d13bf?q=80&w=600&auto=format&fit=crop',
      subject: 'Toán THPT',
      bio: '10 năm kinh nghiệm luyện thi THPTQG. Phương pháp dễ hiểu, bám sát đề.',
      hourlyRate: 180000,
      rating: 4.8,
      reviewCount: 124,
    ),
    const Tutor(
      id: 't2',
      name: 'Nguyễn Thu Hà',
      avatarUrl: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?q=80&w=600&auto=format&fit=crop',
      subject: 'Tiếng Anh giao tiếp',
      bio: 'IELTS 8.0. Tập trung vào phản xạ và phát âm.',
      hourlyRate: 220000,
      rating: 4.9,
      reviewCount: 210,
    ),
    const Tutor(
      id: 't3',
      name: 'Phạm Đức Long',
      avatarUrl: 'https://images.unsplash.com/photo-1547425260-76bcadfb4f2c?q=80&w=600&auto=format&fit=crop',
      subject: 'Vật Lý THCS',
      bio: 'Giải thích hiện tượng qua thực nghiệm. Tạo hứng thú học tập.',
      hourlyRate: 160000,
      rating: 4.6,
      reviewCount: 86,
    ),
  ];

  final StreamController<List<Tutor>> _controller = StreamController.broadcast();

  TutorService() {
    // phát danh sách ban đầu
    Future.microtask(() => _controller.add(List.unmodifiable(_mockTutors)));
  }

  List<Tutor> getTutors() => List.unmodifiable(_mockTutors);

  Stream<List<Tutor>> streamAll() => _controller.stream;

  Tutor? getTutorById(String id) {
    try {
      return _mockTutors.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  void addOrUpdate(Tutor tutor) {
    final idx = _mockTutors.indexWhere((t) => t.id == tutor.id);
    if (idx >= 0) {
      _mockTutors[idx] = tutor;
    } else {
      _mockTutors.add(tutor);
    }
    _controller.add(List.unmodifiable(_mockTutors));
  }

  void setApproved(String id, bool approved) {
    final idx = _mockTutors.indexWhere((t) => t.id == id);
    if (idx >= 0) {
      final t = _mockTutors[idx];
      _mockTutors[idx] = Tutor(
        id: t.id,
        name: t.name,
        avatarUrl: t.avatarUrl,
        subject: t.subject,
        bio: t.bio,
        hourlyRate: t.hourlyRate,
        rating: t.rating,
        reviewCount: t.reviewCount,
        approved: approved,
      );
      _controller.add(List.unmodifiable(_mockTutors));
    }
  }

  void delete(String id) {
    _mockTutors.removeWhere((t) => t.id == id);
    _controller.add(List.unmodifiable(_mockTutors));
  }
}
