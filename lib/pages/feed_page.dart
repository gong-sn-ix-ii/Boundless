import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

class FeedPage extends StatefulWidget {
  @override
  _FeedPageState createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  final List<Map<String, String>> posts = [
    {
      'username': 'john_doe',
      'imageUrl': 'https://picsum.photos/400/300?random=1',
      'caption':
          'Beautiful sunset! This is a very long caption that should be trimmed down to two lines and then expandable.',
    },
    {
      'username': 'jane_smith',
      'imageUrl': 'https://picsum.photos/400/300?random=2',
      'caption': 'Amazing view!',
    },
    {
      'username': 'The_Awesome',
      'imageUrl': 'https://picsum.photos/400/300?random=3',
      'caption':
          'AWESOME! This caption is way too long so it needs to be collapsed until the user expands it to view more text about the awesome experience!',
    },
  ];

  final Map<int, bool> _isExpandedMap = {};

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width; // ดึงความกว้างหน้าจอ
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          'Boundless',
          style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold,fontSize: screenWidth * 0.05, ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.chat_bubble_outline, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ChatPage()),
              );
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: posts.length,
        itemBuilder: (context, index) {
          final post = posts[index];
          final isExpanded = _isExpandedMap[index] ?? false;
          return Padding(
            padding: EdgeInsets.all(screenWidth * 0.025), // ปรับระยะห่างตามขนาดหน้าจอ
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                color: Color(0xFF2d292a),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: screenWidth * 0.05,
                      vertical: 10,
                    ),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: Image.network(
                        'https://i.pravatar.cc/150?u=${post['username']}',
                        width: screenWidth * 0.1, // ปรับให้สัมพันธ์หน้าจอ
                        height: screenWidth * 0.1,
                        fit: BoxFit.cover,
                      ),
                    ),
                    title: Text(
                      post['username']!,
                      style: TextStyle(
                        fontSize: screenWidth * 0.045,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    trailing: Icon(Icons.favorite_border, color: Colors.white),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          post['imageUrl']!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: screenWidth * 0.04,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.face, color: Colors.white),
                        SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: Text(
                            post['username']!,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: screenWidth * 0.04,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Icon(Icons.comment, color: Colors.white),
                        SizedBox(width: 8),
                        // ใช้ Flexible เพื่อให้ TextField ยืดตามหน้าจอ
                        Flexible(
                          flex: 5,
                          child: Container(
                            height: 30,
                            decoration: BoxDecoration(
                              color: const Color.fromARGB(255, 68, 68, 68),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: TextField(
                              style: TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'คอมเม้นท์...',
                                hintStyle: TextStyle(color: Colors.white70),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: isExpanded
                                    ? post['caption']
                                    : (post['caption']!.length > 100
                                        ? post['caption']!.substring(0, 100)
                                        : post['caption']),
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: screenWidth * 0.035,
                                  height: 1.4,
                                  shadows: [
                                    Shadow(
                                      offset: Offset(0.5, 0.5),
                                      blurRadius: 0.5,
                                      color: Colors.black45,
                                    ),
                                  ],
                                ),
                              ),
                              if ((post['caption']?.length ?? 0) > 100)
                                TextSpan(
                                  text: isExpanded
                                      ? ' ย่อข้อความ'
                                      : ' ... อ่านเพิ่มเติม',
                                  style: TextStyle(
                                    color: Colors.yellow,
                                    fontSize: screenWidth * 0.035,
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.underline,
                                    shadows: [
                                      Shadow(
                                        offset: Offset(0.3, 0.3),
                                        blurRadius: 0.5,
                                        color: Colors.black,
                                      ),
                                    ],
                                  ),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () {
                                      setState(() {
                                        _isExpandedMap[index] = !isExpanded;
                                      });
                                    },
                                ),
                            ],
                          ),
                          maxLines: isExpanded ? null : 2,
                          overflow: isExpanded
                              ? TextOverflow.visible
                              : TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 10),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFF3B716),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        onPressed: () {
          // เพิ่มฟังก์ชันสร้างโพสต์ใหม่
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

// หน้าแชทจำลอง
class ChatPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Chats',
          style: TextStyle(
            color: Colors.yellow,
            fontWeight: FontWeight.bold,
            fontSize: screenWidth * 0.05,
          ),
        ),
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Center(
        child: Text(
          'หน้านี้สำหรับแชท (ยังไม่เชื่อมระบบจริง)',
          style: TextStyle(
            color: Colors.white,
            fontSize: screenWidth * 0.04,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
