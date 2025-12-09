import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/chat_service.dart';
import '../../services/auth_service.dart';
import '../../services/openai_service.dart';
import '../../models/message.dart';

/// Màn hình chat với AI
class ChatAIScreen extends StatefulWidget {
  static const routeName = '/chat-ai';
  const ChatAIScreen({super.key});

  @override
  State<ChatAIScreen> createState() => _ChatAIScreenState();
}

class _ChatAIScreenState extends State<ChatAIScreen> with AutomaticKeepAliveClientMixin {
  final _chat = ChatService();
  final _openAI = OpenAIService();
  final _ctrl = TextEditingController();
  late final String _roomId;
  bool _isAIResponding = false;
  String? _pendingMessage; // Lưu tin nhắn đang chờ gửi lại
  List<ChatMessage>? _cachedMessages; // Cache messages để hiển thị ngay
  
  @override
  bool get wantKeepAlive => true; // Giữ state khi navigate away

  @override
  void initState() {
    super.initState();
    // Mỗi user có roomId riêng cho chat với AI
    final me = context.read<AuthService>().currentUser;
    _roomId = 'ai-assistant-${me?.id ?? 'guest'}';
    // Không gửi tin nhắn chào mừng tự động vì 'ai' không phải authenticated user
    // Sẽ hiển thị tin nhắn chào mừng trong UI thay vì lưu vào Firestore
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    final me = context.read<AuthService>().currentUser;
    if (me == null || _ctrl.text.trim().isEmpty || _isAIResponding) return;
    
    final userMessage = _ctrl.text.trim();
    // Xóa text ngay để user có thể gõ tiếp
    _ctrl.clear();
    _pendingMessage = null; // Clear pending message
    
    // Optimistic update: Thêm tin nhắn vào cache ngay để hiển thị ngay
    final optimisticMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      roomId: _roomId,
      senderId: me.id,
      text: userMessage,
      sentAt: DateTime.now(),
    );
    
    // Cập nhật cache và rebuild UI ngay
    if (_cachedMessages == null) {
      _cachedMessages = [];
    }
    if (!_cachedMessages!.any((m) => m.id == optimisticMessage.id)) {
      _cachedMessages!.add(optimisticMessage);
      _cachedMessages!.sort((a, b) => a.sentAt.compareTo(b.sentAt));
      if (mounted) {
        setState(() {});
      }
    }
    
