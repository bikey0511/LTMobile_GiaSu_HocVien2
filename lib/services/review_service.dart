import '../models/review.dart';
import 'review_repository.dart';
import 'firestore_refs.dart';

class ReviewService {
  final ReviewRepository _repo = ReviewRepository();

  /// Stream tất cả đánh giá của một gia sư (realtime)
  Stream<List<Review>> streamForTutor(String tutorId) {
    return _repo.streamForTutor(tutorId);
  }

  /// Lấy danh sách đánh giá (sync)
  Future<List<Review>> getReviews(String tutorId) async {
    try {
      return await _repo.streamForTutor(tutorId).first;
    } catch (e) {
      print('Error getting reviews: $e');
      return [];
    }
  }

  /// Thêm đánh giá mới
  Future<void> addReview(Review review) async {
    try {
      await _repo.create(review);
      // Cập nhật rating trung bình của tutor
      await _updateTutorRating(review.tutorId);
    } catch (e) {
      print('Error adding review: $e');
      rethrow;
    }
  }

  /// Kiểm tra xem học viên đã đánh giá gia sư này chưa
  Future<bool> hasReviewed(String studentId, String tutorId) async {
    try {
      return await _repo.hasReviewed(studentId, tutorId);
    } catch (e) {
      print('Error checking review: $e');
      return false;
    }
  }

  /// Lấy đánh giá của học viên cho gia sư
  Future<Review?> getReviewByStudentAndTutor(String studentId, String tutorId) async {
    try {
      return await _repo.getReviewByStudentAndTutor(studentId, tutorId);
    } catch (e) {
      print('Error getting review: $e');
      return null;
    }
  }

  /// Cập nhật rating trung bình của tutor dựa trên tất cả reviews
  Future<void> _updateTutorRating(String tutorId) async {
    try {
      final reviews = await _repo.streamForTutor(tutorId).first;
      if (reviews.isEmpty) return;

      final avgRating = reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;
      
      // Cập nhật rating trong tutors collection
      final tutorRef = FirestoreRefs.tutors().doc(tutorId);
      await tutorRef.update({'rating': avgRating});
      
      print('✅ Updated tutor $tutorId rating to $avgRating');
    } catch (e) {
      print('⚠️ Error updating tutor rating: $e');
      // Không throw để không ảnh hưởng đến việc tạo review
    }
  }
}

