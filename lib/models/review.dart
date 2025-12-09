class Review {
  final String id;
  final String tutorId;
  final String studentId;
  final String comment;
  final double rating;
  final DateTime createdAt;

  const Review({
    required this.id,
    required this.tutorId,
    required this.studentId,
    required this.comment,
    required this.rating,
    required this.createdAt,
  });
}

