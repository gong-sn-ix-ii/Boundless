import 'package:boundless/pages/user_post_feed_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'setting_page.dart';

class ProfilePage extends StatefulWidget {
  // Parameter to accept the userId of the profile to display
  final String? userId;
  const ProfilePage({super.key, this.userId});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final String? _currentUserUid = FirebaseAuth.instance.currentUser?.uid;
  late String _profileUserId;

  @override
  void initState() {
    super.initState();
    // If no userId is passed, use the current user's id (to show your own profile)
    _profileUserId = widget.userId ?? _currentUserUid!;
  }

  // Function to handle Follow/Unfollow logic
  Future<void> _handleFollowUnfollow(bool isCurrentlyFollowing) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(_profileUserId);
    final currentUserRef = FirebaseFirestore.instance.collection('users').doc(_currentUserUid);

    WriteBatch batch = FirebaseFirestore.instance.batch();

    if (isCurrentlyFollowing) {
      // --- Unfollow ---
      batch.update(userRef, { 'followers': FieldValue.arrayRemove([_currentUserUid]) });
      batch.update(currentUserRef, { 'following': FieldValue.arrayRemove([_profileUserId]) });
    } else {
      // --- Follow ---
      batch.update(userRef, { 'followers': FieldValue.arrayUnion([_currentUserUid]) });
      batch.update(currentUserRef, { 'following': FieldValue.arrayUnion([_profileUserId]) });
    }

    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    if (_profileUserId.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: Text("Please login or specify a user", style: TextStyle(color: Colors.white))),
      );
    }

    final bool isMyProfile = _profileUserId == _currentUserUid;
    final double screenWidth = MediaQuery.of(context).size.width;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(_profileUserId).snapshots(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.yellow)));
        }
        if (userSnapshot.hasError || !userSnapshot.hasData || !userSnapshot.data!.exists) {
          return const Scaffold(backgroundColor: Colors.black, body: Center(child: Text("Could not find user data", style: TextStyle(color: Colors.white))));
        }

        final userData = userSnapshot.data!.data() as Map<String, dynamic>;
        final String displayName = userData['displayName'] ?? 'No Name';
        final String bio = userData['bio'] ?? '';
        final String profileUrl = userData['profileURL'] ?? '';
        final String coverUrl = userData['coverPhotoUrl'] ?? '';
        final List followersRaw = userData['followers'] as List? ?? [];
        final int followersCount = followersRaw.length;
        final int followingCount = (userData['following'] as List? ?? []).length;
        final bool isFollowing = followersRaw.contains(_currentUserUid);

        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            clipBehavior: Clip.none,
            children: [
              SizedBox(
                height: 220,
                width: double.infinity,
                child: coverUrl.isNotEmpty
                    ? CachedNetworkImage(imageUrl: coverUrl, fit: BoxFit.cover, placeholder: (c, u) => Container(color: Colors.grey.shade900))
                    : Container(color: Colors.grey.shade900),
              ),
              Positioned(
                top: MediaQuery.of(context).size.height * 0.13,
                left: -screenWidth * 0.5,
                child: Container(
                  width: screenWidth * 2,
                  height: screenWidth * 2,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black),
                ),
              ),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('posts')
                    .where('ownerUid', isEqualTo: _profileUserId)
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, postSnapshot) {
                  final int postCount = postSnapshot.data?.docs.length ?? 0;
                  final postDocs = postSnapshot.data?.docs ?? [];

                  return SingleChildScrollView(
                    padding: const EdgeInsets.only(top: 100, bottom: 20),
                    child: Column(
                      children: [
                        Center(
                          child: Container(
                            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.black, width: 4)),
                            child: CircleAvatar(
                              radius: 60,
                              backgroundImage: profileUrl.isNotEmpty ? CachedNetworkImageProvider(profileUrl) : null,
                              child: profileUrl.isEmpty ? const Icon(Icons.person, size: 60) : null,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildStatBox('Posts', postCount.toString()),
                            _buildStatBox('Followers', followersCount.toString()),
                            _buildStatBox('Following', followingCount.toString()),
                          ],
                        ),

                        // ✅✅✅ ย้ายปุ่มมาไว้ตรงนี้ ✅✅✅
                        //if (!isMyProfile)
                        if (isMyProfile)
                          Padding(
                            padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 4), // ปรับ padding ตามความสวยงาม
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildActionButton(
                                    text: isFollowing ? 'Unfollow' : 'Follow',
                                    onPressed: () => _handleFollowUnfollow(isFollowing),
                                    isPrimary: !isFollowing,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: _buildActionButton(text: "Message", onPressed: () {
                                  // TODO: Implement message functionality
                                })),
                              ],
                            ),
                          ),

                        const SizedBox(height: 20),
                        if (bio.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text(bio, style: const TextStyle(color: Colors.white70, fontSize: 14), textAlign: TextAlign.center),
                          ),

                        const SizedBox(height: 20),
                        const Divider(color: Colors.white24),
                        const SizedBox(height: 10),

                        postSnapshot.connectionState == ConnectionState.waiting
                            ? const CircularProgressIndicator(color: Colors.yellow)
                            : GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 2.0),
                          itemCount: postDocs.length,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2),
                          itemBuilder: (context, index) {
                            final postDoc = postDocs[index];
                            final postData = postDoc.data() as Map<String, dynamic>;
                            final List<String> imageUrls = List<String>.from(postData['imageUrls'] ?? []);
                            final String firstImage = imageUrls.isNotEmpty ? imageUrls.first : '';
                            if (firstImage.isEmpty) return Container(color: Colors.grey.shade800);
                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => UserPostFeedPage(
                                      userId: _profileUserId,
                                      userName: displayName,
                                      initialPostId: postDoc.id,
                                    ),
                                  ),
                                );
                              },
                              child: CachedNetworkImage(imageUrl: firstImage, fit: BoxFit.cover, placeholder: (c, u) => Container(color: Colors.grey.shade800)),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
              if (isMyProfile)
                Positioned(
                  top: 40,
                  right: 16,
                  child: IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => SettingsPage()));
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatBox(String label, String count) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(
            count,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }

  Widget _buildActionButton({required String text, required VoidCallback onPressed, bool isPrimary = false}) {
    final backgroundColor = isPrimary ? Colors.yellow.shade700 : Colors.black;
    final foregroundColor = isPrimary ? Colors.black : Colors.white;
    final borderColor = isPrimary ? Colors.transparent : Colors.yellow.shade700;

    return SizedBox(
      height: 40,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: borderColor, width: 2),
          ),
        ),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}