import 'package:chat_bubbles/chat_bubbles.dart';
import 'package:flutter/material.dart';

class SenderBox extends StatefulWidget {
  final Map<String, dynamic> message;
  final String profileURL;
  const SenderBox({super.key, required this.message, this.profileURL = ""});

  @override
  State<SenderBox> createState() => _SenderBoxState();
}

class _SenderBoxState extends State<SenderBox> {
  @override
  Widget build(BuildContext context) {

    final String content = widget.message['content'];
    final String type = widget.message['type'];
    final bool isSender = widget.message['sender'];

    if (type == 'image') {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Align(
          alignment: isSender ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12.0),
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
                errorBuilder: (context, error, stack) => const Icon(Icons.error),
              ),
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: isSender
          ? Column(
        children: [
          BubbleSpecialThree(
            text: content,
            isSender: isSender,
            color: isSender
                ? Color(0xFFF3B716) // เปลี่ยนเป็นสีที่ต้องการสำหรับผู้ส่ง
                : Colors.blue,
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
              backgroundColor: Colors.grey.shade300, // เพิ่มสีพื้นหลังเผื่อไว้ตอนโหลด

              // 1. ส่วนของรูปภาพ (backgroundImage)
              //    - ถ้า URL มีค่าและไม่ว่างเปล่า ให้ใช้ NetworkImage
              //    - ถ้า URL เป็น null หรือว่างเปล่า ให้ส่งค่า null เข้าไป
              backgroundImage: (widget.profileURL != null && widget.profileURL!.isNotEmpty)
                  ? NetworkImage(widget.profileURL!)
                  : null,

              // 2. ส่วนของ Widget สำรอง (child)
              //    - child จะแสดงก็ต่อเมื่อ backgroundImage เป็น null หรือโหลดรูปไม่สำเร็จ
              //    - ถ้า URL เป็น null หรือว่างเปล่า ให้แสดง Icon สำรอง
              child: (widget.profileURL == null || widget.profileURL!.isEmpty)
                  ? const Icon(
                Icons.account_circle,
                size: 30, // ขนาดของ Icon ควรจะเท่ากับ radius * 2
                color: Colors.white,
              )
                  : null, // ถ้ามีรูปภาพ ก็ไม่ต้องแสดง child
            )
          ),

          Padding(
            padding: EdgeInsets.only(left: 0, bottom: 5),
            child: BubbleSpecialThree(
              text: content,
              isSender: isSender,
              color: isSender
                  ? Colors.black
                  : Colors.blue,
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
