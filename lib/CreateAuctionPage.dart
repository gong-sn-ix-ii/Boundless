// lib/pages/create_auction_page.dart

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // � 1. เพิ่ม import สำหรับ InputFormatter
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class CreateAuctionPage extends StatefulWidget {
  const CreateAuctionPage({super.key});

  @override
  State<CreateAuctionPage> createState() => _CreateAuctionPageState();
}

class _CreateAuctionPageState extends State<CreateAuctionPage> {
  // --- State & Controllers ---
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _startPriceController = TextEditingController();
  final _bidIncrementController = TextEditingController();
  DateTime? _startTime;
  DateTime? _endTime;

  final ImagePicker _picker = ImagePicker();
  List<XFile> _selectedImages = [];
  bool _isProcessing = false;
  double _uploadProgress = 0.0;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _startPriceController.dispose();
    _bidIncrementController.dispose();
    super.dispose();
  }

  // --- Image Handling Logic ---
  Future<void> _pickImages() async {
    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage(imageQuality: 80);
      if (pickedFiles.isNotEmpty) {
        setState(() {
          _selectedImages = pickedFiles;
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

    final XFile? result = await FlutterImageCompress.compressAndGetFile(file.path, targetPath, quality: 70);

    if (result == null) {
      return null;
    }

    return File(result.path);
  }

  // --- Date & Time Picker Logic ---
  Future<void> _selectStartTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _startTime ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(minutes: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (pickedDate == null) return;
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startTime ?? DateTime.now()),
    );
    if (pickedTime != null) {
      setState(() {
        _startTime = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);
      });
    }
  }

  Future<void> _selectEndTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _endTime ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: _startTime ?? DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate == null) return;

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_endTime ?? DateTime.now()),
    );

    if (pickedTime != null) {
      setState(() {
        _endTime = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);
      });
    }
  }

  // --- Submit Logic (แก้ไขแล้ว) ---
  Future<void> _submitAuction() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ไม่พบข้อมูลผู้ใช้ กรุณาล็อกอินใหม่'), backgroundColor: Colors.red));
      return;
    }
    final currentUserUid = currentUser.uid;

    if (!_formKey.currentState!.validate()) return;
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณาเลือกรูปภาพอย่างน้อย 1 รูป'), backgroundColor: Colors.red));
      return;
    }
    if (_endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณาตั้งเวลาสิ้นสุดการประมูล'), backgroundColor: Colors.red));
      return;
    }
    if (_startTime != null && _endTime!.isBefore(_startTime!)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('เวลาสิ้นสุดต้องอยู่หลังเวลาเริ่มต้น'), backgroundColor: Colors.red));
      return;
    }

    setState(() {
      _isProcessing = true;
      _uploadProgress = 0.15;
    });

    try {
      final storageRef = FirebaseStorage.instance.ref();
      List<String> imageUrls = [];

      for (var imageFile in _selectedImages) {
        final compressedFile = await _compressImage(imageFile);
        if (compressedFile == null) continue;
        final uniqueFileName = '${DateTime.now().millisecondsSinceEpoch}_${p.basename(imageFile.path)}';
        final auctionImageRef = storageRef.child('auction_images/$currentUserUid/$uniqueFileName');
        await auctionImageRef.putFile(compressedFile);
        final url = await auctionImageRef.getDownloadURL();
        imageUrls.add(url);
      }

      if (imageUrls.length != _selectedImages.length) {
        throw Exception('เกิดข้อผิดพลาดในการอัปโหลดรูปภาพบางส่วน');
      }

      setState(() => _uploadProgress = 0.8);

      final startPrice = int.tryParse(_startPriceController.text) ?? 0;
      final bidIncrement = int.tryParse(_bidIncrementController.text) ?? 100;

      final auctionData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'imageUrls': imageUrls,
        'ownerUid': currentUserUid,
        'startTime': _startTime != null ? Timestamp.fromDate(_startTime!) : FieldValue.serverTimestamp(),
        'endTime': Timestamp.fromDate(_endTime!),
        'startPrice': startPrice,
        'currentBid': startPrice,
        'highestBidderUid': null,
        'bidIncrement': bidIncrement,
        'bidCount': 0,
        'status': 'active',
      };

      setState(() => _uploadProgress = 0.95);

      await FirebaseFirestore.instance.collection('auctions').add(auctionData);

      setState(() => _uploadProgress = 1.0);
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      print("Error submitting auction: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('สร้างการประมูล', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: _isProcessing ? null : _submitAuction,
            child: Text(
              'ลงประมูล',
              style: TextStyle(
                color: _isProcessing ? Colors.grey : Colors.yellow.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          )
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: _pickImages,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade900,
                            borderRadius: BorderRadius.circular(12),
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
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _titleController,
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                          maxLines: 4,
                          decoration: const InputDecoration(
                            hintText: 'ชื่อผลงาน/สินค้า...',
                            hintStyle: TextStyle(color: Colors.grey),
                            border: InputBorder.none,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'กรุณากรอกชื่อผลงาน';
                            }
                            return null;
                          },

                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24, height: 24),
                  ListTile(
                    leading: const Icon(Icons.add_photo_alternate_outlined, color: Colors.white),
                    title: Text(_selectedImages.isEmpty ? "Add Photos" : "${_selectedImages.length} photos selected", style: const TextStyle(color: Colors.white)),
                    onTap: _pickImages,
                  ),
                  if (_selectedImages.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0, bottom: 16),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 8, mainAxisSpacing: 8),
                        itemCount: _selectedImages.length,
                        itemBuilder: (context, index) {
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(File(_selectedImages[index].path), fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                              ),
                              Positioned(
                                top: -8,
                                right: -8,
                                child: GestureDetector(
                                  onTap: () => _removeImage(index),
                                  child: Container(
                                    decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                                    child: const Icon(Icons.close, color: Colors.white, size: 18),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  const Divider(color: Colors.white24, height: 24),
                  _buildTextFormField(controller: _descriptionController, labelText: 'คำอธิบายสินค้า', maxLines: 3),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      // ✨ 2. แก้ไขการเรียกใช้ Widget สำหรับช่องกรอกตัวเลข
                      Expanded(child: _buildTextFormField(
                          controller: _startPriceController,
                          labelText: 'ราคาเริ่มต้น (บาท)',
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly] // 👈 เพิ่มตัวกรอง
                      )),
                      const SizedBox(width: 16),
                      Expanded(child: _buildTextFormField(
                          controller: _bidIncrementController,
                          labelText: 'บิดเพิ่มขั้นต่ำ (บาท)',
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly] // 👈 เพิ่มตัวกรอง
                      )),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    tileColor: Colors.grey.shade900,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    leading: Icon(Icons.play_circle_fill_outlined, color: Colors.yellow.shade700),
                    title: Text(
                      _startTime == null ? 'ตั้งเวลาเริ่มประมูล (ปล่อยว่างเพื่อเริ่มทันที)' : 'เริ่ม: ${DateFormat('dd/MM/yyyy HH:mm').format(_startTime!)}',
                      style: const TextStyle(color: Colors.white),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                    onTap: _selectStartTime,
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    tileColor: Colors.grey.shade900,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    leading: Icon(Icons.timer_outlined, color: Colors.yellow.shade700),
                    title: Text(
                      _endTime == null ? 'ตั้งเวลาสิ้นสุดการประมูล' : 'สิ้นสุด: ${DateFormat('dd/MM/yyyy HH:mm').format(_endTime!)}',
                      style: const TextStyle(color: Colors.white),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                    onTap: _selectEndTime,
                  )
                ],
              ),
            ),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.85),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'กำลังสร้างการประมูล... (${(_uploadProgress * 100).toStringAsFixed(0)}%)',
                        style: TextStyle(color: Colors.yellow.shade700, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 20),
                      LinearProgressIndicator(
                        value: _uploadProgress,
                        backgroundColor: Colors.grey.shade800,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.yellow.shade700),
                        minHeight: 8,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ✨ 3. แก้ไข Helper Widget ให้รับ inputFormatters ได้
  Widget _buildTextFormField({
    required TextEditingController controller,
    required String labelText,
    int? maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters, // 👈 เพิ่มพารามิเตอร์
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters, // 👈 นำมาใช้งาน
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.grey.shade900,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade800)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.yellow.shade700)),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'กรุณากรอก$labelText';
        }
        if (keyboardType == TextInputType.number) {
          final number = int.tryParse(value);
          if (number == null) {
            return 'กรุณากรอกตัวเลขเท่านั้น';
          }
          if (number <= 0) {
            return 'กรุณากรอกค่าที่มากกว่า 0';
          }
        }
        return null;
      },
    );
  }
}
