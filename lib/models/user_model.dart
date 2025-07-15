import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String displayName;
  final String profileURL;

  UserModel({
    required this.uid,
    required this.displayName,
    required this.profileURL,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};
    return UserModel(
      uid: doc.id,
      displayName: data['displayName'] ?? 'No Name',
      profileURL: data['profileURL'] ?? '',
    );
  }
}