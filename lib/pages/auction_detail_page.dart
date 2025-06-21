// ไฟล์: auction_detail_page.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AuctionDetailPage extends StatelessWidget {
  final int index;
  const AuctionDetailPage({super.key, required this.index});

  @override
  Widget build(BuildContext context) {
    final imageTag = 'auctionImage_$index';
    return Scaffold(
      appBar: AppBar(
        title: const Text("รายละเอียดการประมูล"),
        backgroundColor: Colors.black,
      ),
      body: Column(
        children: [
          Hero(
            tag: imageTag,
            child: CachedNetworkImage(
              imageUrl: 'https://picsum.photos/id/${index + 10}/400/250',
              width: double.infinity,
              height: 250,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'รายละเอียดของงานศิลปะลำดับที่ $index',
              style: const TextStyle(fontSize: 18),
            ),
          ),
          // เพิ่มข้อมูลเพิ่มเติมได้ที่นี่
        ],
      ),
    );
  }
}
