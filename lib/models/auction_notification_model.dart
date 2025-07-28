// lib/models/auction_notification_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class AuctionNotification {
  final String id;
  final String auctionId;
  final String auctionTitle;
  final String artistName;
  final String winnerName;
  final int winningPrice;
  final Timestamp timestamp;
  final bool isRead;

  AuctionNotification({
    required this.id,
    required this.auctionId,
    required this.auctionTitle,
    required this.artistName,
    required this.winnerName,
    required this.winningPrice,
    required this.timestamp,
    required this.isRead,
  });

  factory AuctionNotification.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};
    return AuctionNotification(
      id: doc.id,
      auctionId: data['auctionId'] ?? '',
      auctionTitle: data['auctionTitle'] ?? 'N/A',
      artistName: data['artistName'] ?? 'N/A',
      winnerName: data['winnerName'] ?? 'N/A',
      winningPrice: (data['winningPrice'] as num? ?? 0).toInt(),
      timestamp: data['timestamp'] ?? Timestamp.now(),
      isRead: data['isRead'] ?? true,
    );
  }
}