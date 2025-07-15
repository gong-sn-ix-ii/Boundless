// lib/pages/chat_page.dart
//
// import 'dart:io';
// import 'package:chat_bubbles/chat_bubbles.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:firebase_storage/firebase_storage.dart';
// import '../models/user_model.dart';
// import 'Services/Service.dart';
//
// class Chat extends StatefulWidget {
//   // 1. --- เปลี่ยนเป็น non-nullable เพื่อความปลอดภัย ---
//   final String chatRoomID;
//   const Chat({super.key, required this.chatRoomID});
//
//   @override
//   State<Chat> createState() => _ChatState();
// }
//
// class _ChatState extends State<Chat> {
//   final ScrollController _scrollController = ScrollController();
//   final User? _currentUser = FirebaseAuth.instance.currentUser;
//   final FirestoreService _firestoreService = FirestoreService();
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//
//   // 2. --- เปลี่ยนมาใช้ UserModel ตัวเดียวในการเก็บข้อมูล partner ---
//   UserModel? _partner;
//
//   @override
//   void initState() {
//     super.initState();
//     _loadPartnerInfo();
//   }
//
//   @override
//   void dispose() {
//     _scrollController.dispose();
//     super.dispose();
//   }
//
//   Future<void> _loadPartnerInfo() async {
//     // ป้องกันการทำงานถ้าผู้ใช้หรือ chatRoomID เป็น null
//     if (_currentUser == null || widget.chatRoomID.isEmpty) return;
//
//     try {
//       final List<String> uids = widget.chatRoomID.split('@');
//       // 3. --- แก้ไขการเปรียบเทียบ UID ให้ถูกต้อง ---
//       final String partnerUid = uids.firstWhere((uid) => uid != _currentUser!.uid, orElse: () => '');
//
//       if (partnerUid.isNotEmpty) {
//         // ใช้ service เพื่อดึงข้อมูลมาเป็น UserModel
//         final partnerModel = await _firestoreService.getUserProfile(partnerUid);
//         if (mounted) {
//           setState(() {
//             _partner = partnerModel;
//           });
//         }
//       }
//     } catch (e) {
//       print("Error loading partner info: $e");
//       if (mounted) {
//         setState(() {
//           // สร้าง partner ปลอมๆ เพื่อแสดงผล Error
//           _partner = UserModel(uid: '', displayName: 'Error', profileURL: '');
//         });
//       }
//     }
//   }
//
//   // 4. --- แก้ไขฟังก์ชัน sendMessage ให้สมบูรณ์ ---
//   Future<void> _sendMessage(String text) async {
//     // เพิ่มการตรวจสอบ _partner
//     if (text.trim().isEmpty || _currentUser == null || _partner == null) return;
//
//     final messageData = {
//       'content': text,
//       'senderUID': _currentUser!.uid,
//       'timestamp': FieldValue.serverTimestamp(),
//       'type': 'text',
//     };
//
//     final chatDocRef = _firestore.collection('chats').doc(widget.chatRoomID);
//
//     await chatDocRef.update({
//       'lastMessage': messageData,
//       'activeFor': FieldValue.arrayUnion([_currentUser!.uid, _partner!.uid]),
//     });
//
//     await chatDocRef.collection('messages').add(messageData);
//   }
//
//   // ฟังก์ชัน _pickAndSendImage และ uploadImageToStorage เหมือนเดิม...
//   Future<void> _pickAndSendImage() async { /* ... โค้ดเดิม ... */ }
//   Future<String?> uploadImageToStorage(XFile pickedFile) async { /* ... โค้ดเดิม ... */ }
//
//
//   void _scrollToBottom() {
//     if (_scrollController.hasClients) {
//       Future.delayed(const Duration(milliseconds: 100), () {
//         if (_scrollController.hasClients) {
//           _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
//         }
//       });
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back, color: Colors.white),
//           onPressed: () => Navigator.of(context).pop(),
//         ),
//         titleSpacing: 0.0,
//         title: Row(
//           children: [
//             // 5. --- แสดงผลโดยใช้ข้อมูลจาก _partner (UserModel) ---
//             CircleAvatar(
//               backgroundImage: _partner != null && _partner!.profileURL.isNotEmpty
//                   ? NetworkImage(_partner!.profileURL)
//                   : null,
//               child: (_partner == null || _partner!.profileURL.isEmpty)
//                   ? const Icon(Icons.person, size: 20)
//                   : null,
//             ),
//             const SizedBox(width: 15),
//             Text(_partner?.displayName ?? 'Loading...', style: const TextStyle(fontSize: 18)),
//           ],
//         ),
//         backgroundColor: Colors.black,
//         titleTextStyle: const TextStyle(color: Colors.white),
//       ),
//       body: Container(
//         decoration: const BoxDecoration(
//           image: DecorationImage(
//             image: NetworkImage(
//               "https://img.freepik.com/premium-photo/iphone-wallpapers-with-rainbow-black-background_777078-9490.jpg",
//             ),
//             fit: BoxFit.cover,
//           ),
//         ),
//         child: Column(
//           children: [
//             Expanded(
//               child: StreamBuilder<QuerySnapshot>(
//                 stream: _firestore
//                     .collection('chats')
//                     .doc(widget.chatRoomID)
//                     .collection('messages')
//                     .orderBy('timestamp', descending: false)
//                     .snapshots(),
//                 builder: (context, snapshot) {
//                   // ... ส่วน builder ของ StreamBuilder เหมือนเดิม ...
//                   if (snapshot.connectionState == ConnectionState.waiting) {
//                     return const Center(child: CircularProgressIndicator());
//                   }
//                   if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
//                     return const Center(
//                         child: Text("เริ่มการสนทนาได้เลย!", style: TextStyle(color: Colors.white, fontSize: 18)));
//                   }
//                   if (snapshot.hasError) {
//                     return const Center(child: Text("เกิดข้อผิดพลาด"));
//                   }
//
//                   final messagesDocs = snapshot.data!.docs;
//                   WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
//
//                   return ListView.builder(
//                     controller: _scrollController,
//                     padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
//                     itemCount: messagesDocs.length,
//                     itemBuilder: (context, index) {
//                       final messageDoc = messagesDocs[index];
//                       Map<String, dynamic> messageData = messageDoc.data() as Map<String, dynamic>;
//                       bool isSender = messageData['senderUID'] == _currentUser?.uid;
//
//                       return BubbleSpecialThree(
//                         text: messageData['content'] ?? '',
//                         color: isSender ? const Color(0xFF1B97F3) : const Color(0xFFE8E8EE),
//                         tail: true,
//                         isSender: isSender,
//                         textStyle: TextStyle(
//                             color: isSender ? Colors.white : Colors.black,
//                             fontSize: 16
//                         ),
//                       );
//                     },
//                   );
//                 },
//               ),
//             ),
//             Container(
//               padding: const EdgeInsets.symmetric(horizontal: 8.0),
//               color: Colors.white,
//               child: MessageBar(
//                 onSend: (text) => _sendMessage(text),
//                 actions: [
//                   InkWell(
//                     onTap: _pickAndSendImage,
//                     child: const Icon(Icons.image, color: Colors.black, size: 24),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }




