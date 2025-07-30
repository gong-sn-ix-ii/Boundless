// lib/HomePage.dart

import 'package:flutter/material.dart';
import 'CreateAuctionPage.dart';
import 'CreatePostPage.dart';
import 'MessagesPage.dart';
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
  String? _viewingUserId;
  final GlobalKey<FeedPageState> _feedPageKey = GlobalKey<FeedPageState>();

  void _navigateToUserProfile(String userId) {
    setState(() {
      _viewingUserId = userId;
      _selectedIndex = 2;
    });
  }

  // ✅ แก้ไขฟังก์ชันนี้
  void _onItemTapped(int index) {
    // หากกดที่ Tab Home ซ้ำ จะทำการรีเฟรชข้อมูล
    if (_selectedIndex == index && index == 0) {
      _feedPageKey.currentState?.fetchInitialData();
    }

    setState(() {
      // ถ้าปัจจุบันอยู่ที่หน้า Profile (index 2) และกำลังจะสลับไปหน้าอื่น (index != 2)
      if (_selectedIndex == 2 && index != 2) {
        // ให้รีเซ็ต ID โปรไฟล์ที่ดูกลับเป็นของตัวเอง
        _viewingUserId = null;
      }
      _selectedIndex = index;
    });
  }

  AppBar? _buildAppBar(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    switch (_selectedIndex) {
      case 0: // FeedPage
        return AppBar(
          backgroundColor: Colors.black,
          title: Text(
            'Boundless',
            style: TextStyle(
                color: Colors.yellow,
                fontWeight: FontWeight.bold,
                fontSize: screenWidth * 0.05),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const MessagesPage()));
              },
            ),
          ],
        );
      case 1: // AuctionPage
        return AppBar(
          backgroundColor: Colors.black,
          title: Text(
            'Boundless',
            style: TextStyle(
                color: Colors.yellow,
                fontWeight: FontWeight.bold,
                fontSize: screenWidth * 0.05),
          ),
        );
      case 2: // ProfilePage
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      FeedPage(
          key: _feedPageKey,
          onProfileTapped: _navigateToUserProfile
      ),
      AuctionPage(),
      ProfilePage(
        key: ValueKey(_viewingUserId),
        userId: _viewingUserId,
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _buildAppBar(context),
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black,
        selectedItemColor: Colors.yellow,
        unselectedItemColor: Colors.white70,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.gavel), label: 'Auction'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
        backgroundColor: const Color(0xFFF3B716),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30)),
        onPressed: () {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const CreatePostPage()));
        },
        child: const Icon(Icons.add),
      )
          : _selectedIndex == 1
          ? FloatingActionButton(
        backgroundColor: const Color(0xFFF3B716),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30)),
        onPressed: () {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const CreateAuctionPage()));
        },
        child: const Icon(Icons.add),
      )
          : null,
    );
  }
}