import 'dart:io';

import 'package:boundless/SigninPage.dart';
import 'package:boundless/components/senderBox.dart';
import 'package:chat_bubbles/chat_bubbles.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class Chat extends StatefulWidget {
  const Chat({super.key});

  @override
  State<Chat> createState() => _ChatState();
}

class _ChatState extends State<Chat> {
  final ScrollController _scrollController = ScrollController();
  final String chatDocId = '4J8PvGflXhNpUNaxR9J2@Pnxm0inbFF1JZtxCFecf';
  final String? currentUserUID = '4J8PvGflXhNpUNaxR9J2';

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

      final List<String> uids = chatDocId.split('@');

      final String partnerUid = uids.firstWhere(
        (uid) => uid != currentUserUID,
        orElse: () => '',
      );

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
          _partnerPhotoUrl = userData['photoUrl'];
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
    if (text.trim().isEmpty || currentUserUID == null) {
      return;
    }

    final messageData = {
      'content': text,
      'senderUID': currentUserUID,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'text',
    };

    await _firestore
        .collection('chats')
        .doc(chatDocId)
        .collection('messages')
        .add(messageData);
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
            .doc(chatDocId)
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
            // --- 4. แสดงรูปโปรไฟล์ของคู่สนทนา ---
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
                    .doc(chatDocId)
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
                      return SenderBox(message: messageData);
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
