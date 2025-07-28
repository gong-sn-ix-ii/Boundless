// lib/pages/user_post_feed_page.dart

import 'package:boundless/components/PostCard.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class UserPostFeedPage extends StatefulWidget {
  final String userId;
  final String userName;
  final String initialPostId; // 🔽 1. เปลี่ยนเป็น initialPostId

  const UserPostFeedPage({
    super.key,
    required this.userId,
    required this.userName,
    required this.initialPostId,
  });

  @override
  State<UserPostFeedPage> createState() => _UserPostFeedPageState();
}

// 🔽 2. นำ State Management จาก FeedPage มาปรับใช้
class _UserPostFeedPageState extends State<UserPostFeedPage> {
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = false;
  bool _hasMoreData = true;
  List<DocumentSnapshot> _postDocs = [];
  DocumentSnapshot? _lastDocument;
  final int _limit = 5; // จำนวนโพสต์ที่จะโหลดในแต่ละครั้ง

  @override
  void initState() {
    super.initState();
    _fetchInitialData();

    _scrollController.addListener(() {
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

  // 🔽 3. สร้างฟังก์ชันโหลดข้อมูลชุดแรกที่ซับซ้อนขึ้น
  Future<void> _fetchInitialData() async {
    setState(() => _isLoading = true);

    try {
      // --- Step 1: ดึงโพสต์ที่ผู้ใช้กดมาโดยเฉพาะ ---
      final initialPostDoc = await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.initialPostId)
          .get();

      List<DocumentSnapshot> fetchedDocs = [];
      if (initialPostDoc.exists) {
        fetchedDocs.add(initialPostDoc);
      }

      // --- Step 2: ดึงโพสต์ที่เหลือของผู้ใช้คนนั้น โดยไม่เอาโพสต์แรกซ้ำ ---
      Query restOfPostsQuery = FirebaseFirestore.instance
          .collection('posts')
          .where('ownerUid', isEqualTo: widget.userId)
          .where(FieldPath.documentId, isNotEqualTo: widget.initialPostId) // ไม่เอาโพสต์แรกซ้ำ
          .orderBy('timestamp', descending: true)
          .limit(_limit);

      final restOfPostsSnapshot = await restOfPostsQuery.get();
      fetchedDocs.addAll(restOfPostsSnapshot.docs);

      if (mounted) {
        setState(() {
          _postDocs = fetchedDocs;
          if (restOfPostsSnapshot.docs.isNotEmpty) {
            _lastDocument = restOfPostsSnapshot.docs.last;
          }
          _isLoading = false;
          _hasMoreData = restOfPostsSnapshot.docs.length == _limit;
        });
      }

    } catch (e) {
      print("Error fetching initial user posts: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🔽 4. สร้างฟังก์ชันสำหรับโหลดข้อมูลเพิ่ม (Infinite Scroll)
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
      if(mounted) setState(() => _isLoading = false);
    }
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
      // 🔽 5. ใช้ UI แบบเดียวกับ FeedPage
      body: RefreshIndicator(
        color: Colors.black,
        backgroundColor: Colors.yellow,
        onRefresh: _fetchInitialData,
        child: (_postDocs.isEmpty && !_isLoading)
            ? const Center(child: Text("ผู้ใช้คนนี้ยังไม่มีโพสต์", style: TextStyle(color: Colors.white70)))
            : ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          controller: _scrollController,
          itemCount: _postDocs.length + (_hasMoreData ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == _postDocs.length) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator(color: Colors.yellow)),
              );
            }

            final postDoc = _postDocs[index];
            return PostCard(
              key: ValueKey(postDoc.id),
              postSnapshot: postDoc,
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
