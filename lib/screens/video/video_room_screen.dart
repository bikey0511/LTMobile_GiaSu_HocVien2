import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jitsi_meet_wrapper/jitsi_meet_wrapper.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
// Conditional imports for web vs mobile
import 'video_room_web_stub.dart'
    if (dart.library.html) 'video_room_web.dart' as web;

/// Màn hình phòng học trực tuyến dạng embedded (giống Google Meet) dùng Jitsi.
/// roomId nên là duy nhất cho mỗi buổi học, ví dụ: `${tutorId}-${studentId}-${bookingId}`.
class VideoRoomScreen extends StatefulWidget {
  final String roomId;
  final String title;

  const VideoRoomScreen({super.key, required this.roomId, required this.title});

  @override
  State<VideoRoomScreen> createState() => _VideoRoomScreenState();
}

class _VideoRoomScreenState extends State<VideoRoomScreen> {
  bool _joining = false;
  bool _showVideoRoom = false; // Để hiển thị iframe trên Web
  String? _iframeViewId; // ID của iframe view

  Future<void> _joinMeeting() async {
    final user = context.read<AuthService>().currentUser;
    final userName = user?.fullName ?? 'Người dùng';
    final userEmail = user?.email ?? '';
    
    // Web: sử dụng Jitsi Meet External API để tự động join và set moderator
    if (kIsWeb) {
      // Tạo unique ID cho container
      _iframeViewId = 'jitsi-container-${widget.roomId}-${DateTime.now().millisecondsSinceEpoch}';
      
      // Đăng ký view factory với Jitsi Meet External API
      web.VideoRoomWeb.registerViewFactory(_iframeViewId!, widget.roomId, userName, userEmail);
      
      setState(() {
        _showVideoRoom = true;
      });
      return;
    }

    // Mobile/Desktop: dùng JitsiMeetWrapper nhúng trong app
    setState(() {
      _joining = true;
    });

    try {
      final options = JitsiMeetingOptions(
        roomNameOrUrl: widget.roomId,
        isAudioMuted: false,
        isVideoMuted: false,
        userDisplayName: userName,
        userEmail: userEmail,
      );

      await JitsiMeetWrapper.joinMeeting(options: options);
    } catch (e) {
      if (!mounted) return;
      String errorMsg = 'Không thể mở phòng học';
      final errorStr = e.toString();
      
      if (errorStr.contains('permission') || errorStr.contains('camera') || errorStr.contains('microphone')) {
        errorMsg = 'Vui lòng cấp quyền camera và microphone để tham gia phòng học';
      } else if (errorStr.contains('network') || errorStr.contains('timeout')) {
        errorMsg = 'Lỗi kết nối mạng. Vui lòng kiểm tra kết nối và thử lại';
      } else {
        errorMsg = 'Không thể mở phòng học: $e';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _joining = false;
        });
      }
    }
  }

  @override
  void dispose() {
    if (kIsWeb) {
      // Cleanup Jitsi API trên Web
      web.VideoRoomWeb.dispose();
    } else {
      JitsiMeetWrapper.hangUp();
    }
    super.dispose();
  }

  Future<void> _copyRoomId() async {
    await Clipboard.setData(ClipboardData(text: widget.roomId));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã sao chép mã phòng! Bạn có thể chia sẻ cho bạn bè.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _shareRoomId() async {
    final roomUrl = 'https://meet.jit.si/${Uri.encodeComponent(widget.roomId)}';
    if (kIsWeb) {
      await Clipboard.setData(ClipboardData(text: roomUrl));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã sao chép link phòng học! Bạn có thể chia sẻ cho bạn bè.'),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      // Mobile: dùng share plugin nếu có, hoặc copy
      await Clipboard.setData(ClipboardData(text: roomUrl));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã sao chép link phòng học! Bạn có thể chia sẻ cho bạn bè.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Trên Web: nếu đã join, hiển thị iframe
    if (kIsWeb && _showVideoRoom && _iframeViewId != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Thoát phòng học',
              onPressed: () {
                setState(() {
                  _showVideoRoom = false;
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.copy),
              tooltip: 'Sao chép mã phòng',
              onPressed: _copyRoomId,
            ),
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'Chia sẻ link phòng học',
              onPressed: _shareRoomId,
            ),
          ],
        ),
        body: SizedBox.expand(
          child: HtmlElementView(
            viewType: _iframeViewId!,
          ),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Sao chép mã phòng',
            onPressed: _copyRoomId,
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Chia sẻ link phòng học',
            onPressed: _shareRoomId,
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text(
                        'Mã phòng học',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        widget.roomId,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton.icon(
                            onPressed: _copyRoomId,
                            icon: const Icon(Icons.copy, size: 18),
                            label: const Text('Sao chép mã'),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: _shareRoomId,
                            icon: const Icon(Icons.share, size: 18),
                            label: const Text('Chia sẻ link'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _joining ? null : _joinMeeting,
                icon: const Icon(Icons.video_call),
                label: Text(_joining ? 'Đang vào phòng...' : 'Vào phòng học'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



