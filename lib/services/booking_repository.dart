import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/booking.dart';
import 'firestore_refs.dart';

class BookingRepository {
  final _col = FirestoreRefs.bookings();
  // Cache để giữ dữ liệu khi quay lại màn hình
  final Map<String, List<Booking>> _cache = {};

  /// Tạo lịch đặt học
  Future<void> create(Booking b) async {
    final data = b.toMap();
    data['dateTime'] = Timestamp.fromDate(b.dateTime);
    
    // Retry logic để xử lý Firestore internal assertion errors
    int retries = 0;
    const maxRetries = 3;
    const retryDelay = Duration(milliseconds: 500);
    
    // Delay nhỏ trước khi gửi lần đầu để tránh conflict với stream
    await Future.delayed(const Duration(milliseconds: 300));
    
    while (retries <= maxRetries) {
      try {
        // Thêm delay nhỏ trước khi retry để tránh conflict với stream
        if (retries > 0) {
          await Future.delayed(retryDelay * retries);
        }
        
        // Thêm timeout để tránh treo quá lâu
        await _col.doc(b.id).set(data).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw Exception('Timeout khi đặt lịch. Vui lòng kiểm tra kết nối mạng.');
          },
        );
        print('✅ Booking created successfully: ${b.id}');
        
        // Delay nhỏ sau khi tạo thành công để stream có thời gian cập nhật
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Firestore sẽ tự động emit snapshot mới, stream sẽ tự động cập nhật
        return; // Thành công, thoát khỏi vòng lặp
      } catch (e) {
        final errorStr = e.toString();
        print('❌ Error creating booking (attempt ${retries + 1}/${maxRetries + 1}): $errorStr');
        
        // Kiểm tra các loại lỗi có thể retry
        final isRetryableError = errorStr.contains('INTERNAL ASSERTION FAILED') || 
            errorStr.contains('Unexpected state') ||
            errorStr.contains('network') ||
            errorStr.contains('timeout') ||
            errorStr.contains('unavailable') ||
            errorStr.contains('deadline-exceeded') ||
            errorStr.contains('Dart exception thrown from converted Future');
        
        // Nếu là lỗi có thể retry và chưa hết retry
        if (retries < maxRetries && isRetryableError) {
          retries++;
          print('⚠️ Retrying create booking (attempt ${retries + 1}/${maxRetries + 1})...');
        } else {
          // Nếu không phải lỗi có thể retry hoặc đã hết retry, throw lại với message rõ ràng
          if (errorStr.contains('permission-denied')) {
            throw Exception('Không có quyền đặt lịch. Vui lòng kiểm tra quyền truy cập.');
          } else if (errorStr.contains('unavailable') || errorStr.contains('network')) {
            throw Exception('Lỗi kết nối mạng. Vui lòng kiểm tra kết nối và thử lại.');
          } else if (errorStr.contains('timeout') || errorStr.contains('Timeout')) {
            throw Exception('Timeout khi đặt lịch. Vui lòng kiểm tra kết nối mạng.');
          } else if (errorStr.contains('INTERNAL ASSERTION FAILED') || 
              errorStr.contains('Unexpected state') ||
              errorStr.contains('Dart exception thrown from converted Future')) {
            throw Exception('Lỗi kết nối Firestore. Vui lòng thử lại sau vài giây.');
          } else {
            throw Exception('Không thể đặt lịch: $e');
          }
        }
      }
    }
  }

  /// Stream lịch của học viên
  /// Stream này tự động cập nhật realtime khi có thay đổi trong Firestore
  /// Emit cache ngay lập tức (nếu có), sau đó emit dữ liệu từ Firestore
  Stream<List<Booking>> streamForStudent(String studentId) async* {
    // Nếu studentId rỗng, trả về stream rỗng ngay lập tức
    if (studentId.isEmpty) {
      yield <Booking>[];
      return;
    }
    
    final cacheKey = 'student-$studentId';
    
    // Kiểm tra cache trước - nếu có cache, emit ngay để không mất dữ liệu khi quay lại
    if (_cache.containsKey(cacheKey) && _cache[cacheKey]!.isNotEmpty) {
      print('📦 Using cached bookings for student: ${_cache[cacheKey]!.length} bookings');
      yield _cache[cacheKey]!;
    } else {
      // Nếu không có cache, emit empty list để UI không phải chờ
      yield <Booking>[];
    }
    
    final query = _col
        .where('studentId', isEqualTo: studentId)
        .orderBy('dateTime');
    
    // Đọc dữ liệu ban đầu ngay lập tức (không chờ stream)
    try {
      final initialSnapshot = await query.get();
      final initialBookings = initialSnapshot.docs
          .map((d) {
            try {
              return Booking.fromMap(d.id, d.data());
            } catch (e) {
              return null;
            }
          })
          .whereType<Booking>()
          .toList();
      
      // Cập nhật cache và emit nếu khác với cache
      if (initialBookings.length != _cache[cacheKey]?.length) {
        _cache[cacheKey] = initialBookings;
        yield initialBookings; // Emit dữ liệu ban đầu
      }
    } catch (e) {
      print('⚠️ Error loading initial bookings: $e');
      // Tiếp tục với stream realtime
    }
    
    // Sau đó listen stream realtime để cập nhật khi có thay đổi
    yield* query.snapshots().map((snapshot) {
      try {
        final bookings = snapshot.docs
            .map((d) {
              try {
                return Booking.fromMap(d.id, d.data());
              } catch (e) {
                // Bỏ qua document lỗi
                return null;
              }
            })
            .whereType<Booking>()
            .toList();
        
        // Cập nhật cache
        _cache[cacheKey] = bookings;
        return bookings;
      } catch (e) {
        return <Booking>[];
      }
    }).handleError((error) {
      // Log lỗi nhưng không crash app
      print('Error in streamForStudent: $error');
      return <Booking>[];
    });
  }

  /// Stream lịch của gia sư
  /// Stream này tự động cập nhật realtime khi có thay đổi trong Firestore
  /// Emit cache ngay lập tức (nếu có), sau đó emit dữ liệu từ Firestore
  Stream<List<Booking>> streamForTutor(String tutorId) async* {
    // Nếu tutorId rỗng, trả về stream rỗng ngay lập tức
    if (tutorId.isEmpty) {
      yield <Booking>[];
      return;
    }
    
    final cacheKey = 'tutor-$tutorId';
    
    // Kiểm tra cache trước - nếu có cache, emit ngay để không mất dữ liệu khi quay lại
    if (_cache.containsKey(cacheKey) && _cache[cacheKey]!.isNotEmpty) {
      print('📦 Using cached bookings for tutor: ${_cache[cacheKey]!.length} bookings');
      yield _cache[cacheKey]!;
    } else {
      // Nếu không có cache, emit empty list để UI không phải chờ
      yield <Booking>[];
    }
    
    final query = _col
        .where('tutorId', isEqualTo: tutorId)
        .orderBy('dateTime');
    
    // Đọc dữ liệu ban đầu ngay lập tức (không chờ stream)
    try {
      final initialSnapshot = await query.get();
      final initialBookings = initialSnapshot.docs
          .map((d) {
            try {
              return Booking.fromMap(d.id, d.data());
            } catch (e) {
              return null;
            }
          })
          .whereType<Booking>()
          .toList();
      
      // Cập nhật cache và emit nếu khác với cache
      if (initialBookings.length != _cache[cacheKey]?.length) {
        _cache[cacheKey] = initialBookings;
        yield initialBookings; // Emit dữ liệu ban đầu
      }
    } catch (e) {
      print('⚠️ Error loading initial bookings: $e');
      // Tiếp tục với stream realtime
    }
    
    // Sau đó listen stream realtime để cập nhật khi có thay đổi
    yield* query.snapshots().map((snapshot) {
      try {
        final bookings = snapshot.docs
            .map((d) {
              try {
                return Booking.fromMap(d.id, d.data());
              } catch (e) {
                print('Error parsing booking ${d.id}: $e');
                // Bỏ qua document lỗi
                return null;
              }
            })
            .whereType<Booking>()
            .toList();
        
        // Cập nhật cache
        _cache[cacheKey] = bookings;
        return bookings;
      } catch (e) {
        print('Error in streamForTutor: $e');
        return <Booking>[];
      }
    }).handleError((error) {
      print('Stream error in streamForTutor: $error');
      // Trả về empty list khi có lỗi để UI không bị treo
      return <Booking>[];
    });
  }

  /// Cập nhật trạng thái chấp nhận của gia sư
  Future<void> updateAccepted(String id, bool accepted, {String? reason}) async {
    await _col.doc(id).set({'accepted': accepted, 'rejectReason': reason}, SetOptions(merge: true));
    // Firestore sẽ tự động emit snapshot mới, stream sẽ tự động cập nhật
  }

  /// Cập nhật trạng thái thanh toán
  Future<void> updatePaid(String id, bool paid) async {
    try {
      // Đảm bảo document tồn tại trước khi update
      final doc = await _col.doc(id).get();
      if (!doc.exists) {
        throw Exception('Booking document không tồn tại');
      }
      
      // Sử dụng update để chỉ cập nhật field paid
      // Update sẽ trigger snapshot ngay lập tức, stream sẽ tự động cập nhật
      await _col.doc(id).update({'paid': paid});
    } catch (e) {
      // Nếu update thất bại, log lỗi và throw lại để xử lý ở trên
      print('Lỗi khi update paid: $e');
      rethrow;
    }
  }

  /// Cập nhật số buổi đã hoàn thành
  Future<void> updateCompletedSessions(String id, int completedSessions) async {
    final doc = _col.doc(id);
    final snap = await doc.get();
    if (!snap.exists) return;
    
    final data = snap.data()!;
    final totalSessions = (data['totalSessions'] ?? 1) as int;
    final completed = completedSessions >= totalSessions;
    
    await doc.set({
      'completedSessions': completedSessions,
      'completed': completed,
    }, SetOptions(merge: true));
  }

  /// Lấy danh sách bookings của tutor (sync, để kiểm tra trùng lịch)
  /// Có retry logic để xử lý Firestore internal assertion errors
  /// Luôn trả về danh sách (có thể rỗng), không bao giờ throw error
  Future<List<Booking>> getTutorBookings(String tutorId) async {
    // Nếu tutorId rỗng, trả về danh sách rỗng
    if (tutorId.isEmpty) {
      return <Booking>[];
    }
    
    // Retry logic để xử lý Firestore internal assertion errors
    int retries = 0;
    const maxRetries = 2;
    
    while (retries <= maxRetries) {
      try {
        final snap = await _col
            .where('tutorId', isEqualTo: tutorId)
            .get()
            .timeout(const Duration(seconds: 10));
        return snap.docs.map((d) {
          try {
            return Booking.fromMap(d.id, d.data());
          } catch (e) {
            print('Error parsing booking ${d.id}: $e');
            return null;
          }
        }).whereType<Booking>().toList();
      } catch (e) {
        final errorStr = e.toString();
        // Nếu là lỗi Firestore internal assertion và chưa hết retry
        if (retries < maxRetries && 
            (errorStr.contains('INTERNAL ASSERTION FAILED') || 
             errorStr.contains('Unexpected state') ||
             errorStr.contains('timeout') ||
             errorStr.contains('network'))) {
          // Đợi một chút trước khi retry
          await Future.delayed(Duration(milliseconds: 500 * (retries + 1)));
          retries++;
          print('⚠️ Retry getting tutor bookings (attempt ${retries + 1}/$maxRetries)');
        } else {
          // Nếu không phải lỗi có thể retry hoặc đã hết retry, trả về empty list
          print('❌ Error getting tutor bookings (after ${retries} retries): $e');
          // Không throw, trả về empty list để không chặn đặt lịch
          return <Booking>[];
        }
      }
    }
    
    // Nếu tất cả retry đều thất bại, trả về danh sách rỗng để không chặn đặt lịch
    print('⚠️ All retries failed, returning empty list');
    return <Booking>[];
  }

  /// Hủy booking (đánh dấu là đã hủy)
  Future<void> cancel(String id, {String? reason}) async {
    await _col.doc(id).set({
      'cancelled': true,
      'cancelReason': reason,
    }, SetOptions(merge: true));
  }

  /// Xóa booking (xóa hoàn toàn khỏi database)
  Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }
}
