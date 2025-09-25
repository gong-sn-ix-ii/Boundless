import 'package:flutter/material.dart';

class MessageInputBar extends StatefulWidget {
  final Future<void> Function(String) onSendText;
  final Future<void> Function() onSendImage;
  final FocusNode? focusNode; // 1. เพิ่ม property สำหรับรับ FocusNode

  const MessageInputBar({
    super.key,
    required this.onSendText,
    required this.onSendImage,
    this.focusNode, // 2. เพิ่มใน constructor
  });

  @override
  State<MessageInputBar> createState() => _MessageInputBarState();
}

class _MessageInputBarState extends State<MessageInputBar> {
  final TextEditingController _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _handleSend() {
    if (_textController.text.trim().isNotEmpty) {
      widget.onSendText(_textController.text.trim());
      // 3. เคลียร์ข้อความหลังส่ง แต่ไม่ยุ่งกับ focus
      // การทำแบบนี้จะทำให้แป้นพิมพ์เปิดค้างไว้
      _textController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 8,
        top: 8,
        bottom: 8 + MediaQuery.of(context).viewInsets.bottom, // ดัน UI ขึ้นตามคีย์บอร์ด
      ),
      color: Colors.black,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.image, color: Colors.yellow),
            onPressed: widget.onSendImage,
          ),
          Expanded(
            child: TextField(
              controller: _textController,
              focusNode: widget.focusNode, // 4. ผูก FocusNode กับ TextField
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'พิมพ์ข้อความ...',
                hintStyle: TextStyle(color: Colors.grey[600]),
                filled: true,
                fillColor: Colors.grey[850],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onSubmitted: (_) => _handleSend(), // กด Enter บนคีย์บอร์ดเพื่อส่ง
            ),
          ),

          IconButton(
            icon: const Icon(Icons.send, color: Colors.yellow),
            onPressed: _handleSend,
          ),
        ],
      ),
    );
  }
}