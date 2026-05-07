import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/services/slipok_service.dart';
import '../../core/services/telegram_service.dart';
import '../../core/services/supabase_service.dart';

class UploadSlipScreen extends ConsumerStatefulWidget {
  final int shopId;
  const UploadSlipScreen({super.key, required this.shopId});

  @override
  ConsumerState<UploadSlipScreen> createState() => _UploadSlipScreenState();
}

class _UploadSlipScreenState extends ConsumerState<UploadSlipScreen> {
  XFile? _pickedFile;
  File? _imageFile;
  bool _isLoading = false;
  SlipResult? _result;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _pickedFile = pickedFile;
        _imageFile = File(pickedFile.path);
        _result = null; // reset result
      });
    }
  }

  Future<void> _verifySlip() async {
    if (_pickedFile == null) return;

    setState(() {
      _isLoading = true;
    });

    final slipService = ref.read(slipOkServiceProvider);
    final bytes = await _pickedFile!.readAsBytes();
    final result = await slipService.checkSlip(bytes, _pickedFile!.name);

    setState(() {
      _isLoading = false;
      _result = result;
    });

    if (result != null) {
      if (result.status) {
        final supabaseService = ref.read(supabaseServiceProvider);

        // เช็คว่าสลิปซ้ำหรือไม่
        try {
          final isDuplicate = await supabaseService.isTransactionDuplicate(result.transRef);
          if (isDuplicate) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('สลิปนี้ถูกใช้งานไปแล้ว ไม่สามารถใช้ซ้ำได้'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
        } catch (e) {
          print('Error checking duplicate slip: $e');
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('เกิดข้อผิดพลาดในการตรวจสอบสลิปซ้ำ: $e'),
              backgroundColor: Colors.red,
            ),
          );
          return; // หยุดทำงานถ้าเช็คไม่ได้ ป้องกันการบันทึกซ้ำ
        }

        // แจ้งเตือนผ่าน Telegram
        final telegramService = ref.read(telegramServiceProvider);
        telegramService.sendSlipNotification(
          amount: result.amount,
          transDate: '${result.transDate} ${result.transTime}',
          transRef: result.transRef,
          imageBytes: bytes,
          filename: _pickedFile!.name,
        );

        // บันทึกลง Supabase
        try {
          await supabaseService.recordTransaction(
            shopId: widget.shopId,
            amount: result.amount,
            slipokTransactionId: result.transRef,
            status: 'SUCCESS',
            imageUrl: '', // ข้ามการอัปโหลดรูปไปก่อน (ใส่เป็นว่าง)
            slipDateTime: DateTime.now(),
          );

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('สลิปถูกต้อง และบันทึกข้อมูลเรียบร้อย'),
              backgroundColor: Colors.green,
            ),
          );
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('สลิปถูกต้อง แต่บันทึกข้อมูลล้มเหลว: $e'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('สลิปไม่ถูกต้อง หรือไม่พบข้อมูล'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('เกิดข้อผิดพลาดในการตรวจสอบสลิป'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ตรวจสอบสลิปเงิน')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // แสดงสถานะการเลือกรูป
            Container(
              height: 250,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).primaryColor.withOpacity(0.3),
                ),
              ),
              child: _imageFile != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: kIsWeb
                          ? Image.network(_imageFile!.path, fit: BoxFit.cover)
                          : Image.file(_imageFile!, fit: BoxFit.cover),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.image_search, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text(
                          'ยังไม่ได้เลือกรูปภาพสลิป',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('ถ่ายรูป'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).cardColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('คลังภาพ'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).cardColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: (_imageFile != null && !_isLoading)
                  ? _verifySlip
                  : null,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('ตรวจสอบความถูกต้อง'),
            ),

            if (_result != null) ...[
              const SizedBox(height: 32),
              _buildResultCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _result!.status ? Icons.check_circle : Icons.cancel,
                  color: _result!.status ? Colors.green : Colors.red,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  _result!.status
                      ? 'สลิปถูกต้อง (Verified)'
                      : 'สลิปไม่ถูกต้อง (Invalid)',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            _buildDetailRow('รหัสอ้างอิง:', _result!.transRef),
            const SizedBox(height: 12),
            _buildDetailRow(
              'จำนวนเงิน:',
              '${_result!.amount.toStringAsFixed(2)} บาท',
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              'วันที่-เวลา:',
              '${_result!.transDate} ${_result!.transTime}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 16)),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ],
    );
  }
}
