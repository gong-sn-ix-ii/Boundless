// ฟังก์ชั่นสำหรับตัดคำเกินให้เป็น Hello World...
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../models/user_model.dart';

String truncateText(String text, int maxLength) {
  if (text.length <= maxLength) {
    return text;
  }
  return '${text.substring(0, maxLength)}...';
}

String formatTimestamp(Timestamp? timestamp) {
  if (timestamp == null) {
    return '';
  }

  final now = DateTime.now();
  final postTime = timestamp.toDate();
  final difference = now.difference(postTime);

  if (difference.inDays >= 1) {
    // ถ้าเกิน 1 วัน ให้แสดงเป็น dd/MM/yyyy
    return DateFormat('dd/MM/yyyy').format(postTime);
  } else if (difference.inHours >= 1) {
    // ถ้าเกิน 1 ชั่วโมง
    return '${difference.inHours} ชม.';
  } else if (difference.inMinutes >= 1) {
    // ถ้าเกิน 1 นาที
    return '${difference.inMinutes} นาที';
  } else {
    // ถ้าน้อยกว่า 1 นาที
    return 'เมื่อสักครู่';
  }
}


String getChatRoomId(String uid1, String uid2) {
  List<String> uids = [uid1, uid2];
  uids.sort();
  return '${uids[0]}@${uids[1]}';
}

//สำหรับ Firebase

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<UserModel> getUserProfile(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();

      // ตรวจสอบว่ามีข้อมูลหรือไม่ก่อนแปลง
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      } else {
        throw Exception("User with UID $uid not found");
      }
    } catch (e) {
      print("Error getting user profile: $e");
      rethrow;
    }
  }

  String getChatRoomId(String uid1, String uid2) {
    List<String> uids = [uid1, uid2];
    uids.sort();
    return '${uids[0]}@${uids[1]}';
  }

  Future<List<UserModel>> searchUsers(String query, String currentUid) async {
    if (query.trim().isEmpty) {
      return [];
    }

    final result = await _db
        .collection('users')

        .where('displayName', isGreaterThanOrEqualTo: query)
        .where('displayName', isLessThanOrEqualTo: query + '\uf8ff')
        .limit(15)
        .get();

    return result.docs
        .map((doc) => UserModel.fromFirestore(doc))
        .where((user) => user.uid != currentUid) // กรองตัวเองออก
        .toList();
  }
}
