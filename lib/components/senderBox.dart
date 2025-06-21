import 'package:chat_bubbles/chat_bubbles.dart';
import 'package:flutter/material.dart';

class SenderBox extends StatefulWidget {
  final Map<String, dynamic> message;

  const SenderBox({super.key, required this.message});

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
                ? Colors.black
                : Colors.blue,
            tail: true,
            textStyle: const TextStyle(
              color: Colors.white,
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
              backgroundImage: NetworkImage(
                'https://imageio.forbes.com/specials-images/imageserve/5d35eacaf1176b0008974b54/0x0.jpg?format=jpg&crop=4560,2565,x790,y784,safe&height=900&width=1600&fit=bounds',
              ),
              radius: 15,
            ),
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
