import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Trang chi tiết gia sư: lấy dữ liệu Firestore theo id
import '../../services/repository_factory.dart';
import '../../services/auth_service.dart';
import '../../models/student.dart';
import '../../widgets/rating_stars.dart';
import '../../widgets/primary_button.dart';
import '../chat/chat_screen.dart';
import '../../services/review_service.dart';
import '../../models/review.dart';
import '../../models/tutor.dart';
import '../../services/user_service.dart';
import '../booking/booking_screen.dart';

class TutorDetailScreen extends StatefulWidget {
  static const routeName = '/tutor-detail';
  const TutorDetailScreen({super.key});

  @override
  State<TutorDetailScreen> createState() => _TutorDetailScreenState();
}

class _TutorDetailScreenState extends State<TutorDetailScreen> {
  Tutor? _cachedTutor;
  bool _isLoading = true;
  String? _error;
  String? _tutorId;
  bool _hasLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Lấy tutorId từ route arguments trong didChangeDependencies
    if (!_hasLoaded) {
      _tutorId = ModalRoute.of(context)?.settings.arguments as String? ?? '';
      _hasLoaded = true;
      _loadTutor();
    }
  }

  Future<void> _loadTutor() async {
    if (_tutorId == null || _tutorId!.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = 'Không tìm thấy ID gia sư';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Thử load bằng getById trước (nhanh hơn)
      final tutor = await RepoFactory.tutor()
          .getById(_tutorId!)
          .timeout(const Duration(seconds: 5));
      
      if (tutor != null) {
        setState(() {
          _cachedTutor = tutor;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _error = 'Không tìm thấy gia sư';
        });
      }
    } catch (e) {
      // Nếu có lỗi nhưng có cache, vẫn hiển thị cache
      if (_cachedTutor != null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      setState(() {
        _isLoading = false;
        _error = 'Không thể tải thông tin gia sư. Vui lòng thử lại.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Hiển thị loading
    if (_isLoading && _cachedTutor == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết gia sư')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Hiển thị error
    if (_error != null && _cachedTutor == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết gia sư')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(_error!),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _loadTutor,
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    // Hiển thị nội dung (có thể là cache hoặc data mới)
    final tutor = _cachedTutor;
    if (tutor == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết gia sư')),
        body: const Center(
          child: Text('Không tìm thấy gia sư'),
        ),
      );
    }

    // Hiển thị nội dung ngay, stream chỉ để cập nhật realtime
    return StreamBuilder<Tutor?>(
      stream: RepoFactory.tutor().streamById(_tutorId!).timeout(
        const Duration(seconds: 3),
        onTimeout: (sink) {
          // Nếu timeout, emit cache nếu có
          sink.add(_cachedTutor);
        },
      ),
      builder: (context, snap) {
        // Cập nhật cache khi có dữ liệu mới
        if (snap.hasData && snap.data != null) {
          _cachedTutor = snap.data;
        }
        
        // Dùng data mới nếu có, không thì dùng cache hoặc tutor hiện tại
        final currentTutor = snap.data ?? _cachedTutor ?? tutor;
        return _buildContent(currentTutor);
      },
    );
  }
  
  Widget _buildContent(Tutor tutor) {
    final user = context.read<AuthService>().currentUser;
    return Scaffold(
      appBar: AppBar(title: Text(tutor.name)),
      floatingActionButton: user != null && user.role == UserRole.student
          ? FloatingActionButton.extended(
              onPressed: () {
                // Tạo room ID nhất quán bằng cách sắp xếp IDs
                final ids = [tutor.id, user.id]..sort();
                final roomId = '${ids[0]}-${ids[1]}';
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(roomId: roomId, title: 'Chat với ${tutor.name}'),
                  ),
                );
              },
              icon: const Icon(Icons.chat),
              label: const Text('Chat với gia sư'),
            )
          : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hiển thị rating từ reviews thay vì từ tutor.rating
            StreamBuilder<List<Review>>(
              stream: ReviewService().streamForTutor(tutor.id).timeout(
                const Duration(seconds: 3),
                onTimeout: (sink) {
                  sink.add([]);
                },
              ),
              builder: (context, reviewSnap) {
                final reviews = reviewSnap.data ?? [];
                final avgRating = reviews.isNotEmpty
                    ? reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length
                    : tutor.rating; // Fallback về tutor.rating nếu chưa có reviews
                final reviewCount = reviews.isNotEmpty ? reviews.length : tutor.reviewCount;
                
                return Row(
                  children: [
                    CircleAvatar(radius: 36, backgroundImage: NetworkImage(tutor.avatarUrl)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tutor.subject, style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 6),
                          RatingStars(rating: avgRating, count: reviewCount),
                          const SizedBox(height: 6),
                          Text('${tutor.hourlyRate.toStringAsFixed(0)} đ/giờ', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: const Color(0xFF1E88E5))),
                        ],
                      ),
                    )
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            Text('Giới thiệu', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(tutor.bio),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Đặt lịch học',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => BookingScreen(initialTutor: tutor),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Text('Đánh giá', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _ReviewsSection(tutorId: tutor.id),
          ],
        ),
      ),
    );
  }
}

