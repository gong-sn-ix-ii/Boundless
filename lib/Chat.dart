// lib/Chat.dart

import 'dart:convert';
import 'dart:io';

import 'package:boundless/components/message_input_bar.dart';
import 'package:boundless/components/senderBox.dart';
import 'package:boundless/photo_gallery_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:boundless/pages/call_page.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;

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
  final _realtimeDB = FirebaseDatabase.instance;
  final FocusNode _inputFocusNode = FocusNode(); // ✅ เพิ่ม FocusNode

  String _partnerName = "Loading...";
  String? _partnerPhotoUrl;
  String? _partnerUid;

  @override
  void initState() {
    super.initState();
    _loadPartnerInfo();
    _listenForIncomingCall();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _inputFocusNode.dispose(); // ✅ อย่าลืม dispose()
    super.dispose();
  }

  void _listenForIncomingCall() {
    final ref = _realtimeDB.ref('calls/${widget.chatRoomID}');
    ref.onValue.listen((event) {
      if (!mounted) return;
      final data = event.snapshot.value;
      if (data == null) return;
      final callData = Map<String, dynamic>.from(data as Map);
      if (callData['receiverUid'] == currentUserUID && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CallPage(
              chatRoomId: callData['channelId'],
              isVideo: callData['isVideo'] ?? false,
              callerName: _partnerName,
              token: callData['token'],
            ),
          ),
        );
      }
    });
  }

  void _startCall({required bool isVideo}) async {
    await [Permission.microphone, if (isVideo) Permission.camera].request();
    if (_partnerUid == null) return;
    final token = await _generateToken(widget.chatRoomID!);
    if (token == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ไม่สามารถเริ่มการโทรได้"), backgroundColor: Colors.red));
      return;
    }
    try {
      final ref = _realtimeDB.ref('calls/${widget.chatRoomID}');
      await ref.set({
        'callerUid': currentUserUID, 'receiverUid': _partnerUid,
        'isVideo': isVideo, 'channelId': widget.chatRoomID,
        'token': token, 'timestamp': ServerValue.timestamp,
      });
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CallPage(
              chatRoomId: widget.chatRoomID!, isVideo: isVideo,
              callerName: _partnerName, token: token,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("เกิดข้อผิดพลาดในการโทร (DB)"), backgroundColor: Colors.red));
    }
  }

  Future<String?> _generateToken(String channelId) async {
    try {
      final response = await http.post(
        Uri.parse('https://agora-qca2libyva-uc.a.run.app'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'channelName': widget.chatRoomID, 'uid': 0}),
      );
      if (response.statusCode == 200) return jsonDecode(response.body)['token'];
    } catch (e) {
      print("Token Error: $e");
    }
    return null;
  }

  Future<void> _loadPartnerInfo() async {
    try {
      if (widget.chatRoomID == null || widget.chatRoomID!.isEmpty) return;
      final chatDoc = await _firestore.collection('chats').doc(widget.chatRoomID).get();
      if (!chatDoc.exists) {
        if (mounted) setState(() => _partnerName = "Chat not found");
        return;
      }
      final chatData = chatDoc.data() as Map<String, dynamic>;
      final participants = List<String>.from(chatData['participants'] ?? []);
      _partnerUid = participants.firstWhere((uid) => uid != currentUserUID, orElse: () => '');
      if (_partnerUid!.isEmpty) {
        if (mounted) setState(() => _partnerName = "Unknown User");
        return;
      }
      final userDoc = await _firestore.collection('users').doc(_partnerUid).get();
      if (userDoc.exists && mounted) {
        final userData = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _partnerName = userData['displayName'] ?? 'No Name';
          _partnerPhotoUrl = userData['profileURL'];
        });
      }
    } catch (e) {
      if (mounted) setState(() => _partnerName = "Error");
    }
  }

  // ✅ เพิ่มฟังก์ชันนี้เข้ามาใหม่
  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 50), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0, // สำหรับ list แบบ reverse, 0.0 คือตำแหน่งล่างสุด
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    if (_partnerUid == null || _partnerUid!.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: ไม่พบผู้รับ"), backgroundColor: Colors.red));
      return;
    }
    final messageData = {'content': text, 'senderUID': currentUserUID, 'timestamp': FieldValue.serverTimestamp(), 'type': 'text'};
    final chatDocRef = _firestore.collection('chats').doc(widget.chatRoomID);
    await chatDocRef.update({'lastMessage': messageData, 'activeFor': FieldValue.arrayUnion([currentUserUID, _partnerUid!])});
    await chatDocRef.collection('messages').add(messageData);

    _scrollToBottom(); // ✅ เรียกใช้ฟังก์ชัน scroll ที่นี่
  }

  Future<void> _pickAndSendImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (pickedFile == null) return;
    try {
      final imageURL = await uploadImageToStorage(pickedFile);
      if (imageURL != null) {
        final messageData = {'content': imageURL, 'senderUID': currentUserUID, 'timestamp': FieldValue.serverTimestamp(), 'type': 'image'};
        if (_partnerUid == null || _partnerUid!.isEmpty) return;
        final chatDocRef = _firestore.collection('chats').doc(widget.chatRoomID);
        final messageRef = chatDocRef.collection('messages').doc();
        WriteBatch batch = _firestore.batch();
        batch.update(chatDocRef, {'lastMessage': {'content': '[รูปภาพ]', 'senderUID': currentUserUID, 'timestamp': FieldValue.serverTimestamp(), 'type': 'image'}, 'activeFor': FieldValue.arrayUnion([currentUserUID, _partnerUid!])});
        batch.set(messageRef, messageData);
        await batch.commit();
        _scrollToBottom(); // ✅ เรียกใช้ฟังก์ชัน scroll ที่นี่ด้วย
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("ส่งรูปภาพไม่สำเร็จ: $e"), backgroundColor: Colors.red));
    }
  }

  Future<String?> uploadImageToStorage(XFile pickedFile) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return null;
      final fileToUpload = File(pickedFile.path);
      final uniqueFileName = '${DateTime.now().millisecondsSinceEpoch}_${pickedFile.name}';
      final path = 'chat_images/${currentUser.uid}/$uniqueFileName';
      final storageReference = FirebaseStorage.instance.ref().child(path);
      await storageReference.putFile(fileToUpload);
      return await storageReference.getDownloadURL();
    } catch (e) {
      print('Failed Upload: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.of(context).pop()),
        titleSpacing: 0.0,
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: _partnerPhotoUrl != null && _partnerPhotoUrl!.isNotEmpty ? NetworkImage(_partnerPhotoUrl!) : null,
              child: (_partnerPhotoUrl == null || _partnerPhotoUrl!.isEmpty) ? const Icon(Icons.person, size: 20) : null,
            ),
            const SizedBox(width: 15),
            Text(_partnerName, style: const TextStyle(fontSize: 18)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.call, color: Colors.white), onPressed: () => _startCall(isVideo: false)),
          IconButton(icon: const Icon(Icons.videocam, color: Colors.white), onPressed: () => _startCall(isVideo: true)),
        ],
        backgroundColor: Colors.black,
        titleTextStyle: const TextStyle(color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(color: Colors.grey[850]),
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('chats').doc(widget.chatRoomID).collection('messages').orderBy('timestamp', descending: true).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    // ✅ แก้ไขให้เป็นสีเหลือง
                    return const Center(child: CircularProgressIndicator(color: Colors.yellow));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text("เริ่มการสนทนาได้เลย!", style: TextStyle(fontSize: 24, color: Colors.white)));
                  }
                  if (snapshot.hasError) {
                    return const Center(child: Text("เกิดข้อผิดพลาด"));
                  }

                  final messagesDocs = snapshot.data!.docs;

                  final allImageUrls = messagesDocs
                      .where((doc) => (doc.data() as Map<String, dynamic>)['type'] == 'image')
                      .map((doc) => (doc.data() as Map<String, dynamic>)['content'] as String)
                      .toList();

                  return ListView.builder(
                    reverse: true,
                    controller: _scrollController,
                    itemCount: messagesDocs.length,
                    itemBuilder: (context, index) {
                      final messageDoc = messagesDocs[index];
                      Map<String, dynamic> messageData = messageDoc.data() as Map<String, dynamic>;
                      final bool isSender = messageData['senderUID'] == currentUserUID;
                      messageData['sender'] = isSender;

                      if (messageData['type'] == 'image') {
                        final currentImageUrl = messageData['content'] as String;
                        final currentImageIndex = allImageUrls.indexOf(currentImageUrl);
                        return SenderBox(
                          message: messageData,
                          heroTag: 'chat_image_${messageDoc.id}',
                          onImageTap: () {
                            FocusScope.of(context).unfocus();
                            _inputFocusNode.unfocus();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PhotoGalleryPage(
                                  imageUrls: allImageUrls,
                                  initialIndex: currentImageIndex,
                                  heroTagPrefix: 'chat_image_',
                                ),
                              ),
                            );
                          },
                        );
                      } else {
                        return SenderBox(message: messageData, profileURL: isSender ? "" : _partnerPhotoUrl ?? "");
                      }
                    },
                  );
                },
              ),
            ),
            MessageInputBar(
              focusNode: _inputFocusNode, // ✅ ส่ง FocusNode เข้าไป
              onSendText: _sendMessage,
              onSendImage: _pickAndSendImage,
            ),
          ],
        ),
      ),
    );
  }
}