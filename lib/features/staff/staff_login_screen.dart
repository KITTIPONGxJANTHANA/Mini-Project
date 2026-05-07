import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'join_shop_screen.dart';
import '../../core/services/supabase_service.dart';

class StaffLoginScreen extends ConsumerStatefulWidget {
  const StaffLoginScreen({super.key});

  @override
  ConsumerState<StaffLoginScreen> createState() => _StaffLoginScreenState();
}

class _StaffLoginScreenState extends ConsumerState<StaffLoginScreen> {
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  void _submit() async {
    final phone = _phoneController.text.trim();

    if (phone.isEmpty || phone.length < 9) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณากรอกเบอร์โทรศัพท์ให้ถูกต้อง'), backgroundColor: Colors.red));
       return;
    }

    setState(() => _isLoading = true);

    final fakeEmail = '$phone@slipapp.local';
    final fakePassword = '${phone}abc123!';

    try {
      final supabaseService = ref.read(supabaseServiceProvider);
      try {
        await supabaseService.signIn(fakeEmail, fakePassword);
      } catch (e) {
        await supabaseService.signUp(fakeEmail, fakePassword);
        // หลังจากสมัคร สมมติสร้าง Role ให้เป็น staff
        final user = Supabase.instance.client.auth.currentUser;
        if (user != null) {
          await Supabase.instance.client.from('users').upsert({
            'id': user.id,
            'role': 'staff',
          });
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('เข้าสู่ระบบสำเร็จ!'), backgroundColor: Colors.green));
      
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const JoinShopScreen()),
      );

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
      appBar: AppBar(title: const Text('เข้าสู่ระบบ (พนักงาน)')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'เบอร์โทรศัพท์ (ไม่ต้องมี -)', 
                prefixIcon: Icon(Icons.phone),
                hintText: 'เช่น 0812345678',
              ),
              keyboardType: TextInputType.phone,
              maxLength: 10,
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
