// lib/pages/messages_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import 'Chat.dart';
import 'SearchUsersPage.dart';
import 'Services/Service.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  // เก็บ instance ของ Service ไว้ที่นี่ที่เดียว
  final FirestoreService _firestoreService = FirestoreService();

  // ฟังก์ชันสำหรับตัดข้อความ
  String truncateText(String text, int maxLength) {
    if (text.length <= maxLength) {
      return text;
    }
    return '${text.substring(0, maxLength)}...';
  }

  @override
  Widget build(BuildContext context) {
    // ใช้ตัวแปรนี้ที่เดียวใน build method
    final String? _currentUID = FirebaseAuth.instance.currentUser?.uid;

    if (_currentUID == null) {
      return const Scaffold(
        body: Center(child: Text("กำลังโหลดข้อมูลผู้ใช้... หรือกรุณาล็อกอิน")),
      );
    }
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: Colors.black,
        title: const Padding(
          padding: EdgeInsets.only(left: 0),
          child: Text(
            'Boundless Messages',
            style: TextStyle(
              fontSize: 20,
              color: Color(0xFFF3B716),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SearchUsersPage()),
          );
        },
        backgroundColor: Color(0xFFF3B716),
        child: const Icon(Icons.add, color: Colors.black, size: 30),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("chats")
                  .where('activeFor', arrayContains: _currentUID)
                  .orderBy('lastMessage.timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      "ยังไม่มีแชท\nกดปุ่ม + เพื่อเริ่มคุยกับเพื่อน",
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final chatDoc = snapshot.data!.docs[index];
                    final data = chatDoc.data() as Map<String, dynamic>;
                    final String otherUserID =
                        (data['participants'] as List<dynamic>).firstWhere(
                          (id) => id != _currentUID,
                          orElse: () => '',
                        );

                    if (otherUserID.isEmpty) return const SizedBox.shrink();

                    // 1. --- ปรับ FutureBuilder ให้ใช้ UserModel ---
                    return FutureBuilder<UserModel>(
                      future: _firestoreService.getUserProfile(otherUserID),
                      builder: (context, userSnapshot) {
                        final String lastMessage =
                            data['lastMessage']?['content'] ?? '...';

                        if (userSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Container(
                            height: 70,
                            child: const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          );
                        }
                        if (userSnapshot.hasError || !userSnapshot.hasData) {
                          return ListTile(
                            title: Text("Unknown User"),
                            subtitle: Text(lastMessage),
                          );
                        }

                        // 2. --- เข้าถึงข้อมูลจาก Model โดยตรง ---
                        final UserModel otherUser = userSnapshot.data!;
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12.0,
                            vertical: 6.0,
                          ), // <-- เพิ่มระยะห่าง
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Colors.grey[900],
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            onPressed: () {
                              final String chatRoomID = _firestoreService
                                  .getChatRoomId(_currentUID, otherUserID);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      Chat(chatRoomID: chatRoomID),
                                ),
                              );
                            },
                            child: Container(
                              height: 70,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundImage:
                                        otherUser.profileURL.isNotEmpty
                                        ? NetworkImage(otherUser.profileURL)
                                        : null,
                                    child: otherUser.profileURL.isEmpty
                                        ? const Icon(Icons.person)
                                        : null,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          otherUser.displayName,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          truncateText(lastMessage, 25),
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.white70,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
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
