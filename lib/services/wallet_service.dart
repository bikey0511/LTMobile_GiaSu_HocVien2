import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/wallet.dart' as wallet_models;
import 'firestore_refs.dart';
import 'notification_service.dart';
import 'user_service.dart';

/// Service quản lý ví điện tử
class WalletService {
  final _walletCol = FirestoreRefs.wallets();
  final _transactionCol = FirestoreRefs.transactions();

  /// Lấy số dư ví của user
  Future<wallet_models.Wallet?> getWallet(String userId) async {
    final doc = await _walletCol.doc(userId).get();
    if (!doc.exists) {
      // Tạo ví mới với số dư 0
      final newWallet = wallet_models.Wallet(
        userId: userId,
        balance: 0,
        updatedAt: DateTime.now(),
      );
      await _walletCol.doc(userId).set(newWallet.toMap());
      return newWallet;
    }
    return wallet_models.Wallet.fromMap(doc.id, doc.data()!);
  }

  /// Stream số dư ví (real-time)
  Stream<wallet_models.Wallet> streamWallet(String userId) {
    return _walletCol.doc(userId).snapshots().map((doc) {
      if (!doc.exists) {
        return wallet_models.Wallet(userId: userId, balance: 0, updatedAt: DateTime.now());
      }
      return wallet_models.Wallet.fromMap(doc.id, doc.data()!);
    });
  }

