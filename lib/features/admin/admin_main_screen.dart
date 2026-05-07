import 'package:flutter/material.dart';
import 'admin_dashboard_tab.dart';
import 'admin_history_tab.dart';
import '../auth/role_selection_screen.dart'; // import สำหรับ logout หรือ profile

class AdminMainScreen extends StatefulWidget {
  final int shopId;
  const AdminMainScreen({super.key, required this.shopId});

  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  int _currentIndex = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      AdminDashboardTab(shopId: widget.shopId),
      AdminHistoryTab(shopId: widget.shopId),
      // สร้าง Profile Tab จำลองในตัวแปรนี้เลย
      const Center(child: Text('Profile Page', style: TextStyle(color: Colors.grey))),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == 2) {
             // ตัวอย่างให้ Profile เป็นปุ่ม Logout ไปก่อน
             Navigator.of(context).pushReplacement(
               MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
             );
             return;
          }
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: Theme.of(context).cardColor,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
