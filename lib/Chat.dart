import 'dart:io';

import 'package:boundless/components/senderBox.dart';
import 'package:chat_bubbles/chat_bubbles.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:boundless/pages/call_page.dart';
import 'package:boundless/config/agora_config.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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

  String _partnerName = "Loading...";
  String? _partnerPhotoUrl;
  String _draftText = "";
  String? _partnerUid;

  @override
  void initState() {
    super.initState();
    _loadPartnerInfo();
    _listenForIncomingCall(); // ✅ เพิ่มตรงนี้
    _testFirebaseWrite(); // ✅ เพิ่มตรงนี้เพื่อทดสอบการเขียนข้อมูล
  }

  void _testFirebaseWrite() async {
  try {
    final testRef = _realtimeDB.ref('test/connection');
    print(">>> [TEST] Attempting to write to Firebase...");
    await testRef.set({'status': 'ok', 'time': DateTime.now().toIso8601String()});
    print("✅✅✅ [TEST] Firebase write test SUCCESSFUL!");
  } catch (e) {
    print("❌❌❌ [TEST] Firebase write test FAILED: $e");
  }
}
  void _listenForIncomingCall() {
    final ref = _realtimeDB.ref('calls/${widget.chatRoomID}');

    ref.onValue.listen((event) {
      // ✅ เพิ่มบรรทัดนี้เป็นบรรทัดแรกสุดใน listener
      // เพื่อตรวจสอบว่าหน้าจอยังอยู่หรือไม่ ก่อนทำอย่างอื่น
      if (!mounted) return;

      final data = event.snapshot.value;
      if (data == null) return;

      final callData = Map<String, dynamic>.from(data as Map);
      final isForMe = callData['receiverUid'] == currentUserUID;
      if (!isForMe) return;

      final token = callData['token'];
      final isVideo = callData['isVideo'] ?? false;
      final chatRoomId = callData['channelId'];

      if (ModalRoute.of(context)?.isCurrent != true) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CallPage(
            chatRoomId: chatRoomId,
            isVideo: isVideo,
            callerName:
                _partnerName, //แก้เป็น _partnerName เพื่อส่งชื่อคู่สนทนาไป
            token: token,
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    // _realtimeDB
    //     .ref('calls/${widget.chatRoomID}')
    //     .remove(); // ลบ path นี้เมื่อวางสาย
    _scrollController.dispose();
    super.dispose();
  }

  void _startCall({required bool isVideo}) async {
    print("📞 Start Call tapped: isVideo = $isVideo");

    await [Permission.microphone, if (isVideo) Permission.camera].request();
    print("✅ Permission granted");

    if (_partnerUid == null) {
      print("❌ No partner UID");
      return;
    }

    final token = await _generateToken(widget.chatRoomID!);
    print("🧪 Got token: $token");

    if (token == null) {
      print("❌ No token returned");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("ไม่สามารถเริ่มการโทรได้ กรุณาลองใหม่อีกครั้ง"),
            backgroundColor: Colors.red,
          ),
        );
      }

      return;
    }
    try {
      final ref = _realtimeDB.ref('calls/${widget.chatRoomID}');
      await ref.set({
        'callerUid': currentUserUID,
        'receiverUid': _partnerUid,
        'isVideo': isVideo,
        'channelId': widget.chatRoomID,
        'token': token,
        'timestamp': ServerValue.timestamp,
      });

      // ถ้าเขียนข้อมูลสำเร็จ ให้ไปหน้า CallPage
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CallPage(
              chatRoomId: widget.chatRoomID!,
              isVideo: isVideo,
              callerName: _partnerName,
              token: token,
            ),
          ),
        );
      }
    } catch (e) {
      // ถ้าเกิดข้อผิดพลาดขึ้น (เช่น Permission Denied จาก Rules)
      print("❌ Failed to set call data in Firebase: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("เกิดข้อผิดพลาดในการเริ่มการโทร (DB)"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String?> _generateToken(String channelId) async {
    try {
      final response = await http.post(
        //Uri.parse('http://10.0.2.2:3000/agora/token'),
        Uri.parse('http://192.168.1.33:3000/agora/token'),
        
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'channelName': widget.chatRoomID, // ใช้ chatRoomID ตรงนี้
          'uid': 0, // ใช้ 0 สำหรับ UID ของผู้ใช้ปัจจุบัน
        }),
      );
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        return jsonData['token'];
      } else {
        print("Token Error: ${response.statusCode}");
      }
    } catch (e) {
      print("Token Error: $e");
    }
    return null;
  }

  Future<void> _loadPartnerInfo() async {
    try {
      final List<String> uids = widget.chatRoomID!.split('@');
      final String partnerUid = uids.firstWhere(
        (uid) => uid != currentUserUID,
        orElse: () => '',
      );

      _partnerUid = partnerUid;

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
    final String partnerUid = uids.firstWhere(
      (uid) => uid != currentUserUID,
      orElse: () => '',
    );

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

        actions: [
          IconButton(
            icon: Icon(Icons.call, color: Colors.white),
            onPressed: () => _startCall(isVideo: false),
          ),
          IconButton(
            icon: Icon(Icons.videocam, color: Colors.white),
            onPressed: () => _startCall(isVideo: true),
          ),
        ],

        backgroundColor: Colors.black,
        titleTextStyle: TextStyle(color: Colors.white),
      ),
      body: Container(
        // decoration: const BoxDecoration(
        //   image: DecorationImage(
        //     image: NetworkImage(
        //       "https://img.freepik.com/premium-photo/iphone-wallpapers-with-rainbow-black-background_777078-9490.jpg",
        //     ),
        //     opacity: 1,
        //     fit: BoxFit.cover,
        //   ),
        // ),
        decoration: BoxDecoration(
          color: Colors.grey[850], // เปลี่ยนเป็นสีเทาเข้ม
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
                      return SenderBox(
                        message: messageData,
                        profileURL:
                            "https://upload.wikimedia.org/wikipedia/commons/thumb/c/c8/McLaren_P1.jpg/500px-McLaren_P1.jpg",
                      );
                    },
                  );
                },
              ),
            ),
            // Container(
            //   padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
            //   color: Colors.transparent,
            //   child: MessageBar(
            //     onSend: (text) => _sendMessage(text),
            //     actions: [
            //       InkWell(
            //         onTap: _pickAndSendImage,
            //         child: const Icon(
            //           Icons.image,
            //           color: Color(0xFFF3B716),
            //           size: 24,
            //         ),
            //       ),
            //     ],

            //   ),
            // ),
            _buildCustomMessageInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      color: Colors.transparent,
      child: TextField(
        controller: TextEditingController(text: _draftText)
          ..selection = TextSelection.fromPosition(
            TextPosition(offset: _draftText.length),
          ),
        onChanged: (val) => setState(() => _draftText = val),
        style: TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: "พิมพ์ข้อความ...",
          hintStyle: TextStyle(color: Colors.white70),
          filled: true,
          fillColor: Colors.black,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          // --- ส่วนที่แก้ไข ---
          // 1. ย้ายไอคอนรูปภาพมาไว้ด้านซ้ายสุดด้วย prefixIcon
          prefixIcon: IconButton(
            icon: const Icon(Icons.image, color: Color(0xFFF3B716)),
            onPressed: _pickAndSendImage,
          ),
          // 2. เหลือแค่ไอคอนส่งข้อความไว้ที่ suffixIcon ด้านขวา
          suffixIcon: IconButton(
            icon: const Icon(Icons.send, color: Color(0xFFF3B716)),
            onPressed: _draftText.trim().isEmpty
                ? null // ปุ่มจะเป็นสีเทา กดไม่ได้ ถ้าไม่มีข้อความ
                : () {
                    _sendMessage(_draftText.trim());
                    // เคลียร์ข้อความใน TextField
                    setState(() => _draftText = "");
                  },
          ),
        ),
      ),
    );
  }
}
