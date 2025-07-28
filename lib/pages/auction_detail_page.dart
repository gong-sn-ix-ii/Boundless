import 'package:boundless/pages/edit_auction_page.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class AuctionDetailPage extends StatefulWidget {
  final String auctionId;
  const AuctionDetailPage({super.key, required this.auctionId});

  @override
  State<AuctionDetailPage> createState() => _AuctionDetailPageState();
}

// ✅ Mixin added here to listen for notifications on this page
class _AuctionDetailPageState extends State<AuctionDetailPage> {
  late int selectedImageIndex;
  final _bidController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  Map<String, dynamic>? _auctionData;
  StreamSubscription? _auctionSubscription;
  Timer? _timer;
  Duration? _timeLeft;

  @override
  void initState() {
    super.initState();
    selectedImageIndex = 0;
    _listenToAuctionData();
  }

  @override
  void dispose() {
    _auctionSubscription?.cancel();
    _timer?.cancel();
    _bidController.dispose();
    super.dispose();
  }

  void _listenToAuctionData() {
    _auctionSubscription = FirebaseFirestore.instance
        .collection('auctions')
        .doc(widget.auctionId)
        .snapshots()
        .listen((snapshot) {
      if (mounted && snapshot.exists) {
        final newData = snapshot.data();
        setState(() {
          _auctionData = newData;
        });

        if (newData != null) {
          final int currentBid = newData['currentBid'] ?? 0;
          final int bidIncrement = newData['bidIncrement'] ?? 100;
          final String newMinBid = (currentBid + bidIncrement).toString();
          final currentTextValue = int.tryParse(_bidController.text) ?? 0;
          if (currentTextValue < (currentBid + bidIncrement)) {
            _bidController.text = newMinBid;
          }
        }
        _startTimer();
      } else if (mounted) {
        setState(() {
          _auctionData = null;
        });
      }
    });
  }

