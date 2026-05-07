import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:typed_data';

final telegramServiceProvider = Provider<TelegramService>((ref) {
  return TelegramService();
});

class TelegramService {
  final Dio _dio = Dio();
  
  final String _botToken = dotenv.env['TELEGRAM_BOT_TOKEN'] ?? '';
  final String _chatId = dotenv.env['TELEGRAM_CHAT_ID'] ?? '';

  Future<bool> sendSlipNotification({
    required double amount,
    required String transDate,
    required String transRef,
    required Uint8List imageBytes,
    required String filename,
  }) async {
    final String url = 'https://api.telegram.org/bot$_botToken/sendPhoto';
    
    final String caption = '''
🔔 *แจ้งเตือนยอดเงินเข้า*
------------------------
💰 จำนวนเงิน: ${amount.toStringAsFixed(2)} บาท
🕒 วันที่-เวลา: $transDate
🧾 รหัสอ้างอิง: $transRef
------------------------
ตรวจสอบสลิปสำเร็จ (Verified via SlipOK)
''';

    try {
      FormData formData = FormData.fromMap({
        'chat_id': _chatId,
        'photo': MultipartFile.fromBytes(imageBytes, filename: filename),
        'caption': caption,
        'parse_mode': 'Markdown',
      });

      final response = await _dio.post(
        url,
        data: formData,
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Telegram Error: $e');
      return false;
    }
  }
}
