import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../config/app_config.dart';

// Lớp để chứa kết quả đã được phân tích từ AI
class AiParsedResponse {
  final String speech; // Nội dung để AI nói
  final String? action; // Hành động cần thực hiện (vd: 'search')
  final String? query;  // Từ khóa cho hành động đó (vd: 'quán ăn')

  AiParsedResponse({required this.speech, this.action, this.query});
}

class AiService {

  final GenerativeModel _model;

  AiService()
      : _model = GenerativeModel(
    model: 'gemini-2.5-flash', // Sử dụng model ổn định
    apiKey: AppConfig.geminiApiKey,
    safetySettings: [
      SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none),
      SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none),
      SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.none),
      SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.none),
    ],
  );

  // Hàm này bây giờ sẽ nhận thêm vị trí hiện tại của người dùng
  Future<AiParsedResponse> getAiResponse(String userPrompt, {String? currentLocation}) async {
    try {
      // --- PROMPT NÂNG CẤP ---
      final locationContext = currentLocation != null && currentLocation.isNotEmpty
          ? "Vị trí hiện tại của người dùng là: $currentLocation. Hãy sử dụng vị trí này để đưa ra kết quả phù hợp nhất nếu người dùng không nói rõ một địa điểm cụ thể."
          : "Không có thông tin vị trí. Nếu người dùng hỏi địa điểm 'gần đây', hãy nói họ cung cấp vị trí.";

      final fullPrompt = """
        Bạn là một trợ lý AI trong ứng dụng bản đồ.
        Nhiệm vụ của bạn là phân tích yêu cầu của người dùng và trả lời dưới dạng một JSON OBJECT DUY NHẤT.
        JSON phải có các trường: "speech" (nội dung bạn sẽ nói), và "action" (hành động ứng dụng cần làm).
        
        $locationContext

        Các 'action' hợp lệ:
        1. "search": Khi người dùng muốn tìm một loại địa điểm chung chung (quán ăn, cây xăng...).
            - Nếu là 'search', phải có thêm trường "query".
            - Nếu người dùng nói "gần đây", "gần tôi",... và có thông tin vị trí, hãy tạo query kết hợp giữa yêu cầu và vị trí. Ví dụ: "quán ăn ở $currentLocation".
            - Nếu người dùng nói địa điểm cụ thể (ví dụ: "ở Bình Thạnh"), hãy ưu tiên địa điểm đó. Ví dụ: "quán ăn ở Bình Thạnh".
        2. "navigate": Khi người dùng muốn chỉ đường đến một địa điểm cụ thể.
            - Nếu là 'navigate', phải có thêm trường "query" chứa tên địa điểm đó.
        3. "none": Cho các câu hỏi thông thường, tán gẫu. Không cần "query".

        QUY TẮC BẮT BUỘC:
        - LUÔN LUÔN trả lời bằng một JSON object hợp lệ nằm trong khối ```json ... ```.
        - KHÔNG thêm bất kỳ văn bản nào bên ngoài khối markdown đó.
        - Giữ câu trả lời 'speech' ngắn gọn, thân thiện.

        Ví dụ 1 (có vị trí):
        - Vị trí: "Quận 1, TPHCM"
        - Người dùng: "tìm giúp tôi vài quán ăn gần đây"
        - Trả lời của bạn:
        ```json
        {
            "speech": "Được chứ, để tôi tìm các quán ăn ở Quận 1 nhé.",
            "action": "search",
            "query": "quán ăn ở Quận 1, TPHCM"
        }
        ```

        Ví dụ 2 (địa điểm cụ thể):
        - Vị trí: "Quận 1, TPHCM"
        - Người dùng: "tìm các quán ăn ở Bình Thạnh"
        - Trả lời của bạn:
        ```json
        {
            "speech": "Ok, đang tìm các quán ăn ở Bình Thạnh cho bạn.",
            "action": "search",
            "query": "quán ăn ở Bình Thạnh"
        }
        ```

        Ví dụ 3 (không có vị trí):
        - Vị trí: không có
        - Người dùng: "tìm cây xăng gần đây"
        - Trả lời của bạn:
        ```json
        {
            "speech": "Để tìm cây xăng gần bạn, tôi cần biết vị trí hiện tại của bạn.",
            "action": "none"
        }
        ```

        Yêu cầu của người dùng: "$userPrompt"
      """;

      final response = await _model.generateContent([Content.text(fullPrompt)]);

      if (response.text != null && response.text!.isNotEmpty) {
        try {
          var responseText = response.text!;
          final startIndex = responseText.indexOf('```json');
          final endIndex = responseText.lastIndexOf('```');

          if (startIndex != -1 && endIndex != -1 && startIndex < endIndex) {
            responseText =
                responseText.substring(startIndex + 7, endIndex).trim();
          }

          final jsonResponse = jsonDecode(responseText);

          return AiParsedResponse(
            speech: jsonResponse['speech'] ?? "Tôi chưa hiểu ý bạn lắm.",
            action: jsonResponse['action'],
            query: jsonResponse['query'],
          );
        } catch (e) {
          print("Lỗi phân tích JSON từ AI: $e. Phản hồi gốc: ${response.text}");
          return AiParsedResponse(speech: response.text!, action: 'none');
        }
      } else {
        return AiParsedResponse(
            speech: "Xin lỗi, tôi không thể xử lý yêu cầu này.",
            action: 'none');
      }
    } catch (e) {
      print("LỖI KHI GỌI GEMINI API: $e");
      return AiParsedResponse(
          speech: "Đã xảy ra lỗi kết nối tới AI, bạn thử lại nhé.",
          action: 'none');
    }
  }
}