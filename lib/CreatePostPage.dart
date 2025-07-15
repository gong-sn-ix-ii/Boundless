// lib/pages/create_post_page.dart

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final TextEditingController _captionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  List<XFile> _selectedImages = [];
  bool _isUploading = false;
  final String? _currentUserUid = FirebaseAuth.instance.currentUser?.uid;

  // ฟังก์ชันสำหรับเลือกหลายรูปภาพ
  Future<void> _pickImages() async {
    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage(
        imageQuality: 80, // ลดคุณภาพเพื่อขนาดไฟล์ที่เล็กลง
      );
      if (pickedFiles.isNotEmpty) {
        setState(() {
          _selectedImages = pickedFiles;
        });
      }
    } catch (e) {
      print("Error picking images: $e");
    }
  }

  // ฟังก์ชันสำหรับอัปโหลดไฟล์และรับ URL กลับมา
  Future<List<String>> _uploadFiles(List<XFile> images) async {
    List<String> imageUrls = [];
    final storageRef = FirebaseStorage.instance.ref();

    for (var imageFile in images) {
      // สร้าง reference ไปยัง path ที่จะเก็บไฟล์
      final postImageRef = storageRef.child('post_images/${_currentUserUid}/${DateTime.now().millisecondsSinceEpoch}_${imageFile.name}');

      try {
        // อัปโหลดไฟล์
        await postImageRef.putFile(File(imageFile.path));
        // ดึง URL ของไฟล์ที่อัปโหลดแล้ว
        final downloadUrl = await postImageRef.getDownloadURL();
        imageUrls.add(downloadUrl);
      } catch (e) {
        print("Error uploading file: $e");
      }
    }
    return imageUrls;
  }

  // ฟังก์ชันสำหรับสร้างโพสต์
  Future<void> _submitPost() async {
    if (_selectedImages.isEmpty || _isUploading) return;

    setState(() { _isUploading = true; });

    try {
      // 1. อัปโหลดรูปภาพทั้งหมด
      final List<String> imageUrls = await _uploadFiles(_selectedImages);

      if (imageUrls.isEmpty) {
        throw Exception("Image upload failed.");
      }

      // 2. ดึงข้อมูลโปรไฟล์ของผู้ใช้ปัจจุบัน (เพื่อทำ Denormalization)
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUserUid).get();
      final userData = userDoc.data() as Map<String, dynamic>?;

      // 3. เตรียมข้อมูลสำหรับบันทึกลง Firestore
      final postData = {
        'ownerUid': _currentUserUid,
        'ownerDisplayName': userData?['displayName'] ?? 'Unknown User',
        'ownerProfileUrl': userData?['profileURL'] ?? '',
        'caption': _captionController.text.trim(),
        'imageUrls': imageUrls, // <-- เก็บเป็น Array of Strings
        'timestamp': FieldValue.serverTimestamp(),
        'likedBy': [],
        'commentCount': 0,
      };

      // 4. เพิ่ม Document ใหม่ใน Collection 'posts'
      await FirebaseFirestore.instance.collection('posts').add(postData);

      // 5. กลับไปหน้าก่อนหน้าเมื่อโพสต์สำเร็จ
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      print("Error submitting post: $e");
      // TODO: แสดง Error Dialog ให้ผู้ใช้ทราบ
    } finally {
      if (mounted) {
        setState(() { _isUploading = false; });
      }
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text("Boundless Post", style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold)),
        actions: [
          // ปุ่มสำหรับโพสต์
          TextButton(
            onPressed: (_selectedImages.isNotEmpty && !_isUploading) ? _submitPost : null,
            child: Text(
              "Post",
              style: TextStyle(
                color: (_selectedImages.isNotEmpty && !_isUploading) ? Colors.yellow : Colors.grey,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [

                Container(
                  height: 250,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade800),
                  ),
                  child: _selectedImages.isEmpty
                      ? Center(
                    child: TextButton.icon(
                      icon: const Icon(Icons.photo_library, color: Colors.yellow),
                      label: const Text("Select Images", style: TextStyle(color: Colors.yellow, fontSize: 18)),
                      onPressed: _pickImages,
                    ),
                  )
                      : GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 4,
                      mainAxisSpacing: 4,
                    ),
                    itemCount: _selectedImages.length,
                    itemBuilder: (context, index) {
                      return Image.file(File(_selectedImages[index].path), fit: BoxFit.cover);
                    },
                  ),
                ),
                const SizedBox(height: 16),
                // --- ช่องใส่ Caption ---
                TextField(
                  controller: _captionController,
                  // ปรับสีตัวอักษรให้เป็นสีดำเพื่อให้อ่านง่ายบนพื้นหลังสีเหลือง
                  style: const TextStyle(color: Colors.black),
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: "เขียนคำอธิบายที่นี่...",
                    hintStyle: TextStyle(color: Colors.black.withOpacity(0.6)),

                    // --- 2 บรรทัดที่เพิ่มเข้ามา ---
                    filled: true, // บอกให้ TextField เติมสีพื้นหลัง
                    fillColor: Colors.white, // กำหนดสีเหลือง (ปรับความโปร่งใสได้)
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                )
              ],
            ),
          ),
          // --- Loading Overlay ---
          if (_isUploading)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.yellow),
                    SizedBox(height: 16),
                    Text("Uploading...", style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

