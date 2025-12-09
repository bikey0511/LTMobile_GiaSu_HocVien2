import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/message.dart';
import 'firestore_refs.dart';

/// Service để quản lý chat realtime với Firestore
class ChatService {
  final _col = FirestoreRefs.messages();
  
  // Cache để ChatListScreen có thể truy cập tin nhắn cuối (tạm thời)
  final Map<String, List<ChatMessage>> _roomToMessages = {};
  Map<String, List<ChatMessage>> get roomToMessages => _roomToMessages;

  /// Stream tin nhắn realtime của một phòng chat
  /// Emit cache ngay lập tức (nếu có), sau đó emit dữ liệu từ Firestore
  /// Tự động retry và poll lại dữ liệu nếu stream bị lỗi
  Stream<List<ChatMessage>> streamRoom(String roomId) async* {
    print('📡 Starting stream for room: $roomId');
    
    // Nếu roomId rỗng, trả về stream rỗng ngay lập tức
    if (roomId.isEmpty) {
      print('⚠️ Empty roomId, returning empty stream');
      yield <ChatMessage>[];
      return;
    }
    
    // Kiểm tra cache trước - nếu có cache, emit ngay để không mất dữ liệu khi quay lại
    if (_roomToMessages.containsKey(roomId) && _roomToMessages[roomId]!.isNotEmpty) {
      print('📦 Using cached messages: ${_roomToMessages[roomId]!.length} messages');
      yield _roomToMessages[roomId]!;
    } else {
      // Nếu không có cache, emit empty list để UI không phải chờ
      yield <ChatMessage>[];
    }
    
    // Hàm helper để load và emit messages
    Future<List<ChatMessage>> _loadMessages() async {
      try {
        final snapshot = await _col
            .where('roomId', isEqualTo: roomId)
            .get();
        
        final messages = snapshot.docs
            .map((doc) {
              try {
                return ChatMessage.fromMap(doc.id, doc.data());
              } catch (e) {
                print('❌ Error parsing message ${doc.id}: $e');
                return null;
              }
            })
            .whereType<ChatMessage>()
            .toList();
        
        // Sort theo sentAt trong code (không cần index)
        messages.sort((a, b) => a.sentAt.compareTo(b.sentAt));
        
        // Cập nhật cache
        _roomToMessages[roomId] = messages;
        
        return messages;
      } catch (e) {
        print('⚠️ Error loading messages: $e');
        return _roomToMessages[roomId] ?? <ChatMessage>[];
      }
    }
    
    // Load dữ liệu ban đầu ngay lập tức
    try {
      final initialMessages = await _loadMessages();
      // Luôn emit nếu có dữ liệu, để đảm bảo StreamBuilder có data
      // Emit ngay cả nếu giống cache (để StreamBuilder rebuild và hiển thị)
      if (initialMessages.isNotEmpty) {
        print('📥 Emitting initial messages: ${initialMessages.length} messages');
        yield initialMessages;
      } else {
        // Nếu không có data, vẫn emit cache nếu có (để không mất dữ liệu)
        final cached = _roomToMessages[roomId] ?? <ChatMessage>[];
        if (cached.isNotEmpty) {
          print('📦 No initial messages, emitting cache: ${cached.length} messages');
          yield cached;
        }
      }
    } catch (e) {
      print('⚠️ Error loading initial messages: $e');
      // Nếu có lỗi, vẫn emit cache nếu có
      final cached = _roomToMessages[roomId] ?? <ChatMessage>[];
      if (cached.isNotEmpty) {
        yield cached;
      }
    }
    
    // Thêm delay nhỏ trước khi tạo stream để tránh conflict
    await Future.delayed(const Duration(milliseconds: 200));
    
    // Retry logic với exponential backoff
    int retryCount = 0;
    const maxRetries = 5;
    
    while (retryCount < maxRetries) {
      try {
        // Listen stream realtime để cập nhật khi có thay đổi
        await for (final snapshot in _col
            .where('roomId', isEqualTo: roomId)
            .snapshots()
            .timeout(
              const Duration(seconds: 60), // Tăng timeout lên 60s
              onTimeout: (sink) {
                print('⚠️ Stream timeout for room $roomId, will retry');
                sink.close();
              },
            )) {
          retryCount = 0; // Reset retry count khi stream hoạt động
          
          try {
            print('📨 Received ${snapshot.docs.length} documents for room $roomId');
            final messages = snapshot.docs
                .map((doc) {
                  try {
                    final data = doc.data();
                    final message = ChatMessage.fromMap(doc.id, data);
                    return message;
                  } catch (e) {
                    print('❌ Error parsing message ${doc.id}: $e');
                    return null;
                  }
                })
                .whereType<ChatMessage>()
                .toList();
            
            // Sort theo sentAt trong code (không cần index)
            messages.sort((a, b) => a.sentAt.compareTo(b.sentAt));
            
            print('📋 Total valid messages: ${messages.length}');
            
            // Merge với cache hiện tại để đảm bảo không mất tin nhắn mới
            // (tin nhắn mới có thể đã được thêm vào cache trước khi Firestore emit snapshot)
            final cachedMessages = _roomToMessages[roomId] ?? <ChatMessage>[];
            final mergedMessages = <ChatMessage>[];
            final messageIds = <String>{};
            
            // Thêm tất cả messages từ Firestore
            for (final msg in messages) {
              if (!messageIds.contains(msg.id)) {
                mergedMessages.add(msg);
                messageIds.add(msg.id);
              }
            }
            
            // Thêm messages từ cache mà chưa có trong Firestore snapshot
            // (có thể là tin nhắn vừa gửi chưa được Firestore sync)
            for (final msg in cachedMessages) {
              if (!messageIds.contains(msg.id)) {
                mergedMessages.add(msg);
                messageIds.add(msg.id);
              }
            }
            
            // Sort lại sau khi merge
            mergedMessages.sort((a, b) => a.sentAt.compareTo(b.sentAt));
            
            // Cập nhật cache
            _roomToMessages[roomId] = mergedMessages;
            
            print('📋 Merged messages: ${mergedMessages.length} (from Firestore: ${messages.length}, from cache: ${cachedMessages.length})');
            
            yield mergedMessages;
          } catch (e) {
            print('❌ Error processing snapshot for room $roomId: $e');
            // Nếu có lỗi xử lý snapshot, emit cache nếu có
            final cached = _roomToMessages[roomId] ?? <ChatMessage>[];
            if (cached.isNotEmpty) {
              yield cached;
            }
          }
        }
        
        // Nếu stream kết thúc (không phải do timeout), emit cache và break
        print('📡 Stream ended for room $roomId, emitting cache');
        final cached = _roomToMessages[roomId] ?? <ChatMessage>[];
        if (cached.isNotEmpty) {
          yield cached;
        }
        break;
      } catch (e) {
        retryCount++;
        print('❌ Stream error for room $roomId (attempt $retryCount/$maxRetries): $e');
        final errorStr = e.toString();
        
        // Nếu là lỗi permission, không retry
        if (errorStr.contains('permission-denied')) {
          print('🚫 Permission denied for room $roomId, stopping retry');
          final cached = _roomToMessages[roomId] ?? <ChatMessage>[];
          if (cached.isNotEmpty) {
            yield cached;
          }
          break;
        }
        
        // Poll lại dữ liệu trước khi retry stream
        try {
          final polledMessages = await _loadMessages();
          if (polledMessages.isNotEmpty) {
            yield polledMessages;
          }
        } catch (pollError) {
          print('⚠️ Error polling messages: $pollError');
        }
        
        // Nếu chưa đạt max retries, đợi một chút rồi retry
        if (retryCount < maxRetries) {
          // Exponential backoff: 1s, 2s, 4s, 8s, 16s
          final delaySeconds = 1 << (retryCount - 1);
          print('⏳ Retrying stream in $delaySeconds seconds...');
          await Future.delayed(Duration(seconds: delaySeconds));
        } else {
          // Đã hết retry, poll định kỳ mỗi 5 giây
          print('🔄 Max retries reached, switching to polling mode (every 5s)');
          // Emit cache trước khi vào polling mode
          final cached = _roomToMessages[roomId] ?? <ChatMessage>[];
          if (cached.isNotEmpty) {
            yield cached;
          }
          
          while (true) {
            await Future.delayed(const Duration(seconds: 5));
            try {
              final polledMessages = await _loadMessages();
              // Luôn emit nếu có data, kể cả nếu giống cache (để StreamBuilder rebuild)
              if (polledMessages.isNotEmpty) {
                yield polledMessages;
              } else {
                // Nếu không có data, vẫn emit cache nếu có
                final cached = _roomToMessages[roomId] ?? <ChatMessage>[];
                if (cached.isNotEmpty) {
                  yield cached;
                }
              }
            } catch (pollError) {
              print('⚠️ Error in polling mode: $pollError');
              // Nếu có lỗi, vẫn emit cache nếu có
              final cached = _roomToMessages[roomId] ?? <ChatMessage>[];
              if (cached.isNotEmpty) {
                yield cached;
              }
            }
          }
        }
      }
    }
    
    // Nếu vòng lặp kết thúc (không vào polling mode), emit cache cuối cùng
    final finalCache = _roomToMessages[roomId] ?? <ChatMessage>[];
    if (finalCache.isNotEmpty) {
      print('📦 Emitting final cache: ${finalCache.length} messages');
      yield finalCache;
    }
  }
  
  
  /// Gửi tin nhắn
  Future<void> sendMessage(String roomId, String senderId, String text) async {
    // Validate input
    if (roomId.isEmpty || senderId.isEmpty || text.trim().isEmpty) {
      throw Exception('Thông tin tin nhắn không hợp lệ');
    }

    // Thêm delay nhỏ trước khi gửi để tránh conflict với stream đang chạy
    await Future.delayed(const Duration(milliseconds: 300));

    final msg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      roomId: roomId,
      senderId: senderId,
      text: text.trim(),
      sentAt: DateTime.now(),
    );

