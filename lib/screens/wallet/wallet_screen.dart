import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/wallet.dart';
import '../../models/student.dart';
import '../../services/auth_service.dart';
import '../../services/wallet_service.dart';
import '../../widgets/input_field.dart';
import '../../widgets/primary_button.dart';

class WalletScreen extends StatefulWidget {
  static const routeName = '/wallet';
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> with AutomaticKeepAliveClientMixin {
  final _walletService = WalletService();
  final _amountController = TextEditingController();
  final _bankAccountController = TextEditingController();
  final _bankNameController = TextEditingController();
  bool _loading = false;
  Wallet? _cachedWallet;
  List<Transaction>? _cachedTransactions;
  
  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _amountController.dispose();
    _bankAccountController.dispose();
    _bankNameController.dispose();
    super.dispose();
  }

  Future<void> _deposit() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập số tiền hợp lệ'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _loading = true);
    final user = context.read<AuthService>().currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    final err = await _walletService.deposit(
      userId: user.id,
      amount: amount,
      description: 'Nạp tiền vào ví',
    );
    setState(() => _loading = false);

    if (!mounted) return;

    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err),
          backgroundColor: Colors.red,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nạp tiền thành công!'),
          backgroundColor: Colors.green,
        ),
      );
      _amountController.clear();
    }
  }

  Future<void> _withdraw() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập số tiền hợp lệ'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_bankAccountController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập số tài khoản ngân hàng'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_bankNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập tên ngân hàng'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận rút tiền'),
        content: Text(
          'Bạn muốn rút ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(amount)} '
          'về tài khoản ${_bankNameController.text} - ${_bankAccountController.text}?\n\n'
          'Yêu cầu rút tiền sẽ được gửi đến admin để duyệt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _loading = true);
    final user = context.read<AuthService>().currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    final err = await _walletService.withdraw(
      userId: user.id,
      amount: amount,
      bankAccount: _bankAccountController.text.trim(),
      bankName: _bankNameController.text.trim(),
    );
    setState(() => _loading = false);

    if (!mounted) return;

    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err),
          backgroundColor: Colors.red,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Yêu cầu rút tiền đã được gửi. Vui lòng chờ admin duyệt.'),
          backgroundColor: Colors.green,
        ),
      );
      _amountController.clear();
      _bankAccountController.clear();
      _bankNameController.clear();
    }
  }

  String _getTransactionTypeText(TransactionType type) {
    switch (type) {
      case TransactionType.deposit:
        return 'Nạp tiền';
      case TransactionType.withdrawal:
        return 'Rút tiền';
      case TransactionType.payment:
        return 'Thanh toán';
      case TransactionType.earning:
        return 'Nhận tiền';
      case TransactionType.refund:
        return 'Hoàn tiền';
    }
  }

  Color _getTransactionTypeColor(TransactionType type) {
    switch (type) {
      case TransactionType.deposit:
      case TransactionType.earning:
        return Colors.green;
      case TransactionType.withdrawal:
      case TransactionType.payment:
        return Colors.orange;
      case TransactionType.refund:
        return Colors.blue;
    }
  }

  IconData _getTransactionTypeIcon(TransactionType type) {
    switch (type) {
      case TransactionType.deposit:
        return Icons.add_circle;
      case TransactionType.withdrawal:
        return Icons.remove_circle;
      case TransactionType.payment:
        return Icons.payment;
      case TransactionType.earning:
        return Icons.attach_money;
      case TransactionType.refund:
        return Icons.undo;
    }
  }

  String _getStatusText(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.pending:
        return 'Đang chờ';
      case TransactionStatus.completed:
        return 'Hoàn thành';
      case TransactionStatus.failed:
        return 'Thất bại';
      case TransactionStatus.cancelled:
        return 'Đã hủy';
    }
  }

  Color _getStatusColor(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.pending:
        return Colors.orange;
      case TransactionStatus.completed:
        return Colors.green;
      case TransactionStatus.failed:
        return Colors.red;
      case TransactionStatus.cancelled:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Cần gọi để AutomaticKeepAliveClientMixin hoạt động
    final user = context.watch<AuthService>().currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Vui lòng đăng nhập')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ví điện tử'),
      ),
      body: StreamBuilder<Wallet>(
        stream: _walletService.streamWallet(user.id),
        builder: (context, snapshot) {
          // Cập nhật cache khi có dữ liệu
          if (snapshot.hasData && snapshot.data != null) {
            _cachedWallet = snapshot.data;
          }
          
          // Nếu đang loading, hiển thị cache nếu có
          if (snapshot.connectionState == ConnectionState.waiting) {
            if (_cachedWallet != null) {
              // Hiển thị cache ngay, không cần chờ
            } else {
              return FutureBuilder(
                future: Future.delayed(const Duration(seconds: 3)),
                builder: (context, timeoutSnap) {
                  if (timeoutSnap.connectionState == ConnectionState.done) {
                    // Sau 3 giây, hiển thị wallet mặc định
                    final wallet = Wallet(
                      userId: user.id,
                      balance: 0,
                      updatedAt: DateTime.now(),
                    );
                    return _buildWalletContent(wallet, user);
                  }
                  return const Center(child: CircularProgressIndicator());
                },
              );
            }
          }

          final wallet = snapshot.data ?? _cachedWallet ?? Wallet(
            userId: user.id,
            balance: 0,
            updatedAt: DateTime.now(),
          );
          
          return _buildWalletContent(wallet, user);
        },
      ),
    );
  }
  
  Widget _buildWalletContent(Wallet wallet, dynamic user) {
    final isStudent = user.role == UserRole.student;
    final isTutor = user.role == UserRole.tutor;
    
    return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Card số dư
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Text(
                          'Số dư hiện tại',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(wallet.balance),
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Form nạp tiền (học viên) hoặc rút tiền (gia sư)
                if (isStudent) ...[
                  const Text(
                    'Nạp tiền vào ví',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  InputField(
                    controller: _amountController,
                    label: 'Số tiền (VNĐ)',
                    keyboardType: TextInputType.number,
                    enabled: !_loading,
                  ),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    label: _loading ? 'Đang xử lý...' : 'Nạp tiền',
                    onPressed: _loading ? null : _deposit,
                  ),
                ] else if (isTutor) ...[
                  const Text(
                    'Rút tiền về tài khoản',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  InputField(
                    controller: _amountController,
                    label: 'Số tiền (VNĐ)',
                    keyboardType: TextInputType.number,
                    enabled: !_loading,
                  ),
                  const SizedBox(height: 16),
                  InputField(
                    controller: _bankNameController,
                    label: 'Tên ngân hàng',
                    enabled: !_loading,
                  ),
                  const SizedBox(height: 16),
                  InputField(
                    controller: _bankAccountController,
                    label: 'Số tài khoản',
                    keyboardType: TextInputType.number,
                    enabled: !_loading,
                  ),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    label: _loading ? 'Đang xử lý...' : 'Gửi yêu cầu rút tiền',
                    onPressed: _loading ? null : _withdraw,
                  ),
                ],
                const SizedBox(height: 32),

                // Lịch sử giao dịch
                const Text(
                  'Lịch sử giao dịch',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                StreamBuilder<List<Transaction>>(
                  stream: _walletService.streamTransactions(user.id),
                  builder: (context, snapshot) {
                    // Cập nhật cache khi có dữ liệu
                    if (snapshot.hasData && snapshot.data != null) {
                      _cachedTransactions = snapshot.data;
                    }
                    
                    // Nếu đang loading, hiển thị cache nếu có
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      if (_cachedTransactions != null && _cachedTransactions!.isNotEmpty) {
                        return _buildTransactionsList(_cachedTransactions!);
                      }
                      return FutureBuilder(
                        future: Future.delayed(const Duration(seconds: 3)),
                        builder: (context, timeoutSnap) {
                          if (timeoutSnap.connectionState == ConnectionState.done) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32),
                                child: Text('Chưa có giao dịch nào'),
                              ),
                            );
                          }
                          return const Center(child: CircularProgressIndicator());
                        },
                      );
                    }

                    final transactions = snapshot.data ?? _cachedTransactions ?? [];

                    if (transactions.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text('Chưa có giao dịch nào'),
                        ),
                      );
                    }

                    return _buildTransactionsList(transactions);
                  },
                ),
              ],
            ),
          );
  }
  
  Widget _buildTransactionsList(List<Transaction> transactions) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final t = transactions[index];
        final isPositive = t.type == TransactionType.deposit ||
            t.type == TransactionType.earning ||
            t.type == TransactionType.refund;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getTransactionTypeColor(t.type).withOpacity(0.2),
              child: Icon(
                _getTransactionTypeIcon(t.type),
                color: _getTransactionTypeColor(t.type),
              ),
            ),
            title: Text(_getTransactionTypeText(t.type)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.description),
                const SizedBox(height: 4),
                Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(t.createdAt),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                if (t.status != TransactionStatus.completed)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getStatusColor(t.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _getStatusText(t.status),
                      style: TextStyle(
                        fontSize: 10,
                        color: _getStatusColor(t.status),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            trailing: Text(
              '${isPositive ? '+' : '-'}${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(t.amount)}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isPositive ? Colors.green : Colors.orange,
              ),
            ),
          ),
        );
      },
    );
  }
}

