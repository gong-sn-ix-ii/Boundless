import 'package:flutter/material.dart';
import 'pages/feed_page.dart';
import 'pages/auction_page.dart';
import 'pages/profile_page.dart';
import 'dart:async';



class MainPage extends StatefulWidget {
  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    // เริ่มต้น Agora หรือการตั้งค่าอื่น ๆ ที่จำเป็นที่นี่
    initForAgora();
  }
  
  Future<void> initForAgora() async {
    // เรียกใช้ฟังก์ชันที่จำเป็นสำหรับ Agora ที่นี่
    // เช่น การเชื่อมต่อกับ Agora SDK หรือการตั้งค่าอื่น ๆ
  }

  final List<Widget> _pages = [
    FeedPage(),
    AuctionPage(),
    ProfilePage(),
    //Chat(), // Assuming you have a Chat page
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black,
        selectedItemColor: Color(0xFFF3B716),
        unselectedItemColor: Colors.white70,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.gavel), label: 'Auction'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