import 'dart:io';

import 'package:boundless/components/senderBox.dart';
import 'package:chat_bubbles/chat_bubbles.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class Chat extends StatefulWidget {
  final String? chatRoomID;
  const Chat({super.key, required this.chatRoomID});

  @override
  State<Chat> createState() => _ChatState();
}

class _ChatState extends State<Chat> {
  final ScrollController _scrollController = ScrollController();
  final String currentUserUID = FirebaseAuth.instance.currentUser!.uid;

  final _firestore = FirebaseFirestore.instance;

  String _partnerName = "Loading...";
  String? _partnerPhotoUrl;

  @override
  void initState() {
    super.initState();
    _loadPartnerInfo();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPartnerInfo() async {
    try {

      final List<String> uids = widget.chatRoomID!.split('@');

      final String partnerUid = uids.firstWhere(
        (uid) => uid != currentUserUID,
        orElse: () => '',
      );

      print("Partner UID ======> ${partnerUid} | curernt UID ${currentUserUID}");

      if (partnerUid.isEmpty) {
        if (mounted) setState(() => _partnerName = "Unknown User");
        return;
      }

      final DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(partnerUid)
          .get();

      if (userDoc.exists && mounted) {
        final userData = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _partnerName = userData['displayName'] ?? 'No Name';
          _partnerPhotoUrl = userData['profileURL'];
        });
      }
    } catch (e) {
      print("Error loading partner info: $e");
      if (mounted) setState(() => _partnerName = "Error");
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _sendMessage(String text) async {
    // 1. ตรวจสอบข้อมูลเบื้องต้น
    if (text.trim().isEmpty) {
      return;
    }

    // 2. หา UID ของคู่สนทนาจาก chatRoomID
    final List<String> uids = widget.chatRoomID!.split('@');
    final String partnerUid = uids.firstWhere((uid) => uid != currentUserUID, orElse: () => '');

    // ป้องกันกรณีหา partner ไม่เจอ
    if (partnerUid.isEmpty) {
      print("Error: Could not determine partner's UID.");
      return;
    }

    final messageData = {
      'content': text,
      'senderUID': currentUserUID,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'text',
    };

    final chatDocRef = _firestore.collection('chats').doc(widget.chatRoomID);

    await chatDocRef.update({
      // อัปเดตข้อความล่าสุด
      'lastMessage': messageData,
      'activeFor': FieldValue.arrayUnion([currentUserUID, partnerUid]),
    });

    await chatDocRef.collection('messages').add(messageData);
  }

  Future<void> _pickAndSendImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
    );

