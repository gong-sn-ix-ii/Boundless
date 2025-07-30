// lib/services/notification_service.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  final _currentUser = FirebaseAuth.instance.currentUser;

  // Stream ที่จะคอยส่ง List ของการแจ้งเตือนที่ยังไม่ได้อ่าน
  Stream<List<QueryDocumentSnapshot>> get unreadNotificationsStream {
    if (_currentUser == null) {
      return Stream.value([]); // คืนค่า Stream ว่างๆ ถ้ายังไม่ล็อกอิน
    }
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser!.uid)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs);
  }

  // ฟังก์ชันสำหรับ Mark การแจ้งเตือนว่าอ่านแล้ว
  Future<void> markAsRead(String notificationId) async {
    if (_currentUser == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser!.uid)
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }
}