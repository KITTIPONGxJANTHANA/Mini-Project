import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class AdminHistoryTab extends StatefulWidget {
  final int shopId;
  const AdminHistoryTab({super.key, required this.shopId});

  @override
  State<AdminHistoryTab> createState() => _AdminHistoryTabState();
}

class _AdminHistoryTabState extends State<AdminHistoryTab> {
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);
    try {
      final startOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final response = await Supabase.instance.client
          .from('transactions')
          .select()
          .eq('shop_id', widget.shopId)
          .gte('datetime', startOfDay.toIso8601String())
          .lt('datetime', endOfDay.toIso8601String())
          .order('datetime', ascending: false);

      if (!mounted) return;
      setState(() {
        _history = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      print("Error fetching history: $e");
      if (mounted) setState(() => _isLoading = false);
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
      await _fetchHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ประวัติรายการตรวจสอบ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () => _selectDate(context),
            tooltip: 'เลือกวันที่',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            width: double.infinity,
            child: Text(
              'ประวัติของวันที่ ${DateFormat('dd MMM yyyy').format(_selectedDate)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _history.isEmpty
                    ? const Center(child: Text('ไม่พบประวัติการตรวจสอบสลิปในวันนี้', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: _history.length,
                        itemBuilder: (context, index) {
                          final item = _history[index];
                          final isValid = item['status'] == 'valid' || item['status'] == 'SUCCESS';
                          
                          final dt = DateTime.parse(item['datetime']).toLocal();
                          final formattedTime = DateFormat('HH:mm').format(dt);
                          final amount = (item['amount'] as num).toDouble();

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12.0),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16.0),
                              leading: CircleAvatar(
                                backgroundColor: isValid 
                                    ? Colors.green.withOpacity(0.2) 
                                    : Colors.red.withOpacity(0.2),
                                child: Icon(
                                  isValid ? Icons.check : Icons.close,
                                  color: isValid ? Colors.green : Colors.red,
                                ),
                              ),
                              title: Text(
                                '${amount.toStringAsFixed(2)} บาท',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text('เวลา $formattedTime'),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    isValid ? 'ถูกต้อง' : 'ไม่ถูกต้อง',
                                    style: TextStyle(
                                      color: isValid ? Colors.green : Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
