import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
// Firebase options chỉ cần khi bật Firebase. Nếu bạn không dùng Firebase, giữ nguyên không import file này.
import 'firebase_options.dart';

import 'services/auth_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/booking/booking_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/classroom/classroom_screen.dart';
import 'screens/notification/notification_screen.dart';
import 'screens/tutor/tutor_detail_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/tutor/tutor_dashboard_screen.dart';
import 'screens/chat/chat_screen.dart';
import 'screens/chat/chat_ai_screen.dart';
import 'screens/chat/chat_list_screen.dart';
import 'screens/admin/admin_chat_list_screen.dart';
import 'services/chat_service.dart';
import 'screens/tutor/create_class_screen.dart';
import 'screens/tutor/tutor_profile_setup_screen.dart';
import 'screens/wallet/wallet_screen.dart';
import 'screens/profile/edit_profile_screen.dart';
import 'screens/profile/change_password_screen.dart';
import 'screens/booking/booking_history_screen.dart';
import 'screens/tutor/tutor_booking_history_screen.dart';
import 'screens/admin/admin_bookings_screen.dart';
import 'services/repository_factory.dart';
import 'services/firestore_refs.dart';
import 'models/student.dart';
import 'widgets/role_guard.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Khởi tạo Firebase SỚM để các màn hình dùng Firestore không lỗi [core/no-app]
  runApp(const AppBootstrap());
}

/// Gate khởi tạo Firebase: đảm bảo Firebase.initializeApp() chạy trước khi vào app
class AppBootstrap extends StatelessWidget {
  const AppBootstrap({super.key});

