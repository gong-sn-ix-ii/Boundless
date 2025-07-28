// lib/HomePage.dart

import 'package:flutter/material.dart';
import 'pages/feed_page.dart';
import 'pages/auction_page.dart';
import 'pages/profile_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  // รายการของหน้าต่างๆ ยังคงเหมือนเดิม
  final List<Widget> _pages = [
    const FeedPage(),
    const AuctionPage(),
    ProfilePage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ✅ ใช้ IndexedStack เพื่อแสดงผลหน้าที่เลือกและเก็บหน้าอื่นไว้ใน state
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black,
        selectedItemColor: Colors.yellow,
        unselectedItemColor: Colors.white70,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        // เพิ่ม type: BottomNavigationBarType.fixed เพื่อให้พื้นหลังแสดงสีที่กำหนด
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.gavel), label: 'Auction'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}