    try {
      // Gửi tin nhắn của user
      await _chat.sendMessage(_roomId, me.id, userMessage);
      
      // Cập nhật lại cache từ service
      final updatedCache = _chat.roomToMessages[_roomId];
      if (updatedCache != null && updatedCache.isNotEmpty) {
        _cachedMessages = List.from(updatedCache);
        if (mounted) {
          setState(() {});
        }
      }
      
      // Hiển thị loading cho AI response
      setState(() => _isAIResponding = true);
      
      // Lấy response từ OpenAI
      final aiResponse = await _openAI.getAIResponse(userMessage);
      
      // Lưu AI response vào Firestore với senderId là user hiện tại
      // (vì 'ai' không phải authenticated user, ta dùng user ID nhưng đánh dấu là AI)
      await _chat.sendMessage(_roomId, me.id, '🤖 AI: $aiResponse');
      
      if (mounted) {
        setState(() => _isAIResponding = false);
      }
    } catch (e) {
      // Nếu lỗi, lưu lại tin nhắn để có thể thử lại
      _pendingMessage = userMessage;
      
      if (mounted) {
        setState(() => _isAIResponding = false);
        
        String errorMsg = 'Không thể gửi tin nhắn. Vui lòng thử lại.';
        final errorStr = e.toString();
        
        // Parse error message từ exception - ưu tiên message từ service
        if (errorStr.contains('Lỗi kết nối Firestore')) {
          errorMsg = 'Lỗi kết nối Firestore. Vui lòng thử lại sau vài giây.';
        } else if (errorStr.contains('Lỗi kết nối mạng')) {
          errorMsg = 'Lỗi kết nối mạng. Vui lòng kiểm tra kết nối và thử lại.';
        } else if (errorStr.contains('Không có quyền') || errorStr.contains('permission-denied')) {
          errorMsg = 'Không có quyền gửi tin nhắn. Vui lòng kiểm tra quyền truy cập.';
        } else if (errorStr.contains('INTERNAL ASSERTION FAILED') || 
            errorStr.contains('Unexpected state') ||
            errorStr.contains('Dart exception thrown from converted Future')) {
          errorMsg = 'Lỗi kết nối Firestore. Vui lòng thử lại sau vài giây.';
        } else if (errorStr.contains('network') || errorStr.contains('timeout') || errorStr.contains('unavailable')) {
          errorMsg = 'Lỗi kết nối mạng. Vui lòng kiểm tra kết nối và thử lại.';
        } else if (errorStr.contains('Timeout')) {
          errorMsg = 'Timeout khi gửi tin nhắn. Vui lòng kiểm tra kết nối mạng.';
        }
        
        print('❌ Error sending message to AI: $errorStr');
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Thử lại',
              textColor: Colors.white,
              onPressed: () {
                // Thử gửi lại tin nhắn đã lưu
                final currentUser = context.read<AuthService>().currentUser;
                if (_pendingMessage != null && currentUser != null) {
                  _sendMessageRetry(_pendingMessage!, currentUser.id);
                }
              },
            ),
          ),
        );
      }
    }
  }
  
  Future<void> _sendMessageRetry(String text, String senderId) async {
    try {
      await _chat.sendMessage(_roomId, senderId, text);
      _pendingMessage = null; // Clear pending message on success
      
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        setState(() => _isAIResponding = true);
      }
      
      // Lấy response từ OpenAI
      final aiResponse = await _openAI.getAIResponse(text);
      
      // Lưu AI response vào Firestore
      await _chat.sendMessage(_roomId, senderId, '🤖 AI: $aiResponse');
      
      if (mounted) {
        setState(() => _isAIResponding = false);
      }
    } catch (e) {
      // Vẫn giữ pending message để có thể thử lại
      if (mounted) {
        setState(() => _isAIResponding = false);
        
        String errorMsg = 'Không thể gửi tin nhắn. Vui lòng thử lại.';
        final errorStr = e.toString();
        
        // Parse error message để hiển thị chi tiết hơn - ưu tiên message từ service
        if (errorStr.contains('Lỗi kết nối Firestore')) {
          errorMsg = 'Lỗi kết nối Firestore. Vui lòng thử lại sau vài giây.';
        } else if (errorStr.contains('Lỗi kết nối mạng')) {
          errorMsg = 'Lỗi kết nối mạng. Vui lòng kiểm tra kết nối và thử lại.';
        } else if (errorStr.contains('Không có quyền') || errorStr.contains('permission-denied')) {
          errorMsg = 'Không có quyền gửi tin nhắn. Vui lòng kiểm tra quyền truy cập.';
        } else if (errorStr.contains('INTERNAL ASSERTION FAILED') || 
            errorStr.contains('Unexpected state') ||
            errorStr.contains('Dart exception thrown from converted Future')) {
          errorMsg = 'Lỗi kết nối Firestore. Vui lòng thử lại sau vài giây.';
        } else if (errorStr.contains('network') || errorStr.contains('timeout') || errorStr.contains('unavailable')) {
          errorMsg = 'Lỗi kết nối mạng. Vui lòng kiểm tra kết nối và thử lại.';
        } else if (errorStr.contains('Timeout')) {
          errorMsg = 'Timeout khi gửi tin nhắn. Vui lòng kiểm tra kết nối mạng.';
        }
        
        print('❌ Error in _sendMessageRetry for AI: $errorStr');
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    super.build(context); // Cần gọi để AutomaticKeepAliveClientMixin hoạt động
    final me = context.read<AuthService>().currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.smart_toy, color: Colors.blue),
            SizedBox(width: 8),
            Text('Chat với AI'),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _chat.streamRoom(_roomId),
              builder: (context, snap) {
                // Cập nhật cache khi có dữ liệu
                if (snap.hasData && snap.data != null) {
                  _cachedMessages = snap.data;
                }
                
                // Merge với cache để đảm bảo có tin nhắn mới nhất
                List<ChatMessage> displayItems = snap.data ?? [];
                if (_cachedMessages != null && _cachedMessages!.isNotEmpty) {
                  final merged = <ChatMessage>[];
                  final messageIds = <String>{};
                  
                  for (final msg in displayItems) {
                    if (!messageIds.contains(msg.id)) {
                      merged.add(msg);
                      messageIds.add(msg.id);
                    }
                  }
                  
                  for (final msg in _cachedMessages!) {
                    if (!messageIds.contains(msg.id)) {
                      merged.add(msg);
                      messageIds.add(msg.id);
                    }
                  }
                  
                  merged.sort((a, b) => a.sentAt.compareTo(b.sentAt));
                  displayItems = merged;
                }
                
                if (displayItems.isEmpty && snap.connectionState == ConnectionState.waiting) {
                  // Nếu có cache, hiển thị cache ngay
                  if (_cachedMessages != null && _cachedMessages!.isNotEmpty) {
                    displayItems = _cachedMessages!;
                  } else {
                    return const Center(child: CircularProgressIndicator());
                  }
                }
                
                if (snap.hasError) {
                  final errorStr = snap.error.toString();
                  String errorMsg = 'Lỗi kết nối Firestore. Vui lòng thử lại sau vài giây.';
                  
                  if (errorStr.contains('permission-denied')) {
                    errorMsg = 'Không có quyền truy cập tin nhắn. Vui lòng kiểm tra quyền truy cập.';
                  } else if (errorStr.contains('network') || errorStr.contains('timeout') || errorStr.contains('unavailable')) {
                    errorMsg = 'Lỗi kết nối mạng. Vui lòng kiểm tra kết nối và thử lại.';
                  } else if (errorStr.contains('INTERNAL ASSERTION FAILED') || 
                      errorStr.contains('Unexpected state') ||
                      errorStr.contains('Dart exception thrown from converted Future')) {
                    errorMsg = 'Lỗi kết nối Firestore. Vui lòng thử lại sau vài giây.';
                  }
                  
                  print('❌ Stream error in ChatAIScreen: $errorStr');
                  
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(errorMsg, textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            setState(() {}); // Force rebuild to retry
                          },
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  );
                }
                
                if (displayItems.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.smart_toy, size: 64, color: Colors.blue),
                        const SizedBox(height: 16),
                        const Text(
                          'Xin chào! Tôi là trợ lý AI.',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Tôi có thể giúp bạn với:\n• Đặt lịch học\n• Thanh toán\n• Sử dụng ứng dụng',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }
                
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: displayItems.length + (_isAIResponding ? 1 : 0),
                  itemBuilder: (context, i) {
                    // Hiển thị loading indicator cho AI response
                    if (i == displayItems.length && _isAIResponding) {
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'AI đang suy nghĩ...',
                                style: TextStyle(color: Colors.blue.shade700),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    
                    final m = displayItems[i];
                    final isMe = m.senderId == me?.id;
                    final isAI = m.text.startsWith('🤖 AI:');
                    
                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(12),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        decoration: BoxDecoration(
                          color: isAI 
                              ? Colors.blue.shade50 
                              : (isMe ? const Color(0xFF1E88E5) : Colors.grey[300]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isAI)
                              Row(
                                children: [
                                  const Icon(Icons.smart_toy, size: 16, color: Colors.blue),
                                  const SizedBox(width: 4),
                                  Text(
                                    'AI Assistant',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            if (isAI) const SizedBox(height: 4),
                            Text(
                              isAI ? m.text.substring(7) : m.text, // Bỏ '🤖 AI: ' prefix
                              style: TextStyle(
                                color: isAI 
                                    ? Colors.black87 
                                    : (isMe ? Colors.white : Colors.black87),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    decoration: const InputDecoration(
                      hintText: 'Nhắn tin với AI...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Color(0xFF1E88E5)),
                  onPressed: _sendMessage,
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF1E88E5).withOpacity(0.1),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