    final data = msg.toMap();
    data['sentAt'] = Timestamp.fromDate(msg.sentAt);

    // Retry logic để xử lý Firestore internal assertion errors
    int retries = 0;
    const maxRetries = 3;
    const retryDelay = Duration(milliseconds: 500);
    
    while (retries <= maxRetries) {
      try {
        // Thêm delay nhỏ trước khi gửi để tránh conflict với stream
        if (retries > 0) {
          await Future.delayed(retryDelay * retries);
        }
        
        // Thêm timeout để tránh treo quá lâu
        await _col.doc(msg.id).set(data).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw Exception('Timeout khi gửi tin nhắn. Vui lòng kiểm tra kết nối mạng.');
          },
        );
        print('✅ Message sent successfully: ${msg.id}');
        
        // Cập nhật cache ngay lập tức để UI hiển thị tin nhắn ngay
        // Không cần chờ stream emit lại từ Firestore
        final currentMessages = _roomToMessages[roomId] ?? <ChatMessage>[];
        // Kiểm tra xem tin nhắn đã có trong cache chưa (tránh duplicate)
        if (!currentMessages.any((m) => m.id == msg.id)) {
          currentMessages.add(msg);
          // Sort lại theo sentAt
          currentMessages.sort((a, b) => a.sentAt.compareTo(b.sentAt));
          _roomToMessages[roomId] = currentMessages;
          print('📦 Updated cache with new message: ${currentMessages.length} messages');
        }
        