class _ReviewsSection extends StatefulWidget {
  final String tutorId;
  const _ReviewsSection({required this.tutorId});

  @override
  State<_ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends State<_ReviewsSection> {
  final _service = ReviewService();
  List<Review>? _cachedReviews;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Review>>(
          stream: _service.streamForTutor(widget.tutorId).timeout(
            const Duration(seconds: 3),
            onTimeout: (sink) {
              sink.add(_cachedReviews ?? []);
            },
          ),
          builder: (context, reviewSnap) {
            // Cập nhật cache khi có dữ liệu
            if (reviewSnap.hasData) {
              _cachedReviews = reviewSnap.data;
            }
            
            // Dùng cache nếu đang loading
            final reviews = reviewSnap.data ?? _cachedReviews ?? [];
            final avgRating = reviews.isNotEmpty
                ? reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length
                : 0.0;
            
            // Nếu đang loading và chưa có cache, hiển thị empty state thay vì loading
            if (reviewSnap.connectionState == ConnectionState.waiting && reviews.isEmpty) {
              return const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Chưa có đánh giá', style: TextStyle(color: Colors.grey)),
                ],
              );
            }
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (reviews.isNotEmpty) ...[
                  Row(
                    children: [
                      Text(
                        'Đánh giá: ${avgRating.toStringAsFixed(1)}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '(${reviews.length} đánh giá)',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                if (reviews.isEmpty)
                  const Text('Chưa có đánh giá', style: TextStyle(color: Colors.grey)),
                if (reviews.isNotEmpty)
                  ...reviews.map((r) => _ReviewCard(review: r)),
              ],
            );
          },
        );
  }
}

// Widget để hiển thị review card với tên người đánh giá
class _ReviewCard extends StatelessWidget {
  final Review review;

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: StreamBuilder<StudentProfile?>(
        stream: UserService().streamById(review.studentId).timeout(
          const Duration(seconds: 3),
          onTimeout: (sink) {
            sink.add(null);
          },
        ),
        builder: (context, userSnap) {
          final student = userSnap.data;
          final studentName = student?.fullName ?? 'Học viên';
          final studentAvatar = student?.avatarUrl;

          return ListTile(
            leading: CircleAvatar(
              backgroundImage: studentAvatar != null && studentAvatar.isNotEmpty
                  ? NetworkImage(studentAvatar)
                  : null,
              child: studentAvatar == null || studentAvatar.isEmpty
                  ? Text(studentName.isNotEmpty ? studentName[0].toUpperCase() : '?')
                  : null,
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    studentName,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ...List.generate(5, (i) {
                  final starIndex = i + 1;
                  if (starIndex <= review.rating) {
                    // Sao đầy
                    return const Icon(Icons.star, size: 16, color: Colors.amber);
                  } else if (starIndex - 0.5 <= review.rating) {
                    // Sao nửa
                    return const Icon(Icons.star_half, size: 16, color: Colors.amber);
                  } else {
                    // Sao rỗng
                    return const Icon(Icons.star_border, size: 16, color: Colors.amber);
                  }
                }),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (review.comment.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(review.comment),
                ] else
                  const Text('(Không có nhận xét)', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 4),
                Text(
                  '${DateTime.now().difference(review.createdAt).inDays} ngày trước',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
