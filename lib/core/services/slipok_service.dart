import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:typed_data';

// Provider สำหรับการเรียกใช้ SlipOK Service
final slipOkServiceProvider = Provider<SlipOkService>((ref) {
  return SlipOkService();
});

class SlipOkService {
  final Dio _dio = Dio();
  
  final String _apiUrl = dotenv.env['SLIPOK_API_URL'] ?? '';
  final String _apiKey = dotenv.env['SLIPOK_API_KEY'] ?? ''; 

  // ฟังก์ชันสําหรับตรวจสอบสลิป
  Future<SlipResult?> checkSlip(Uint8List imageBytes, String filename) async {
    try {
      // ใช้ FormData เพราะเป็นการส่งไฟล์ภาพ
      FormData formData = FormData.fromMap({
        // คำว่า 'files' หรือ 'image' ขึ้นอยู่กับ API Docs (ตามปกติมักใช้ 'files')
        "files": MultipartFile.fromBytes(imageBytes, filename: filename), 
      });

      final response = await _dio.post(
        _apiUrl,
        data: formData,
        options: Options(
          headers: {
            "x-authorization": _apiKey,
            // "Content-Type" Dio จัดการให้อัตโนมัติเมื่อเป็น FormData
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        // กรณี success API มักจะแนบ data เข้ามาด้านใน
        if (data['data'] != null) {
          final resultData = data['data'];
          return SlipResult(
            amount: (resultData['amount'] ?? 0).toDouble(),
            transDate: resultData['transDate'] ?? '',
            transTime: resultData['transTime'] ?? '',
            transRef: resultData['transRef'] ?? '',
            status: true,
          );
        } else {
          // โครงสร้าง Response อาจจะแตกต่าง รบกวนเทียบกับ API Docs อีกครั้ง
          return SlipResult(
             status: false,
             amount: 0, transDate: '', transTime: '', transRef: ''
          );
        }
      } else {
        return SlipResult(
          status: false,
          amount: 0, transDate: '', transTime: '', transRef: ''
        );
      }
    } catch (e) {
      print("SlipOK Error: $e");
      return null;
    }
  }
}

class SlipResult {
  final bool status;
  final double amount;
  final String transDate;
  final String transTime;
  final String transRef;

  SlipResult({
    required this.status,
    required this.amount,
    required this.transDate,
    required this.transTime,
    required this.transRef,
  });
}
