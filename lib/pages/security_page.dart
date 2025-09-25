import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SecurityPage extends StatefulWidget {
  const SecurityPage({super.key});

  @override
  State<SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends State<SecurityPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _user;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _isEmailEditable = false; // ✅ นำตัวแปรนี้กลับมาใช้
  bool _isPhoneEditable = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    _user = _auth.currentUser;
    if (_user != null) {
      final docSnapshot =
      await _firestore.collection('users').doc(_user!.uid).get();

      if (docSnapshot.exists && mounted) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        _emailController.text = data['email'] ?? _user!.email ?? 'No email';
        _phoneController.text = data['phoneNumber'] ?? 'No phone number';
        setState(() {});
      } else if (mounted) {
        _emailController.text = _user!.email ?? 'No email';
        _phoneController.text = _user!.phoneNumber ?? 'No phone number';
        setState(() {});
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<bool> _reauthenticateUser(String password) async {
    if (_user == null) return false;
    setState(() => _isLoading = true);
    try {
      final cred =
      EmailAuthProvider.credential(email: _user!.email!, password: password);
      await _user!.reauthenticateWithCredential(cred);
      return true;
    } on FirebaseAuthException catch (e) {
      _showSnackBar('Error: ${e.message}', isError: true);
      return false;
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _promptForCurrentPassword(VoidCallback onAuthenticated) {
    _passwordController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: const Text('Confirm Your Identity',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: _passwordController,
          obscureText: true,
          style: const TextStyle(color: Colors.white),
          decoration: _buildInputDecoration('Enter your current password'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () async {
              final password = _passwordController.text;
              Navigator.pop(context);
              if (await _reauthenticateUser(password)) {
                onAuthenticated();
              }
            },
            child:
            Text('Confirm', style: TextStyle(color: Colors.yellow.shade700)),
          ),
        ],
      ),
    );
  }

  // ✅ นำฟังก์ชันเปลี่ยนอีเมลแบบยืนยันในแอปกลับมา
  void _handleChangeEmail() async {
    if (_user == null) return;
    final newEmail = _emailController.text.trim();
    setState(() => _isLoading = true);
    try {
      // เหลือแค่บรรทัดนี้พอ! แอปมีหน้าที่แค่สั่งให้ Auth เริ่มกระบวนการ
      await _user!.verifyBeforeUpdateEmail(newEmail);

      _showSnackBar('Verification email sent to $newEmail. Please check your inbox.');
      setState(() => _isEmailEditable = false);
    } on FirebaseAuthException catch (e) {
      _showSnackBar('Error: ${e.message}', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _handleChangePassword() {
    _promptForCurrentPassword(() {
      _newPasswordController.clear();
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.grey[850],
          title: const Text('Set New Password',
              style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: _newPasswordController,
            obscureText: true,
            style: const TextStyle(color: Colors.white),
            decoration: _buildInputDecoration('Enter your new password'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white)),
            ),
            TextButton(
              onPressed: () async {
                setState(() => _isLoading = true);
                Navigator.pop(context);
                try {
                  await _user!.updatePassword(_newPasswordController.text.trim());
                  _showSnackBar('Password updated successfully.');
                } on FirebaseAuthException catch (e) {
                  _showSnackBar('Error: ${e.message}', isError: true);
                } finally {
                  setState(() => _isLoading = false);
                }
              },
              child:
              Text('Update', style: TextStyle(color: Colors.yellow.shade700)),
            ),
          ],
        ),
      );
    });
  }

  void _handleSendResetEmail() async {
    if (_user?.email == null) {
      _showSnackBar('No email address found.', isError: true);
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _auth.sendPasswordResetEmail(email: _user!.email!);
      _showSnackBar('Password reset email sent to ${_user!.email}.');
    } on FirebaseAuthException catch (e) {
      _showSnackBar('Error: ${e.message}', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _handleChangePhone() async {
    if (_user == null) return;
    final newPhone = _phoneController.text.trim();
    setState(() => _isLoading = true);
    try {
      await _firestore.collection('users').doc(_user!.uid).update({
        'phoneNumber': newPhone,
      });
      _showSnackBar('เบอร์โทรศัพท์ได้ถูกบันทึกเรียบร้อยแล้ว');
      setState(() => _isPhoneEditable = false);
    } catch (e) {
      _showSnackBar('พบปัญหาในการบันทึกเบอร์โทรศัพท์: ${e.toString()}',
          isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Security', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          if (_user == null)
            const Center(
                child: Text('No user logged in.',
                    style: TextStyle(color: Colors.white)))
          else
            ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                _buildSectionHeader('Account Information'),
                _buildTextField(
                    _emailController, 'Email', Icons.email, _isEmailEditable),
                // ✅ แก้ไขส่วนของปุ่ม Email กลับเป็นเหมือนเดิม
                if (_isEmailEditable)
                  _buildActionButton('Save Email', _handleChangeEmail)
                else
                  _buildActionButton('Change Email', () {
                    _promptForCurrentPassword(() {
                      setState(() => _isEmailEditable = true);
                    });
                  }),
                const SizedBox(height: 16),
                _buildTextField(
                    _phoneController, 'Phone Number', Icons.phone, _isPhoneEditable),
                if (_isPhoneEditable)
                  _buildActionButton('Save Phone', _handleChangePhone)
                else
                  _buildActionButton('Change Phone', () {
                    setState(() => _isPhoneEditable = true);
                  }),
                _buildSectionHeader('Password'),
                _buildActionButton('Change Password', _handleChangePassword),
                // ✅ นำปุ่มส่งอีเมลรีเซ็ตรหัสผ่านกลับมา
                const SizedBox(height: 8),
                _buildActionButton(
                    'Send Password Reset Email', _handleSendResetEmail),
              ],
            ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child:
                CircularProgressIndicator(color: Colors.yellow.shade700),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
            color: Colors.grey.shade400,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      IconData icon, bool enabled) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      style: const TextStyle(color: Colors.white),
      decoration: _buildInputDecoration(label, icon: icon),
    );
  }

  Widget _buildActionButton(String text, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.yellow.shade700,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: onPressed,
        child: Text(text,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String labelText, {IconData? icon}) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: TextStyle(color: Colors.grey.shade400),
      prefixIcon:
      icon != null ? Icon(icon, color: Colors.grey.shade400) : null,
      filled: true,
      fillColor: Colors.grey.shade800,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade700),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.yellow.shade700),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade800),
      ),
    );
  }
}