  /// Nạp tiền vào ví (học viên nạp tiền)
  Future<String?> deposit({
    required String userId,
    required double amount,
    String? description,
  }) async {
    if (amount <= 0) {
      return 'Số tiền nạp phải lớn hơn 0';
    }

    try {
      // Sử dụng transaction để đảm bảo tính nhất quán
      await _walletCol.firestore.runTransaction((transaction) async {
        final walletDoc = _walletCol.doc(userId);
        final walletSnap = await transaction.get(walletDoc);
        
        final currentBalance = walletSnap.exists
            ? (walletSnap.data()!['balance'] ?? 0).toDouble()
            : 0.0;
        
        final newBalance = currentBalance + amount;
        
        // Cập nhật số dư
        transaction.set(walletDoc, {
          'userId': userId,
          'balance': newBalance,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });

      // Tạo giao dịch nạp tiền
      final transaction = wallet_models.Transaction(
        id: _transactionCol.doc().id,
        userId: userId,
        type: wallet_models.TransactionType.deposit,
        amount: amount,
        description: description ?? 'Nạp tiền vào ví',
        status: wallet_models.TransactionStatus.completed,
        createdAt: DateTime.now(),
      );
      await _transactionCol.doc(transaction.id).set(transaction.toMap());

      return null; // Thành công
    } catch (e) {
      return 'Lỗi nạp tiền: ${e.toString()}';
    }
  }

  /// Rút tiền từ ví (gia sư rút tiền)
  Future<String?> withdraw({
    required String userId,
    required double amount,
    String? bankAccount,
    String? bankName,
  }) async {
    if (amount <= 0) {
      return 'Số tiền rút phải lớn hơn 0';
    }

    try {
      String? error;
      await _walletCol.firestore.runTransaction((transaction) async {
        final walletDoc = _walletCol.doc(userId);
        final walletSnap = await transaction.get(walletDoc);
        
        final currentBalance = walletSnap.exists
            ? (walletSnap.data()!['balance'] ?? 0).toDouble()
            : 0.0;
        
        if (currentBalance < amount) {
          error = 'Số dư không đủ';
          return;
        }
        
        final newBalance = currentBalance - amount;
        
        // Cập nhật số dư
        transaction.set(walletDoc, {
          'userId': userId,
          'balance': newBalance,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });

      if (error != null) {
        return error;
      }

      // Tạo giao dịch rút tiền (pending, chờ admin duyệt)
      final transaction = wallet_models.Transaction(
        id: _transactionCol.doc().id,
        userId: userId,
        type: wallet_models.TransactionType.withdrawal,
        amount: amount,
        description: bankAccount != null
            ? 'Rút tiền về $bankName - $bankAccount'
            : 'Rút tiền từ ví',
        status: wallet_models.TransactionStatus.pending,
        createdAt: DateTime.now(),
      );
      await _transactionCol.doc(transaction.id).set(transaction.toMap());

      // Gửi thông báo cho admin (lấy adminId từ users collection với email admin@giasu.app)
      try {
        final adminQuery = await FirestoreRefs.users()
            .where('email', isEqualTo: 'admin@giasu.app')
            .limit(1)
            .get();
        if (adminQuery.docs.isNotEmpty) {
          final adminId = adminQuery.docs.first.id;
          final userService = UserService();
          final tutor = await userService.getUser(userId);
          final notificationService = NotificationService();
          await notificationService.notifyWithdrawalRequest(
            adminId,
            transaction.id,
            tutor?.fullName ?? 'Gia sư',
            amount,
          );
        }
      } catch (e) {
        // Bỏ qua lỗi thông báo
      }

      return null; // Thành công
    } catch (e) {
      return 'Lỗi rút tiền: ${e.toString()}';
    }
  }

  /// Thanh toán cho gia sư (học viên trả tiền)
  Future<String?> payBooking({
    required String studentId,
    required String tutorId,
    required String bookingId,
    required double amount,
  }) async {
    if (amount <= 0) {
      return 'Số tiền thanh toán phải lớn hơn 0';
    }

    try {
      String? error;
      await _walletCol.firestore.runTransaction((transaction) async {
        // Kiểm tra số dư học viên
        final studentWalletDoc = _walletCol.doc(studentId);
        final studentWalletSnap = await transaction.get(studentWalletDoc);
        final studentBalance = studentWalletSnap.exists
            ? (studentWalletSnap.data()!['balance'] ?? 0).toDouble()
            : 0.0;
        
        if (studentBalance < amount) {
          error = 'Số dư không đủ để thanh toán';
          return;
        }
        
        // Trừ tiền học viên
        transaction.set(studentWalletDoc, {
          'userId': studentId,
          'balance': studentBalance - amount,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });

      if (error != null) {
        return error;
      }

      // Tạo giao dịch thanh toán cho học viên
      final studentTransaction = wallet_models.Transaction(
        id: _transactionCol.doc().id,
        userId: studentId,
        type: wallet_models.TransactionType.payment,
        amount: amount,
        description: 'Thanh toán cho buổi học',
        status: wallet_models.TransactionStatus.completed,
        createdAt: DateTime.now(),
        relatedBookingId: bookingId,
        relatedUserId: tutorId,
      );
      await _transactionCol.doc(studentTransaction.id).set(studentTransaction.toMap());

      return null; // Thành công
    } catch (e) {
      return 'Lỗi thanh toán: ${e.toString()}';
    }
  }

  /// Gia sư nhận tiền sau khi hoàn thành buổi học
  Future<String?> addEarning({
    required String tutorId,
    required String bookingId,
    required String studentId,
    required double amount,
  }) async {
    if (amount <= 0) {
      return 'Số tiền phải lớn hơn 0';
    }

    try {
      await _walletCol.firestore.runTransaction((transaction) async {
        final tutorWalletDoc = _walletCol.doc(tutorId);
        final tutorWalletSnap = await transaction.get(tutorWalletDoc);
        
        final currentBalance = tutorWalletSnap.exists
            ? (tutorWalletSnap.data()!['balance'] ?? 0).toDouble()
            : 0.0;
        
        final newBalance = currentBalance + amount;
        
        // Cộng tiền cho gia sư
        transaction.set(tutorWalletDoc, {
          'userId': tutorId,
          'balance': newBalance,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });

      // Tạo giao dịch nhận tiền cho gia sư
      final transaction = wallet_models.Transaction(
        id: _transactionCol.doc().id,
        userId: tutorId,
        type: wallet_models.TransactionType.earning,
        amount: amount,
        description: 'Nhận tiền từ buổi học',
        status: wallet_models.TransactionStatus.completed,
        createdAt: DateTime.now(),
        relatedBookingId: bookingId,
        relatedUserId: studentId,
      );
      await _transactionCol.doc(transaction.id).set(transaction.toMap());

      return null; // Thành công
    } catch (e) {
      return 'Lỗi cộng tiền: ${e.toString()}';
    }
  }

  /// Lấy lịch sử giao dịch của user
  Stream<List<wallet_models.Transaction>> streamTransactions(String userId) {
    return _transactionCol
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => wallet_models.Transaction.fromMap(doc.id, doc.data()))
            .toList());
  }

  /// Admin duyệt yêu cầu rút tiền
  Future<String?> approveWithdrawal(String transactionId) async {
    try {
      final transactionDoc = _transactionCol.doc(transactionId);
      await transactionDoc.set({
        'status': wallet_models.TransactionStatus.completed.name,
      }, SetOptions(merge: true));
      return null;
    } catch (e) {
      return 'Lỗi duyệt rút tiền: ${e.toString()}';
    }
  }

  /// Admin từ chối yêu cầu rút tiền (hoàn tiền lại)
  Future<String?> rejectWithdrawal(String transactionId) async {
    try {
      final transactionDoc = await _transactionCol.doc(transactionId).get();
      if (!transactionDoc.exists) {
        return 'Giao dịch không tồn tại';
      }

      final data = transactionDoc.data()!;
      final userId = data['userId'] as String;
      final amount = (data['amount'] ?? 0).toDouble();

      // Hoàn tiền lại cho user
      await _walletCol.firestore.runTransaction((transaction) async {
        final walletDoc = _walletCol.doc(userId);
        final walletSnap = await transaction.get(walletDoc);
        final currentBalance = walletSnap.exists
            ? (walletSnap.data()!['balance'] ?? 0).toDouble()
            : 0.0;
        
        transaction.set(walletDoc, {
          'userId': userId,
          'balance': currentBalance + amount,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });

      // Cập nhật trạng thái giao dịch
      await transactionDoc.reference.set({
        'status': wallet_models.TransactionStatus.cancelled.name,
      }, SetOptions(merge: true));

      return null;
    } catch (e) {
      return 'Lỗi từ chối rút tiền: ${e.toString()}';
    }
  }

  /// Hoàn tiền cho học viên khi hủy booking đã thanh toán (học viên hủy hoặc gia sư từ chối)
  Future<String?> refundBooking({
    required String studentId,
    required String bookingId,
    required double amount,
    String? reason,
  }) async {
    if (amount <= 0) {
      return 'Số tiền hoàn trả phải lớn hơn 0';
    }

    try {
      // Hoàn tiền lại cho học viên
      await _walletCol.firestore.runTransaction((transaction) async {
        final studentWalletDoc = _walletCol.doc(studentId);
        final studentWalletSnap = await transaction.get(studentWalletDoc);
        final currentBalance = studentWalletSnap.exists
            ? (studentWalletSnap.data()!['balance'] ?? 0).toDouble()
            : 0.0;
        
        final newBalance = currentBalance + amount;
        
        // Cộng tiền lại cho học viên
        transaction.set(studentWalletDoc, {
          'userId': studentId,
          'balance': newBalance,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Timeout khi hoàn tiền. Vui lòng thử lại.');
        },
      );

      // Tạo giao dịch hoàn tiền
      // Description sẽ được truyền từ bên gọi, có thể là "Hủy lịch học" hoặc "Gia sư từ chối"
      final refundTransaction = wallet_models.Transaction(
        id: _transactionCol.doc().id,
        userId: studentId,
        type: wallet_models.TransactionType.refund,
        amount: amount,
        description: reason != null 
            ? reason
            : 'Hoàn tiền lịch học',
        status: wallet_models.TransactionStatus.completed,
        createdAt: DateTime.now(),
        relatedBookingId: bookingId,
      );
      
      await _transactionCol.doc(refundTransaction.id).set(refundTransaction.toMap()).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Timeout khi tạo giao dịch hoàn tiền. Vui lòng thử lại.');
        },
      );

      return null; // Thành công
    } catch (e) {
      // Parse error message để hiển thị rõ ràng hơn
      final errorStr = e.toString();
      String errorMsg = 'Lỗi hoàn tiền: $errorStr';
      
      // Nếu là lỗi từ Future, lấy error message thực sự
      if (errorStr.contains('Dart exception thrown from converted Future')) {
        // Thử lấy error thực sự từ exception
        if (e is Exception) {
          errorMsg = 'Lỗi hoàn tiền: ${e.toString().replaceAll('Error: ', '')}';
        } else {
          errorMsg = 'Lỗi hoàn tiền: Vui lòng thử lại sau vài giây.';
        }
      } else if (errorStr.contains('permission-denied')) {
        errorMsg = 'Không có quyền hoàn tiền. Vui lòng kiểm tra quyền truy cập.';
      } else if (errorStr.contains('network') || errorStr.contains('timeout') || errorStr.contains('unavailable')) {
        errorMsg = 'Lỗi kết nối mạng. Vui lòng kiểm tra kết nối và thử lại.';
      } else if (errorStr.contains('Timeout')) {
        errorMsg = 'Timeout khi hoàn tiền. Vui lòng thử lại.';
      }
      
      print('❌ Error refunding booking: $errorMsg');
      return errorMsg;
    }
  }
}

