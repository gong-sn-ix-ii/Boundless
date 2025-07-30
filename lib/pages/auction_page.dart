// lib/pages/auction_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import '../CreateAuctionPage.dart';
import '../Services/Service.dart';
import '../mixins/notification_listener_mixin.dart';
import '../models/user_model.dart';
import 'auction_detail_page.dart';

class AuctionPage extends StatefulWidget {
  const AuctionPage({super.key});

  @override
  State<AuctionPage> createState() => _AuctionPageState();
}

class _AuctionPageState extends State<AuctionPage> with NotificationListenerMixin<AuctionPage>    {

  Future<void> _handleRefresh() async {
    setState(() {});
    return await Future.delayed(const Duration(seconds: 1));
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,

      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('auctions')
            .where('status', isEqualTo: 'active')
            .orderBy('endTime', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.yellow));
          }
          if (snapshot.hasError) {
            print("Firestore Error: ${snapshot.error}");
            return Center(child: Text("เกิดข้อผิดพลาด: ${snapshot.error}", style: const TextStyle(color: Colors.white)));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return RefreshIndicator(
              onRefresh: _handleRefresh,
              backgroundColor: Colors.yellow,
              color: Colors.black,
              child: Stack(
                children: [
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.gavel_rounded, color: Colors.grey.shade700, size: 80),
                        const SizedBox(height: 16),
                        Text(
                          "ยังไม่มีการประมูล",
                          style: TextStyle(fontSize: 20, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "แตะปุ่ม + เพื่อเริ่มสร้างการประมูลของคุณ",
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  ListView(),
                ],
              ),
            );
          }

          final auctionDocs = snapshot.data!.docs;

          return RefreshIndicator(
            onRefresh: _handleRefresh,
            backgroundColor: Colors.yellow,
            color: Colors.black,
            child: Padding(
              padding: EdgeInsets.all(screenWidth * 0.02),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  int crossAxisCount = 2;
                  if (constraints.maxWidth > 600) crossAxisCount = 3;
                  if (constraints.maxWidth > 900) crossAxisCount = 4;

                  return GridView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: auctionDocs.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 0.58,
                    ),
                    itemBuilder: (context, index) {
                      final auctionDoc = auctionDocs[index];
                      return AuctionCard(auctionDoc: auctionDoc);
                    },
                  );
                },
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFF3B716),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateAuctionPage()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class AuctionCard extends StatefulWidget {
  final DocumentSnapshot auctionDoc;
  const AuctionCard({super.key, required this.auctionDoc});

  @override
  State<AuctionCard> createState() => _AuctionCardState();
}

class _AuctionCardState extends State<AuctionCard> {
  Timer? _timer;
  Duration _countdown = Duration.zero;
  String _countdownStatusText = "กำลังซิงค์เวลา...";
  bool _isAuctionActive = false;

  final FirestoreService _firestoreService = FirestoreService();
  UserModel? _owner;

  @override
  void initState() {
    super.initState();
    _loadOwnerData();
    _startTimer();
  }

