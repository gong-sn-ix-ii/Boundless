// lib/pages/edit_auction_page.dart

import 'dart:io';
import 'package:boundless/services/Service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class EditAuctionPage extends StatefulWidget {
  final String auctionId;
  const EditAuctionPage({super.key, required this.auctionId});

  @override
  State<EditAuctionPage> createState() => _EditAuctionPageState();
}

class _EditAuctionPageState extends State<EditAuctionPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;

  // Controllers
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Image Management
  final ImagePicker _picker = ImagePicker();
  List<String> _existingImageUrls = [];
  List<XFile> _newImages = [];
  final List<String> _imagesToDelete = [];

  // Date Management
  DateTime? _startTime;
  DateTime? _endTime;

  @override
  void initState() {
    super.initState();
    _loadAuctionData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadAuctionData() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('auctions').doc(widget.auctionId).get();
      if (doc.exists) {
        final data = doc.data()!;
        _titleController.text = data['title'] ?? '';
        _descriptionController.text = data['description'] ?? '';

        setState(() {
          _existingImageUrls = List<String>.from(data['imageUrls'] ?? []);
          _startTime = (data['startTime'] as Timestamp?)?.toDate();
          _endTime = (data['endTime'] as Timestamp?)?.toDate();
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error loading auction data: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("เกิดข้อผิดพลาดในการโหลดข้อมูล: $e")));
        Navigator.pop(context);
      }
    }
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage(imageQuality: 80);
      if (pickedFiles.isNotEmpty) {
        setState(() {
          _newImages.addAll(pickedFiles);
        });
      }
    } catch (e) {
      print("Error picking images: $e");
    }
  }

  void _removeExistingImage(int index) {
    setState(() {
      final urlToDelete = _existingImageUrls.removeAt(index);
      _imagesToDelete.add(urlToDelete);
    });
  }

  void _removeNewImage(int index) {
    setState(() {
      _newImages.removeAt(index);
    });
  }

  Future<File?> _compressImage(XFile file) async {
    final tempDir = await getTemporaryDirectory();
    final path = tempDir.path;
    final targetPath = p.join(path,'${DateTime.now().millisecondsSinceEpoch}_${p.basename(file.path)}.jpg');

    final result = await FlutterImageCompress.compressAndGetFile(
      file.path,
      targetPath,
      quality: 70,
      minWidth: 1080,
      minHeight: 1080,
    );

    return result != null ? File(result.path) : null;
  }

  Future<List<String>> _uploadNewImages(String currentUserUid) async {
    List<String> uploadedUrls = [];
    for (var imageXFile in _newImages) {
      final compressedFile = await _compressImage(imageXFile);
      if (compressedFile == null) continue;

      final uniqueFileName = '${DateTime.now().millisecondsSinceEpoch}_${p.basename(compressedFile.path)}';
      final storageRef = FirebaseStorage.instance.ref().child('auction_images/$currentUserUid/$uniqueFileName');

      await storageRef.putFile(compressedFile);
      final downloadUrl = await storageRef.getDownloadURL();
      uploadedUrls.add(downloadUrl);
    }
    return uploadedUrls;
  }

  Future<void> _deleteMarkedImages() async {
    for (var url in _imagesToDelete) {
      try {
        final ref = FirebaseStorage.instance.refFromURL(url);
        await ref.delete();
      } catch (e) {
        print("Failed to delete image $url: $e");
      }
    }
  }


  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    if (_existingImageUrls.isEmpty && _newImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("กรุณาเพิ่มรูปภาพอย่างน้อย 1 รูป")));
      return;
    }

    setState(() { _isSaving = true; });

    try {
      final currentUserUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserUid == null) throw Exception("ไม่พบผู้ใช้");

      // 1. Upload new images and get URLs
      final newUploadedUrls = await _uploadNewImages(currentUserUid);

      // 2. Delete images marked for deletion from Storage
      await _deleteMarkedImages();

      // 3. Prepare final list of image URLs for Firestore
      final finalImageUrls = [
        ..._existingImageUrls,
        ...newUploadedUrls,
      ];

      // 4. Prepare data for Firestore update
      final Map<String, dynamic> updatedData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'imageUrls': finalImageUrls,
        'startTime': _startTime,
        'endTime': _endTime,
      };

      // 5. Update Firestore document
      await FirebaseFirestore.instance.collection('auctions').doc(widget.auctionId).update(updatedData);

      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("บันทึกการเปลี่ยนแปลงเรียบร้อยแล้ว"), backgroundColor: Colors.green,));
        Navigator.pop(context);
      }

    } catch (e) {
      print("Error saving changes: $e");
      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("เกิดข้อผิดพลาด: $e"), backgroundColor: Colors.red,));
      }
    } finally {
      if(mounted){
        setState(() { _isSaving = false; });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('แก้ไขการประมูล', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveChanges,
            child: Text(
              'บันทึก',
              style: TextStyle(
                color: _isSaving ? Colors.grey : Colors.yellow.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.yellow))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader("รูปภาพสินค้า"),
              _buildImagePickerSection(),
              const SizedBox(height: 24),

              _buildSectionHeader("รายละเอียด"),
              TextFormField(
                controller: _titleController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('ชื่อสินค้าประมูล'),
                validator: (v) => v!.isEmpty ? 'กรุณากรอกชื่อสินค้า' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                style: const TextStyle(color: Colors.white),
                maxLines: 4,
                decoration: _inputDecoration('รายละเอียดสินค้า'),
                validator: (v) => v!.isEmpty ? 'กรุณากรอกรายละเอียด' : null,
              ),
              const SizedBox(height: 24),

              // 🔽 [แก้ไข] เปลี่ยนไปใช้ UI แบบใหม่
              _buildSectionHeader("กำหนดเวลา"),
              _buildTimeSettingTile(
                iconData: Icons.play_arrow,
                title: "ตั้งเวลาเริ่มประมูล",
                subtitle: _startTime != null
                    ? DateFormat('dd MMM yyyy, HH:mm').format(_startTime!)
                    : "ปล่อยว่างเพื่อเริ่มทันที",
                onTap: () async {
                  DateTime? pickedDate = await _showDateTimePicker(_startTime ?? DateTime.now());
                  if (pickedDate != null) setState(() => _startTime = pickedDate);
                },
              ),
              const SizedBox(height: 12),
              _buildTimeSettingTile(
                iconData: Icons.timer,
                title: "ตั้งเวลาสิ้นสุดการประมูล",
                subtitle: _endTime != null
                    ? DateFormat('dd MMM yyyy, HH:mm').format(_endTime!)
                    : "ยังไม่ได้ตั้งค่า",
                onTap: () async {
                  DateTime? pickedDate = await _showDateTimePicker(
                      _endTime ?? DateTime.now().add(const Duration(days: 1)));
                  if (pickedDate != null) {
                    if (_startTime != null && pickedDate.isBefore(_startTime!)) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text("เวลาสิ้นสุดต้องอยู่หลังเวลาเริ่มต้น")));
                    } else {
                      setState(() => _endTime = pickedDate);
                    }
                  }
                },
              ),
              const SizedBox(height: 40),
              if (_isSaving) const Center(child: CircularProgressIndicator(color: Colors.yellow)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(title, style: const TextStyle(color: Colors.yellow, fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      filled: true,
      fillColor: Colors.grey.shade900,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    );
  }

  Widget _buildImagePickerSection() {
    final allImagesCount = _existingImageUrls.length + _newImages.length;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: allImagesCount + 1,
      itemBuilder: (context, index) {
        // The last item is the "add" button
        if (index == allImagesCount) {
          return GestureDetector(
            onTap: _pickImages,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade700, width: 1),
              ),
              child: const Icon(Icons.add_a_photo_outlined, color: Colors.grey, size: 30),
            ),
          );
        }

        // Display existing images first
        if (index < _existingImageUrls.length) {
          final imageUrl = _existingImageUrls[index];
          return Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(imageUrl, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
              ),
              Positioned(
                top: -8, right: -8,
                child: GestureDetector(
                  onTap: () => _removeExistingImage(index),
                  child: Container(
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    child: const Icon(Icons.close, color: Colors.white, size: 16),
                  ),
                ),
              ),
            ],
          );
        }

        // Display new images
        final newImageIndex = index - _existingImageUrls.length;
        final newImageFile = _newImages[newImageIndex];
        return Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(File(newImageFile.path), fit: BoxFit.cover, width: double.infinity, height: double.infinity),
            ),
            Positioned(
              top: -8, right: -8,
              child: GestureDetector(
                onTap: () => _removeNewImage(newImageIndex),
                child: Container(
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // 🔽 [สร้างใหม่] Helper widget สำหรับสร้าง UI ตั้งเวลาแบบใหม่
  Widget _buildTimeSettingTile({
    required IconData iconData,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.yellow.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(iconData, color: Colors.yellow.shade700, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Future<DateTime?> _showDateTimePicker(DateTime initialDate) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate == null) return null;

    if (!mounted) return null;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );

    if (pickedTime == null) return null;

    return DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
  }
}

