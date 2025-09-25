// settings_page.dart
import 'package:boundless/pages/security_page.dart';
import 'package:flutter/material.dart';
import 'edit_profile_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:boundless/HomePage.dart'; // นำเข้า MainPage เพื่อใช้ในการนำทางกลับไปหน้า Login
import 'package:boundless/main.dart';

class SettingsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text("Settings", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: ListView(
        children: [
          ListTile(
            leading: Icon(Icons.person, color: Colors.white),
            title: Text("Edit Profile", style: TextStyle(color: Colors.white)),
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => EditProfilePage()),
              );
              Navigator.pop(context, result); // ส่งค่ากลับ ProfilePage
            },
          ),
          ListTile(
            leading: Icon(Icons.lock, color: Colors.white),
            title: Text("Security", style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SecurityPage()),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.logout, color: Colors.red),
            title: Text("Logout", style: TextStyle(color: Colors.white)),
            onTap: () {
              // แสดงกล่องโต้ตอบเพื่อยืนยัน
              showDialog(
                context: context,
                builder: (BuildContext dialogContext) {
                  return AlertDialog(
                    backgroundColor: Colors.grey[850],
                    title: Text("ต้องการออกจากระบบใช่หรือไม่?", style: TextStyle(color: Colors.white, fontSize: 16)),
                    content: Text("Are you sure you want to logout?", style: TextStyle(color: Colors.white70)),
                    actions: <Widget>[
                      TextButton(
                        child: Text("ยกเลิก", style: TextStyle(color: Colors.white)),
                        onPressed: () {
                          Navigator.of(dialogContext).pop(); // ปิดแค่ Dialog
                        },
                      ),
                      TextButton(
                        child: Text("ออกจากระบบ", style: TextStyle(color: Colors.red)),
                        onPressed: () async {
                          // --- ใส่โค้ด Logout เดิมของคุณไว้ที่นี่ ---
                          try {
                            await FirebaseAuth.instance.signOut();
                            if (!context.mounted) return;
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (context) => MyApp()),
                                  (Route<dynamic> route) => false,
                            );
                          } catch (e) {
                            print("Error signing out: $e");
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("เกิดข้อผิดพลาด: $e")),
                            );
                          }
                        },
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
