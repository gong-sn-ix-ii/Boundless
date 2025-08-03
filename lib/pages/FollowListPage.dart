// lib/pages/follow_list_page.dart

import 'package:boundless/models/user_model.dart';
import 'package:boundless/pages/profile_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// Enum เพื่อระบุประเภทของ List ที่จะแสดง
enum FollowListType { followers, following }

class FollowListPage extends StatefulWidget {
  final String userId;
  final FollowListType listType;
  final String title;

  const FollowListPage({
    super.key,
    required this.userId,
    required this.listType,
    required this.title,
  });

  @override
  State<FollowListPage> createState() => _FollowListPageState();
}

class _FollowListPageState extends State<FollowListPage> {
  final String? _currentUserUid = FirebaseAuth.instance.currentUser?.uid;
  bool _isLoading = true;

  List<UserModel> _masterUserList = []; // List หลักที่เก็บ User ทุกคน
  List<UserModel> _filteredUserList = []; // List ที่ผ่านการกรองจากการค้นหา
  List<String> _myFollowingList = []; // List คนที่เรากำลังติดตามอยู่

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchData();
    _searchController.addListener(_filterList);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // 1. ดึงข้อมูลว่าปัจจุบันเรา Following ใครอยู่บ้าง (สำหรับแสดงผลปุ่ม)
      if (_currentUserUid != null) {
        final currentUserDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUserUid).get();
        if (currentUserDoc.exists) {
          _myFollowingList = List<String>.from(currentUserDoc.data()?['following'] ?? []);
        }
      }

      // 2. ดึง List ของ UID จากหน้า Profile ที่เรากดเข้ามา
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
      if (!userDoc.exists) {
        setState(() => _isLoading = false);
        return;
      }
      final String fieldToFetch = widget.listType == FollowListType.followers ? 'followers' : 'following';
      final List<String> userIds = List<String>.from(userDoc.data()?[fieldToFetch] ?? []);

      if (userIds.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      // 3. ดึงข้อมูลโปรไฟล์ทั้งหมดของผู้ใช้ใน List นั้นๆ ทีเดียว
      List<UserModel> fetchedUsers = [];
      final userSnapshots = await FirebaseFirestore.instance.collection('users').where(FieldPath.documentId, whereIn: userIds).get();
      for (var doc in userSnapshots.docs) {
        fetchedUsers.add(UserModel.fromFirestore(doc));
      }

      if (mounted) {
        setState(() {
          _masterUserList = fetchedUsers;
          _filteredUserList = fetchedUsers;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching follow list data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterList() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredUserList = _masterUserList;
      } else {
        _filteredUserList = _masterUserList
            .where((user) => user.displayName.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  // --- ฟังก์ชันสำหรับจัดการปุ่ม ---

  Future<void> _handleFollowUnfollow(String targetUserId, bool isCurrentlyFollowing) async {
    if (_currentUserUid == null) return;

    final targetUserRef = FirebaseFirestore.instance.collection('users').doc(targetUserId);
    final currentUserRef = FirebaseFirestore.instance.collection('users').doc(_currentUserUid);
    WriteBatch batch = FirebaseFirestore.instance.batch();

    if (isCurrentlyFollowing) { // Unfollow
      batch.update(targetUserRef, { 'followers': FieldValue.arrayRemove([_currentUserUid]) });
      batch.update(currentUserRef, { 'following': FieldValue.arrayRemove([targetUserId]) });
      setState(() => _myFollowingList.remove(targetUserId));
    } else { // Follow
      batch.update(targetUserRef, { 'followers': FieldValue.arrayUnion([_currentUserUid]) });
      batch.update(currentUserRef, { 'following': FieldValue.arrayUnion([targetUserId]) });
      setState(() => _myFollowingList.add(targetUserId));
    }
    await batch.commit();
  }

  Future<void> _handleRemoveFollower(String targetUserId) async {
    if (_currentUserUid == null) return;

    final targetUserRef = FirebaseFirestore.instance.collection('users').doc(targetUserId);
    final currentUserRef = FirebaseFirestore.instance.collection('users').doc(_currentUserUid);
    WriteBatch batch = FirebaseFirestore.instance.batch();

    // ลบเราออกจาก Following list ของเขา และลบเขาออกจาก Followers list ของเรา
    batch.update(targetUserRef, { 'following': FieldValue.arrayRemove([_currentUserUid]) });
    batch.update(currentUserRef, { 'followers': FieldValue.arrayRemove([targetUserId]) });

    await batch.commit();

    // Refresh UI
    setState(() {
      _masterUserList.removeWhere((user) => user.uid == targetUserId);
      _filterList();
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(widget.title, style: const TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'ค้นหา...',
                hintStyle: TextStyle(color: Colors.grey.shade600),
                prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
                filled: true,
                fillColor: Colors.grey.shade900,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.yellow))
                : _filteredUserList.isEmpty
                ? Center(child: Text("ไม่พบรายชื่อ", style: TextStyle(color: Colors.grey.shade500)))
                : ListView.builder(
              itemCount: _filteredUserList.length,
              itemBuilder: (context, index) {
                final user = _filteredUserList[index];
                return _buildUserTile(user);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(UserModel user) {
    return ListTile(
      leading: CircleAvatar(
        radius: 25,
        backgroundImage: user.profileURL.isNotEmpty ? NetworkImage(user.profileURL) : null,
        child: user.profileURL.isEmpty ? const Icon(Icons.person) : null,
      ),
      title: Text(user.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      onTap: () {
        // กดที่ชื่อหรือรูป ให้ไปที่หน้า Profile ของคนนั้น
        Navigator.push(context, MaterialPageRoute(builder: (context) => ProfilePage(userId: user.uid)));
      },
      trailing: _buildActionButton(user),
    );
  }

  Widget _buildActionButton(UserModel user) {
    // ไม่แสดงปุ่มใดๆ ถ้าเป็นโปรไฟล์ของตัวเอง
    if (user.uid == _currentUserUid) {
      return const SizedBox.shrink();
    }

    // กรณี: เรากำลังดู List "Followers" ของ "ตัวเอง"
    if (widget.listType == FollowListType.followers && widget.userId == _currentUserUid) {
      return ElevatedButton(
        onPressed: () => _handleRemoveFollower(user.uid),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade800),
        child: const Text("ลบออก", style: TextStyle(color: Colors.white)),
      );
    }

    // กรณีอื่นๆ ทั้งหมด (ดู Following list ของตัวเอง, ดู Followers/Following ของคนอื่น)
    final bool isFollowing = _myFollowingList.contains(user.uid);
    return ElevatedButton(
      onPressed: () => _handleFollowUnfollow(user.uid, isFollowing),
      style: ElevatedButton.styleFrom(
        backgroundColor: isFollowing ? Colors.black : Colors.yellow.shade700,
        foregroundColor: isFollowing ? Colors.white : Colors.black,
        side: isFollowing ? BorderSide(color: Colors.grey.shade700) : null,
      ),
      child: Text(isFollowing ? "กำลังติดตาม" : "ติดตาม"),
    );
  }
}