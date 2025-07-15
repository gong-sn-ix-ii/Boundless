import 'package:boundless/Services/Service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import 'package:boundless/CreatePostPage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../MessagesPage.dart';
import '../components/PostCard.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  _FeedPageState createState() => _FeedPageState();
}


class _FeedPageState extends State<FeedPage> {
  // ดึง UID ของผู้ใช้ปัจจุบันมาเก็บไว้
  final String? _currentUserUid = FirebaseAuth.instance.currentUser?.uid;
  final ScrollController _scrollController = ScrollController();

  // --- State สำหรับจัดการ Pagination ---
  bool _isLoading = false;
  bool _hasMoreData = true;
  List<DocumentSnapshot> _postDocs = [];
  DocumentSnapshot? _lastDocument;
  List<String> _hiddenPostIds = [];
  final int _initialLimit = 2; // โหลดครั้งแรก 6 โพสต์
  final int _nextLimit = 3;    // โหลดครั้งถัดไป 3 โพสต์

@override
  void initState() {
    super.initState();
    _fetchInitialData();

    // เพิ่ม Listener ให้กับ ScrollController
    _scrollController.addListener(() {
      // ตรวจสอบว่าเลื่อนถึงท้ายสุดของหน้าจอหรือไม่
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
          !_isLoading &&
          _hasMoreData) {
        _fetchMorePosts();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    if (_currentUserUid == null) return;
    setState(() => _isLoading = true);

    try {
      // 1. ดึงรายการโพสต์ที่ถูกซ่อนก่อน
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUserUid).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>?;
        _hiddenPostIds = List<String>.from(userData?['hiddenPosts'] ?? []);
      }

      // 2. ดึงโพสต์ชุดแรก
      QuerySnapshot postSnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .orderBy('timestamp', descending: true)
          .limit(_initialLimit)
          .get();

      final fetchedDocs = postSnapshot.docs;

      // กรองโพสต์ที่ซ่อนไว้ออก
      final visibleDocs = fetchedDocs.where((post) => !_hiddenPostIds.contains(post.id)).toList();

      if (mounted) {
        setState(() {
          _postDocs = visibleDocs;
          if (fetchedDocs.isNotEmpty) {
            _lastDocument = fetchedDocs.last;
          }
          _isLoading = false;
          // ถ้าจำนวนที่ดึงมาได้น้อยกว่าที่ขอไป แสดงว่าไม่มีข้อมูลเพิ่มแล้ว
          _hasMoreData = fetchedDocs.length == _initialLimit;
        });
      }
    } catch (e) {
      print("Error fetching initial data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchMorePosts() async {
    if (_isLoading || !_hasMoreData) return;
    setState(() => _isLoading = true);

    try {
      QuerySnapshot postSnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .orderBy('timestamp', descending: true)
          .startAfterDocument(_lastDocument!) // เริ่มดึงต่อจากเอกสารตัวสุดท้าย
          .limit(_nextLimit)
          .get();

      final fetchedDocs = postSnapshot.docs;
      final visibleDocs = fetchedDocs.where((post) => !_hiddenPostIds.contains(post.id)).toList();

      if (mounted) {
        setState(() {
          _postDocs.addAll(visibleDocs);
          if (fetchedDocs.isNotEmpty) {
            _lastDocument = fetchedDocs.last;
          }
          _isLoading = false;
          _hasMoreData = fetchedDocs.length == _nextLimit;
        });
      }
    } catch (e) {
      print("Error fetching more posts: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width; // ดึงความกว้างหน้าจอ
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          'Boundless',
          style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold,fontSize: screenWidth * 0.05, ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.chat_bubble_outline, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => MessagesPage()),
              );
            },
          ),
        ],
      ),
      // --- ส่วน Body ที่แก้ไขใหม่โดยใช้ Nested StreamBuilder ---
      body: _currentUserUid == null
          ? const Center(child: Text("Please log in...", style: TextStyle(color: Colors.white)))
          : RefreshIndicator(
        color: Colors.black,
        backgroundColor: Colors.yellow,
        onRefresh: _fetchInitialData, // ดึงข้อมูลใหม่เมื่อผู้ใช้ลากจอลง
        child: ListView.builder(
          controller: _scrollController,
          itemCount: _postDocs.length + (_hasMoreData ? 1 : 0), // +1 สำหรับ Loading Indicator
          itemBuilder: (context, index) {
            // ถ้าเป็น item สุดท้าย และยังมีข้อมูลเพิ่ม ให้แสดง Loading Indicator
            if (index == _postDocs.length) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator(color: Colors.yellow,)),
              );
            }

            final postDoc = _postDocs[index];
            return PostCard(
              key: ValueKey(postDoc.id),
              postSnapshot: postDoc,
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFF3B716),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => CreatePostPage()));
          // TODO: เพิ่มฟังก์ชันสำหรับสร้างโพสต์ใหม่
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

// // หน้าแชทจำลอง
// class ChatPage extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     final screenWidth = MediaQuery.of(context).size.width;
//     return Scaffold(
//       appBar: AppBar(
//         title: Text(
//           'Chats',
//           style: TextStyle(
//             color: Colors.yellow,
//             fontWeight: FontWeight.bold,
//             fontSize: screenWidth * 0.05,
//           ),
//         ),
//         backgroundColor: Colors.black,
//         leading: IconButton(
//           icon: Icon(Icons.arrow_back, color: Colors.white),
//           onPressed: () {
//             Navigator.pop(context);
//           },
//         ),
//       ),
//       body: Center(
//         child: Text(
//           'หน้านี้สำหรับแชท (ยังไม่เชื่อมระบบจริง)',
//           style: TextStyle(
//             color: Colors.white,
//             fontSize: screenWidth * 0.04,
//           ),
//           textAlign: TextAlign.center,
//         ),
//       ),
//     );
//   }
// }
