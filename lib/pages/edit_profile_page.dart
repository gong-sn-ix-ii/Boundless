// lib/pages/edit_profile_page.dart

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_cropper/image_cropper.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  // --- State Management ---
  bool _isLoading = true;
  bool _isSaving = false;
  final String? _currentUserUid = FirebaseAuth.instance.currentUser?.uid;

  // --- Data Controllers & Variables ---
  final _displayNameController = TextEditingController();
  final _bioController = TextEditingController();
  String _profileUrl = '';
  String _coverUrl = '';

  // --- Image Picker State ---
  // ✨ ส่วนนี้จะเก็บแค่ไฟล์ชั่วคราวในเครื่อง ทำให้แสดงผลเร็ว
  final ImagePicker _picker = ImagePicker();
  XFile? _newProfileImage;
  XFile? _newCoverImage;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  // --- Logic Functions ---

  Future<void> _loadUserData() async {
    if (_currentUserUid == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUserUid).get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        _displayNameController.text = data['displayName'] ?? '';
        _bioController.text = data['bio'] ?? '';
        setState(() {
          _profileUrl = data['profileURL'] ?? '';
          _coverUrl = data['coverPhotoUrl'] ?? '';
        });
      }
    } catch (e) {
      print("Error loading user data: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ✨ ฟังก์ชันนี้ทำงานกับไฟล์ในเครื่องเท่านั้น ไม่มีการอัปโหลด ทำให้เร็ว
  Future<void> _pickAndCropImage({
    required Function(XFile) onCropped,
    CropAspectRatio? aspectRatio,
  }) async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 90);

    if (pickedFile != null) {
      final CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        aspectRatio: aspectRatio,
        uiSettings: [
          AndroidUiSettings(
              toolbarTitle: 'ปรับแต่งรูปภาพ',
              toolbarColor: Colors.black,
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.original,
              lockAspectRatio: aspectRatio != null,
              activeControlsWidgetColor: Colors.yellow.shade700
          ),
          IOSUiSettings(
            title: 'ปรับแต่งรูปภาพ',
            aspectRatioLockEnabled: aspectRatio != null,
          ),
        ],
      );

      if (croppedFile != null) {
        onCropped(XFile(croppedFile.path));
      }
    }
  }


  Future<String?> _uploadImage(XFile imageFile, String folderName) async {
    if (_currentUserUid == null) return null;
    try {
      final file = File(imageFile.path);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storageRef = FirebaseStorage.instance.ref().child('$folderName/$_currentUserUid/$fileName');
      await storageRef.putFile(file);
      return await storageRef.getDownloadURL();
    } catch (e) {
      print("Error uploading image: $e");
      return null;
    }
  }

  Future<void> _deleteImageFromUrl(String imageUrl) async {
    if (imageUrl.isEmpty || !imageUrl.startsWith('https://firebasestorage.googleapis.com')) return;
    try {
      final ref = FirebaseStorage.instance.refFromURL(imageUrl);
      await ref.delete();
      print("Successfully deleted old image: $imageUrl");
    } catch (e) {
      print("Failed to delete old image ($imageUrl): $e");
    }
  }

  // ✨ การอัปโหลดและลบทั้งหมดจะเกิดขึ้นในฟังก์ชันนี้ที่เดียว เมื่อกด "บันทึก"
  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);

    try {
      String newProfileUrl = _profileUrl;
      String newCoverUrl = _coverUrl;

      final oldProfileUrl = _profileUrl;
      final oldCoverUrl = _coverUrl;

      // 1. อัปโหลดรูปโปรไฟล์ใหม่ (ถ้ามีการเลือก)
      if (_newProfileImage != null) {
        newProfileUrl = await _uploadImage(_newProfileImage!, 'profile_pictures') ?? _profileUrl;
      }

      // 2. อัปโหลดรูปปกใหม่ (ถ้ามีการเลือก)
      if (_newCoverImage != null) {
        newCoverUrl = await _uploadImage(_newCoverImage!, 'cover_pictures') ?? _coverUrl;
      }

      // 3. เตรียมข้อมูลทั้งหมดเพื่ออัปเดตลง Firestore
      final Map<String, dynamic> updatedData = {
        'displayName': _displayNameController.text.trim(),
        'bio': _bioController.text.trim(),
        'profileURL': newProfileUrl,
        'coverPhotoUrl': newCoverUrl,
      };

      await FirebaseFirestore.instance.collection('users').doc(_currentUserUid).update(updatedData);

      // 4. ลบรูปโปรไฟล์เก่าออกจาก Storage (ถ้ามีการอัปโหลดรูปใหม่สำเร็จ)
      if (_newProfileImage != null && newProfileUrl != oldProfileUrl) {
        await _deleteImageFromUrl(oldProfileUrl);
      }

      // 5. ลบรูปปกเก่าออกจาก Storage (ถ้ามีการอัปโหลดรูปใหม่สำเร็จ)
      if (_newCoverImage != null && newCoverUrl != oldCoverUrl) {
        await _deleteImageFromUrl(oldCoverUrl);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("บันทึกโปรไฟล์เรียบร้อยแล้ว"), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      print("Error saving profile: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("เกิดข้อผิดพลาด: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }


  // --- UI Widgets ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.yellow))
          : Stack(
        children: [
          _buildBody(),
          _buildAppBar(),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton(
              onPressed: _isSaving ? null : _saveProfile,
              child: _isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('บันทึก', style: TextStyle(color: Colors.yellow.shade700, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildHeader(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildSettingTile(
                  icon: Icons.person_outline,
                  title: 'ชื่อที่แสดง',
                  subtitle: _displayNameController.text,
                  onTap: () => _showEditDialog('ชื่อที่แสดง', _displayNameController),
                ),
                _buildSettingTile(
                  icon: Icons.article_outlined,
                  title: 'คำอธิบายตัวตน (Bio)',
                  subtitle: _bioController.text,
                  onTap: () => _showEditDialog('คำอธิบายตัวตน (Bio)', _bioController, maxLines: 3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return SizedBox(
      height: 280,
      child: Stack(
        children: [
          ClipPath(
            clipper: WaveClipper(),
            child: GestureDetector(
              onTap: () => _pickAndCropImage(
                onCropped: (file) => setState(() => _newCoverImage = file),
                aspectRatio: const CropAspectRatio(ratioX: 16, ratioY: 9),
              ),
              child: Container(
                height: 220,
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  image: _newCoverImage != null
                      ? DecorationImage(image: FileImage(File(_newCoverImage!.path)), fit: BoxFit.cover)
                      : (_coverUrl.isNotEmpty ? DecorationImage(image: CachedNetworkImageProvider(_coverUrl), fit: BoxFit.cover) : null),
                ),
                child: Center(
                  child: Icon(Icons.camera_alt, color: Colors.white.withOpacity(0.5), size: 40),
                ),
              ),
            ),
          ),
          Positioned(
            top: 150,
            left: 0,
            right: 0,
            child: Column(
              children: [
                GestureDetector(
                  onTap: () => _pickAndCropImage(
                    onCropped: (file) => setState(() => _newProfileImage = file),
                    aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1), // ทำให้เป็นสี่เหลี่ยมจัตุรัส
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircleAvatar(
                        radius: 54,
                        backgroundColor: Colors.black,
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.grey.shade800,
                          backgroundImage: _newProfileImage != null
                              ? FileImage(File(_newProfileImage!.path)) as ImageProvider
                              : (_profileUrl.isNotEmpty ? CachedNetworkImageProvider(_profileUrl) : null),
                          child: (_newProfileImage == null && _profileUrl.isEmpty)
                              ? const Icon(Icons.person, size: 50, color: Colors.white70)
                              : null,
                        ),
                      ),
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.yellow.shade700,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.edit, color: Colors.black, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return Card(
      color: Colors.grey.shade900,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: Colors.yellow.shade700),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle.isNotEmpty ? subtitle : 'ยังไม่ได้ตั้งค่า', style: const TextStyle(color: Colors.white70), maxLines: 1, overflow: TextOverflow.ellipsis,),
        trailing: const Icon(Icons.chevron_right, color: Colors.white70),
        onTap: onTap,
      ),
    );
  }

  Future<void> _showEditDialog(String title, TextEditingController controller, {int maxLines = 1}) async {
    final tempController = TextEditingController(text: controller.text);
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey.shade900,
          title: Text('แก้ไข$title', style: const TextStyle(color: Colors.white)),
          content: TextField(
            controller: tempController,
            maxLines: maxLines,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey.shade800,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('ยกเลิก', style: TextStyle(color: Colors.white70)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('บันทึก', style: TextStyle(color: Colors.yellow.shade700)),
              onPressed: () {
                setState(() {
                  controller.text = tempController.text;
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}

// Custom Clipper for the wave effect
class WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(0, size.height - 50);
    var firstControlPoint = Offset(size.width / 4, size.height);
    var firstEndPoint = Offset(size.width / 2.25, size.height - 30.0);
    path.quadraticBezierTo(firstControlPoint.dx, firstControlPoint.dy,
        firstEndPoint.dx, firstEndPoint.dy);

    var secondControlPoint =
    Offset(size.width - (size.width / 3.25), size.height - 65);
    var secondEndPoint = Offset(size.width, size.height - 40);
    path.quadraticBezierTo(secondControlPoint.dx, secondControlPoint.dy,
        secondEndPoint.dx, secondEndPoint.dy);

    path.lineTo(size.width, size.height - 40);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
