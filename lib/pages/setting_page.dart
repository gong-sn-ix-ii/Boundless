// settings_page.dart
import 'package:flutter/material.dart';
import 'edit_profile_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:boundless/main_page.dart'; // นำเข้า MainPage เพื่อใช้ในการนำทางกลับไปหน้า Login
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
              // ยังไม่ทำหน้านี้
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("ยังไม่ได้ทำหน้านี้นะ ")),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.logout, color: Colors.white),
            title: Text("Logout", style: TextStyle(color: Colors.white)),
            onTap: () async {
              // ยังไม่ได้ผูกระบบ auth
              // Navigator.pop(context);
              // ScaffoldMessenger.of(context).showSnackBar(
              //   SnackBar(content: Text("ออกจากระบบเรียบร้อย")),
              // );

              try {
                // --- 1. สั่งให้ Firebase ทำการออกจากระบบ ---
                await FirebaseAuth.instance.signOut();

                print("User signed out successfully.");

                // --- 2. (สำคัญมาก) นำผู้ใช้กลับไปที่หน้า Login ---
                // ตรวจสอบ context ก่อนใช้งาน (เป็น Best Practice ป้องกัน Error)
                if (!context.mounted) return;

                // นำทางกลับไปหน้า Login และล้างหน้าจอก่อนหน้าทั้งหมดทิ้งไป
                // เพื่อไม่ให้ผู้ใช้กด 'ย้อนกลับ' กลับมาหน้านี้ได้อีก
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => MyApp()), // <-- แก้เป็นหน้า Login ของคุณ
                      (Route<dynamic> route) => false, // คำสั่งให้ลบ Route เก่าทั้งหมด
                );

              } catch (e) {
                // จัดการ Error ที่อาจเกิดขึ้น (เช่น ปัญหา Network)
                print("Error signing out: $e");

                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("เกิดข้อผิดพลาดในการออกจากระบบ: $e")),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