        // Thêm delay nhỏ sau khi gửi thành công để stream có thời gian cập nhật
        await Future.delayed(const Duration(milliseconds: 100));
        
        return; // Thành công, thoát khỏi vòng lặp
      } catch (e) {
        final errorStr = e.toString();
        print('❌ Error sending message (attempt ${retries + 1}/${maxRetries + 1}): $errorStr');
        
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
          print('⚠️ Retrying send message (attempt ${retries + 1}/${maxRetries + 1})...');
        } else {
          // Nếu không phải lỗi có thể retry hoặc đã hết retry, throw lại với message rõ ràng
          if (errorStr.contains('permission-denied')) {
            throw Exception('Không có quyền gửi tin nhắn. Vui lòng kiểm tra quyền truy cập.');
          } else if (errorStr.contains('unavailable') || errorStr.contains('network')) {
            throw Exception('Lỗi kết nối mạng. Vui lòng kiểm tra kết nối và thử lại.');
          } else if (errorStr.contains('timeout') || errorStr.contains('Timeout')) {
            throw Exception('Timeout khi gửi tin nhắn. Vui lòng kiểm tra kết nối mạng.');
          } else if (errorStr.contains('INTERNAL ASSERTION FAILED') || 
              errorStr.contains('Unexpected state') ||
              errorStr.contains('Dart exception thrown from converted Future')) {
            throw Exception('Lỗi kết nối Firestore. Vui lòng thử lại sau vài giây.');
          } else {
            throw Exception('Không thể gửi tin nhắn: $e');
          }
        }
      }
    }
  }

  /// Xóa tin nhắn (tùy chọn)
  Future<void> deleteMessage(String messageId) async {
    try {
      await _col.doc(messageId).delete();
    } catch (e) {
      throw Exception('Không thể xóa tin nhắn: $e');
    }
  }

  /// Lấy tin nhắn cuối cùng của một room (query trực tiếp từ Firestore)
  Future<ChatMessage?> getLastMessage(String roomId) async {
    try {
      // Bỏ orderBy để tránh cần index, sẽ sort trong code
      final snapshot = await _col
          .where('roomId', isEqualTo: roomId)
          .get();

      if (snapshot.docs.isEmpty) return null;

      // Parse và sort trong code
      final messages = snapshot.docs
          .map((doc) {
            try {
              return ChatMessage.fromMap(doc.id, doc.data());
            } catch (e) {
              return null;
            }
          })
          .whereType<ChatMessage>()
          .toList();
      
      if (messages.isEmpty) return null;
      
      // Sort theo sentAt và lấy tin nhắn cuối cùng
      messages.sort((a, b) => b.sentAt.compareTo(a.sentAt));
      return messages.first;
    } catch (e) {
      print('Error getting last message for room $roomId: $e');
      return null;
    }
  }

  /// Stream tin nhắn cuối cùng của một room (realtime)
  Stream<ChatMessage?> streamLastMessage(String roomId) {
    // Bỏ orderBy để tránh cần index, sẽ sort trong code
    return _col
        .where('roomId', isEqualTo: roomId)
        .snapshots()
        .map((snapshot) {
      try {
        if (snapshot.docs.isEmpty) {
          // Không có tin nhắn, cập nhật cache rỗng
          _roomToMessages[roomId] = [];
          return null;
        }
        
        // Parse và sort trong code
        final messages = snapshot.docs
            .map((doc) {
              try {
                return ChatMessage.fromMap(doc.id, doc.data());
              } catch (e) {
                return null;
              }
            })
            .whereType<ChatMessage>()
            .toList();
        
        if (messages.isEmpty) {
          _roomToMessages[roomId] = [];
          return null;
        }
        
        // Sort theo sentAt và lấy tin nhắn cuối cùng
        messages.sort((a, b) => b.sentAt.compareTo(a.sentAt));
        final lastMessage = messages.first;
        
        // Cập nhật cache với tất cả messages (đã sort)
        _roomToMessages[roomId] = messages;
        return lastMessage;
      } catch (e) {
        print('Error parsing last message for room $roomId: $e');
        return null;
      }
    }).handleError((error) {
      print('Stream error for last message in room $roomId: $error');
      return null;
    });
  }

  /// Đánh dấu tất cả tin nhắn chưa đọc của user là đã đọc (tất cả các room)
  Future<void> markAllAsRead(String userId) async {
    try {
      print('🔍 Fetching unread messages for user $userId...');
      // Lấy tất cả tin nhắn chưa được đọc bởi user này (từ người khác)
      final snapshot = await _col
          .where('senderId', isNotEqualTo: userId)
          .get();

      if (snapshot.docs.isEmpty) {
        print('ℹ️ No messages to mark as read for user $userId');
        return;
      }

      print('📨 Found ${snapshot.docs.length} messages from others, checking rooms...');
      final batch = FirebaseFirestore.instance.batch();
      int count = 0;
      int skipped = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final roomId = data['roomId'] as String? ?? '';
        
        // Kiểm tra xem user có tham gia room này không
        bool isUserInRoom = false;
        if (roomId.startsWith('ai-assistant-')) {
          final roomUserId = roomId.replaceFirst('ai-assistant-', '');
          isUserInRoom = roomUserId == userId;
        } else if (roomId.startsWith('group-')) {
          // Bỏ qua chat nhóm vì cần kiểm tra booking
          skipped++;
          continue;
        } else if (roomId.contains('-')) {
          final parts = roomId.split('-');
          if (parts.length == 2) {
            isUserInRoom = parts[0] == userId || parts[1] == userId;
          }
        }
        
        // Chỉ đánh dấu nếu user tham gia room
        if (!isUserInRoom) {
          skipped++;
          continue;
        }
        
        final readByRaw = data['readBy'];
        List<String> readBy = [];
        
        if (readByRaw != null) {
          if (readByRaw is List) {
            readBy = List<String>.from(readByRaw);
          } else if (readByRaw is String) {
            readBy = [readByRaw];
          }
        }
        
        // Nếu user chưa đọc tin nhắn này, thêm vào readBy
        if (!readBy.contains(userId)) {
          readBy.add(userId);
          batch.update(doc.reference, {'readBy': readBy});
          count++;
        }
      }

      if (count > 0) {
        print('💾 Committing batch update for $count messages...');
        await batch.commit();
        print('✅ Marked $count messages as read for user $userId (all rooms), skipped $skipped');
        // Đợi một chút để Firestore cập nhật và stream emit lại
        await Future.delayed(const Duration(milliseconds: 500));
      } else {
        print('ℹ️ All messages already read for user $userId (checked ${snapshot.docs.length}, skipped $skipped)');
      }
    } catch (e) {
      print('❌ Error marking all messages as read: $e');
      rethrow;
    }
  }

  /// Đánh dấu tất cả tin nhắn trong room là đã đọc bởi user
  Future<void> markRoomAsRead(String roomId, String userId) async {
    try {
      // Lấy tất cả tin nhắn trong room chưa được đọc bởi user này
      final snapshot = await _col
          .where('roomId', isEqualTo: roomId)
          .where('senderId', isNotEqualTo: userId) // Chỉ đánh dấu tin nhắn từ người khác
          .get();

      final batch = FirebaseFirestore.instance.batch();
      int count = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final readByRaw = data['readBy'];
        List<String> readBy = [];
        
        // Parse readBy từ nhiều định dạng có thể
        if (readByRaw != null) {
          if (readByRaw is List) {
            readBy = List<String>.from(readByRaw);
          } else if (readByRaw is String) {
            readBy = [readByRaw];
          }
        }
        
        // Nếu user chưa đọc tin nhắn này, thêm vào readBy
        if (!readBy.contains(userId)) {
          readBy.add(userId);
          batch.update(doc.reference, {'readBy': readBy});
          count++;
        }
      }

      if (count > 0) {
        await batch.commit();
        print('✅ Marked $count messages as read in room $roomId for user $userId');
        // Đợi một chút để Firestore cập nhật và stream emit lại
        await Future.delayed(const Duration(milliseconds: 300));
        // Force trigger stream update bằng cách query lại room này
        try {
          // Query lại room để trigger stream update
          await _col
              .where('roomId', isEqualTo: roomId)
              .limit(1)
              .get();
        } catch (_) {
          // Ignore error, chỉ cần trigger stream
        }
      } else {
        print('ℹ️ All messages already read in room $roomId for user $userId');
      }
    } catch (e) {
      print('Error marking room as read: $e');
      // Không throw để không làm gián đoạn UI
    }
  }

  /// Đếm số tin nhắn chưa đọc cho một room cụ thể
  Stream<int> unreadMessageCountForRoom(String roomId, String userId) {
    return _col
        .where('roomId', isEqualTo: roomId)
        .where('senderId', isNotEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      try {
        int count = 0;
        final now = DateTime.now();
        final cutoffDate = now.subtract(const Duration(days: 30));
        
        for (var doc in snapshot.docs) {
          final data = doc.data();
          final sentAt = data['sentAt'];
          
          DateTime? sentAtDate;
          if (sentAt != null) {
            try {
              if (sentAt is Timestamp) {
                sentAtDate = sentAt.toDate();
              } else if (sentAt is String) {
                sentAtDate = DateTime.tryParse(sentAt);
              }
            } catch (_) {
              continue;
            }
          }
          
          if (sentAtDate == null || !sentAtDate.isAfter(cutoffDate)) {
            continue;
          }
          
          // Kiểm tra xem user đã đọc tin nhắn này chưa
          final readByRaw = data['readBy'];
          bool isRead = false;
          
          if (readByRaw != null) {
            if (readByRaw is List) {
              final readByList = List<String>.from(readByRaw);
              isRead = readByList.contains(userId);
            } else if (readByRaw is String) {
              isRead = readByRaw == userId;
            }
          }
          
          if (!isRead) {
            count++;
          }
        }
        return count;
      } catch (e) {
        print('Error counting unread for room $roomId: $e');
        return 0;
      }
    }).handleError((error) {
      print('Stream error for unread count in room $roomId: $error');
      return 0;
    });
  }

  /// Đếm số tin nhắn chưa đọc cho một user
  /// Đếm tin nhắn từ người khác trong các room mà user tham gia
  Stream<int> unreadMessageCount(String userId) {
    // Lấy tất cả tin nhắn từ Firestore
    return _col
        .where('senderId', isNotEqualTo: userId) // Chỉ lấy tin nhắn từ người khác
        .snapshots()
        .map((snapshot) {
      try {
        int count = 0;
        final now = DateTime.now();
        // Chỉ đếm tin nhắn trong 30 ngày gần đây để tránh đếm quá nhiều tin nhắn cũ
        final cutoffDate = now.subtract(const Duration(days: 30));
        
        for (var doc in snapshot.docs) {
          final data = doc.data();
          final roomId = data['roomId'] as String? ?? '';
          final sentAt = data['sentAt'];
          
          // Parse sentAt
          DateTime? sentAtDate;
          if (sentAt != null) {
            try {
              if (sentAt is Timestamp) {
                sentAtDate = sentAt.toDate();
              } else if (sentAt is String) {
                sentAtDate = DateTime.tryParse(sentAt);
              }
            } catch (_) {
              continue;
            }
          }
          
          // Chỉ đếm tin nhắn trong 30 ngày gần đây
          if (sentAtDate == null || !sentAtDate.isAfter(cutoffDate)) {
            continue;
          }
          
          // Kiểm tra chính xác xem user có tham gia room này không
          // RoomId format: 
          // - 'tutorId-studentId' (chat 1-1 giữa tutor và student)
          // - 'group-{bookingId}' (chat nhóm)
          // - 'ai-assistant-{userId}' (chat với AI)
          // - '{adminId}-{userId}' (chat với admin)
          
          bool isUserInRoom = false;
          
          if (roomId.startsWith('ai-assistant-')) {
            // Chat với AI: format 'ai-assistant-{userId}'
            final roomUserId = roomId.replaceFirst('ai-assistant-', '');
            isUserInRoom = roomUserId == userId;
          } else if (roomId.startsWith('group-')) {
            // Chat nhóm: format 'group-{bookingId}'
            // Tạm thời bỏ qua chat nhóm vì cần query booking để kiểm tra user có trong nhóm không
            // Có thể cải thiện sau bằng cách cache danh sách booking
            continue;
          } else if (roomId.contains('-')) {
            // Chat 1-1: format 'tutorId-studentId' hoặc '{adminId}-{userId}'
            // Chỉ có 1 dấu gạch ngang, split thành 2 phần
            final parts = roomId.split('-');
            if (parts.length == 2) {
              // Kiểm tra userId có khớp với một trong hai phần (chính xác, không phải substring)
              isUserInRoom = parts[0] == userId || parts[1] == userId;
            } else {
              // Nếu có nhiều dấu gạch ngang, có thể là format khác, bỏ qua
              continue;
            }
          } else {
            // RoomId không có format hợp lệ, bỏ qua
            continue;
          }
          
          // Chỉ đếm nếu user tham gia room, tin nhắn từ người khác, và chưa đọc
          if (isUserInRoom) {
            // Kiểm tra xem user đã đọc tin nhắn này chưa
            final readBy = data['readBy'];
            List<String> readByList = [];
            if (readBy != null) {
              if (readBy is List) {
                readByList = List<String>.from(readBy);
              } else if (readBy is String) {
                readByList = [readBy];
              }
            }
            if (!readByList.contains(userId)) {
              count++;
            }
          }
        }
        if (count > 0) {
          print('📊 Unread count for user $userId: $count (có tin nhắn chưa đọc)');
        }
        return count;
      } catch (e) {
        print('❌ Error counting unread messages: $e');
        return 0;
      }
    }).handleError((error) {
      print('❌ Stream error for unread count: $error');
      return 0;
    });
  }
}

