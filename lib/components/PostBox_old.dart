import 'package:boundless/Services/Service.dart';
import 'package:flutter/material.dart';

class PostBox extends StatelessWidget {
  final String username;
  final String avatarUrl;
  final String postImageUrl;
  final String caption;

  const PostBox({
    super.key,
    required this.username,
    required this.avatarUrl,
    required this.postImageUrl,
    required this.caption,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1A1A1A), // สีพื้นหลังการ์ด (ดำเทา)
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Header ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Row(
              children: [
                InkWell(onTap: () {}, splashColor: Colors.black, child: CircleAvatar(
                  radius: 16,
                  backgroundImage: NetworkImage(avatarUrl),
                ),),
                const SizedBox(width: 10),
                Text(
                  truncateText(username, 24),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(), // ดันไอคอนไปทางขวา
                IconButton(
                  icon: const Icon(Icons.more_horiz, color: Colors.white),
                  onPressed: () {
                    // TODO: Implement more options
                  },
                ),
              ],
            ),
          ),

          // --- Post Image ---
          Image.network(
            postImageUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Container(
                height: 300, // กำหนดความสูงชั่วคราวขณะโหลด
                color: Colors.black26,
                child: const Center(child: CircularProgressIndicator()),
              );
            },
            errorBuilder: (context, error, stack) => Container(
              height: 300,
              color: Colors.black26,
              child: const Icon(Icons.error, color: Colors.red),
            ),
          ),

          // --- Action Bar ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.favorite_border, color: Colors.white),
                  onPressed: () {
                    // TODO: Implement like action
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
                  onPressed: () {
                    // TODO: Implement comment action
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.send_outlined, color: Colors.white),
                  onPressed: () {
                    // TODO: Implement share action
                  },
                ),
              ],
            ),
          ),

          // --- Caption ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.white),
                children: [
                  TextSpan(
                    text: '$username : ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: caption),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
