// ไฟล์: auction_page.dart
import 'package:boundless/SigninPage.dart';
import 'package:flutter/material.dart';
import '../Chat.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'auction_detail_page.dart';

class AuctionPage extends StatelessWidget {
  const AuctionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width; // ดึงขนาดหน้าจอ

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          'Boundless',
          style: TextStyle(
            color: Colors.yellow,
            fontWeight: FontWeight.bold,
            fontSize: screenWidth * 0.05, // ปรับตามหน้าจอ
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.chat_bubble_outline, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SignInPage()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(screenWidth * 0.02), // ปรับ padding
        child: LayoutBuilder(
          builder: (context, constraints) {
            // ตรวจขนาดหน้าจอเพื่อกำหนดจำนวน column
            int crossAxisCount = 2;
            if (constraints.maxWidth > 600) crossAxisCount = 3;
            if (constraints.maxWidth > 900) crossAxisCount = 4;

            return GridView.builder(
              itemCount: 8,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.65,
              ),
              itemBuilder: (context, index) {
                return AuctionCard(index: index);
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFF3B716),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        onPressed: () {
          // เพิ่มฟังก์ชันสร้างโพสต์ประมูลใหม่
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class AuctionCard extends StatelessWidget {
  final int index;
  const AuctionCard({super.key, required this.index});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final imageTag = 'auctionImage_$index'; // ใช้ tag เดียวกันกับ Hero

    return LayoutBuilder(
      builder: (context, constraints) {
        return AspectRatio(
          aspectRatio: 0.75,
          child: InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AuctionDetailPage(index: index),
                ),
              );
            },
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 2,
              child: Column(
                children: [
                  Hero(
                    tag: imageTag,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                      child: CachedNetworkImage(
                        imageUrl: 'https://picsum.photos/id/${index + 10}/200/110',
                        height: constraints.maxWidth * 0.6,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => SizedBox(
                          height: constraints.maxWidth * 0.6,
                          child: const Center(child: CircularProgressIndicator()),
                        ),
                        errorWidget: (context, url, error) => SizedBox(
                          height: constraints.maxWidth * 0.6,
                          child: const Center(child: Icon(Icons.broken_image)),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.all(screenWidth * 0.025),
                      child: Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "xxxxx",
                                    style: TextStyle(
                                      fontSize: screenWidth * 0.035,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "0 days     00:00:00",
                                    style: TextStyle(fontSize: screenWidth * 0.032),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "xxx บาท",
                                    style: TextStyle(
                                      fontSize: screenWidth * 0.035,
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "จำนวนผู้ประมูล 0 ครั้ง",
                                    style: TextStyle(fontSize: screenWidth * 0.032),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color.fromARGB(255, 200, 200, 200),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              child: Text(
                                "เข้าร่วมประมูล",
                                style: TextStyle(
                                  fontSize: screenWidth * 0.035,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
