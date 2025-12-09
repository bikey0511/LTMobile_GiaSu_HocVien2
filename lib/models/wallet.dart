/// Model cho ví điện tử của user
class Wallet {
  final String userId;
  final double balance; // Số dư hiện tại
  final DateTime updatedAt;

  const Wallet({
    required this.userId,
    required this.balance,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'balance': balance,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Wallet.fromMap(String id, Map<String, dynamic> data) {
    DateTime parsedDate;
    final rawDate = data['updatedAt'];
    if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else if (rawDate != null && rawDate.runtimeType.toString() == 'Timestamp') {
      try {
        parsedDate = (rawDate as dynamic).toDate() as DateTime;
      } catch (_) {
        parsedDate = DateTime.now();
      }
    } else {
      parsedDate = DateTime.now();
    }
    return Wallet(
      userId: id,
      balance: (data['balance'] ?? 0).toDouble(),
      updatedAt: parsedDate,
    );
  }
}

/// Loại giao dịch
enum TransactionType {
  deposit, // Nạp tiền
  withdrawal, // Rút tiền
  payment, // Thanh toán cho gia sư
  earning, // Nhận tiền từ học viên
  refund, // Hoàn tiền
}

/// Trạng thái giao dịch
enum TransactionStatus {
  pending, // Đang chờ xử lý
  completed, // Đã hoàn thành
  failed, // Thất bại
  cancelled, // Đã hủy
}

/// Model cho giao dịch
class Transaction {
  final String id;
  final String userId;
  final TransactionType type;
  final double amount;
  final String description;
  final TransactionStatus status;
  final DateTime createdAt;
  final String? relatedBookingId; // ID booking liên quan (nếu có)
  final String? relatedUserId; // User liên quan (ví dụ: học viên thanh toán cho gia sư)

  const Transaction({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    required this.description,
    required this.status,
    required this.createdAt,
    this.relatedBookingId,
    this.relatedUserId,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'type': type.name,
      'amount': amount,
      'description': description,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'relatedBookingId': relatedBookingId,
      'relatedUserId': relatedUserId,
    };
  }

  factory Transaction.fromMap(String id, Map<String, dynamic> data) {
    DateTime parsedDate;
    final rawDate = data['createdAt'];
    if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else if (rawDate != null && rawDate.runtimeType.toString() == 'Timestamp') {
      try {
        parsedDate = (rawDate as dynamic).toDate() as DateTime;
      } catch (_) {
        parsedDate = DateTime.now();
      }
    } else {
      parsedDate = DateTime.now();
    }
    return Transaction(
      id: id,
      userId: data['userId'] ?? '',
      type: TransactionType.values.firstWhere(
        (t) => t.name == (data['type'] ?? ''),
        orElse: () => TransactionType.deposit,
      ),
      amount: (data['amount'] ?? 0).toDouble(),
      description: data['description'] ?? '',
      status: TransactionStatus.values.firstWhere(
        (s) => s.name == (data['status'] ?? ''),
        orElse: () => TransactionStatus.pending,
      ),
      createdAt: parsedDate,
      relatedBookingId: data['relatedBookingId'] as String?,
      relatedUserId: data['relatedUserId'] as String?,
    );
  }
}


