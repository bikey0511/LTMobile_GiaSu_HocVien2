import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service để tích hợp với OpenAI API
class OpenAIService {
  // Thay YOUR_API_KEY bằng API key của bạn từ https://platform.openai.com/api-keys
  static const String _apiKey = 'YOUR_OPENAI_API';
  static const String _apiUrl = '';

  /// Gửi tin nhắn đến OpenAI và nhận phản hồi
  Future<String> getAIResponse(String userMessage, {String? context}) async {
    try {
      // Nếu chưa có API key, trả về response mặc định
      if (_apiKey == 'YOUR_OPENAI_API_KEY' || _apiKey.isEmpty) {
        return _getDefaultResponse(userMessage);
      }

      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo', // Hoặc 'gpt-4' nếu có
          'messages': [
            {
              'role': 'system',
              'content': context ?? '''Bạn là trợ lý AI của một ứng dụng kết nối gia sư và học viên. 
Bạn giúp học viên:
- Đặt lịch học với gia sư
- Thanh toán học phí qua ví điện tử
- Sử dụng các tính năng của app
- Hỗ trợ kỹ thuật

Hãy trả lời ngắn gọn, thân thiện và hữu ích bằng tiếng Việt.''',
            },
            {
              'role': 'user',
              'content': userMessage,
            },
          ],
          'max_tokens': 500,
          'temperature': 0.7,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'] as String;
      } else {
        print('OpenAI API error: ${response.statusCode} - ${response.body}');
        return _getDefaultResponse(userMessage);
      }
    } catch (e) {
      print('Error calling OpenAI: $e');
      return _getDefaultResponse(userMessage);
    }
  }

  /// Response mặc định nếu không có API key hoặc lỗi
  String _getDefaultResponse(String userMessage) {
    final lowerMessage = userMessage.toLowerCase();
    
    if (lowerMessage.contains('xin chào') || lowerMessage.contains('hello') || lowerMessage.contains('hi')) {
      return 'Xin chào! Tôi là trợ lý AI. Tôi có thể giúp bạn với các câu hỏi về:\n• Đặt lịch học\n• Thanh toán\n• Sử dụng ứng dụng\n• Hỗ trợ kỹ thuật';
    } else if (lowerMessage.contains('đặt lịch') || lowerMessage.contains('booking')) {
      return 'Để đặt lịch học:\n1. Vào tab "Đặt lịch"\n2. Chọn gia sư và thời gian\n3. Chọn số buổi học (1, 2, 3 hoặc 8 buổi - giảm 15%)\n4. Chọn học một mình hoặc học nhóm\n5. Thanh toán học phí\n\nBạn cần hỗ trợ thêm gì không?';
    } else if (lowerMessage.contains('thanh toán') || lowerMessage.contains('payment')) {
      return 'Bạn có thể thanh toán bằng ví điện tử trong app:\n• Nạp tiền vào ví từ tài khoản admin\n• Thanh toán học phí tự động từ ví\n• Xem lịch sử giao dịch\n\nVào tab "Hồ sơ" → "Ví điện tử" để quản lý.';
    } else if (lowerMessage.contains('phòng học') || lowerMessage.contains('classroom')) {
      return 'Phòng học sẽ hiển thị sau khi:\n• Gia sư đã chấp nhận lịch học\n• Bạn đã thanh toán học phí\n\nTrong phòng học bạn có thể:\n• Tham gia video call với gia sư\n• Xem tài liệu khóa học\n• Làm bài tập\n• Chat với gia sư và nhóm học';
    } else if (lowerMessage.contains('bài tập') || lowerMessage.contains('assignment')) {
      return 'Bạn có thể:\n• Xem bài tập trong tab "Phòng học"\n• Nộp bài tập với file đính kèm\n• Xem điểm và nhận xét từ gia sư\n\nVào "Phòng học" → Chọn khóa học → Nhấn nút "Bài tập"';
    } else if (lowerMessage.contains('cảm ơn') || lowerMessage.contains('thank')) {
      return 'Không có gì! Chúc bạn học tập tốt. Nếu cần hỗ trợ thêm, cứ hỏi tôi nhé! 😊';
    } else if (lowerMessage.contains('giúp') || lowerMessage.contains('help')) {
      return 'Tôi có thể giúp bạn:\n\n📚 Đặt lịch học với gia sư\n💰 Thanh toán học phí\n💬 Chat với gia sư\n👥 Tham gia lớp học nhóm\n📱 Sử dụng các tính năng của app\n📝 Làm bài tập\n\nBạn muốn biết thêm về điều gì?';
    } else {
      return 'Cảm ơn bạn đã hỏi! Tôi đang học hỏi thêm để trả lời tốt hơn. Bạn có thể:\n• Hỏi về cách đặt lịch học\n• Hỏi về thanh toán\n• Hỏi về phòng học và bài tập\n\nHoặc liên hệ admin để được hỗ trợ trực tiếp.';
    }
  }
}


