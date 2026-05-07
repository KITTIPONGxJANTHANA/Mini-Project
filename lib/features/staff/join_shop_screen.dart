import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/supabase_service.dart';
import 'upload_slip_screen.dart';

class JoinShopScreen extends ConsumerStatefulWidget {
  const JoinShopScreen({super.key});

  @override
  ConsumerState<JoinShopScreen> createState() => _JoinShopScreenState();
}

class _JoinShopScreenState extends ConsumerState<JoinShopScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;

  Future<void> _joinShop() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกรหัสร้านค้า'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final supabaseService = ref.read(supabaseServiceProvider);
      // ในตัวอย่างนี้ เราสามารถใช้ฟังก์ชัน joinShopWithCode ที่จำลองไว้
      final shopId = await supabaseService.joinShopWithCode(code);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เข้าร่วมร้านค้าสำเร็จ!'), backgroundColor: Colors.green),
      );

      // นำทางไปยังหน้า Upload Slip และล้าง code หน้า join ทิ้ง
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => UploadSlipScreen(shopId: shopId)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('เข้าร่วมร้านค้า (พนักงาน)')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.storefront_rounded, size: 80, color: Colors.grey),
            const SizedBox(height: 24),
            const Text(
              'กรอกรหัสร้านค้า (Shop Code) ที่ได้รับจากเจ้าของร้าน เพื่อเข้าสู่ระบบตรวจสอบสลิปของร้านนั้น',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _codeController,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 2),
              decoration: InputDecoration(
                hintText: 'เช่น ABC1234',
                prefixIcon: const Icon(Icons.qr_code),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _joinShop,
              child: _isLoading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                : const Text('เข้าร่วมร้านค้า', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
