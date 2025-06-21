import 'package:boundless/main_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

// Import หน้าที่คุณต้องการไปหลังจากล็อกอินสำเร็จ และหน้าสมัครสมาชิก
import 'package:boundless/Chat.dart';
import 'package:boundless/SignUpPage.dart'; // สมมติว่าไฟล์ที่แล้วชื่อ SignUpPage.dart

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  // --- 1. จัดการ State และ Controllers ---
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _auth = FirebaseAuth.instance;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- 2. ฟังก์ชันสำหรับ Logic การเข้าสู่ระบบ ---
  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      // ใช้ signInWithEmailAndPassword เพื่อเข้าสู่ระบบ
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // ถ้าสำเร็จ ให้ไปที่หน้าต่อไป
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => MainPage()),
        );
      }
    } on FirebaseAuthException catch (e) {

      String message = 'อีเมลหรือรหัสผ่านไม่ถูกต้อง';
      if (e.code == 'invalid-credential') {
        message = 'อีเมลหรือรหัสผ่านไม่ถูกต้อง';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // --- 3. สร้าง UI สำหรับหน้าเข้าสู่ระบบ ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('BOUNDLESS', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // โลโก้
              Image.asset(
                'assets/logo_boundless.PNG', // ตรวจสอบว่า path ถูกต้อง
                height: 120,
              ),
              const SizedBox(height: 48),

              // ช่องกรอกอีเมล
              _buildTextField(
                controller: _emailController,
                labelText: 'อีเมล',
                hintText: 'กรอกอีเมล',
                keyboardType: TextInputType.emailAddress,
                validator: (value) => !(value?.contains('@') ?? false) ? 'กรุณากรอกอีเมลให้ถูกต้อง' : null,
              ),
              const SizedBox(height: 16),

              // ช่องกรอกรหัสผ่าน
              _buildTextField(
                controller: _passwordController,
                labelText: 'รหัสผ่าน',
                hintText: 'กรอกรหัสผ่าน',
                obscureText: true,
                validator: (value) => (value?.length ?? 0) < 6 ? 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร' : null,
              ),
              const SizedBox(height: 40),

              // ปุ่มเข้าสู่ระบบ
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _signIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: _isLoading
                      ? const SpinKitRing(color: Colors.white, lineWidth: 3, size: 24)
                      : const Text('เข้าสู่ระบบ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),

              // ปุ่มสำหรับไปหน้าสมัครสมาชิก
              // TextButton(
              //   onPressed: () {
              //     Navigator.of(context).push(
              //       MaterialPageRoute(builder: (context) => const SignUpPage()),
              //     );
              //   },
              //   child: const Text('ยังไม่มีบัญชี? สมัครสมาชิก'),
              // ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.gavel_outlined), label: 'Service'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
        currentIndex: 2, // สมมติว่าหน้านี้คือหน้า Profile
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

  // Helper method สำหรับสร้าง TextFormField ให้เหมือนกัน
  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(labelText, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            hintText: hintText,
            filled: true,
            fillColor: Colors.grey[200],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
}
