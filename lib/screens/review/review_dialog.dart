import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/review.dart';
import '../../services/review_repository.dart';
import '../../services/review_service.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_refs.dart';
import '../../widgets/rating_stars.dart';

class ReviewDialog extends StatefulWidget {
  final String tutorId;
  final String bookingId;
  final Review? existingReview; // Nếu có, cho phép chỉnh sửa

  const ReviewDialog({
    super.key,
    required this.tutorId,
    required this.bookingId,
    this.existingReview,
  });

  @override
  State<ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<ReviewDialog> {
  final _commentController = TextEditingController();
  double _rating = 5.0;
  final _reviewRepo = ReviewRepository();
  final _reviewService = ReviewService();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingReview != null) {
      _rating = widget.existingReview!.rating;
      _commentController.text = widget.existingReview!.comment;
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Cho phép đánh giá mà không cần nhận xét (comment là optional)
    // Chỉ cần có rating là đủ
    if (_rating < 1 || _rating > 5) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn đánh giá từ 1 đến 5 sao'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final user = context.read<AuthService>().currentUser;
      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng đăng nhập để đánh giá'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Kiểm tra xem đã có review chưa (nếu có thì update, không thì create)
      if (_isSubmitting) return; // Tránh double submit
      setState(() => _isSubmitting = true);

      final review = Review(
        id: widget.existingReview?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        tutorId: widget.tutorId,
        studentId: user.id,
        comment: _commentController.text.trim(), // Có thể để trống
        rating: _rating,
        createdAt: widget.existingReview?.createdAt ?? DateTime.now(),
      );

      // Dùng ReviewService để tự động cập nhật tutor rating
      if (widget.existingReview != null) {
        // Update existing review
        await _reviewRepo.create(review);
        // Cập nhật rating của tutor sau khi update review
        await _reviewService.getReviews(widget.tutorId).then((reviews) {
          if (reviews.isNotEmpty) {
            final avgRating = reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;
            FirestoreRefs.tutors().doc(widget.tutorId).update({'rating': avgRating});
          }
        }).catchError((e) {
          print('⚠️ Error updating tutor rating: $e');
        });
      } else {
        // Create new review (tự động cập nhật tutor rating)
        await _reviewService.addReview(review);
      }

      if (!mounted) return;
      setState(() => _isSubmitting = false);
      Navigator.pop(context, true); // Trả về true để báo đã đánh giá thành công
      
      // Hiển thị thông báo thành công sau khi đóng dialog
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cảm ơn bạn đã đánh giá!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('❌ Error submitting review: $e');
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      
      String errorMsg = 'Lỗi khi gửi đánh giá';
      final errorStr = e.toString();
      
      if (errorStr.contains('permission-denied')) {
        errorMsg = 'Không có quyền tạo đánh giá. Vui lòng kiểm tra Firestore rules hoặc đăng nhập lại.';
      } else if (errorStr.contains('network') || errorStr.contains('timeout') || errorStr.contains('unavailable')) {
        errorMsg = 'Lỗi kết nối mạng. Vui lòng kiểm tra kết nối và thử lại.';
      } else if (errorStr.contains('Timeout')) {
        errorMsg = 'Timeout khi gửi đánh giá. Vui lòng kiểm tra kết nối mạng.';
      } else {
        errorMsg = 'Lỗi: ${e.toString()}';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existingReview != null ? 'Chỉnh sửa đánh giá' : 'Đánh giá khóa học'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Đánh giá của bạn:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            // Rating stars với slider
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _rating,
                    min: 1,
                    max: 5,
                    divisions: 4,
                    label: _rating.toStringAsFixed(1),
                    onChanged: (value) => setState(() => _rating = value),
                  ),
                ),
                const SizedBox(width: 8),
                RatingStars(rating: _rating, count: 0, color: Colors.amber),
                const SizedBox(width: 8),
                Text(
                  _rating.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Nhận xét:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _commentController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Chia sẻ trải nghiệm của bạn về khóa học...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting 
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Text('Gửi đánh giá'),
        ),
      ],
    );
  }
}

