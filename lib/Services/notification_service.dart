



import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/material.dart';

import 'dart:async';



import '../models/auction_notification_model.dart';



// =================================================================

// ✨ 1. แก้ไขคลาส NotificationController ทั้งหมด

// =================================================================

class NotificationController extends ChangeNotifier {

  final NotificationService _service = NotificationService();

  StreamSubscription? _subscription;

  List<AuctionNotification> _notifications = [];

// --- 👇 1.1 เพิ่ม Flag สำหรับตรวจสอบสถานะ ---

  bool _isDisposed = false;



  List<AuctionNotification> get notifications => _notifications;



  void startListening() {

    _subscription?.cancel();

    _subscription = _service.getUnreadNotifications().listen((snapshot) {

// --- 👇 1.2 เพิ่มการตรวจสอบก่อนเรียก notifyListeners ---

      if (_isDisposed) return; // ถ้าถูก dispose ไปแล้ว ให้ออกจากฟังก์ชันทันที



      _notifications = snapshot.docs

          .map((doc) => AuctionNotification.fromFirestore(doc))

          .toList();

      notifyListeners();

    });

  }



  void stopListening() {

    _subscription?.cancel();

  }



  Future<void> markAsRead(String notificationId) async {

// --- 👇 1.3 เพิ่มการตรวจสอบก่อนเรียก notifyListeners ---

    if (_isDisposed) return;



    await _service.markNotificationAsRead(notificationId);

    _notifications.removeWhere((notification) => notification.id == notificationId);

    notifyListeners();

  }



// --- 👇 1.4 Override เมธอด dispose ---

  @override

  void dispose() {

    _isDisposed = true; // ตั้งค่า Flag ว่าถูกทำลายแล้ว

    _subscription?.cancel();

    super.dispose();

  }

}





// =================================================================

// คลาส NotificationService (ไม่ต้องแก้ไข)

// =================================================================

class NotificationService {

  final FirebaseFirestore _db = FirebaseFirestore.instance;



  Future<void> createAuctionEndNotification(String auctionId) async {

    try {

      final auctionDoc = await _db.collection('auctions').doc(auctionId).get();

      if (!auctionDoc.exists) return;



      final auctionData = auctionDoc.data()!;

      final String ownerUid = auctionData['ownerUid'];

      final String? highestBidderUid = auctionData['highestBidderUid'];



      if (highestBidderUid == null || highestBidderUid.isEmpty) return;



      final ownerDoc = await _db.collection('users').doc(ownerUid).get();

      final String artistName = ownerDoc.data()?['displayName'] ?? 'ไม่พบชื่อศิลปิน';



      final winnerDoc = await _db.collection('users').doc(highestBidderUid).get();

      final String winnerName = winnerDoc.data()?['displayName'] ?? 'ไม่พบชื่อ';



      final bidsSnapshot = await _db.collection('auctions').doc(auctionId).collection('bids').get();

      final Set<String> participantUids = {ownerUid};

      for (var doc in bidsSnapshot.docs) {

        participantUids.add(doc.data()['bidderUid']);

      }



      final notificationData = {

        'auctionId': auctionId,

        'auctionTitle': auctionData['title'] ?? 'N/A',

        'artistName': artistName,

        'winnerName': winnerName,

        'winningPrice': auctionData['currentBid'] ?? 0,

        'timestamp': FieldValue.serverTimestamp(),

        'isRead': false,

      };



      WriteBatch batch = _db.batch();

      for (String uid in participantUids) {

        final notificationRef = _db.collection('users').doc(uid).collection('notifications').doc(auctionId);

        batch.set(notificationRef, notificationData, SetOptions(merge: true));

      }

      await batch.commit();



    } catch (e) {

      print("Error creating auction end notification: $e");

    }

  }



  Stream<QuerySnapshot> getUnreadNotifications() {

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {

      return const Stream.empty();

    }

    return _db

        .collection('users')

        .doc(user.uid)

        .collection('notifications')

        .where('isRead', isEqualTo: false)

        .orderBy('timestamp', descending: true)

        .snapshots();

  }



  Future<void> markNotificationAsRead(String notificationId) async {

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    await _db

        .collection('users')

        .doc(user.uid)

        .collection('notifications')

        .doc(notificationId)

        .update({'isRead': true});

  }

}