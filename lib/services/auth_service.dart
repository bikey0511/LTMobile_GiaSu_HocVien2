import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';

import '../models/student.dart';
import 'user_registry.dart';
import 'user_service.dart';
import 'firestore_refs.dart';

class AuthService extends ChangeNotifier {
  static const String _adminEmail = 'admin@giasu.app';
  static const String _adminPassword = 'Admin@123';
  static const int maxStudents = 10000; // giới hạn đăng ký học viên
  static const int maxTutors = 2000; // giới hạn đăng ký gia sư
  static const int minAccountLength = 6; // độ dài tối thiểu của tài khoản (email)
  static const int minPasswordLength = 6; // độ dài tối thiểu của mật khẩu
  static const Duration networkTimeout = Duration(seconds: 2); // fail-fast để không treo UI
  bool _isChecking = true;
  bool _isLoggedIn = false;
  StudentProfile? _currentUser;
  bool _firebaseReady = false;

  bool get isChecking => _isChecking;
  bool get isLoggedIn => _isLoggedIn;
  StudentProfile? get currentUser => _currentUser;

  AuthService() {
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      await Firebase.initializeApp();
      _firebaseReady = true;
      final fbUser = fb.FirebaseAuth.instance.currentUser;
      if (fbUser != null) {
        // Fetch thông tin user từ Firestore để lấy role chính xác
        try {
          final userService = UserService();
          final userProfile = await userService.getUser(fbUser.uid).timeout(networkTimeout);
          
          if (userProfile != null) {
            // Có thông tin trong Firestore, dùng thông tin đó
            _currentUser = userProfile;
            _isLoggedIn = true;
          } else {
            // Chưa có trong Firestore, tạo mới với role mặc định
            _currentUser = StudentProfile(
              id: fbUser.uid,
              fullName: fbUser.displayName ?? 'Học viên',
              email: fbUser.email ?? '',
              avatarUrl: fbUser.photoURL ?? 'https://i.pravatar.cc/150?img=12',
              role: fbUser.email == _adminEmail ? UserRole.admin : UserRole.student,
            );
            // Lưu vào Firestore
            await userService.upsertUser(_currentUser!).timeout(networkTimeout);
            _isLoggedIn = true;
          }
        } catch (e) {
          // Nếu không fetch được từ Firestore, dùng thông tin từ Firebase Auth
          _currentUser = StudentProfile(
            id: fbUser.uid,
            fullName: fbUser.displayName ?? 'Học viên',
            email: fbUser.email ?? '',
            avatarUrl: fbUser.photoURL ?? 'https://i.pravatar.cc/150?img=12',
            role: fbUser.email == _adminEmail ? UserRole.admin : UserRole.student,
          );
          _isLoggedIn = true;
        }
      }
    } catch (_) {
      _firebaseReady = false;
    } finally {
      _isChecking = false;
      notifyListeners();
    }
  }

  Future<String?> login({required String email, required String password}) async {
    // Single admin account (mock or Firebase)
    if (email == _adminEmail) {
      // Luôn kiểm tra password phải đúng Admin@123
      if (password != _adminPassword) {
        return 'Sai thông tin đăng nhập Admin';
      }

      // Nếu Firebase ready, thử đăng nhập Firebase
      if (_firebaseReady) {
        try {
          // Đảm bảo không còn user nào đang đăng nhập trước khi đăng nhập mới
          final currentUserBeforeLogin = fb.FirebaseAuth.instance.currentUser;
          if (currentUserBeforeLogin != null) {
            try {
              await fb.FirebaseAuth.instance.signOut();
              await Future.delayed(const Duration(milliseconds: 100));
            } catch (_) {
              // Ignore
            }
          }
          
          await fb.FirebaseAuth.instance
              .signInWithEmailAndPassword(email: email, password: password)
              .timeout(networkTimeout);
          
          // Đợi một chút để đảm bảo Firebase đã cập nhật currentUser
          await Future.delayed(const Duration(milliseconds: 100));
          
          // Firebase login thành công
          final fbUser = fb.FirebaseAuth.instance.currentUser;
          _currentUser = StudentProfile(
            id: fbUser?.uid ?? 'admin-uid',
            fullName: 'Quản trị viên',
            email: _adminEmail,
            avatarUrl: 'https://i.pravatar.cc/150?img=1',
            role: UserRole.admin,
          );
          _isLoggedIn = true;
          notifyListeners();
          return null;
        } catch (e) {
          // Firebase login fail (có thể user chưa tồn tại hoặc lỗi mạng)
          // Fallback về mock login nếu password đúng
          // Password đã được check ở trên, nên ở đây chắc chắn đúng
          _currentUser = StudentProfile(
            id: 'admin-uid',
            fullName: 'Quản trị viên',
            email: _adminEmail,
            avatarUrl: 'https://i.pravatar.cc/150?img=1',
            role: UserRole.admin,
          );
          _isLoggedIn = true;
          notifyListeners();
          return null;
        }
      } else {
        // Firebase không ready, dùng mock login
        _currentUser = StudentProfile(
          id: 'admin-uid',
          fullName: 'Quản trị viên',
          email: _adminEmail,
          avatarUrl: 'https://i.pravatar.cc/150?img=1',
          role: UserRole.admin,
        );
        _isLoggedIn = true;
        notifyListeners();
        return null;
      }
    }
    if (_firebaseReady) {
      try {
        // Đảm bảo không còn user nào đang đăng nhập trước khi đăng nhập mới
        final currentUserBeforeLogin = fb.FirebaseAuth.instance.currentUser;
        if (currentUserBeforeLogin != null && currentUserBeforeLogin.email != email) {
          // Có user khác đang đăng nhập, sign out trước
          try {
            await fb.FirebaseAuth.instance.signOut();
            await Future.delayed(const Duration(milliseconds: 100));
          } catch (_) {
            // Ignore
          }
        }
        
        await fb.FirebaseAuth.instance
            .signInWithEmailAndPassword(email: email, password: password)
            .timeout(networkTimeout);
        
        // Đợi một chút để đảm bảo Firebase đã cập nhật currentUser
        await Future.delayed(const Duration(milliseconds: 100));
        
        final fbUser = fb.FirebaseAuth.instance.currentUser;
        if (fbUser == null) {
          return 'Đăng nhập thất bại. Vui lòng thử lại.';
        }
        
        // Fetch thông tin user từ Firestore để lấy role chính xác
        try {
          final userService = UserService();
          final userProfile = await userService.getUser(fbUser.uid).timeout(networkTimeout);
          
          if (userProfile != null) {
            // Có thông tin trong Firestore, dùng thông tin đó
            _currentUser = userProfile;
          } else {
            // Chưa có trong Firestore, tạo mới với role mặc định là student
            _currentUser = StudentProfile(
              id: fbUser.uid,
              fullName: fbUser.displayName ?? 'Học viên',
              email: fbUser.email ?? email,
              avatarUrl: fbUser.photoURL ?? 'https://i.pravatar.cc/150?img=12',
              role: UserRole.student,
            );
            // Lưu vào Firestore
            await userService.upsertUser(_currentUser!).timeout(networkTimeout);
          }
        } catch (e) {
          // Nếu không fetch được từ Firestore, dùng thông tin từ Firebase Auth
          _currentUser = StudentProfile(
            id: fbUser.uid,
            fullName: fbUser.displayName ?? 'Học viên',
            email: fbUser.email ?? email,
            avatarUrl: fbUser.photoURL ?? 'https://i.pravatar.cc/150?img=12',
            role: UserRole.student,
          );
          // Lưu vào Firestore (best-effort)
          try {
            await UserService().upsertUser(_currentUser!).timeout(networkTimeout);
          } catch (_) {
            // ignore errors
          }
        }
        
        _isLoggedIn = true;
        notifyListeners();
        return null;
      } catch (e) {
        // Xử lý lỗi rõ ràng hơn
        String errorMessage = 'Đăng nhập thất bại';
        if (e is fb.FirebaseAuthException) {
          switch (e.code) {
            case 'user-not-found':
              errorMessage = 'Không tìm thấy tài khoản với email này. Vui lòng kiểm tra lại email hoặc đăng ký tài khoản mới.';
              break;
            case 'wrong-password':
            case 'invalid-credential':
              errorMessage = 'Sai mật khẩu. Vui lòng kiểm tra lại mật khẩu hoặc sử dụng chức năng "Quên mật khẩu".';
              break;
            case 'invalid-email':
              errorMessage = 'Email không hợp lệ. Vui lòng nhập đúng định dạng email.';
              break;
            case 'user-disabled':
              errorMessage = 'Tài khoản đã bị vô hiệu hóa. Vui lòng liên hệ quản trị viên.';
              break;
            case 'too-many-requests':
              errorMessage = 'Quá nhiều lần thử đăng nhập. Vui lòng thử lại sau vài phút.';
              break;
            case 'network-request-failed':
              errorMessage = 'Lỗi kết nối mạng. Vui lòng kiểm tra kết nối internet và thử lại.';
              break;
            case 'operation-not-allowed':
              errorMessage = 'Phương thức đăng nhập này không được phép. Vui lòng liên hệ quản trị viên.';
              break;
            default:
              // Kiểm tra message để hiển thị thông báo phù hợp
              final message = e.message?.toLowerCase() ?? '';
              if (message.contains('password') || message.contains('credential')) {
                errorMessage = 'Sai mật khẩu hoặc email. Vui lòng kiểm tra lại thông tin đăng nhập.';
              } else if (message.contains('user') && message.contains('not found')) {
                errorMessage = 'Không tìm thấy tài khoản. Vui lòng đăng ký tài khoản mới.';
              } else {
                errorMessage = 'Lỗi đăng nhập: ${e.message ?? e.code}';
              }
          }
        } else if (e is TimeoutException) {
          errorMessage = 'Hết thời gian chờ. Vui lòng kiểm tra kết nối và thử lại.';
        } else {
          errorMessage = 'Lỗi đăng nhập: ${e.toString()}';
        }
        return errorMessage;
      }
    }
    // Mock login
    await Future.delayed(const Duration(milliseconds: 500));
    _currentUser = StudentProfile(
      id: 'mock-student-1',
      fullName: 'Nguyễn Văn A',
      email: email,
      avatarUrl: 'https://i.pravatar.cc/150?img=15',
      role: UserRole.student,
    );
    _isLoggedIn = true;
    notifyListeners();
    return null;
  }

  Future<String?> register({required String name, required String email, required String password, required UserRole role}) async {
    if (role == UserRole.admin) {
      return 'Tài khoản Admin do hệ thống cấp. Vui lòng chọn vai trò khác.';
    }
    // Kiểm tra độ dài tối thiểu
    if (email.trim().length < minAccountLength) {
      return 'Tài khoản (email) phải có ít nhất $minAccountLength ký tự.';
    }
    if (password.length < minPasswordLength) {
      return 'Mật khẩu phải có ít nhất $minPasswordLength ký tự.';
    }
    // Kiểm tra giới hạn theo vai trò
    if (_firebaseReady) {
      try {
        final query = await FirestoreRefs
            .users()
            .where('role', isEqualTo: role.name)
            .get()
            .timeout(networkTimeout);
        final count = query.size;
        if (role == UserRole.student && count >= maxStudents) return 'Đã đạt giới hạn số lượng Học viên.';
        if (role == UserRole.tutor && count >= maxTutors) return 'Đã đạt giới hạn số lượng Gia sư.';
      } catch (_) {}
    } else {
      final reg = UserRegistry();
      final count = reg.countByRole(role);
      if (role == UserRole.student && count >= maxStudents) return 'Đã đạt giới hạn số lượng Học viên.';
      if (role == UserRole.tutor && count >= maxTutors) return 'Đã đạt giới hạn số lượng Gia sư.';
    }
    if (_firebaseReady) {
      try {
        final cred = await fb.FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email, password: password)
            .timeout(networkTimeout);
        try {
          await cred.user?.updateDisplayName(name).timeout(networkTimeout);
        } catch (_) {
          // ignore display name update failures
        }
        _currentUser = StudentProfile(
          id: cred.user!.uid,
          fullName: name,
          email: email,
          avatarUrl: 'https://i.pravatar.cc/150?img=14',
          role: role,
        );
        _isLoggedIn = true;
        // Lưu hồ sơ vào Firestore (users) - không để treo UI nếu lỗi mạng/quyền
        try {
          await UserService().upsertUser(_currentUser!).timeout(networkTimeout);
        } catch (_) {
          // swallow; profile write is best-effort
        }
        notifyListeners();
        return null;
      } catch (e) {
        // Bắt lỗi trùng email từ Firebase Auth
        final msg = e.toString().contains('email-already-in-use')
            ? 'Tài khoản đã tồn tại. Vui lòng dùng email khác.'
            : e.toString();
        return msg;
      }
    }
    // Mock register
    // Kiểm tra trùng email trong registry
    if (UserRegistry().emailExists(email)) {
      return 'Tài khoản đã tồn tại. Vui lòng dùng email khác.';
    }
    await Future.delayed(const Duration(milliseconds: 500));
    _currentUser = StudentProfile(
      id: 'mock-student-2',
      fullName: name,
      email: email,
      avatarUrl: 'https://i.pravatar.cc/150?img=14',
      role: role,
    );
    _isLoggedIn = true;
    // Ghi nhận vào registry để Admin có thể đếm trong mock mode
    UserRegistry().addOrUpdate(_currentUser!);
    notifyListeners();
    return null;
  }

  /// Đăng nhập bằng Google với vai trò đã chọn
  Future<String?> signInWithGoogle({UserRole? selectedRole}) async {
    if (!_firebaseReady) {
      return 'Firebase chưa sẵn sàng. Vui lòng thử lại sau.';
    }

    try {
      // Cấu hình GoogleSignIn với scopes tối thiểu (không cần People API)
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: [
          'email',
          'profile',
        ],
        // Web sẽ tự động lấy clientId từ meta tag trong index.html
      );
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      
      if (googleUser == null) {
        return 'Đăng nhập Google bị hủy';
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = fb.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await fb.FirebaseAuth.instance.signInWithCredential(credential);
      final fbUser = userCredential.user;

      if (fbUser == null) {
        return 'Đăng nhập Google thất bại';
      }

      // Lấy email từ Firebase user hoặc Google user
      final userEmail = fbUser.email ?? googleUser.email;
      final isAdmin = (userEmail ?? '') == _adminEmail;
      if (isAdmin) {
        // Admin không cần chọn vai trò
        _currentUser = StudentProfile(
          id: fbUser.uid,
          fullName: fbUser.displayName ?? googleUser.displayName ?? 'Quản trị viên',
          email: userEmail ?? _adminEmail,
          avatarUrl: fbUser.photoURL ?? googleUser.photoUrl ?? 'https://i.pravatar.cc/150?img=1',
          role: UserRole.admin,
        );
        try {
          await UserService().upsertUser(_currentUser!).timeout(networkTimeout);
        } catch (_) {}
        _isLoggedIn = true;
        notifyListeners();
        return null;
      }

      // Kiểm tra xem user đã có trong Firestore chưa
      final userService = UserService();
      final existingUser = await userService.getUser(fbUser.uid).timeout(networkTimeout);

      UserRole role;
      if (existingUser != null) {
        // User đã tồn tại, dùng role hiện có
        role = existingUser.role;
      } else if (selectedRole != null) {
        // Lần đầu đăng nhập, dùng role đã chọn
        role = selectedRole;
      } else {
        // Chưa chọn role, trả về error code đặc biệt để UI hiển thị dialog
        return 'NEED_ROLE_SELECTION';
      }

      _currentUser = StudentProfile(
        id: fbUser.uid,
        fullName: fbUser.displayName ?? googleUser.displayName ?? 'Người dùng',
        email: userEmail ?? googleUser.email ?? '',
        avatarUrl: fbUser.photoURL ?? googleUser.photoUrl ?? 'https://i.pravatar.cc/150?img=12',
        role: role,
      );

      // Lưu hồ sơ vào Firestore
      try {
        await userService.upsertUser(_currentUser!).timeout(networkTimeout);
      } catch (_) {
        // ignore errors
      }

      _isLoggedIn = true;
      notifyListeners();
      return null;
    } catch (e) {
      return 'Lỗi đăng nhập Google: ${e.toString()}';
    }
  }

  /// Gửi email reset mật khẩu
  Future<String?> sendPasswordResetEmail(String email) async {
    if (!_firebaseReady) {
      return 'Firebase chưa sẵn sàng. Vui lòng thử lại sau.';
    }

    try {
      await fb.FirebaseAuth.instance
          .sendPasswordResetEmail(email: email.trim())
          .timeout(networkTimeout);
      return null; // Thành công
    } catch (e) {
      String errorMsg = 'Không thể gửi email đặt lại mật khẩu.';
      if (e.toString().contains('user-not-found')) {
        errorMsg = 'Email không tồn tại trong hệ thống.';
      } else if (e.toString().contains('invalid-email')) {
        errorMsg = 'Email không hợp lệ.';
      } else {
        errorMsg = 'Lỗi: ${e.toString()}';
      }
      return errorMsg;
    }
  }

  Future<void> logout() async {
    // Reset state trước để UI phản hồi ngay
    _isLoggedIn = false;
    _currentUser = null;
    _isChecking = false;
    notifyListeners();
    
    // Sau đó mới sign out từ Firebase và Google
    if (_firebaseReady) {
      try {
        // Đăng xuất Google trước
        try {
          final googleSignIn = GoogleSignIn();
          await googleSignIn.signOut();
        } catch (_) {
          // Ignore errors
        }
        
        // Sign out từ Firebase Auth - thử nhiều lần để đảm bảo
        try {
          await fb.FirebaseAuth.instance.signOut();
          // Đợi một chút để đảm bảo Firebase đã xử lý xong
          await Future.delayed(const Duration(milliseconds: 200));
          
          // Kiểm tra lại và sign out lại nếu cần
          var checkUser = fb.FirebaseAuth.instance.currentUser;
          int retryCount = 0;
          while (checkUser != null && retryCount < 3) {
            await fb.FirebaseAuth.instance.signOut();
            await Future.delayed(const Duration(milliseconds: 200));
            checkUser = fb.FirebaseAuth.instance.currentUser;
            retryCount++;
          }
        } catch (e) {
          // Ignore errors nhưng vẫn tiếp tục
        }
      } catch (e) {
        // Ignore errors nhưng vẫn tiếp tục
      }
    }
    
    // Đảm bảo state đã được reset hoàn toàn
    _isLoggedIn = false;
    _currentUser = null;
    _isChecking = false;
    notifyListeners();
  }

  /// Cập nhật thông tin user hiện tại (sau khi edit profile)
  void updateCurrentUser(StudentProfile updatedProfile) {
    _currentUser = updatedProfile;
    notifyListeners();
  }
}
