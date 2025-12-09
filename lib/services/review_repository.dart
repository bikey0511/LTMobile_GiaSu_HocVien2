import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/review.dart';
import 'firestore_refs.dart';

class ReviewRepository {
  final _col = FirestoreRefs.reviews();

  /// Tạo đánh giá mới
  Future<void> create(Review review) async {
    try {
      final data = {
        'tutorId': review.tutorId,
        'studentId': review.studentId,
        'comment': review.comment,
        'rating': review.rating,
        'createdAt': Timestamp.fromDate(review.createdAt),
      };
      
      // Retry logic để xử lý lỗi tạm thời
      int retries = 0;
      const maxRetries = 3;
      const retryDelay = Duration(milliseconds: 500);
      
      while (retries <= maxRetries) {
        try {
          await _col.doc(review.id).set(data).timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Timeout khi tạo đánh giá. Vui lòng kiểm tra kết nối mạng.');
            },
          );
          print('✅ Review created successfully: ${review.id}');
          return;
        } catch (e) {
          final errorStr = e.toString();
          print('❌ Error creating review (attempt ${retries + 1}/${maxRetries + 1}): $errorStr');
          
          // Kiểm tra các loại lỗi có thể retry
          final isRetryableError = errorStr.contains('INTERNAL ASSERTION FAILED') || 
              errorStr.contains('Unexpected state') ||
              errorStr.contains('network') ||
              errorStr.contains('timeout') ||
              errorStr.contains('unavailable') ||
              errorStr.contains('deadline-exceeded');
          
          // Nếu là lỗi permission, không retry
          if (errorStr.contains('permission-denied')) {
            throw Exception('Không có quyền tạo đánh giá. Vui lòng kiểm tra quyền truy cập Firestore.');
          }
          
          // Nếu là lỗi có thể retry và chưa hết retry
          if (retries < maxRetries && isRetryableError) {
            retries++;
            await Future.delayed(retryDelay * retries);
          } else {
            // Nếu không phải lỗi có thể retry hoặc đã hết retry, throw lại
            if (errorStr.contains('network') || errorStr.contains('unavailable')) {
              throw Exception('Lỗi kết nối mạng. Vui lòng kiểm tra kết nối và thử lại.');
            } else if (errorStr.contains('timeout') || errorStr.contains('Timeout')) {
              throw Exception('Timeout khi tạo đánh giá. Vui lòng kiểm tra kết nối mạng.');
            } else {
              throw Exception('Không thể tạo đánh giá: $e');
            }
          }
        }
      }
    } catch (e) {
      print('❌ Final error creating review: $e');
      rethrow;
    }
  }

  /// Stream tất cả đánh giá của một gia sư
  /// Bỏ orderBy để tránh cần composite index, sẽ sort trong code
  Stream<List<Review>> streamForTutor(String tutorId) {
    return _col
        .where('tutorId', isEqualTo: tutorId)
        .snapshots()
        .map((snapshot) {
      try {
        final reviews = snapshot.docs.map((doc) {
          final data = doc.data();
          return Review(
            id: doc.id,
            tutorId: data['tutorId'] ?? '',
            studentId: data['studentId'] ?? '',
            comment: data['comment'] ?? '',
            rating: (data['rating'] ?? 0).toDouble(),
            createdAt: (data['createdAt'] as Timestamp).toDate(),
          );
        }).toList();
        
        // Sort theo createdAt descending trong code
        reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        
        return reviews;
      } catch (e) {
        print('Error parsing reviews: $e');
        return <Review>[];
      }
    }).handleError((error) {
      print('Stream error for reviews: $error');
      return <Review>[];
    });
  }

  /// Kiểm tra xem học viên đã đánh giá gia sư này chưa (cho một booking cụ thể)
  Future<bool> hasReviewed(String studentId, String tutorId) async {
    try {
      final snapshot = await _col
          .where('studentId', isEqualTo: studentId)
          .where('tutorId', isEqualTo: tutorId)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 10));
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('❌ Error checking hasReviewed: $e');
      // Nếu có lỗi, trả về false để không block UI
      return false;
    }
  }

  /// Lấy đánh giá của học viên cho gia sư
  Future<Review?> getReviewByStudentAndTutor(String studentId, String tutorId) async {
    try {
      final snapshot = await _col
          .where('studentId', isEqualTo: studentId)
          .where('tutorId', isEqualTo: tutorId)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 10));
      
      if (snapshot.docs.isEmpty) return null;
      
      final doc = snapshot.docs.first;
      final data = doc.data();
      return Review(
        id: doc.id,
        tutorId: data['tutorId'] ?? '',
        studentId: data['studentId'] ?? '',
        comment: data['comment'] ?? '',
        rating: (data['rating'] ?? 0).toDouble(),
        createdAt: (data['createdAt'] as Timestamp).toDate(),
      );
    } catch (e) {
      print('❌ Error getting review: $e');
      // Nếu có lỗi permission, vẫn trả về null để cho phép tạo review mới
      // Hoặc có thể throw lại để UI hiển thị lỗi
      rethrow;
    }
  }
}




