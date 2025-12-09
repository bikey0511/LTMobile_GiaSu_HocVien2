import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

// Trang chủ: hiển thị danh sách gia sư từ Firestore qua StreamBuilder
import '../../services/repository_factory.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/tutor_card.dart';
import '../../models/tutor.dart';
import '../notification/notification_screen.dart';
import '../tutor/tutor_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showLoadingTimeout = false;
  List<Tutor>? _cachedTutors; // Cache tutors để hiển thị ngay
  
  // Filters cho tìm kiếm nâng cao
  String? _selectedSubject;
  double? _minRating;
  double? _maxPrice;
  double? _minPrice;
  bool _showFilters = false;
  
  @override
  bool get wantKeepAlive => true; // Giữ state khi navigate away

  @override
  void initState() {
    super.initState();
    // Kiểm tra lịch học hôm nay và gửi thông báo nhắc nhở
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkTodayBookings();
    });
    // Kiểm tra định kỳ mỗi 5 phút để gửi nhắc nhở trước 1 tiếng
    _startReminderTimer();
    
    // Sau 3 giây, nếu vẫn chưa có dữ liệu, hiển thị empty state thay vì loading
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _showLoadingTimeout) {
        setState(() {
          _showLoadingTimeout = false;
        });
      }
    });
  }

  void _startReminderTimer() {
    // Kiểm tra mỗi 5 phút để gửi nhắc nhở trước 1 tiếng
    Future.delayed(const Duration(minutes: 5), () {
      if (mounted) {
        _checkTodayBookings();
        _startReminderTimer(); // Lặp lại
      }
    });
  }

  Future<void> _checkTodayBookings() async {
    final user = context.read<AuthService>().currentUser;
    if (user == null) return;

    try {
      final bookingRepo = RepoFactory.booking();
      final tutorRepo = RepoFactory.tutor();
      final notificationService = NotificationService();

      // Lấy tất cả bookings của học viên
      final bookings = await bookingRepo.streamForStudent(user.id).first;
      
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Tìm các booking hôm nay và sắp tới (đã được chấp nhận và đã thanh toán)
      for (final booking in bookings) {
        if (!booking.accepted || !booking.paid || booking.rejectReason != null || booking.cancelled) {
          continue;
        }

        final bookingDate = DateTime(
          booking.dateTime.year,
          booking.dateTime.month,
          booking.dateTime.day,
        );

        // 1. Nhắc nhở trong ngày: Nếu booking là hôm nay, gửi nhắc nhở 1 lần
        if (bookingDate == today) {
          try {
            final tutor = await tutorRepo.getById(booking.tutorId);
            if (tutor != null) {
              final timeStr = DateFormat('HH:mm').format(booking.dateTime);
              await notificationService.notifyTodayBookingReminder(
                user.id,
                booking.id,
                tutor.name,
                timeStr,
              );
            }
          } catch (e) {
            // Bỏ qua lỗi
          }
        }

        // 2. Nhắc nhở trước 1 tiếng: Kiểm tra nếu booking sắp bắt đầu trong 1 giờ
        final oneHourBefore = booking.dateTime.subtract(const Duration(hours: 1));
        final timeDiff = oneHourBefore.difference(now);
        
        // Kiểm tra nếu thời gian hiện tại đã gần mốc "1 tiếng trước" (trong khoảng 5 phút)
        // hoặc đã qua mốc "1 tiếng trước" nhưng chưa đến giờ học
        if (timeDiff.inMinutes >= -5 && 
            timeDiff.inMinutes <= 5 && 
            now.isBefore(booking.dateTime)) {
          try {
            final tutor = await tutorRepo.getById(booking.tutorId);
            if (tutor != null) {
              final timeStr = DateFormat('HH:mm').format(booking.dateTime);
              await notificationService.notifyOneHourBeforeBooking(
                user.id,
                booking.id,
                tutor.name,
                timeStr,
              );
            }
          } catch (e) {
            // Bỏ qua lỗi
          }
        }
      }
    } catch (e) {
      // Bỏ qua lỗi khi kiểm tra
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Cần gọi để AutomaticKeepAliveClientMixin hoạt động
    final user = context.watch<AuthService>().currentUser;
    final repo = RepoFactory.tutor();
    final notificationService = NotificationService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gia sư nổi bật'),
        actions: [
          // Icon thông báo với badge số lượng chưa đọc
          if (user != null)
            StreamBuilder<int>(
              stream: notificationService.unreadCount(user.id),
              builder: (context, snap) {
                final unreadCount = snap.data ?? 0;
                return Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined),
                      onPressed: () {
                        Navigator.pushNamed(context, NotificationScreen.routeName);
                      },
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            unreadCount > 9 ? '9+' : '$unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Thanh tìm kiếm và bộ lọc
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Tìm kiếm gia sư (tên, môn học, chuyên môn...)',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onChanged: (value) {
                          setState(() => _searchQuery = value.toLowerCase());
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(_showFilters ? Icons.filter_alt : Icons.filter_alt_outlined),
                      onPressed: () {
                        setState(() => _showFilters = !_showFilters);
                      },
                      tooltip: 'Bộ lọc nâng cao',
                    ),
                  ],
                ),
                // Bộ lọc nâng cao
                if (_showFilters) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // Lọc theo môn học
                      DropdownButton<String>(
                        value: _selectedSubject,
                        hint: const Text('Môn học'),
                        items: ['Toán', 'Lý', 'Hóa', 'Văn', 'Anh', 'Sinh', 'Sử', 'Địa']
                            .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (value) {
                          setState(() => _selectedSubject = value);
                        },
                      ),
                      // Lọc theo đánh giá tối thiểu
                      DropdownButton<double>(
                        value: _minRating,
                        hint: const Text('Đánh giá tối thiểu'),
                        items: [4.0, 4.5, 5.0]
                            .map((r) => DropdownMenuItem(value: r, child: Text('${r.toStringAsFixed(1)}+ sao')))
                            .toList(),
                        onChanged: (value) {
                          setState(() => _minRating = value);
                        },
                      ),
                      // Lọc theo giá
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 100,
                            child: TextField(
                              decoration: const InputDecoration(
                                hintText: 'Giá min',
                                border: OutlineInputBorder(),
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                setState(() => _minPrice = double.tryParse(value));
                              },
                            ),
                          ),
                          const Text(' - '),
                          SizedBox(
                            width: 100,
                            child: TextField(
                              decoration: const InputDecoration(
                                hintText: 'Giá max',
                                border: OutlineInputBorder(),
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                setState(() => _maxPrice = double.tryParse(value));
                              },
                            ),
                          ),
                        ],
                      ),
                      // Nút xóa bộ lọc
                      TextButton.icon(
                        icon: const Icon(Icons.clear),
                        label: const Text('Xóa bộ lọc'),
                        onPressed: () {
                          setState(() {
                            _selectedSubject = null;
                            _minRating = null;
                            _minPrice = null;
                            _maxPrice = null;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Danh sách gia sư
          Expanded(
            child: StreamBuilder<List<Tutor>>(
              stream: repo.streamApprovedTutors(),
              builder: (context, snap) {
                // Cập nhật cache khi có dữ liệu
                if (snap.hasData && snap.data != null) {
                  _cachedTutors = snap.data;
                }
                
                // Nếu đang chờ dữ liệu lần đầu và chưa hết timeout
                if (snap.connectionState == ConnectionState.waiting && !snap.hasData && !_showLoadingTimeout) {
                  // Nếu có cache, hiển thị cache ngay để không bị lag
                  if (_cachedTutors != null && _cachedTutors!.isNotEmpty) {
                    return _buildTutorsList(_cachedTutors!);
                  }
                  
                  // Bật flag để sau 3 giây sẽ hiển thị empty state
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        _showLoadingTimeout = true;
                      });
                    }
                  });
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }
                
                // Nếu có lỗi
                if (snap.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Lỗi: ${snap.error}'),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            setState(() {});
                          },
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  );
                }
                
                // Hiển thị dữ liệu cũ nếu có, không chờ loading
                if (snap.connectionState == ConnectionState.waiting && snap.hasData) {
                  // Có dữ liệu cũ, hiển thị ngay
                  final tutors = snap.data!;
                  final filteredTutors = _searchQuery.isEmpty
                      ? tutors
                      : tutors.where((t) {
                          final query = _searchQuery;
                          return t.name.toLowerCase().contains(query) ||
                              t.subject.toLowerCase().contains(query) ||
                              t.bio.toLowerCase().contains(query);
                        }).toList();
                  
                  if (filteredTutors.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.search_off, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isEmpty
                                ? 'Chưa có gia sư khả dụng'
                                : 'Không tìm thấy gia sư phù hợp',
                            style: const TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredTutors.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final t = filteredTutors[index];
                      return TutorCard(
                        tutor: t,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => TutorDetailScreen(),
                            settings: RouteSettings(arguments: t.id),
                          ),
                        ),
                      );
                    },
                  );
                }
                
                if (snap.connectionState == ConnectionState.waiting) {
                  // Chỉ hiển thị loading khi chưa có dữ liệu
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snap.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Lỗi: ${snap.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  );
                }
                
                final tutors = snap.data ?? _cachedTutors ?? [];
                
                return _buildTutorsList(tutors);
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTutorsList(List<Tutor> tutors) {
    // Lọc theo từ khóa tìm kiếm và bộ lọc nâng cao
    var filteredTutors = tutors.where((t) {
      // Lọc theo từ khóa tìm kiếm
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery;
        final matchesSearch = t.name.toLowerCase().contains(query) ||
            t.subject.toLowerCase().contains(query) ||
            t.bio.toLowerCase().contains(query);
        if (!matchesSearch) return false;
      }
      
      // Lọc theo môn học
      if (_selectedSubject != null && t.subject != _selectedSubject) {
        return false;
      }
      
      // Lọc theo đánh giá tối thiểu
      if (_minRating != null && t.rating < _minRating!) {
        return false;
      }
      
      // Lọc theo giá
      if (_minPrice != null && t.hourlyRate < _minPrice!) {
        return false;
      }
      if (_maxPrice != null && t.hourlyRate > _maxPrice!) {
        return false;
      }
      
      return true;
    }).toList();
    
    // Sắp xếp: đánh giá cao nhất trước, sau đó giá thấp nhất
    filteredTutors.sort((a, b) {
      if (a.rating != b.rating) {
        return b.rating.compareTo(a.rating);
      }
      return a.hourlyRate.compareTo(b.hourlyRate);
    });

    if (filteredTutors.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty
                  ? 'Chưa có gia sư khả dụng'
                  : 'Không tìm thấy gia sư phù hợp',
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filteredTutors.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final t = filteredTutors[index];
        return TutorCard(
          tutor: t,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TutorDetailScreen(),
              settings: RouteSettings(arguments: t.id),
            ),
          ),
        );
      },
    );
  }
}
