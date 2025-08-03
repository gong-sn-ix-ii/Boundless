// lib/mixins/notification_listener_mixin.dart

import 'dart:async';
import 'package:boundless/services/notification_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:intl/intl.dart';

// Mixin นี้จะช่วยให้ StatefulWidget ใดๆ ก็ตามสามารถดักฟังและแสดง Notification ได้
mixin NotificationListenerMixin<T extends StatefulWidget> on State<T> {
  final NotificationService _notificationService = NotificationService();
  StreamSubscription? _notificationSubscription;
  bool _isDialogShowing = false;

  // Controller สำหรับ Confetti
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    // สร้าง Controller
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 1));
    // เริ่มดักฟังการแจ้งเตือนเมื่อหน้านี้ถูกสร้าง
    _notificationSubscription =
        _notificationService.unreadNotificationsStream.listen(_handleNotifications);
  }

  @override
  void dispose() {
    // หยุดการดักฟังเมื่อหน้านี้ถูกทำลาย
    _notificationSubscription?.cancel();
    // ทำลาย Controller
    _confettiController.dispose();
    super.dispose();
  }

  void _handleNotifications(List<QueryDocumentSnapshot> notifications) {
    // ถ้าไม่มีการแจ้งเตือนใหม่ หรือมี Dialog แสดงอยู่แล้ว ก็ไม่ต้องทำอะไร
    if (notifications.isEmpty || _isDialogShowing) {
      return;
    }

    // แสดง Dialog สำหรับการแจ้งเตือนอันแรกสุด
    _showAuctionEndDialog(notifications.first);
  }

  void _showAuctionEndDialog(QueryDocumentSnapshot notification) {
    if (!mounted) return;

    _confettiController.play(); // สั่งให้ Confetti เริ่มทำงาน!

    setState(() {
      _isDialogShowing = true;
    });

    final data = notification.data() as Map<String, dynamic>;

    // ดึงข้อมูลรูปภาพมาใช้
    final List<String> imageUrls = List<String>.from(data['imageUrls'] ?? []);

    // แปลงเวลาและจัดรูปแบบเป็นภาษาไทย
    final timestamp = data['timestamp'] as Timestamp?;
    final String formattedDate = timestamp != null
        ? DateFormat('d MMMM yyyy, HH:mm', 'th_TH').format(timestamp.toDate())
        : 'N/A';

    showDialog(
      context: context,
      barrierDismissible: false, // ไม่ให้กดปิดนอก Dialog
      builder: (context) {
        // ใช้ StatefulBuilder เพื่อจัดการ State ของ PageView (จุดบอกหน้าปัจจุบัน)
        return StatefulBuilder(
          builder: (context, setDialogState) {
            int currentPage = 0;

            return Stack(
              alignment: Alignment.topCenter,
              children: [
                AlertDialog(
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: Colors.yellow.shade700, width: 2),
                  ),
                  title: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.emoji_events,
                        color: Colors.yellow.shade700,
                        size: 80, // ทำให้ถ้วยใหญ่ขึ้น
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'การประมูลสิ้นสุดแล้ว!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.yellow,
                            fontWeight: FontWeight.bold,
                            fontSize: 22),
                      ),
                    ],
                  ),
                  content: SingleChildScrollView(
                    // ทำให้ Content เลื่อนได้ถ้าเนื้อหายาว
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ส่วนแสดงรูปภาพแบบสไลด์
                        if (imageUrls.isNotEmpty)
                          Column(
                            children: [
                              SizedBox(
                                height: 200,
                                width: double.infinity,
                                child: PageView.builder(
                                  itemCount: imageUrls.length,
                                  onPageChanged: (index) {
                                    setDialogState(() {
                                      currentPage = index;
                                    });
                                  },
                                  itemBuilder: (context, index) {
                                    return ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: CachedNetworkImage(
                                        imageUrl: imageUrls[index],
                                        fit: BoxFit.cover,
                                        placeholder: (c, u) => Container(
                                            color: Colors.grey.shade800),
                                        errorWidget: (c, u, e) =>
                                        const Icon(Icons.error),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              if (imageUrls.length > 1)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children:
                                  List.generate(imageUrls.length, (index) {
                                    return Container(
                                      width: 8.0,
                                      height: 8.0,
                                      margin: const EdgeInsets.symmetric(
                                          vertical: 10.0, horizontal: 2.0),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: currentPage == index
                                            ? Colors.yellow
                                            : Colors.grey,
                                      ),
                                    );
                                  }),
                                ),
                              const SizedBox(height: 16),
                            ],
                          ),

                        Text("ผลงาน: ${data['auctionTitle'] ?? 'N/A'}",
                            style: const TextStyle(
                                color: Colors.white, fontSize: 16)),
                        const SizedBox(height: 8),
                        Text("ศิลปิน: ${data['artistName'] ?? 'N/A'}",
                            style: const TextStyle(
                                color: Colors.white, fontSize: 16)),
                        const SizedBox(height: 8),
                        Text("ผู้ชนะ: ${data['winnerName'] ?? 'N/A'}",
                            style: const TextStyle(
                                color: Colors.white, fontSize: 16)),
                        const SizedBox(height: 8),
                        Text(
                            "ราคาที่ชนะ: ${data['winningPrice'] ?? 0} บาท",
                            style: const TextStyle(
                                color: Colors.white, fontSize: 16)),
                        const SizedBox(height: 12),
                        const Divider(color: Colors.white24),
                        const SizedBox(height: 8),
                        Text("เวลา: $formattedDate",
                            style: TextStyle(
                                color: Colors.grey.shade400, fontSize: 14)),
                      ],
                    ),
                  ),
                  actions: [
                    Center(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.yellow,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 40, vertical: 12),
                        ),
                        onPressed: () async {
                          await _notificationService
                              .markAsRead(notification.id);
                          Navigator.of(context).pop();
                        },
                        child: const Text('ปิด'),
                      ),
                    ),
                  ],
                ),
                // เพิ่ม Widget สำหรับ Confetti
                ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirectionality: BlastDirectionality.explosive,
                  particleDrag: 0.05,
                  emissionFrequency: 0.05,
                  numberOfParticles: 20,
                  gravity: 0.05,
                  shouldLoop: false,
                  colors: const [
                    Colors.yellow,
                    Colors.white,
                    Colors.orange,
                    Colors.grey
                  ],
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      // เมื่อ Dialog ถูกปิด ให้ตั้งค่ากลับเป็น false
      if (mounted) {
        setState(() {
          _isDialogShowing = false;
        });
      }
    });
  }
}