  @override
  Widget build(BuildContext context) {
    Future<FirebaseApp?> _initFirebaseOptional() async {
      try {
        final app = await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        RepoFactory.useFirebase = true;
        print('✅ Firebase đã được khởi tạo thành công. Đồng bộ hai chiều đã được bật.');
        return app;
      } catch (e) {
        // Nếu Firebase khởi tạo thất bại, vẫn bật Firebase mode nếu có thể
        // Điều này đảm bảo app vẫn cố gắng kết nối với Firebase
        print('⚠️ Lỗi khởi tạo Firebase: $e');
        print('⚠️ App sẽ chạy ở chế độ offline (mock data)');
        RepoFactory.useFirebase = false;
        return null;
      }
    }
    return FutureBuilder<FirebaseApp?>(
      // Thử khởi tạo Firebase. Nếu thất bại (không có cấu hình), vẫn vào app offline
      future: _initFirebaseOptional(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        // Nếu có lỗi/không có Firebase, chuyển sang chế độ offline (RepoFactory.useFirebase=false)
        return const AppRoot();
      },
    );
  }
}

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Hệ Thống kết nối Gia Sư và Học viên',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E88E5)),
          scaffoldBackgroundColor: const Color(0xFFF7F9FC),
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
          ),
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(),
          ),
        ),
        home: const AuthGate(),
        routes: {
          LoginScreen.routeName: (_) => const LoginScreen(),
          RegisterScreen.routeName: (_) => const RegisterScreen(),
          ForgotPasswordScreen.routeName: (_) => const ForgotPasswordScreen(),
          '/home': (_) => const MainScaffold(),
          TutorDetailScreen.routeName: (_) => const TutorDetailScreen(),
          AdminDashboardScreen.routeName: (_) => RoleGuard(
                allowed: const [UserRole.admin],
                builder: (_) => const AdminDashboardScreen(),
              ),
          TutorDashboardScreen.routeName: (_) => RoleGuard(
                allowed: const [UserRole.tutor, UserRole.admin],
                builder: (_) => const TutorDashboardScreen(),
              ),
          ChatScreen.routeName: (_) => const ChatScreen(roomId: 'demo', title: 'Chat'),
          ChatAIScreen.routeName: (_) => const ChatAIScreen(),
          ChatListScreen.routeName: (_) => const ChatListScreen(),
          '/admin-chat-list': (_) => RoleGuard(
                allowed: const [UserRole.admin],
                builder: (_) => const AdminChatListScreen(),
              ),
          CreateClassScreen.routeName: (_) => const CreateClassScreen(),
          TutorProfileSetupScreen.routeName: (_) => const TutorProfileSetupScreen(),
          WalletScreen.routeName: (_) => const WalletScreen(),
          NotificationScreen.routeName: (_) => const NotificationScreen(),
          EditProfileScreen.routeName: (_) => const EditProfileScreen(),
          ChangePasswordScreen.routeName: (_) => const ChangePasswordScreen(),
          BookingHistoryScreen.routeName: (_) => RoleGuard(
                allowed: const [UserRole.student],
                builder: (_) => const BookingHistoryScreen(),
              ),
          TutorBookingHistoryScreen.routeName: (_) => RoleGuard(
                allowed: const [UserRole.tutor, UserRole.admin],
                builder: (_) => const TutorBookingHistoryScreen(),
              ),
          AdminBookingsScreen.routeName: (_) => RoleGuard(
                allowed: const [UserRole.admin],
                builder: (_) => const AdminBookingsScreen(),
              ),
        },
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    // Không chờ: khi đang kiểm tra, tạm hiển thị trang đăng nhập
    if (auth.isChecking) return const LoginScreen();
    if (!auth.isLoggedIn) {
      return const LoginScreen();
    }
    // Điều hướng theo vai trò sau khi đăng nhập
    switch (auth.currentUser?.role) {
      case UserRole.admin:
        return const AdminDashboardScreen();
      case UserRole.tutor:
        return const TutorDashboardScreen();
      case UserRole.student:
      default:
        return const MainScaffold();
    }
  }
}

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;

  final _pages = const [
    HomeScreen(),
    BookingScreen(),
    ClassroomScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Trang chủ'),
          NavigationDestination(icon: Icon(Icons.event_outlined), selectedIcon: Icon(Icons.event), label: 'Đặt lịch'),
          NavigationDestination(icon: Icon(Icons.meeting_room_outlined), selectedIcon: Icon(Icons.meeting_room), label: 'Phòng học'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Hồ sơ'),
        ],
      ),
      floatingActionButton: _buildFloatingButtons(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildFloatingButtons() {
    final user = context.read<AuthService>().currentUser;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Nút Chat với AI (riêng biệt, luôn hiển thị)
        FloatingActionButton(
          onPressed: () {
            Navigator.pushNamed(context, ChatAIScreen.routeName);
          },
          heroTag: 'chat-ai',
          backgroundColor: Colors.purple,
          elevation: 4,
          tooltip: 'Chat với AI',
          child: const Icon(Icons.smart_toy),
        ),
        const SizedBox(height: 12),
        // Nút Hỗ trợ (Chat với Admin)
        FloatingActionButton(
          onPressed: () async {
            if (user == null) return;
            
            // Tìm admin user ID từ Firestore
            try {
              final adminQuery = await FirestoreRefs.users()
                  .where('role', isEqualTo: 'admin')
                  .limit(1)
                  .get();
              
              String adminId;
              if (adminQuery.docs.isNotEmpty) {
                adminId = adminQuery.docs.first.id;
              } else {
                // Nếu không tìm thấy admin, dùng roomId đặc biệt
                adminId = 'admin-support';
              }
              
              final roomId = '${adminId}-${user.id}';
              if (context.mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      roomId: roomId,
                      title: 'Hỗ trợ từ Admin',
                    ),
                  ),
                );
              }
            } catch (e) {
              // Fallback: dùng roomId đặc biệt
              final roomId = 'admin-support-${user.id}';
              if (context.mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      roomId: roomId,
                      title: 'Hỗ trợ từ Admin',
                    ),
                  ),
                );
              }
            }
          },
          heroTag: 'chat-admin',
          backgroundColor: Colors.orange,
          elevation: 4,
          tooltip: 'Hỗ trợ',
          child: const Icon(Icons.support_agent),
        ),
        const SizedBox(height: 12),
        // Nút Tin nhắn (riêng biệt, luôn hiển thị) với badge số tin nhắn chưa đọc
        if (user != null)
          StreamBuilder<int>(
            stream: ChatService().unreadMessageCount(user.id),
          builder: (context, snap) {
            final unreadCount = snap.data ?? 0;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                FloatingActionButton(
                  onPressed: () {
                    Navigator.pushNamed(context, ChatListScreen.routeName);
                  },
                  heroTag: 'chat-list',
                  elevation: 4,
                  tooltip: 'Tin nhắn',
                  child: const Icon(Icons.chat),
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 20,
                        minHeight: 20,
                      ),
                      child: Text(
                        unreadCount > 9 ? '9+' : '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
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
    );
  }
}
