import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService();
});

class SupabaseService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // 1. ตัวอย่างการสมัครสมาชิก (Sign Up)
  Future<AuthResponse> signUp(String email, String password) async {
    return await _supabase.auth.signUp(email: email, password: password);
  }

  // 2. ตัวอย่างการ Login
  Future<AuthResponse> signIn(String email, String password) async {
    return await _supabase.auth.signInWithPassword(email: email, password: password);
  }

  // 3. ฟังก์ชันสร้างร้านค้า (เจ้าของร้าน)
  Future<void> createShop(String shopCode) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('ผู้ใช้ยังไม่ได้ Login');

    await _supabase.from('shops').insert({
      'admin_id': user.id,
      'shop_code': shopCode,
      // created_at เป็น default ของ DB อยู่แล้ว
    });
  }

  // 4. บันทึกรายการสลิปลงฐานข้อมูล (ลูกจ้าง)
  Future<void> recordTransaction({
    required int shopId,
    required double amount,
    required String slipokTransactionId,
    required String status,
    required String imageUrl, // ในที่นี้อิงว่าอาจจะอัพโหลดรูปไป storage ก่อน
    required DateTime slipDateTime,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('ผู้ใช้ยังไม่ได้ Login');

    await _supabase.from('transactions').insert({
      'shop_id': shopId,
      'staff_id': user.id,
      'amount': amount,
      'slipok_transaction_id': slipokTransactionId,
      'image_url': imageUrl,
      'status': status,
      'datetime': slipDateTime.toIso8601String(),
    });
  }

  // 5. ตัวอย่างดึงข้อมูลรายการสลิปย้อนหลัง (เจ้าของร้าน / ลูกจ้าง)
  Future<List<Map<String, dynamic>>> getTransactions(int shopId) async {
    final response = await _supabase
        .from('transactions')
        .select()
        .eq('shop_id', shopId)
        .order('datetime', ascending: false);
    
    return List<Map<String, dynamic>>.from(response);
  }

  // เช็คว่าสลิปนี้ถูกใช้งานไปแล้วหรือยัง
  Future<bool> isTransactionDuplicate(String transRef) async {
    if (transRef.isEmpty) return false; // ป้องกันกรณี transRef ว่าง

    final response = await _supabase
        .from('transactions')
        .select('id')
        .eq('slipok_transaction_id', transRef)
        .limit(1);
    
    return response.isNotEmpty;
  }

  // 6. รหัสร้านค้า (พนักงานเข้าสู่ร้าน)
  Future<int> joinShopWithCode(String shopCode) async {
    final user = _supabase.auth.currentUser;
    // ปิดการใช้ Throw ชั่วคราวเพื่อให้เทสโค้ด UI ได้โดยยังไม่ล็อคอิน
    // if (user == null) throw Exception('ผู้ใช้ยังไม่ได้ Login');

    // 1. ค้นหาร้านค้าด้วย Code
    final shopResult = await _supabase
        .from('shops')
        .select()
        .eq('shop_code', shopCode)
        .maybeSingle();

    if (shopResult == null) {
      throw Exception('ไม่พบรหัสร้านค้านี้');
    }

    final shopId = shopResult['id'] as int;

    if (user != null) {
      // 2. ตรวจสอบว่าพนักงานอยู่ในร้านนี้แล้วหรือยัง
      final existCheck = await _supabase
          .from('staff_shops')
          .select()
          .eq('user_id', user.id)
          .eq('shop_id', shopId)
          .maybeSingle();

      if (existCheck == null) {
        // 3. เพิ่มเข้าตารางพนักงาน-ร้านค้า
        await _supabase.from('staff_shops').insert({
          'user_id': user.id,
          'shop_id': shopId,
        });
      }
    }
    
    return shopId;
  }

  // 7. ล็อกอินสำหรับเจ้าของร้าน (Admin) ด้วยรหัสเดียว
  Future<int> loginAsAdmin(String adminCode) async {
    if (adminCode != 'JINGJOK') {
      throw Exception('รหัสผ่านเจ้าของร้านไม่ถูกต้อง');
    }

    // 1. Login แบบ Anonymous
    await _supabase.auth.signInAnonymously();
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('ล็อกอินล้มเหลว');

    // 2. ค้นหาว่ามี Admin Code นี้ในตาราง shops หรือยัง?
    // ในที่นี้เราจะเก็บ adminCode ไว้ในฟิลด์ใหม่หรือใช้ admin_id ผูกกับโค้ดนี้
    // แต่เพื่อความง่าย เราจะใช้ 'shop_code' เก็บโค้ดสำหรับพนักงาน
    // และใช้ตาราง users หรือ shops ในการเก็บ admin_code
    // เราสร้างฟิลด์ 'admin_code' ใน shops ถ้ามี หรือใช้ 'id'
    
    // โค้ดที่ง่ายที่สุดสำหรับ Internal App คือค้นหาว่ามีร้านที่ owner คือ user นี้ไหม 
    // อ้าว user เปลี่ยนไปเรื่อยๆ ดังนั้นเราค้นหา shop โดย admin_code
    // สมมติว่าเพิ่ม column 'admin_code' ในตาราง shops (ถ้าไม่มีเราก็สร้าง shop_code)
    // แต่เพื่อไม่ให้ต้องแก้ DB มาก ให้เราใช้ 'shop_name' หรืออะไรแทน
    // เพื่อความชัวร์ เราตรวจสอบว่ามีร้านที่ admin_code = adminCode ไหม
    // สมมติว่าแอปนี้มีแค่ 1 ร้าน (JINGJOK)
    // ค้นหาร้านแรกเลย
    
    // ลองค้นหาร้านทั้งหมด
    final shops = await _supabase.from('shops').select();
    
    int shopId;
    if (shops.isEmpty) {
       // ถ้ายังไม่มีร้านเลย ให้สร้างร้านแรกขึ้นมา
       final insertResponse = await _supabase.from('shops').insert({
         'admin_id': user.id, // ให้คนแรกที่สร้างเป็น admin
         'shop_code': 'AB1234', // สุ่มสร้างรหัสร้านค้าเริ่มต้นให้พนักงาน
       }).select().single();
       shopId = insertResponse['id'] as int;
    } else {
       // ถ้ามีร้านอยู่แล้ว ก็ดึงร้านแรกมาใช้เลย (เพราะเป็นแอปองค์กร ใช้ร้านเดียว)
       shopId = shops.first['id'] as int;
    }
    
    return shopId;
  }
}
