// lib/pages/search_users_page.dart
import 'dart:async';
import 'package:boundless/Chat.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import 'Services/Service.dart';
class SearchUsersPage extends StatefulWidget {
  const SearchUsersPage({super.key});

  @override
  State<SearchUsersPage> createState() => _SearchUsersPageState();
}

class _SearchUsersPageState extends State<SearchUsersPage> {
  final TextEditingController _searchController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();
  final String _myUID = FirebaseAuth.instance.currentUser!.uid;

  // 1. เปลี่ยนมาใช้ List<UserModel>
  List<UserModel> _searchResults = [];
  bool _isLoading = false;

  // 2. เพิ่ม Debounce Timer
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel(); // ยกเลิก Timer เมื่อปิดหน้า
    super.dispose();
  }

  // 3. ฟังก์ชันค้นหาที่เรียกใช้ Service
  void _searchUsers(String searchQuery) async {
    setState(() {
      _isLoading = true;
    });

    // เรียกใช้ฟังก์ชันจาก Service ที่เราสร้างไว้
    final users = await _firestoreService.searchUsers(searchQuery, _myUID);

    if (mounted) {
      setState(() {
        _searchResults = users;
        _isLoading = false;
      });
    }
  }


  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _searchUsers(query);
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("ค้นหาและเริ่มแชท"),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'พิมพ์ชื่อเพื่อน...',
                suffixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12.0)),
                ),
              ),
              onChanged: _onSearchChanged, // เรียกใช้ฟังก์ชัน Debounce
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _searchResults.isEmpty && _searchController.text.isNotEmpty
                ? const Center(child: Text("ไม่พบผู้ใช้"))
                : ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                // 5. ใช้ข้อมูลจาก UserModel โดยตรง
                final UserModel otherUser = _searchResults[index];

                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: otherUser.profileURL.isNotEmpty ? NetworkImage(otherUser.profileURL) : null,
                    child: otherUser.profileURL.isEmpty ? const Icon(Icons.person) : null,
                  ),
                  title: Text(otherUser.displayName),
                  onTap: () async {
                    try {
                      final chatRoomId = _firestoreService.getChatRoomId(_myUID, otherUser.uid);

                      // --- แก้ไขข้อมูลที่จะสร้าง ---
                      final chatData = {
                        'participants': [_myUID, otherUser.uid],
                        'activeFor': [_myUID], // <--- จุดสำคัญ: ใส่แค่ UID ของเรา (ผู้เริ่ม)
                        'lastMessage': {
                          'content': '',
                          'senderUID': _myUID, // อาจจะใส่ UID ของเราไว้เลย
                          'timestamp': FieldValue.serverTimestamp(),
                          'type': 'system', // อาจจะเปลี่ยน type เป็น system หรือ text ก็ได้
                        }
                      };

                      await FirebaseFirestore.instance
                          .collection('chats')
                          .doc(chatRoomId)
                          .set(chatData, SetOptions(merge: true));

                      // ... ส่วนของ Navigator เหมือนเดิม ...
                      if (!context.mounted) return;
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => Chat(chatRoomID: chatRoomId),
                        ),
                      );

                    } catch (e) {
                      print("Error creating chat room: $e");
                    }
                  },

                );
              },
            ),
          ),
        ],
      ),
    );
  }
}