import 'package:boundless/main.dart';

import 'package:boundless/models/auction_notification_model.dart';

import 'package:flutter/material.dart';

import 'package:intl/intl.dart';

import 'package:provider/provider.dart';



import '../Services/notification_service.dart';





mixin NotificationListenerMixin<T extends StatefulWidget> on State<T> {

  bool _isDialogShowing = false;



  @override

  void didChangeDependencies() {

    super.didChangeDependencies();

    final notifications =

        Provider.of<NotificationController>(context).notifications;

    if (notifications.isNotEmpty && !_isDialogShowing) {

      WidgetsBinding.instance.addPostFrameCallback((_) {

        _showNotificationDialog(notifications.first);

      });

    }

  }



  Future<void> _showNotificationDialog(AuctionNotification notification) async {

    final controller =

    Provider.of<NotificationController>(context, listen: false);



    setState(() {

      _isDialogShowing = true;

    });



    await showDialog(

      context: context,

      barrierDismissible: false, // ป้องกันการกดปิดนอก Dialog

      builder: (dialogContext) => _AuctionEndDialog(

        auctionTitle: notification.auctionTitle,

        artistName: notification.artistName,

        winnerName: notification.winnerName,

        winningPrice: notification.winningPrice,

        onClose: () async {

// เมื่อปิด Dialog ให้ Mark ว่าอ่านแล้ว

          await controller.markAsRead(notification.id);

          if (mounted) {

            Navigator.of(dialogContext).pop();

          }

        },

      ),

    );



    setState(() {

      _isDialogShowing = false;

    });

  }

}



// Dialog ที่จะแสดงผล สามารถเก็บไว้ในไฟล์เดียวกันนี้ได้

class _AuctionEndDialog extends StatelessWidget {

  final String auctionTitle;

  final String artistName;

  final String winnerName;

  final int winningPrice;

  final VoidCallback onClose;



  const _AuctionEndDialog({

    required this.auctionTitle,

    required this.artistName,

    required this.winnerName,

    required this.winningPrice,

    required this.onClose,

  });



  @override

  Widget build(BuildContext context) {

    return Dialog(

      backgroundColor: Colors.transparent,

      child: Container(

        padding: const EdgeInsets.all(24),

        decoration: BoxDecoration(

          color: const Color(0xFF1a1a1a),

          borderRadius: BorderRadius.circular(20),

          border: Border.all(color: Colors.yellow.shade700, width: 2),

        ),

        child: Column(

          mainAxisSize: MainAxisSize.min,

          children: [

            Icon(Icons.emoji_events, color: Colors.yellow.shade600, size: 60),

            const SizedBox(height: 16),

            const Text(

              'การประมูลสิ้นสุดแล้ว!',

              style: TextStyle(

                  color: Colors.white,

                  fontSize: 22,

                  fontWeight: FontWeight.bold),

            ),

            const SizedBox(height: 24),

            _buildResultRow('ผลงาน:', auctionTitle),

            _buildResultRow('ศิลปิน:', artistName),

            const Divider(color: Colors.white24, height: 24),

            _buildResultRow('ผู้ชนะการประมูล:', winnerName, isWinner: true),

            _buildResultRow('ด้วยราคา:',

                '${NumberFormat("#,##0").format(winningPrice)} บาท',

                isWinner: true),

            const SizedBox(height: 32),

            SizedBox(

              width: double.infinity,

              child: ElevatedButton(

                onPressed: onClose, // เรียกใช้ callback เมื่อกดปิด

                style: ElevatedButton.styleFrom(

                  backgroundColor: Colors.yellow.shade700,

                  foregroundColor: Colors.black,

                  padding: const EdgeInsets.symmetric(vertical: 12),

                  shape: RoundedRectangleBorder(

                    borderRadius: BorderRadius.circular(20),

                  ),

                ),

                child: const Text('ปิด',

                    style:

                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),

              ),

            ),

          ],

        ),

      ),

    );

  }



  Widget _buildResultRow(String label, String value, {bool isWinner = false}) {

    return Padding(

      padding: const EdgeInsets.symmetric(vertical: 4.0),

      child: Row(

        mainAxisAlignment: MainAxisAlignment.spaceBetween,

        children: [

          Text(label,

              style: const TextStyle(color: Colors.white70, fontSize: 14)),

          Flexible(

            child: Text(

              value,

              textAlign: TextAlign.end,

              style: TextStyle(

                color: isWinner ? Colors.yellow.shade600 : Colors.white,

                fontSize: 16,

                fontWeight: isWinner ? FontWeight.bold : FontWeight.normal,

              ),

            ),

          ),

        ],

      ),

    );

  }

}