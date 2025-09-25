// lib/components/senderBox.dart

import 'package:chat_bubbles/chat_bubbles.dart';
import 'package:flutter/material.dart';

class SenderBox extends StatefulWidget {
  final Map<String, dynamic> message;
  final String profileURL;
  // พารามิเตอร์ที่เพิ่มเข้ามา
  final VoidCallback? onImageTap;
  final String? heroTag;

  const SenderBox({
    super.key,
    required this.message,
    this.profileURL = "",
    // เพิ่มใน constructor
    this.onImageTap,
    this.heroTag,
  });

  @override
  State<SenderBox> createState() => _SenderBoxState();
}

class _SenderBoxState extends State<SenderBox> {
  @override
  Widget build(BuildContext context) {
    final String content = widget.message['content'];
    final String type = widget.message['type'];
    final bool isSender = widget.message['sender'];

    // --- ส่วนสำหรับแสดงผลรูปภาพ ---
    if (type == 'image') {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Align(
          alignment: isSender ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
            child: GestureDetector(
              onTap: widget.onImageTap, // เรียกใช้ฟังก์ชันเมื่อกด
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12.0),
                child: Hero(
                  tag: widget.heroTag ?? content, // ใช้ heroTag สำหรับอนิเมชัน
                  child: Image.network(
                    content,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        height: 200,
                        color: Colors.black54,
                        child: const Center(child: CircularProgressIndicator()),
                      );
                    },
                    errorBuilder: (context, error, stack) =>
                    const Icon(Icons.error),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // --- ส่วนสำหรับแสดงผลข้อความ (เหมือนเดิม) ---
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: isSender
          ? Column(
        children: [
          BubbleSpecialThree(
            text: content,
            isSender: isSender,
            color: isSender
                ? Color(0xFFF3B716) // สีสำหรับผู้ส่ง
                : Colors.blue, // สีสำหรับผู้รับ (ตัวอย่าง)
            tail: true,
            textStyle: const TextStyle(
              color: Colors.black,
              fontSize: 16,
            ),
          ),
        ],
      )
          : Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Padding(
            padding: EdgeInsets.only(left: 5),
            child: CircleAvatar(
              radius: 15,
              backgroundColor: Colors.grey.shade300,
              backgroundImage: (widget.profileURL.isNotEmpty)
                  ? NetworkImage(widget.profileURL)
                  : null,
              child: (widget.profileURL.isEmpty)
                  ? const Icon(
                Icons.account_circle,
                size: 30,
                color: Colors.white,
              )
                  : null,
            ),
          ),
          Padding(
            padding: EdgeInsets.only(left: 0, bottom: 5),
            child: BubbleSpecialThree(
              text: content,
              isSender: isSender,
              color: isSender
                  ? Colors.black
                  : Colors.blue, // สีสำหรับผู้รับ (ตัวอย่าง)
              tail: true,
              textStyle: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}