    if (pickedFile != null && currentUserUID != null) {
      final String? imageURL = await uploadImageToStorage(pickedFile);

      if (imageURL != null) {
        final messageData = {
          'content': imageURL,
          'senderUID': currentUserUID,
          'timestamp': FieldValue.serverTimestamp(),
          'type': 'image',
        };

        await _firestore
            .collection('chats')
            .doc(widget.chatRoomID)
            .collection('messages')
            .add(messageData);
      }
    }
  }

  Future<String?> uploadImageToStorage(XFile pickedFile) async {
    try {
      File fileToUpload = File(pickedFile.path);
      String fileName = 'files/${pickedFile.name}';
      Reference storageReference = FirebaseStorage.instance.ref().child(
        fileName,
      );
      await storageReference.putFile(fileToUpload);
      String downloadUrl = await storageReference.getDownloadURL();
      print('Upload Success! URL: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('Failed Upload: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0.0,
        title: Row(
          children: [

            CircleAvatar(
              backgroundImage:
                  _partnerPhotoUrl != null && _partnerPhotoUrl!.isNotEmpty
                  ? NetworkImage(_partnerPhotoUrl!)
                  : null,
              child: (_partnerPhotoUrl == null || _partnerPhotoUrl!.isEmpty)
                  ? const Icon(Icons.person, size: 20) // รูปสำรอง
                  : null,
            ),
            SizedBox(width: 15),
            // --- 4. แสดงชื่อของคู่สนทนา ---
            Text(_partnerName, style: TextStyle(fontSize: 18)),
          ],
        ),
        backgroundColor: Colors.black,
        titleTextStyle: TextStyle(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: NetworkImage(
              "https://img.freepik.com/premium-photo/iphone-wallpapers-with-rainbow-black-background_777078-9490.jpg",
            ),
            opacity: 1,
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('chats')
                    .doc(widget.chatRoomID)
                    .collection('messages')
                    .orderBy('timestamp', descending: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text(
                        "เริ่มการสนทนาได้เลย!",
                        style: TextStyle(fontSize: 24, color: Colors.white),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return const Center(child: Text("เกิดข้อผิดพลาด"));
                  }

                  final messagesDocs = snapshot.data!.docs;

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _scrollToBottom();
                  });

                  return ListView.builder(
                    controller: _scrollController,
                    itemCount: messagesDocs.length,
                    itemBuilder: (context, index) {
                      final messageDoc = messagesDocs[index];
                      Map<String, dynamic> messageData =
                          messageDoc.data() as Map<String, dynamic>;
                      messageData['sender'] =
                          messageData['senderUID'] == currentUserUID;
                      return SenderBox(message: messageData, profileURL: "https://upload.wikimedia.org/wikipedia/commons/thumb/c/c8/McLaren_P1.jpg/500px-McLaren_P1.jpg",);
                    },
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              color: Colors.white,
              child: MessageBar(
                onSend: (text) => _sendMessage(text),
                actions: [
                  InkWell(
                    onTap: _pickAndSendImage,
                    child: const Icon(
                      Icons.image,
                      color: Colors.black,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
