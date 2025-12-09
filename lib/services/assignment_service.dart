import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/assignment.dart';
import 'firestore_refs.dart';

/// Service để quản lý bài tập
class AssignmentService {
  final _assignmentCol = FirestoreRefs.assignments();
  final _submissionCol = FirestoreRefs.submissions();

  /// Tạo bài tập mới
  Future<Assignment> createAssignment({
    required String bookingId,
    required String tutorId,
    required String title,
    required String description,
    required DateTime dueDate,
    List<String> attachments = const [],
    int maxScore = 100,
  }) async {
    try {
      final assignment = Assignment(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        bookingId: bookingId,
        tutorId: tutorId,
        title: title,
        description: description,
        dueDate: dueDate,
        createdAt: DateTime.now(),
        attachments: attachments,
        maxScore: maxScore,
      );

      final data = assignment.toMap();
      data['dueDate'] = Timestamp.fromDate(assignment.dueDate);
      data['createdAt'] = Timestamp.fromDate(assignment.createdAt);

      await _assignmentCol.doc(assignment.id).set(data);

      return assignment;
    } catch (e) {
      throw Exception('Không thể tạo bài tập: $e');
    }
  }

  /// Upload file đính kèm cho bài tập
  Future<String> uploadAttachment(File file, String assignmentId, String fileName) async {
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('assignments/$assignmentId/$fileName');
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      throw Exception('Không thể upload file: $e');
    }
  }

  /// Stream danh sách bài tập của một booking
  Stream<List<Assignment>> streamAssignmentsForBooking(String bookingId) {
    return _assignmentCol
        .where('bookingId', isEqualTo: bookingId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Assignment.fromMap(doc.id, doc.data()))
          .toList();
    }).handleError((error) {
      return <Assignment>[];
    });
  }

  /// Xóa bài tập
  Future<void> deleteAssignment(Assignment assignment) async {
    try {
      // Xóa tất cả submissions liên quan
      final submissions = await _submissionCol
          .where('assignmentId', isEqualTo: assignment.id)
          .get();
      
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in submissions.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // Xóa assignment
      await _assignmentCol.doc(assignment.id).delete();
    } catch (e) {
      throw Exception('Không thể xóa bài tập: $e');
    }
  }

  /// Nộp bài tập
  Future<Submission> submitAssignment({
    required String assignmentId,
    required String studentId,
    String? content,
    List<String> attachments = const [],
  }) async {
    try {
      // Kiểm tra xem đã nộp chưa
      final existing = await _submissionCol
          .where('assignmentId', isEqualTo: assignmentId)
          .where('studentId', isEqualTo: studentId)
          .limit(1)
          .get();

      String submissionId;
      if (existing.docs.isNotEmpty) {
        // Cập nhật bài nộp cũ
        submissionId = existing.docs.first.id;
        await _submissionCol.doc(submissionId).update({
          'content': content,
          'attachments': attachments,
          'submittedAt': Timestamp.fromDate(DateTime.now()),
          'score': null, // Reset điểm khi nộp lại
          'feedback': null,
          'gradedAt': null,
        });
      } else {
        // Tạo bài nộp mới
        submissionId = DateTime.now().millisecondsSinceEpoch.toString();
        final submission = Submission(
          id: submissionId,
          assignmentId: assignmentId,
          studentId: studentId,
          content: content,
          attachments: attachments,
          submittedAt: DateTime.now(),
        );

        final data = submission.toMap();
        data['submittedAt'] = Timestamp.fromDate(submission.submittedAt);

        await _submissionCol.doc(submissionId).set(data);
      }

      // Lấy lại submission vừa tạo/cập nhật
      final doc = await _submissionCol.doc(submissionId).get();
      return Submission.fromMap(submissionId, doc.data()!);
    } catch (e) {
      throw Exception('Không thể nộp bài: $e');
    }
  }

  /// Upload file đính kèm cho bài nộp
  Future<String> uploadSubmissionFile(File file, String submissionId, String fileName) async {
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('submissions/$submissionId/$fileName');
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      throw Exception('Không thể upload file: $e');
    }
  }

  /// Stream bài nộp của một học viên cho một bài tập
  Stream<Submission?> streamSubmission(String assignmentId, String studentId) {
    return _submissionCol
        .where('assignmentId', isEqualTo: assignmentId)
        .where('studentId', isEqualTo: studentId)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return Submission.fromMap(snapshot.docs.first.id, snapshot.docs.first.data());
    });
  }

  /// Stream tất cả bài nộp của một bài tập (cho gia sư)
  Stream<List<Submission>> streamSubmissionsForAssignment(String assignmentId) {
    return _submissionCol
        .where('assignmentId', isEqualTo: assignmentId)
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Submission.fromMap(doc.id, doc.data()))
          .toList();
    }).handleError((error) {
      return <Submission>[];
    });
  }

  /// Chấm điểm bài tập
  Future<void> gradeSubmission({
    required String submissionId,
    required int score,
    String? feedback,
  }) async {
    try {
      await _submissionCol.doc(submissionId).update({
        'score': score,
        'feedback': feedback,
        'gradedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('Không thể chấm điểm: $e');
    }
  }
}

