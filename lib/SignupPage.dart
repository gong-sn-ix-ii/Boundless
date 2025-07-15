import 'package:boundless/main_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

// Import หน้าที่คุณต้องการไปหลังจากสมัครสำเร็จ
import 'package:boundless/Chat.dart'; // ตัวอย่าง: ไปที่หน้า Chat
import 'package:boundless/SigninPage.dart'; // หน้าสำหรับเข้าสู่ระบบ

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  // --- 1. จัดการ State และ Controllers ---
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // เพิ่ม Controller สำหรับยืนยันรหัสผ่าน
  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController =
      TextEditingController(); // <--- เพิ่ม Controller
  final _phoneController = TextEditingController();

  // สร้าง Instance ของ Firebase เพื่อความสะดวก
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  @override
  void dispose() {
    // อย่าลืม dispose controllers ทั้งหมด
    _displayNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose(); // <--- เพิ่ม dispose
    _phoneController.dispose();
    super.dispose();
  }

  // --- 2. ฟังก์ชันสำหรับ Logic การสมัครสมาชิก ---
  Future<void> _signUp() async {
    // การตรวจสอบ validation จะจัดการเรื่องรหัสผ่านไม่ตรงกันให้เอง
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      // ขั้นตอนที่ 1: สร้างผู้ใช้ใน Firebase Authentication
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text
                .trim(), // ใช้รหัสผ่านจาก controller ตัวแรก
          );

      User? newUser = userCredential.user;

      if (newUser != null) {
        // ขั้นตอนที่ 2: สร้าง Document ของผู้ใช้ใน Firestore Collection 'users'
        await _firestore.collection('users').doc(newUser.uid).set({
          'uid': newUser.uid,
          'displayName': _displayNameController.text.trim(),
          'email': _emailController.text.trim(),
          'phoneNumber': _phoneController.text.trim(),
          'photoUrl': '',
          'lastSeen': FieldValue.serverTimestamp(),
        });

        await newUser.updateDisplayName(_displayNameController.text.trim());

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => MainPage()),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      String message = 'เกิดข้อผิดพลาด';
      if (e.code == 'email-already-in-use') {
        message = 'อีเมลนี้ถูกใช้งานแล้ว';
      } else if (e.code == 'weak-password') {
        message = 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // --- 3. สร้าง UI ตามดีไซน์ใหม่ ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'BOUNDLESS',
          style: TextStyle(
            color: Color(0xFFF3B716),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.black,
        elevation: 0.5,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 50.0, vertical: 60.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Image.asset('assets/Logo_boundless_original.png', height: 100),
              const SizedBox(height: 48),

              _buildTextField(
                controller: _displayNameController,
                labelText: 'ชื่อผู้ใช้',
                validator: (value) =>
                    value!.isEmpty ? 'กรุณากรอกชื่อผู้ใช้' : null,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _emailController,
                labelText: 'อีเมล',
                keyboardType: TextInputType.emailAddress,
                validator: (value) => !(value?.contains('@') ?? false)
                    ? 'กรุณากรอกอีเมลให้ถูกต้อง'
                    : null,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _passwordController,
                labelText: 'รหัสผ่าน',
                obscureText: true,
                validator: (value) => (value?.length ?? 0) < 6
                    ? 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร'
                    : null,
              ),
              const SizedBox(height: 16),
              // --- เพิ่มช่องยืนยันรหัสผ่าน ---
              _buildTextField(
                controller: _confirmPasswordController,
                labelText: 'ยืนยันรหัสผ่าน',
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'กรุณายืนยันรหัสผ่าน';
                  }
                  if (value != _passwordController.text) {
                    return 'รหัสผ่านไม่ตรงกัน';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _phoneController,
                labelText: 'เบอร์โทรศัพท์',
                keyboardType: TextInputType.phone,
                validator: (value) =>
                    value!.isEmpty ? 'กรุณากรอกเบอร์โทรศัพท์' : null,
              ),
              const SizedBox(height: 70),

              SizedBox(
                width:
                    MediaQuery.of(context).size.width *
                    0.5, // ปรับให้ยาวประมาณ 50% ของหน้าจอ
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _signUp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFF3B716),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: _isLoading
                      ? const SpinKitRing(
                          color: Colors.white,
                          lineWidth: 3,
                          size: 24,
                        )
                      : const Text(
                          'ยืนยัน',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 2),

              // ปุ่มสำหรับไปหน้าเข้าสู่ระบบ
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const SignInPage()),
                  );
                },
                child: const Text(
                  'มีบัญชีอยู่แล้ว? เข้าสู่ระบบ',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
      // bottomNavigationBar: BottomNavigationBar(
      //   items: const [
      //     BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
      //     BottomNavigationBarItem(icon: Icon(Icons.gavel_outlined), label: 'Service'),
      //     BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
      //   ],
      //   currentIndex: 2,
      //   selectedItemColor: Colors.black,
      //   unselectedItemColor: Colors.grey,
      //   showSelectedLabels: false,
      //   showUnselectedLabels: false,
      //   type: BottomNavigationBarType.fixed,
      // ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          labelText,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            hintText: 'กรอก$labelText',
            filled: true,
            fillColor: Colors.grey[500],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }
}
