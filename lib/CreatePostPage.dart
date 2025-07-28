// lib/pages/CreatePostPage.dart

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

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
  double _uploadProgress = 0.0;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage(imageQuality: 80);
      if (pickedFiles.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(pickedFiles);
        });
      }
    } catch (e) {
      print("Error picking images: $e");
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<File?> _compressImage(XFile file) async {
    final tempDir = await getTemporaryDirectory();
    final path = tempDir.path;
    final targetPath = p.join(path, '${DateTime.now().millisecondsSinceEpoch}_${p.basename(file.path)}.jpg');
    final result = await FlutterImageCompress.compressAndGetFile(
      file.path,
      targetPath,
      quality: 70,
      minWidth: 1080,
      minHeight: 1080,
    );
    return result != null ? File(result.path) : null;
  }

  Future<void> _submitPost() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("กรุณาล็อกอินก่อนโพสต์")));
      return;
    }
    if (_selectedImages.isEmpty || _isUploading) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.15;
    });

    try {
      List<String> imageUrls = [];
      final storageRef = FirebaseStorage.instance.ref();

      for (var imageFile in _selectedImages) {
        final compressedFile = await _compressImage(imageFile);
        if (compressedFile == null) continue;

        final uniqueFileName = '${DateTime.now().millisecondsSinceEpoch}_${p.basename(imageFile.path)}';
        final postImageRef = storageRef.child('post_images/${currentUser.uid}/$uniqueFileName');

        await postImageRef.putFile(compressedFile);
        final url = await postImageRef.getDownloadURL();
        imageUrls.add(url);
      }

      if (imageUrls.length != _selectedImages.length) {
        throw Exception("การอัปโหลดรูปภาพล้มเหลว");
      }

      setState(() => _uploadProgress = 0.9);

      // --- ✨ Refactored Data: ไม่มีการบันทึก ownerDisplayName และ ownerProfileUrl ---
      final postData = {
        'ownerUid': currentUser.uid,
        'caption': _captionController.text.trim(),
        'imageUrls': imageUrls,
        'timestamp': FieldValue.serverTimestamp(),
        'likedBy': [],
        'commentCount': 0,
      };

      await FirebaseFirestore.instance.collection('posts').add(postData);

      setState(() => _uploadProgress = 1.0);
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      print("Error submitting post: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("เกิดข้อผิดพลาด: ${e.toString()}"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: _isUploading ? null : () => Navigator.of(context).pop(),
        ),
        title: const Text("Create Post", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: false,
        actions: [
          TextButton(
            onPressed: (_selectedImages.isNotEmpty && !_isUploading) ? _submitPost : null,
            child: Text(
              "Post",
              style: TextStyle(
                color: (_selectedImages.isNotEmpty && !_isUploading) ? Colors.yellow.shade700 : Colors.grey,
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
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade900,
                          borderRadius: BorderRadius.circular(8),
                          image: _selectedImages.isNotEmpty
                              ? DecorationImage(
                            image: FileImage(File(_selectedImages.first.path)),
                            fit: BoxFit.cover,
                          )
                              : null,
                        ),
                        child: _selectedImages.isEmpty
                            ? const Icon(Icons.photo_library_outlined, color: Colors.grey, size: 40)
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _captionController,
                          style: const TextStyle(color: Colors.white),
                          maxLines: 4,
                          decoration: const InputDecoration(
                            hintText: "Write a caption...",
                            hintStyle: TextStyle(color: Colors.grey),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white24, height: 1),
                ListTile(
                  leading: const Icon(Icons.add_photo_alternate_outlined, color: Colors.white),
                  title: Text(
                    _selectedImages.isEmpty
                        ? "Add photos"
                        : "${_selectedImages.length} photos selected",
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: _pickImages,
                ),
                if (_selectedImages.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: _selectedImages.length,
                      itemBuilder: (context, index) {
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(_selectedImages[index].path),
                                fit: BoxFit.cover,
                                cacheWidth: 200,
                              ),
                            ),
                            Positioned(
                              top: -8,
                              right: -8,
                              child: GestureDetector(
                                onTap: () => _removeImage(index),
                                child: Container(
                                  padding: const EdgeInsets.all(2.0),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          if (_isUploading)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.yellow.shade700),
                    const SizedBox(height: 16),
                    const Text("Posting...", style: TextStyle(color: Colors.white, fontSize: 16)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
