import 'package:flutter/material.dart';

class ProfilePage extends StatelessWidget {
  // รูปจำลอง (แทนรูปที่โพสต์ไว้)
  final List<String> imageUrls = List.generate(
    20,
    (index) => 'https://picsum.photos/id/${index + 10}/200/200',
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text('Username', style: TextStyle(color: Colors.yellow)),
        actions: [
          IconButton(
            icon: Icon(Icons.menu, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // ส่วนโปรไฟล์ด้านบน
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ชื่อแสดงด้านบน
                Text(
                  'Kanta Kittiitthiwat',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                SizedBox(height: 12),

                // แถวรูปโปรไฟล์ + stat
                Row(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundImage: NetworkImage(
                        'https://i.pravatar.cc/150?random=5',
                      ),
                    ),
                    SizedBox(width: 20),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatColumn('Posts', '24'),
                          _buildStatColumn('Followers', '1.2K'),
                          _buildStatColumn('Following', '180'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Bio
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'ชื่อนี้มีแต่ให้ 🤍\nชอบถ่ายภาพ | นักเดินทาง 🌏',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ),
          SizedBox(height: 16),
          Divider(color: Colors.white24),
          SizedBox(height: 10),
          
          // Grid แนวนอนแบบ 4 แถว
          Container(
            
            height:
                (MediaQuery.of(context).size.width / 3) * 3, // +6 เผื่อช่องว่าง
            child: GridView.builder(
              scrollDirection: Axis.horizontal, // แนวนอน
              itemCount: imageUrls.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, // แสดง 4 แถว
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
                childAspectRatio: 1, // ให้จัตุรัส
              ),
              itemBuilder: (context, index) {
                return Image.network(imageUrls[index], fit: BoxFit.cover);
              },
            ),
          ),
        ],
      ),
    );
  }

  // ฟังก์ชันย่อยสร้างคอลัมน์สถิติ
  Widget _buildStatColumn(String label, String count) {
    return Column(
      children: [
        Text(
          count,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.white70)),
      ],
    );
  }
}
