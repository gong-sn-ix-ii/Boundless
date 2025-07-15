import 'package:flutter/material.dart';
import 'edit_profile_page.dart';
import 'setting_page.dart';


class ProfilePage extends StatefulWidget {
  
  @override
  _ProfilePageState createState() => _ProfilePageState();
}


class _ProfilePageState extends State<ProfilePage> {
  final List<String> imageUrls = List.generate(20,(index) => 'https://picsum.photos/id/${index + 10}/200/200',);
    
  String coverUrl = 'https://images.unsplash.com/photo-1607746882042-944635dfe10e';
  String profileUrl = 'https://i.pravatar.cc/150?img=10';

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          // 🔝 รูปปก – อยู่ล่างกว่าเพื่อให้วงกลมอยู่บน
          SizedBox(
            height: 220,
            width: double.infinity,
            child: Image.network(coverUrl, fit: BoxFit.cover),
          ),

          // ✅ วงกลมใหญ่อยู่ *บนรูปปก* และเลื่อนต่ำลงมาครึ่งจอ
          Positioned(
            top: MediaQuery.of(context).size.height * 0.13,
            left: -screenWidth * 0.5,
            child: Container(
              width: screenWidth * 2,
              height: screenWidth * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black,
              ),
            ),
          ),

          

          // 🔽 เนื้อหาเลื่อน
          SingleChildScrollView(

            padding: EdgeInsets.only(top: 100),
            child: Column(
              children: [
                // 🟡 รูปโปรไฟล์
                Center(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 4),
                    ),
                    child: CircleAvatar(
                      radius: 60,
                      backgroundImage: NetworkImage(profileUrl),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Kanta Kittiitthiwat',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatBox('Posts', '24'),
                    _buildStatBox('Followers', '1.2K'),
                    _buildStatBox('Following', '180'),
                  ],
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'ชื่อนี้มีแต่ให้ 🤍\nชอบถ่ายภาพ | นักเดินทาง 🌏',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 20),
                Divider(color: Colors.white24),
                const SizedBox(height: 10),

                // 📸 Grid แนวนอนแบบ 3 แถว
                Container(
                  height: (screenWidth / 3) * 3,
                  child: GridView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: imageUrls.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 2,
                      mainAxisSpacing: 2,
                      childAspectRatio: 1,
                    ),
                    itemBuilder: (context, index) {
                      return Image.network(imageUrls[index], fit: BoxFit.cover);
                    },
                  ),
                ),
              ],
            ),
          ),
        // 📍 ปุ่มสามขีด
          Positioned(
            top: 40,
            right: 16,
            child: IconButton(
              icon: Icon(Icons.menu, color: Colors.white),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SettingsPage()),
                );

                if (result != null && result is Map) {
                  setState(() {
                    coverUrl = result['cover'] ?? coverUrl;
                    profileUrl = result['profile'] ?? profileUrl;
                  });
                }
              },

            ),
          ),
        ],
      ),
    );
  }

  // Widget _buildStatColumn(String label, String count) {
  //   return Column(
  //     children: [
  //       Text(
  //         count,
  //         style: TextStyle(
  //           color: Colors.white,
  //           fontWeight: FontWeight.bold,
  //           fontSize: 18,
  //         ),
  //       ),
  //       const SizedBox(height: 4),
  //       Text(label, style: TextStyle(color: Colors.white70)),
  //     ],
  //   );
  // }

  Widget _buildStatBox(String label, String count) {
  return Column(
    children: [
      // 🔲 กรอบสีเทาครอบแค่ตัวเลข
      Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          count,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      const SizedBox(height: 4),
      // 🏷️ Label ด้านล่าง ไม่อยู่ในกรอบ
      Text(
        label,
        style: TextStyle(color: Colors.white70),
      ),
    ],
  );
}

}