  Future<void> _loadOwnerData() async {
    final data = widget.auctionDoc.data() as Map<String, dynamic>?;
    final ownerUid = data?['ownerUid'] as String?;
    if (ownerUid != null) {
      final user = await _firestoreService.getUserProfile(ownerUid);
      if (mounted) {
        setState(() {
          _owner = user;
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    final data = widget.auctionDoc.data() as Map<String, dynamic>?;
    final startTime = (data?['startTime'] as Timestamp?)?.toDate();
    final endTime = (data?['endTime'] as Timestamp?)?.toDate();

    if (endTime == null) return;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final now = DateTime.now();

      if (startTime != null && now.isBefore(startTime)) {
        setState(() {
          _isAuctionActive = false;
          _countdown = startTime.difference(now);
          _countdownStatusText = "จะเริ่มใน: ${_formatDuration(_countdown)}";
        });
      }
      else if (now.isBefore(endTime)) {
        setState(() {
          _isAuctionActive = true;
          _countdown = endTime.difference(now);
          _countdownStatusText = "สิ้นสุดใน: ${_formatDuration(_countdown)}";
        });
      }
      else {
        // เมื่อการประมูลจบ ก็แค่เปลี่ยนสถานะใน UI
        // Cloud Function จะเป็นตัวจัดการสร้าง Notification ให้เอง
        setState(() {
          _isAuctionActive = false;
          _countdown = Duration.zero;
          _countdownStatusText = "การประมูลสิ้นสุดแล้ว";
        });
        timer.cancel();
      }
    });
  }

  String _formatDuration(Duration duration) {
    if (duration.isNegative) return "0 วัน 00:00:00";

    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final days = duration.inDays;
    final hours = twoDigits(duration.inHours.remainder(24));
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));

    return "$days วัน $hours:$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    // ... โค้ดส่วน build เหมือนเดิมทั้งหมด ไม่ต้องแก้ไข ...
    final screenWidth = MediaQuery.of(context).size.width;
    final auctionData = widget.auctionDoc.data() as Map<String, dynamic>? ?? {};
    final String title = auctionData['title'] ?? 'ไม่มีชื่อ';
    final List<String> imageUrls = List<String>.from(auctionData['imageUrls'] ?? []);
    final String firstImage = imageUrls.isNotEmpty ? imageUrls.first : '';
    final int currentBid = auctionData['currentBid'] ?? 0;
    final int bidCount = auctionData['bidCount'] ?? 0;
    final imageTag = widget.auctionDoc.id;

    return LayoutBuilder(
      builder: (context, constraints) {
        return AspectRatio(
          aspectRatio: 0.75,
          child: InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: _isAuctionActive ? () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AuctionDetailPage(auctionId: widget.auctionDoc.id),
                ),
              );
            } : null,
            child: Card(
              color: const Color(0xFF2d292a),
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
                      child: firstImage.isNotEmpty
                          ? CachedNetworkImage(
                        imageUrl: firstImage,
                        height: constraints.maxWidth * 0.6,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(color: Colors.grey.shade800, height: constraints.maxWidth * 0.6),
                        errorWidget: (context, url, error) => Container(color: Colors.grey.shade800, height: constraints.maxWidth * 0.6, child: const Icon(Icons.broken_image)),
                      )
                          : Container(color: Colors.grey.shade800, height: constraints.maxWidth * 0.6, child: const Icon(Icons.image_not_supported)),
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
                                    title,
                                    style: TextStyle(color: Colors.white, fontSize: screenWidth * 0.035, fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  _owner == null
                                      ? Row( // Placeholder
                                    children: [
                                      const CircleAvatar(radius: 10, backgroundColor: Colors.grey),
                                      const SizedBox(width: 6),
                                      Container(height: 12, width: 80, color: Colors.grey.shade300),
                                    ],
                                  )
                                      : Row( // Real Data
                                    children: [
                                      CircleAvatar(
                                        radius: 10,
                                        backgroundImage: _owner!.profileURL.isNotEmpty
                                            ? NetworkImage(_owner!.profileURL)
                                            : null,
                                        child: _owner!.profileURL.isEmpty
                                            ? const Icon(Icons.person, size: 10)
                                            : null,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          _owner!.displayName,
                                          style: TextStyle(color: Colors.grey.shade400, fontSize: screenWidth * 0.03),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _countdownStatusText,
                                    style: TextStyle(fontSize: screenWidth * 0.032, color: _isAuctionActive ? Colors.blueAccent : Colors.orangeAccent),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "$currentBid บาท",
                                    style: TextStyle(fontSize: screenWidth * 0.035, color: Colors.yellow, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "จำนวนผู้ประมูล $bidCount ครั้ง",
                                    style: TextStyle(color: Colors.white70, fontSize: screenWidth * 0.032),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isAuctionActive ? () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => AuctionDetailPage(auctionId: widget.auctionDoc.id)));
                              } : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isAuctionActive ? Colors.yellow.shade700 : Colors.grey.shade800,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              child: Text(
                                "เข้าร่วมประมูล",
                                style: TextStyle(fontSize: screenWidth * 0.035, color: _isAuctionActive ? Colors.black : Colors.grey.shade500),
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
