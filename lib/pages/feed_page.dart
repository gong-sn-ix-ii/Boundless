// lib/pages/feed_page.dart

import 'package:flutter/material.dart';
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
  // --- State and controllers ---
  final String? _currentUserUid = FirebaseAuth.instance.currentUser?.uid;
  final ScrollController _scrollController = ScrollController();

  // --- Pagination State ---
  bool _isLoading = false;
  bool _hasMoreData = true;
  List<DocumentSnapshot> _postDocs = [];
  DocumentSnapshot? _lastDocument;
  List<String> _hiddenPostIds = [];
  final int _initialLimit = 5;
  final int _nextLimit = 3;

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

  Future<void> _fetchInitialData() async {
    if (_currentUserUid == null) return;
    setState(() => _isLoading = true);

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUserUid).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>?;
        _hiddenPostIds = List<String>.from(userData?['hiddenPosts'] ?? []);
      }

      Query postQuery = FirebaseFirestore.instance
          .collection('posts')
          .orderBy('timestamp', descending: true);

      // Note: whereNotIn is limited to 10 items. For more, client-side filtering is needed.
      if (_hiddenPostIds.isNotEmpty) {
        postQuery = postQuery.where(FieldPath.documentId, whereNotIn: _hiddenPostIds);
      }

      QuerySnapshot postSnapshot = await postQuery.limit(_initialLimit).get();

      final fetchedDocs = postSnapshot.docs;

      if (mounted) {
        setState(() {
          _postDocs = fetchedDocs; // The query already filters hidden posts
          if (fetchedDocs.isNotEmpty) {
            _lastDocument = fetchedDocs.last;
          }
          _isLoading = false;
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
      Query postQuery = FirebaseFirestore.instance
          .collection('posts')
          .orderBy('timestamp', descending: true)
          .startAfterDocument(_lastDocument!);

      if (_hiddenPostIds.isNotEmpty) {
        postQuery = postQuery.where(FieldPath.documentId, whereNotIn: _hiddenPostIds);
      }

      QuerySnapshot postSnapshot = await postQuery.limit(_nextLimit).get();

      final fetchedDocs = postSnapshot.docs;

      if (mounted) {
        setState(() {
          _postDocs.addAll(fetchedDocs);
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
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          'Boundless',
          style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold, fontSize: screenWidth * 0.05),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MessagesPage()),
              );
            },
          ),
        ],
      ),
      body: _currentUserUid == null
          ? const Center(child: Text("Please log in...", style: TextStyle(color: Colors.white)))
          : RefreshIndicator(
        color: Colors.black,
        backgroundColor: Colors.yellow,
        onRefresh: _fetchInitialData,
        child: (_postDocs.isEmpty && !_isLoading)
            ? Center( // ✅ UI พิเศษเมื่อไม่มีโพสต์
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.explore_off_outlined, color: Colors.grey.shade700, size: 80),
              const SizedBox(height: 16),
              Text(
                "ยังไม่มีเรื่องราวใหม่",
                style: TextStyle(fontSize: 20, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                "สร้างโพสต์แรกของคุณ หรือรอการอัปเดตจากเพื่อนๆ",
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        )
            : ListView.builder( // ✅ UI ปกติเมื่อมีโพสต์
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
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFF3B716),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreatePostPage()),
          );
          if (result == true) {
            _fetchInitialData();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}