import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
// import 'package:cloud_firestore/cloud_firestore.dart'; // 🔧 เปิดเมื่อใช้ Firebase จริง

class AuctionDetailPage extends StatefulWidget {
  final int index;
  const AuctionDetailPage({super.key, required this.index});

  @override
  State<AuctionDetailPage> createState() => _AuctionDetailPageState();
}

class _AuctionDetailPageState extends State<AuctionDetailPage> {
  late int selectedImageIndex;
  int currentBid = 1000;
  int bidCount = 0;

  @override
  void initState() {
    super.initState();
    selectedImageIndex = 0;
    _loadAuctionData(); // 🔽 โหลดข้อมูลจาก Firebase เมื่อเริ่มต้น
  }

  // 🔧 ส่วนนี้คือฟังก์ชันโหลดข้อมูลจาก Firebase
  Future<void> _loadAuctionData() async {
    // final doc = await FirebaseFirestore.instance
    //     .collection('auctions')
    //     .doc('item_${widget.index}')
    //     .get();

    // if (doc.exists) {
    //   final data = doc.data()!;
    //   setState(() {
    //     currentBid = data['currentBid'] ?? 1000;
    //     bidCount = data['bidCount'] ?? 0;
    //   });
    // }
  }

  // 🔧 ฟังก์ชันบันทึกการบิดกลับไปที่ Firebase
  Future<void> _updateBid(int amount) async {
    setState(() {
      currentBid += amount;
      bidCount++;
    });

    // await FirebaseFirestore.instance
    //     .collection('auctions')
    //     .doc('item_${widget.index}')
    //     .update({
    //       'currentBid': currentBid,
    //       'bidCount': bidCount,
    //     });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('คุณบิดเพิ่ม $amount บาท')));
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double fontSize = screenWidth * 0.042;
    final double titleSize = screenWidth * 0.05;
    final imageTag = 'auctionImage_${widget.index}';

    final List<String> imageUrls = List.generate(
      10,
      (i) => 'https://picsum.photos/id/${widget.index * 10 + i}/400/250',
    );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          "รายละเอียดการประมูล",
          style: TextStyle(
            color: Colors.yellow,
            fontWeight: FontWeight.bold,
            fontSize: titleSize,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: imageTag,
              child: CachedNetworkImage(
                imageUrl: imageUrls[selectedImageIndex],
                width: double.infinity,
                height: 300,

                //width: double.infinity,
                //height: MediaQuery.of(context).size.width, // สูง = กว้าง เพื่อให้เป็นจัตุรัส
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 15),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: imageUrls.length,
                itemBuilder: (context, i) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedImageIndex = i;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: i == selectedImageIndex
                              ? Colors.yellow
                              : Colors.transparent,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: imageUrls[i],
                          width:
                              MediaQuery.of(context).size.width *
                              0.2, // กำหนดความกว้างให้เหมาะสม
                          height: 70,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ชื่อผลงาน: ศิลป์สะท้านใจ',
                    style: TextStyle(
                      fontSize: titleSize,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'ศิลปิน: ศิลปินหมายเลข ${widget.index + 1}',
                    style: TextStyle(fontSize: fontSize, color: Colors.white70),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'เวลาประมูลที่เหลือ: 2 วัน 03:45:12',
                    style: TextStyle(fontSize: fontSize, color: Colors.white70),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'จำนวนการบิด: $bidCount ครั้ง',
                    style: TextStyle(fontSize: fontSize, color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.center, // หรือ Alignment.center ก็ได้
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 60,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize:
                            MainAxisSize.min, // <<< 💡 ให้หดตามเนื้อหา
                        children: [
                          Text(
                            'ราคาปัจจุบัน: ',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: fontSize,
                            ),
                          ),
                          Text(
                            '$currentBid บาท',
                            style: TextStyle(
                              color: Colors.yellow,
                              fontSize: fontSize + 2,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildBidButton('+100', 100, fontSize),
                  const SizedBox(width: 12),
                  _buildBidButton('+500', 500, fontSize),
                  const SizedBox(width: 12),
                  _buildBidButton('+1000', 1000, fontSize),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat, // ✅ อยู่ตรงกลางด้านล่าง
      floatingActionButton: SizedBox(
        width: MediaQuery.of(context).size.width * 0.7, // กว้าง 70% ของหน้าจอ
        height: 50,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.yellow[700],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            elevation: 5,
          ),
          onPressed: () => _updateBid(100),
          child: Text(
            'เข้าร่วมประมูล (เริ่มที่ +100)',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: fontSize,
            ),
          ),
        ),
      ),
    );
  }

  // ปุ่มบิดราคาย่อย
  Widget _buildBidButton(String label, int amount, double fontSize) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.grey[800],
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
      ),
      onPressed: () => _updateBid(amount),
      child: Text(
        label,
        style: TextStyle(fontSize: fontSize, color: Colors.white),
      ),
    );
  }
}
