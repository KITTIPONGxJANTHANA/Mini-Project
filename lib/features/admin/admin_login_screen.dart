import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin_main_screen.dart';
import '../../core/services/supabase_service.dart';

class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  ConsumerState<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen> {
  final _codeController = TextEditingController();
  bool _isLoading = false;

  void _submit() async {
    final code = _codeController.text.trim();

    if (code.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณากรอกรหัสเจ้าของร้าน'), backgroundColor: Colors.red));
       return;
    }

    setState(() => _isLoading = true);

    try {
      final supabaseService = ref.read(supabaseServiceProvider);
      
      final shopId = await supabaseService.loginAsAdmin(code);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('เข้าสู่ระบบสำเร็จ!'), backgroundColor: Colors.green));
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => AdminMainScreen(shopId: shopId)));

    } on AuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.red));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('เข้าสู่ระบบ (เจ้าของร้าน)')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(
                labelText: 'รหัสเจ้าของร้าน (Admin Code)', 
                prefixIcon: Icon(Icons.vpn_key),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 32),
            if (_isLoading)
               const Center(child: CircularProgressIndicator())
            else ...[
               ElevatedButton(
                 onPressed: _submit,
                 child: const Text('เข้าสู่ระบบ / เริ่มต้นใช้งาน'),
               ),
            ]
          ],
        ),
      ),
    );
  }
}
