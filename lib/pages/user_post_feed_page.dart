// lib/pages/user_post_feed_page.dart

import 'package:boundless/components/PostCard.dart';
import 'package:boundless/pages/profile_page.dart'; // ✅ 1. เพิ่ม Import สำหรับ ProfilePage
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class UserPostFeedPage extends StatefulWidget {
  final String userId;
  final String userName;
  final String initialPostId;

  const UserPostFeedPage({
    super.key,
    required this.userId,
    required this.userName,
    required this.initialPostId,
  });

  @override
  State<UserPostFeedPage> createState() => _UserPostFeedPageState();
}

class _UserPostFeedPageState extends State<UserPostFeedPage> {
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = false;
  bool _hasMoreData = true;
  List<DocumentSnapshot> _postDocs = [];
  DocumentSnapshot? _lastDocument;
  final int _limit = 5;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200 &&
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

  // ✅ 2. แก้ไขฟังก์ชันดึงข้อมูลให้ถูกต้องตามข้อจำกัดของ Firestore
  Future<void> _fetchInitialData() async {
    setState(() => _isLoading = true);
    try {
      // ดึงโพสต์ทั้งหมดของผู้ใช้มาเลย
      final querySnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .where('ownerUid', isEqualTo: widget.userId)
          .orderBy('timestamp', descending: true)
          .limit(_limit)
          .get();

      List<DocumentSnapshot> fetchedDocs = querySnapshot.docs;

      // หาโพสต์ที่ผู้ใช้กดเข้ามา
      final initialPostIndex = fetchedDocs.indexWhere((doc) => doc.id == widget.initialPostId);

      // ถ้าเจอ ให้ย้ายไปไว้บนสุดของ List
      if (initialPostIndex != -1) {
        final initialPostDoc = fetchedDocs.removeAt(initialPostIndex);
        fetchedDocs.insert(0, initialPostDoc);
      } else {
        // ถ้าไม่เจอ (อาจจะอยู่นอก limit แรก) ให้ดึงมาต่างหากแล้วแทรกเข้าไป
        final initialPostDoc = await FirebaseFirestore.instance
            .collection('posts').doc(widget.initialPostId).get();
        if(initialPostDoc.exists) {
          fetchedDocs.insert(0, initialPostDoc);
        }
      }

      if (mounted) {
        setState(() {
          _postDocs = fetchedDocs;
          if (fetchedDocs.isNotEmpty) {
            _lastDocument = fetchedDocs.last;
          }
          _isLoading = false;
          _hasMoreData = querySnapshot.docs.length == _limit;
        });
      }
    } catch (e) {
      print("Error fetching initial user posts: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchMorePosts() async {
    if (_isLoading || !_hasMoreData) return;
    setState(() => _isLoading = true);

    try {
      Query postQuery = FirebaseFirestore.instance
          .collection('posts')
          .where('ownerUid', isEqualTo: widget.userId)
          .orderBy('timestamp', descending: true)
          .startAfterDocument(_lastDocument!)
          .limit(_limit);

      final postSnapshot = await postQuery.get();
      final fetchedDocs = postSnapshot.docs;

      if (mounted) {
        setState(() {
          _postDocs.addAll(fetchedDocs);
          if (fetchedDocs.isNotEmpty) {
            _lastDocument = fetchedDocs.last;
          }
          _isLoading = false;
          _hasMoreData = fetchedDocs.length == _limit;
        });
      }
    } catch (e) {
      print("Error fetching more user posts: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ✅ 3. เพิ่มฟังก์ชันสำหรับนำทางไปหน้าโปรไฟล์ (เมื่อกดจาก PostCard ในหน้านี้)
  void _navigateToUserProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfilePage(userId: userId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          "${widget.userName}'s Posts",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: RefreshIndicator(
        color: Colors.black,
        backgroundColor: Colors.yellow,
        onRefresh: _fetchInitialData,
        child: (_postDocs.isEmpty && !_isLoading)
            ? const Center(
            child: Text("ผู้ใช้คนนี้ยังไม่มีโพสต์", style: TextStyle(color: Colors.white70)))
            : ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          controller: _scrollController,
          itemCount: _postDocs.length + (_hasMoreData ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == _postDocs.length) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(
                    child: CircularProgressIndicator(color: Colors.yellow)),
              );
            }

            final postDoc = _postDocs[index];
            return PostCard(
              key: ValueKey(postDoc.id),
              postSnapshot: postDoc,
              // ✅ 4. ส่งฟังก์ชันที่สร้างขึ้นใหม่ให้กับ PostCard
              onProfileTapped: _navigateToUserProfile,
              onDelete: () {
                if (mounted) {
                  setState(() {
                    _postDocs.removeAt(index);
                  });
                }
              },
            );
          },
        ),
      ),
    );
  }
}