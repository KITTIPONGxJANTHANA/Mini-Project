import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:math';

class AdminDashboardTab extends StatefulWidget {
  final int shopId;
  const AdminDashboardTab({super.key, required this.shopId});

  @override
  State<AdminDashboardTab> createState() => _AdminDashboardTabState();
}

class _AdminDashboardTabState extends State<AdminDashboardTab> {
  String _shopCode = "กำลังโหลด...";
  bool _isLoading = true;
  
  double _todayTotal = 0.0;
  double _weekTotal = 0.0;
  double _monthTotal = 0.0;

  DateTime _selectedDate = DateTime.now();
  double _selectedDateTotal = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchShopData();
  }

  String _generateRandomCode(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random();
    return String.fromCharCodes(Iterable.generate(
        length, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }

  Future<void> _fetchShopData() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('shops')
          .select('shop_code')
          .eq('id', widget.shopId)
          .maybeSingle();

      if (response != null) {
        setState(() {
           _shopCode = response['shop_code'];
           _isLoading = false;
        });
      }

      await _fetchStats(widget.shopId);

    } catch (e) {
      print("Error fetching shop data: $e");
      setState(() {
        _shopCode = "เกิดข้อผิดพลาด";
        _isLoading = false;
      });
    }
  }

  Future<void> _regenerateShopCode() async {
    setState(() => _isLoading = true);
    try {
      final newCode = _generateRandomCode(6);
      
      await Supabase.instance.client
          .from('shops')
          .update({'shop_code': newCode})
          .eq('id', widget.shopId);

      setState(() {
        _shopCode = newCode;
        _isLoading = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('สร้างรหัสร้านใหม่เรียบร้อยแล้ว! (รหัสเก่าจะใช้งานไม่ได้อีก)'),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      print("Error regenerating shop code: $e");
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('เกิดข้อผิดพลาดในการสร้างรหัสใหม่'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<void> _fetchStats(int shopId) async {
    try {
      // ดึงเฉพาะรายการที่สถานะเป็น 'SUCCESS' หรือ 'valid' (ตามที่คุณบันทึกในหน้า UploadSlipScreen)
      final response = await Supabase.instance.client
          .from('transactions')
          .select('amount, datetime, status')
          .eq('shop_id', shopId)
          .inFilter('status', ['SUCCESS', 'valid']); // รองรับทั้งสองแบบ

      final now = DateTime.now();
      double today = 0.0;
      double week = 0.0;
      double month = 0.0;
      double selectedDateTotal = 0.0;

      for (var row in response) {
        final amount = (row['amount'] as num).toDouble();
        final dt = DateTime.parse(row['datetime']).toLocal();

        // ของวันนี้
        if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
          today += amount;
        }
        
        // ของเดือนนี้
        if (dt.year == now.year && dt.month == now.month) {
          month += amount;
        }

        // ของสัปดาห์นี้ โค้ดแบบง่าย (ภายใน 7 วันย้อนหลัง)
        final daysDiff = now.difference(dt).inDays;
        if (daysDiff >= 0 && daysDiff < 7) {
          week += amount;
        }

        // ของวันที่เลือก
        if (dt.year == _selectedDate.year && dt.month == _selectedDate.month && dt.day == _selectedDate.day) {
          selectedDateTotal += amount;
        }
      }

      setState(() {
        _todayTotal = today;
        _weekTotal = week;
        _monthTotal = month;
        _selectedDateTotal = selectedDateTotal;
      });
    } catch (e) {
      print("Error fetching stats: $e");
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      await _fetchStats(widget.shopId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Dashboard')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
           crossAxisAlignment: CrossAxisAlignment.stretch,
           children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      const Text('รหัสร้านค้าสำหรับลูกจ้าง', style: TextStyle(color: Colors.grey, fontSize: 16)),
                      const SizedBox(height: 12),
                      _isLoading
                         ? const CircularProgressIndicator()
                         : Text(
                             _shopCode,
                             style: TextStyle(
                               fontSize: 32,
                               fontWeight: FontWeight.bold,
                               color: Theme.of(context).primaryColor,
                               letterSpacing: 2,
                             ),
                           ),
                      const SizedBox(height: 16),
                      if (!_isLoading)
                        ElevatedButton.icon(
                          onPressed: _regenerateShopCode,
                          icon: const Icon(Icons.refresh),
                          label: const Text('เปลี่ยนรหัสร้านใหม่'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade800,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      const SizedBox(height: 16),
                      const Text('บอกรหัสนี้ให้พนักงาน เพื่อให้พวกเขาสามารถตรวจสอบสลิปของร้านได้', 
                                 textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12))
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              
              // ส่วนของการเลือกดูยอดเงินรายวัน (Date Picker)
              Card(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Theme.of(context).primaryColor.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ยอดเงินวันที่ ${DateFormat('dd MMM yyyy').format(_selectedDate)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_selectedDateTotal.toStringAsFixed(2)} บาท',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => _selectDate(context),
                        icon: const Icon(Icons.calendar_month),
                        style: IconButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              const Text('สรุปยอดเงิน (อัปเดตอัตโนมัติ)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildStatCard('วันนี้', _todayTotal.toStringAsFixed(2))),
                  const SizedBox(width: 16),
                  Expanded(child: _buildStatCard('สัปดาห์นี้', _weekTotal.toStringAsFixed(2))),
                ],
              ),
              const SizedBox(height: 16),
              _buildStatCard('เดือนนี้', _monthTotal.toStringAsFixed(2), isLarge: true),
           ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String amount, {bool isLarge = false}) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(isLarge ? 24.0 : 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 8),
            Text(
              amount,
              style: TextStyle(
                fontSize: isLarge ? 28 : 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            const Text('บาท', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
