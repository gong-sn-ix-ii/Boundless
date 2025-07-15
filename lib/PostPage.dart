import 'package:boundless/Chat.dart';
import 'package:boundless/SigninPage.dart';
import 'package:boundless/components/PostBox_old.dart';
import 'package:flutter/material.dart';

class PostPage extends StatelessWidget {
  const PostPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Scaffold และ AppBar จะถูกจัดการในหน้านี้
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Boundless',
          style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (context) => const SignInPage()));
            },
          ),
        ],
      ),
      // --- แก้ไขตรงนี้: เอา Column ออก แล้วใส่ ListView.builder เป็น body โดยตรง ---
      body: ListView.builder(
        itemCount: 10,
        itemBuilder: (context, index) {
          // แก้ไขตัวแปร idnex เป็น index
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: PostBox(
              username: "Username_90909",
              avatarUrl:
                  "https://i.pravatar.cc/150?u=1001", // ใช้ URL ที่แตกต่างกันเพื่อให้เห็นภาพ
              postImageUrl:
                  "https://imageio.forbes.com/specials-images/imageserve/5d35eacaf1176b0008974b54/0x0.jpg?format=jpg&crop=4560,2565,x790,y784,safe&height=900&width=1600&fit=bounds",
              caption: "รถเท่ห์ สำหรับคนเท่ห์ๆ #sunset #travel",
            ),
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: 'Home',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.refresh), label: 'Refresh'),

          BottomNavigationBarItem(
            icon: Icon(Icons.add_box_outlined),
            label: 'Post',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.gavel_outlined),
            label: 'Service',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
        currentIndex: 0, // ควรเป็น 0 ถ้าหน้านี้คือหน้า Home
        selectedItemColor:
            Colors.white, // เปลี่ยนเป็นสีขาวเพื่อให้มองเห็นบนพื้นดำ
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.black, // ตั้งค่าพื้นหลังให้เข้ากัน
        showSelectedLabels: false,
        showUnselectedLabels: false,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