  void _startTimer() {
    _timer?.cancel();
    final endTime = (_auctionData?['endTime'] as Timestamp?)?.toDate();
    if (endTime != null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        final now = DateTime.now();
        if (now.isBefore(endTime)) {
          setState(() { _timeLeft = endTime.difference(now); });
        } else {
          timer.cancel();
          setState(() { _timeLeft = Duration.zero; });
        }
      });
    }
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return "N/A";
    if (duration.isNegative || duration.inSeconds == 0) return "การประมูลสิ้นสุดแล้ว";
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final days = duration.inDays;
    final hours = twoDigits(duration.inHours.remainder(24));
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$days วัน $hours:$minutes:$seconds";
  }

  Future<void> _placeBid(int newBidAmount) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณาล็อกอินเพื่อเข้าร่วมประมูล')));
      return;
    }

    final batch = FirebaseFirestore.instance.batch();
    final auctionRef = FirebaseFirestore.instance.collection('auctions').doc(widget.auctionId);

    batch.update(auctionRef, {
      'currentBid': newBidAmount,
      'bidCount': FieldValue.increment(1),
      'highestBidderUid': currentUser.uid,
    });

    final bidRef = auctionRef.collection('bids').doc();
    batch.set(bidRef, {
      'bidderUid': currentUser.uid,
      'bidAmount': newBidAmount,
      'timestamp': FieldValue.serverTimestamp(),
    });

    try {
      await batch.commit();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('คุณได้บิดราคาเป็น $newBidAmount บาท'), backgroundColor: Colors.green));
      FocusScope.of(context).unfocus();
    } catch (e) {
      print(e);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _showBidConfirmationDialog(int bidAmount) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text('ยืนยันการบิดราคา', style: TextStyle(color: Colors.white)),
        content: Text('คุณแน่ใจหรือไม่ว่าต้องการบิดราคาที่ $bidAmount บาท?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('ยืนยัน', style: TextStyle(color: Colors.yellow.shade700))),
        ],
      ),
    );
    if (confirmed == true) {
      await _placeBid(bidAmount);
    }
  }

  void _adjustBid(int change) {
    if (_auctionData == null) return;
    final int currentBid = _auctionData!['currentBid'] ?? 0;
    final int bidIncrement = _auctionData!['bidIncrement'] ?? 100;
    final int minBid = currentBid + bidIncrement;
    int currentFieldValue = int.tryParse(_bidController.text) ?? minBid;
    int newValue = currentFieldValue + change;
    if (newValue < minBid) {
      newValue = minBid;
    }
    _bidController.text = newValue.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (_auctionData == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black),
        body: const Center(child: CircularProgressIndicator(color: Colors.yellow)),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final double fontSize = screenWidth * 0.042;
    final double titleSize = screenWidth * 0.05;
    final imageTag = widget.auctionId;
    final String title = _auctionData!['title'] ?? 'ไม่มีชื่อ';
    final String ownerUid = _auctionData!['ownerUid'] ?? '';
    final String ownerName = _auctionData!['ownerDisplayName'] ?? 'ไม่ระบุ';
    final int bidCount = _auctionData!['bidCount'] ?? 0;
    final int currentBid = _auctionData!['currentBid'] ?? 0;
    final int bidIncrement = _auctionData!['bidIncrement'] ?? 100;
    final List<String> imageUrls = List<String>.from(_auctionData!['imageUrls'] ?? []);
    final bool isOwner = FirebaseAuth.instance.currentUser?.uid == ownerUid;
    final int quickBid1 = currentBid + bidIncrement;
    final int quickBid2 = currentBid + (bidIncrement * 2);
    final int quickBid3 = (currentBid + bidIncrement) * 2;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text("รายละเอียดการประมูล", style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold, fontSize: titleSize)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.redAccent),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => EditAuctionPage(auctionId: widget.auctionId)));
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: imageTag,
              child: CachedNetworkImage(
                imageUrl: imageUrls.isNotEmpty ? imageUrls[selectedImageIndex] : '',
                width: double.infinity,
                height: 300,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(height: 300, color: Colors.grey.shade900),
                errorWidget: (context, url, error) => Container(height: 300, color: Colors.grey.shade900, child: const Icon(Icons.image_not_supported)),
              ),
            ),
            if (imageUrls.length > 1) ...[
              const SizedBox(height: 15),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: imageUrls.length,
                  itemBuilder: (context, i) {
                    return GestureDetector(
                      onTap: () { setState(() { selectedImageIndex = i; }); },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          border: Border.all(color: i == selectedImageIndex ? Colors.yellow : Colors.transparent, width: 2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: imageUrls[i],
                            width: MediaQuery.of(context).size.width * 0.2,
                            height: 70,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ชื่อผลงาน: $title', style: TextStyle(fontSize: titleSize, color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 3),
                  Text('ศิลปิน: $ownerName', style: TextStyle(fontSize: fontSize, color: Colors.white70)),
                  const SizedBox(height: 3),
                  Text('เวลาประมูลที่เหลือ: ${_formatDuration(_timeLeft)}', style: TextStyle(fontSize: fontSize, color: Colors.blueAccent)),
                  const SizedBox(height: 3),
                  Text('จำนวนการบิด: $bidCount ครั้ง', style: TextStyle(fontSize: fontSize, color: Colors.white70)),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 8),
                      decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('ราคาปัจจุบัน: ', style: TextStyle(color: Colors.white70, fontSize: fontSize)),
                          Text('$currentBid บาท', style: TextStyle(color: Colors.yellow, fontSize: fontSize + 2, fontWeight: FontWeight.bold)),
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
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildBidButton(quickBid1)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildBidButton(quickBid2)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildBidButton(quickBid3)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _buildIncrementDecrementButton(icon: Icons.remove, onPressed: () => _adjustBid(-bidIncrement)),
                        Expanded(
                          child: TextFormField(
                            controller: _bidController,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              contentPadding: EdgeInsets.zero,
                              filled: true,
                              fillColor: Colors.grey.shade900,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) return '';
                              final int? amount = int.tryParse(value);
                              if (amount == null) return '';
                              if (amount < currentBid + bidIncrement) return '';
                              return null;
                            },
                          ),
                        ),
                        _buildIncrementDecrementButton(icon: Icons.add, onPressed: () => _adjustBid(bidIncrement)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.yellow[700],
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            final int amount = int.parse(_bidController.text);
                            _showBidConfirmationDialog(amount);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('ราคาที่กรอกไม่ถูกต้อง ต้องมากกว่า ${currentBid + bidIncrement} บาท'), backgroundColor: Colors.orange)
                            );
                          }
                        },
                        child: Text('บิดด้วยราคานี้', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: fontSize)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 32, 16, 8),
              child: Text("ประวัติการบิด", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Container(
              height: 200,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('auctions').doc(widget.auctionId).collection('bids').orderBy('timestamp', descending: true).snapshots(),
                builder: (context, snapshot) {
                  if(!snapshot.hasData) return const Center(child: Text("ยังไม่มีผู้ประมูล", style: TextStyle(color: Colors.white70)));
                  return ListView.builder(
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final bidData = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                      final int bidAmount = bidData['bidAmount'];
                      final String bidderUid = bidData['bidderUid'];
                      final Timestamp timestamp = bidData['timestamp'] ?? Timestamp.now();

                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance.collection('users').doc(bidderUid).get(),
                        builder: (context, userSnapshot) {
                          String bidderName = "Loading...";
                          if(userSnapshot.hasData) {
                            bidderName = userSnapshot.data!['displayName'] ?? "Unknown";
                          }
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: (userSnapshot.data?['profileURL'] != null && userSnapshot.data!['profileURL']!.isNotEmpty)
                                  ? NetworkImage(userSnapshot.data!['profileURL'])
                                  : null,
                              child: (userSnapshot.data?['profileURL'] == null || userSnapshot.data!['profileURL']!.isEmpty)
                                  ? const Icon(Icons.person)
                                  : null,
                            ),
                            title: Text("$bidderName ได้บิดราคา", style: const TextStyle(color: Colors.white)),
                            subtitle: Text(DateFormat('dd MMM yyyy, HH:mm').format(timestamp.toDate()), style: const TextStyle(color: Colors.grey)),
                            trailing: Text("$bidAmount บาท", style: const TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold)),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildIncrementDecrementButton({required IconData icon, required VoidCallback onPressed}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(color: Colors.yellow[700], shape: BoxShape.circle),
      child: IconButton(
        icon: Icon(icon, color: Colors.black),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildBidButton(int amount) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.yellow[700],
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      onPressed: () => _showBidConfirmationDialog(amount),
      child: Text(
        '+${NumberFormat("#,##0").format(amount)}',
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      ),
    );
  }
}

// // lib/pages/auction_detail_page.dart
//
// import 'package:boundless/pages/edit_auction_page.dart';
// import 'package:flutter/material.dart';
// import 'package:cached_network_image/cached_network_image.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:intl/intl.dart';
// import 'dart:async';
//
// import '../mixins/notification_listener_mixin.dart';
//
// class AuctionDetailPage extends StatefulWidget {
//   final String auctionId;
//   const AuctionDetailPage({super.key, required this.auctionId});
//
//   @override
//   State<AuctionDetailPage> createState() => _AuctionDetailPageState();
// }
//
// class _AuctionDetailPageState extends State<AuctionDetailPage>  with NotificationListenerMixin<AuctionDetailPage> {
//   // --- State & Controllers ---
//   late int selectedImageIndex;
//   final _bidController = TextEditingController();
//   final _formKey = GlobalKey<FormState>();
//
//   Map<String, dynamic>? _auctionData;
//   StreamSubscription? _auctionSubscription;
//   Timer? _timer;
//   Duration? _timeLeft;
//
//   @override
//   void initState() {
//     super.initState();
//     selectedImageIndex = 0;
//     _listenToAuctionData();
//   }
//
//   @override
//   void dispose() {
//     _auctionSubscription?.cancel();
//     _timer?.cancel();
//     _bidController.dispose();
//     super.dispose();
//   }
//
//   void _listenToAuctionData() {
//     _auctionSubscription = FirebaseFirestore.instance
//         .collection('auctions')
//         .doc(widget.auctionId)
//         .snapshots()
//         .listen((snapshot) {
//       if (snapshot.exists) {
//         if(mounted){
//           final newData = snapshot.data();
//           setState(() {
//             _auctionData = newData;
//           });
//
//           // --- 🔽 [แก้ไข] อัปเดตค่าในช่องกรอกทุกครั้งที่มีข้อมูลใหม่ ---
//           if (newData != null) {
//             final int currentBid = newData['currentBid'] ?? 0;
//             final int bidIncrement = newData['bidIncrement'] ?? 100;
//             final String newMinBid = (currentBid + bidIncrement).toString();
//
//             // เพื่อไม่ให้ cursor กระโดดถ้าผู้ใช้กำลังพิมพ์
//             // เราจะอัปเดตก็ต่อเมื่อค่าในช่องกรอกน้อยกว่าค่าขั้นต่ำใหม่
//             final currentTextValue = int.tryParse(_bidController.text) ?? 0;
//             if (currentTextValue < (currentBid + bidIncrement)) {
//               _bidController.text = newMinBid;
//             }
//           }
//           _startTimer();
//         }
//       } else {
//         if(mounted){
//           setState(() {
//             _auctionData = null;
//           });
//         }
//       }
//     });
//   }
//
//   void _startTimer() {
//     _timer?.cancel();
//     final endTime = (_auctionData?['endTime'] as Timestamp?)?.toDate();
//
//     if (endTime != null) {
//       _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
//         final now = DateTime.now();
//         if (now.isBefore(endTime)) {
//           if (mounted) {
//             setState(() { _timeLeft = endTime.difference(now); });
//           }
//         } else {
//           timer.cancel();
//           if (mounted) {
//             setState(() { _timeLeft = Duration.zero; });
//           }
//         }
//       });
//     }
//   }
//
//   String _formatDuration(Duration? duration) {
//     if (duration == null) return "N/A";
//     if (duration.isNegative || duration.inSeconds == 0) return "การประมูลสิ้นสุดแล้ว";
//     String twoDigits(int n) => n.toString().padLeft(2, '0');
//     final days = duration.inDays;
//     final hours = twoDigits(duration.inHours.remainder(24));
//     final minutes = twoDigits(duration.inMinutes.remainder(60));
//     final seconds = twoDigits(duration.inSeconds.remainder(60));
//     return "$days วัน $hours:$minutes:$seconds";
//   }
//
//   Future<void> _placeBid(int newBidAmount) async {
//     final currentUser = FirebaseAuth.instance.currentUser;
//     if (currentUser == null) {
//       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณาล็อกอินเพื่อเข้าร่วมประมูล')));
//       return;
//     }
//
//     final batch = FirebaseFirestore.instance.batch();
//     final auctionRef = FirebaseFirestore.instance.collection('auctions').doc(widget.auctionId);
//
//     batch.update(auctionRef, {
//       'currentBid': newBidAmount,
//       'bidCount': FieldValue.increment(1),
//       'highestBidderUid': currentUser.uid,
//     });
//
//     final bidRef = auctionRef.collection('bids').doc();
//     batch.set(bidRef, {
//       'bidderUid': currentUser.uid,
//       'bidAmount': newBidAmount,
//       'timestamp': FieldValue.serverTimestamp(),
//     });
//
//     try {
//       await batch.commit();
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('คุณได้บิดราคาเป็น $newBidAmount บาท'), backgroundColor: Colors.green,));
//       // ไม่ต้อง clear controller แล้ว เพราะ _listenToAuctionData จะอัปเดตให้เอง
//       FocusScope.of(context).unfocus();
//     } catch (e) {
//       print(e);
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red,));
//     }
//   }
//
//   Future<void> _showBidConfirmationDialog(int bidAmount) async {
//     final bool? confirmed = await showDialog<bool>(
//       context: context,
//       builder: (context) => AlertDialog(
//         backgroundColor: Colors.grey.shade900,
//         title: const Text('ยืนยันการบิดราคา', style: TextStyle(color: Colors.white)),
//         content: Text('คุณแน่ใจหรือไม่ว่าต้องการบิดราคาที่ $bidAmount บาท?', style: const TextStyle(color: Colors.white70)),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context, false),
//             child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
//           ),
//           TextButton(
//             onPressed: () => Navigator.pop(context, true),
//             child: Text('ยืนยัน', style: TextStyle(color: Colors.yellow.shade700)),
//           ),
//         ],
//       ),
//     );
//
//     if (confirmed == true) {
//       await _placeBid(bidAmount);
//     }
//   }
//
//   void _adjustBid(int change) {
//     if (_auctionData == null) return;
//     final int currentBid = _auctionData!['currentBid'] ?? 0;
//     final int bidIncrement = _auctionData!['bidIncrement'] ?? 100;
//     final int minBid = currentBid + bidIncrement;
//
//     int currentFieldValue = int.tryParse(_bidController.text) ?? minBid;
//     int newValue = currentFieldValue + change;
//
//     if (newValue < minBid) {
//       newValue = minBid;
//     }
//
//     _bidController.text = newValue.toString();
//   }
//
//
//   @override
//   Widget build(BuildContext context) {
//     if (_auctionData == null) {
//       return Scaffold(
//         backgroundColor: Colors.black,
//         appBar: AppBar(backgroundColor: Colors.black),
//         body: const Center(child: CircularProgressIndicator(color: Colors.yellow)),
//       );
//     }
//
//     final screenWidth = MediaQuery.of(context).size.width;
//     final double fontSize = screenWidth * 0.042;
//     final double titleSize = screenWidth * 0.05;
//     final imageTag = widget.auctionId;
//
//     final String title = _auctionData!['title'] ?? 'ไม่มีชื่อ';
//     final String ownerUid = _auctionData!['ownerUid'] ?? '';
//     final String ownerName = _auctionData!['ownerDisplayName'] ?? 'ไม่ระบุ';
//     final int bidCount = _auctionData!['bidCount'] ?? 0;
//     final int currentBid = _auctionData!['currentBid'] ?? 0;
//     final int bidIncrement = _auctionData!['bidIncrement'] ?? 100;
//     final List<String> imageUrls = List<String>.from(_auctionData!['imageUrls'] ?? []);
//     final bool isOwner = FirebaseAuth.instance.currentUser?.uid == ownerUid;
//
//     final int quickBid1 = currentBid + bidIncrement;
//     final int quickBid2 = currentBid + (bidIncrement * 2);
//     final int quickBid3 = (currentBid + bidIncrement) * 2;
//
//
//     return Scaffold(
//       backgroundColor: Colors.black,
//       appBar: AppBar(
//         backgroundColor: Colors.black,
//         title: Text(
//           "รายละเอียดการประมูล",
//           style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold, fontSize: titleSize),
//         ),
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back, color: Colors.white),
//           onPressed: () => Navigator.of(context).pop(),
//         ),
//         actions: [
//           if (isOwner)
//             IconButton(
//               icon: const Icon(Icons.edit, color: Colors.redAccent),
//               onPressed: () {
//                 Navigator.push(context, MaterialPageRoute(builder: (context) => EditAuctionPage(auctionId: widget.auctionId)));
//               },
//             ),
//         ],
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.only(bottom: 80),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Hero(
//               tag: imageTag,
//               child: CachedNetworkImage(
//                 imageUrl: imageUrls.isNotEmpty ? imageUrls[selectedImageIndex] : '',
//                 width: double.infinity,
//                 height: 300,
//                 fit: BoxFit.cover,
//                 placeholder: (context, url) => Container(height: 300, color: Colors.grey.shade900),
//                 errorWidget: (context, url, error) => Container(height: 300, color: Colors.grey.shade900, child: const Icon(Icons.image_not_supported)),
//               ),
//             ),
//             if (imageUrls.length > 1) ...[
//               const SizedBox(height: 15),
//               SizedBox(
//                 height: 100,
//                 child: ListView.builder(
//                   scrollDirection: Axis.horizontal,
//                   padding: const EdgeInsets.symmetric(horizontal: 12),
//                   itemCount: imageUrls.length,
//                   itemBuilder: (context, i) {
//                     return GestureDetector(
//                       onTap: () { setState(() { selectedImageIndex = i; }); },
//                       child: Container(
//                         margin: const EdgeInsets.symmetric(horizontal: 6),
//                         decoration: BoxDecoration(
//                           border: Border.all(
//                             color: i == selectedImageIndex ? Colors.yellow : Colors.transparent,
//                             width: 2,
//                           ),
//                           borderRadius: BorderRadius.circular(8),
//                         ),
//                         child: ClipRRect(
//                           borderRadius: BorderRadius.circular(8),
//                           child: CachedNetworkImage(
//                             imageUrl: imageUrls[i],
//                             width: MediaQuery.of(context).size.width * 0.2,
//                             height: 70,
//                             fit: BoxFit.cover,
//                           ),
//                         ),
//                       ),
//                     );
//                   },
//                 ),
//               ),
//             ],
//             const SizedBox(height: 20),
//             Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 16.0),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     'ชื่อผลงาน: $title',
//                     style: TextStyle(fontSize: titleSize, color: Colors.white, fontWeight: FontWeight.bold),
//                   ),
//                   const SizedBox(height: 3),
//                   Text(
//                     'ศิลปิน: $ownerName',
//                     style: TextStyle(fontSize: fontSize, color: Colors.white70),
//                   ),
//                   const SizedBox(height: 3),
//                   Text(
//                     'เวลาประมูลที่เหลือ: ${_formatDuration(_timeLeft)}',
//                     style: TextStyle(fontSize: fontSize, color: Colors.blueAccent),
//                   ),
//                   const SizedBox(height: 3),
//                   Text(
//                     'จำนวนการบิด: $bidCount ครั้ง',
//                     style: TextStyle(fontSize: fontSize, color: Colors.white70),
//                   ),
//                   const SizedBox(height: 16),
//                   Align(
//                     alignment: Alignment.center,
//                     child: Container(
//                       padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 8),
//                       decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(10)),
//                       child: Row(
//                         mainAxisSize: MainAxisSize.min,
//                         children: [
//                           Text('ราคาปัจจุบัน: ', style: TextStyle(color: Colors.white70, fontSize: fontSize)),
//                           Text(
//                             '$currentBid บาท',
//                             style: TextStyle(color: Colors.yellow, fontSize: fontSize + 2, fontWeight: FontWeight.bold),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//
//             const SizedBox(height: 24),
//             Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 16.0),
//               child: Form(
//                 key: _formKey,
//                 child: Column(
//                   children: [
//                     Row(
//                       children: [
//                         Expanded(child: _buildBidButton(quickBid1)),
//                         const SizedBox(width: 8),
//                         Expanded(child: _buildBidButton(quickBid2)),
//                         const SizedBox(width: 8),
//                         Expanded(child: _buildBidButton(quickBid3)),
//                       ],
//                     ),
//                     const SizedBox(height: 16),
//                     Row(
//                       children: [
//                         _buildIncrementDecrementButton(icon: Icons.remove, onPressed: () => _adjustBid(-bidIncrement)),
//                         Expanded(
//                           child: TextFormField(
//                             controller: _bidController,
//                             textAlign: TextAlign.center,
//                             style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
//                             keyboardType: TextInputType.number,
//                             decoration: InputDecoration(
//                               contentPadding: EdgeInsets.zero,
//                               filled: true,
//                               fillColor: Colors.grey.shade900,
//                               border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
//                             ),
//                             validator: (value) {
//                               if (value == null || value.isEmpty) return '';
//                               final int? amount = int.tryParse(value);
//                               if (amount == null) return '';
//                               if (amount < currentBid + bidIncrement) return '';
//                               return null;
//                             },
//                           ),
//                         ),
//                         _buildIncrementDecrementButton(icon: Icons.add, onPressed: () => _adjustBid(bidIncrement)),
//                       ],
//                     ),
//                     const SizedBox(height: 12),
//                     SizedBox(
//                       width: double.infinity,
//                       height: 50,
//                       child: ElevatedButton(
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: Colors.yellow[700],
//                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                         ),
//                         onPressed: () {
//                           if (_formKey.currentState!.validate()) {
//                             final int amount = int.parse(_bidController.text);
//                             _showBidConfirmationDialog(amount);
//                           } else {
//                             ScaffoldMessenger.of(context).showSnackBar(
//                                 SnackBar(content: Text('ราคาที่กรอกไม่ถูกต้อง ต้องมากกว่า ${currentBid + bidIncrement} บาท'), backgroundColor: Colors.orange,)
//                             );
//                           }
//                         },
//                         child: Text(
//                           'บิดด้วยราคานี้',
//                           style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: fontSize),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//
//             const Padding(
//               padding: EdgeInsets.fromLTRB(16, 32, 16, 8),
//               child: Text("ประวัติการบิด", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
//             ),
//             Container(
//               height: 200,
//               padding: const EdgeInsets.symmetric(horizontal: 16),
//               child: StreamBuilder<QuerySnapshot>(
//                 stream: FirebaseFirestore.instance.collection('auctions').doc(widget.auctionId).collection('bids').orderBy('timestamp', descending: true).snapshots(),
//                 builder: (context, snapshot) {
//                   if(!snapshot.hasData) return const Center(child: Text("ยังไม่มีผู้ประมูล", style: TextStyle(color: Colors.white70)));
//                   return ListView.builder(
//                     itemCount: snapshot.data!.docs.length,
//                     itemBuilder: (context, index) {
//                       final bidData = snapshot.data!.docs[index].data() as Map<String, dynamic>;
//                       final int bidAmount = bidData['bidAmount'];
//                       final String bidderUid = bidData['bidderUid'];
//                       final Timestamp timestamp = bidData['timestamp'] ?? Timestamp.now();
//
//                       return FutureBuilder<DocumentSnapshot>(
//                         future: FirebaseFirestore.instance.collection('users').doc(bidderUid).get(),
//                         builder: (context, userSnapshot) {
//                           String bidderName = "Loading...";
//                           if(userSnapshot.hasData) {
//                             bidderName = userSnapshot.data!['displayName'] ?? "Unknown";
//                           }
//                           return ListTile(
//                             leading: CircleAvatar(
//                               backgroundImage: (userSnapshot.data?['profileURL'] != null && userSnapshot.data!['profileURL']!.isNotEmpty)
//                                   ? NetworkImage(userSnapshot.data!['profileURL'])
//                                   : null,
//                               child: (userSnapshot.data?['profileURL'] == null || userSnapshot.data!['profileURL']!.isEmpty)
//                                   ? const Icon(Icons.person)
//                                   : null,
//                             ),
//                             title: Text("$bidderName ได้บิดราคา", style: const TextStyle(color: Colors.white)),
//                             subtitle: Text(DateFormat('dd MMM yyyy, HH:mm').format(timestamp.toDate()), style: const TextStyle(color: Colors.grey)),
//                             trailing: Text("$bidAmount บาท", style: const TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold)),
//                           );
//                         },
//                       );
//                     },
//                   );
//                 },
//               ),
//             )
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildIncrementDecrementButton({required IconData icon, required VoidCallback onPressed}) {
//     return Container(
//       margin: const EdgeInsets.symmetric(horizontal: 8),
//       decoration: BoxDecoration(
//           color: Colors.yellow[700],
//           shape: BoxShape.circle
//       ),
//       child: IconButton(
//         icon: Icon(icon, color: Colors.black),
//         onPressed: onPressed,
//       ),
//     );
//   }
//
//   Widget _buildBidButton(int amount) {
//     return ElevatedButton(
//       style: ElevatedButton.styleFrom(
//         backgroundColor: Colors.yellow[700],
//         foregroundColor: Colors.black,
//         padding: const EdgeInsets.symmetric(vertical: 12),
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//       ),
//       onPressed: () => _showBidConfirmationDialog(amount),
//       child: Text(
//         '+${NumberFormat("#,##0").format(amount)}',
//         style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
//       ),
//     );
//   }
// }




// import 'package:flutter/material.dart';
// import 'package:cached_network_image/cached_network_image.dart';
// // import 'package:cloud_firestore/cloud_firestore.dart'; // 🔧 เปิดเมื่อใช้ Firebase จริง

// class AuctionDetailPage extends StatefulWidget {
//   final int index;
//   const AuctionDetailPage({super.key, required this.index});

//   @override
//   State<AuctionDetailPage> createState() => _AuctionDetailPageState();
// }

// class _AuctionDetailPageState extends State<AuctionDetailPage> {
//   late int selectedImageIndex;
//   int currentBid = 1000;
//   int bidCount = 0;

//   @override
//   void initState() {
//     super.initState();
//     selectedImageIndex = 0;
//     _loadAuctionData(); // 🔽 โหลดข้อมูลจาก Firebase เมื่อเริ่มต้น
//   }

//   // 🔧 ส่วนนี้คือฟังก์ชันโหลดข้อมูลจาก Firebase
//   Future<void> _loadAuctionData() async {
//     // final doc = await FirebaseFirestore.instance
//     //     .collection('auctions')
//     //     .doc('item_${widget.index}')
//     //     .get();

//     // if (doc.exists) {
//     //   final data = doc.data()!;
//     //   setState(() {
//     //     currentBid = data['currentBid'] ?? 1000;
//     //     bidCount = data['bidCount'] ?? 0;
//     //   });
//     // }
//   }

//   // 🔧 ฟังก์ชันบันทึกการบิดกลับไปที่ Firebase
//   Future<void> _updateBid(int amount) async {
//     setState(() {
//       currentBid += amount;
//       bidCount++;
//     });

//     // await FirebaseFirestore.instance
//     //     .collection('auctions')
//     //     .doc('item_${widget.index}')
//     //     .update({
//     //       'currentBid': currentBid,
//     //       'bidCount': bidCount,
//     //     });

//     ScaffoldMessenger.of(
//       context,
//     ).showSnackBar(SnackBar(content: Text('คุณบิดเพิ่ม $amount บาท')));
//   }

//   @override
//   Widget build(BuildContext context) {
//     final double screenWidth = MediaQuery.of(context).size.width;
//     final double fontSize = screenWidth * 0.042;
//     final double titleSize = screenWidth * 0.05;
//     final imageTag = 'auctionImage_${widget.index}';

//     final List<String> imageUrls = List.generate(
//       10,
//       (i) => 'https://picsum.photos/id/${widget.index * 10 + i}/400/250',
//     );

//     return Scaffold(
//       backgroundColor: Colors.black,
//       appBar: AppBar(
//         backgroundColor: Colors.black,
//         title: Text(
//           "รายละเอียดการประมูล",
//           style: TextStyle(
//             color: Colors.yellow,
//             fontWeight: FontWeight.bold,
//             fontSize: titleSize,
//           ),
//         ),
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back, color: Colors.white),
//           onPressed: () => Navigator.of(context).pop(),
//         ),
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.only(bottom: 80),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Hero(
//               tag: imageTag,
//               child: CachedNetworkImage(
//                 imageUrl: imageUrls[selectedImageIndex],
//                 width: double.infinity,
//                 height: 300,

//                 //width: double.infinity,
//                 //height: MediaQuery.of(context).size.width, // สูง = กว้าง เพื่อให้เป็นจัตุรัส
//                 fit: BoxFit.cover,
//               ),
//             ),
//             const SizedBox(height: 15),
//             SizedBox(
//               height: 100,
//               child: ListView.builder(
//                 scrollDirection: Axis.horizontal,
//                 padding: const EdgeInsets.symmetric(horizontal: 12),
//                 itemCount: imageUrls.length,
//                 itemBuilder: (context, i) {
//                   return GestureDetector(
//                     onTap: () {
//                       setState(() {
//                         selectedImageIndex = i;
//                       });
//                     },
//                     child: Container(
//                       margin: const EdgeInsets.symmetric(horizontal: 6),
//                       decoration: BoxDecoration(
//                         border: Border.all(
//                           color: i == selectedImageIndex
//                               ? Colors.yellow
//                               : Colors.transparent,
//                           width: 2,
//                         ),
//                         borderRadius: BorderRadius.circular(8),
//                       ),
//                       child: ClipRRect(
//                         borderRadius: BorderRadius.circular(8),
//                         child: CachedNetworkImage(
//                           imageUrl: imageUrls[i],
//                           width:
//                               MediaQuery.of(context).size.width *
//                               0.2, // กำหนดความกว้างให้เหมาะสม
//                           height: 70,
//                           fit: BoxFit.cover,
//                         ),
//                       ),
//                     ),
//                   );
//                 },
//               ),
//             ),
//             const SizedBox(height: 20),
//             Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 16.0),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     'ชื่อผลงาน: ศิลป์สะท้านใจ',
//                     style: TextStyle(
//                       fontSize: titleSize,
//                       color: Colors.white,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                   const SizedBox(height: 3),
//                   Text(
//                     'ศิลปิน: ศิลปินหมายเลข ${widget.index + 1}',
//                     style: TextStyle(fontSize: fontSize, color: Colors.white70),
//                   ),
//                   const SizedBox(height: 3),
//                   Text(
//                     'เวลาประมูลที่เหลือ: 2 วัน 03:45:12',
//                     style: TextStyle(fontSize: fontSize, color: Colors.white70),
//                   ),
//                   const SizedBox(height: 3),
//                   Text(
//                     'จำนวนการบิด: $bidCount ครั้ง',
//                     style: TextStyle(fontSize: fontSize, color: Colors.white70),
//                   ),
//                   const SizedBox(height: 16),
//                   Align(
//                     alignment: Alignment.center, // หรือ Alignment.center ก็ได้
//                     child: Container(
//                       padding: const EdgeInsets.symmetric(
//                         horizontal: 60,
//                         vertical: 8,
//                       ),
//                       decoration: BoxDecoration(
//                         color: Colors.white12,
//                         borderRadius: BorderRadius.circular(10),
//                       ),
//                       child: Row(
//                         mainAxisSize:
//                             MainAxisSize.min, // <<< 💡 ให้หดตามเนื้อหา
//                         children: [
//                           Text(
//                             'ราคาปัจจุบัน: ',
//                             style: TextStyle(
//                               color: Colors.white70,
//                               fontSize: fontSize,
//                             ),
//                           ),
//                           Text(
//                             '$currentBid บาท',
//                             style: TextStyle(
//                               color: Colors.yellow,
//                               fontSize: fontSize + 2,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             const SizedBox(height: 24),
//             Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 16.0),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   _buildBidButton('+100', 100, fontSize),
//                   const SizedBox(width: 12),
//                   _buildBidButton('+500', 500, fontSize),
//                   const SizedBox(width: 12),
//                   _buildBidButton('+1000', 1000, fontSize),
//                 ],
//               ),
//             ),
//             const SizedBox(height: 32),
//           ],
//         ),
//       ),
//       floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat, // ✅ อยู่ตรงกลางด้านล่าง
//       floatingActionButton: SizedBox(
//         width: MediaQuery.of(context).size.width * 0.7, // กว้าง 70% ของหน้าจอ
//         height: 50,
//         child: ElevatedButton(
//           style: ElevatedButton.styleFrom(
//             backgroundColor: Colors.yellow[700],
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(30),
//             ),
//             elevation: 5,
//           ),
//           onPressed: () => _updateBid(100),
//           child: Text(
//             'เข้าร่วมประมูล (เริ่มที่ +100)',
//             style: TextStyle(
//               color: Colors.black,
//               fontWeight: FontWeight.bold,
//               fontSize: fontSize,
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   // ปุ่มบิดราคาย่อย
//   Widget _buildBidButton(String label, int amount, double fontSize) {
//     return ElevatedButton(
//       style: ElevatedButton.styleFrom(
//         backgroundColor: Colors.grey[800],
//         padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
//       ),
//       onPressed: () => _updateBid(amount),
//       child: Text(
//         label,
//         style: TextStyle(fontSize: fontSize, color: Colors.white),
//       ),
//     );
//   }
// }
