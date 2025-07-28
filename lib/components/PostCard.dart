// lib/components/PostCard.dart

import 'package:boundless/Services/Service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../photo_gallery_page.dart';

// Helper class to keep PageView pages alive
class KeepAlivePage extends StatefulWidget {
  final Widget child;
  const KeepAlivePage({super.key, required this.child});

  @override
  State<KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<KeepAlivePage> with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }

  @override
  bool get wantKeepAlive => true;
}

class PostCard extends StatefulWidget {
  final DocumentSnapshot postSnapshot;
  final VoidCallback onDelete;

  const PostCard({
    super.key,
    required this.postSnapshot,
    required this.onDelete,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  // --- State variables ---
  final String? _currentUserUid = FirebaseAuth.instance.currentUser?.uid;
  final FirestoreService _firestoreService = FirestoreService(); // ✨ Add service instance
  Map<String, dynamic>? _postData;
  late bool _isLiked;
  late int _likeCount;
  late int _commentCount;
  bool _isExpanded = false;
  final TextEditingController _commentController = TextEditingController();
  final PageController _pageController = PageController();
  int _currentPageIndex = 0;
  List<String> _imageUrls = [];
  late final TapGestureRecognizer _readMoreRecognizer;
  late final FocusNode _commentFocusNode;
  final Map<String, Map<String, String>> _commenterInfoCache = {};

  // ✨ State for holding the user data future
  Future<UserModel>? _ownerFuture;


  @override
  void initState() {
    super.initState();
    _initializeState();
    _commentFocusNode = FocusNode();
    _readMoreRecognizer = TapGestureRecognizer()
      ..onTap = () {
        setState(() {
          _isExpanded = !_isExpanded;
        });
      };
  }

  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.postSnapshot.id != oldWidget.postSnapshot.id) {
      _initializeState();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _commentController.dispose();
    _readMoreRecognizer.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  void _initializeState() {
    if (widget.postSnapshot.exists && widget.postSnapshot.data() != null) {
      _postData = widget.postSnapshot.data() as Map<String, dynamic>;
      List<dynamic> likedByRaw = _postData!['likedBy'] ?? [];
      _likeCount = likedByRaw.length;
      _isLiked = _currentUserUid != null ? likedByRaw.contains(_currentUserUid) : false;
      List<dynamic> imageUrlsRaw = _postData!['imageUrls'] ?? [];
      _imageUrls = imageUrlsRaw.map((e) => e.toString()).toList();
      _commentCount = (_postData!['commentCount'] as num? ?? 0).toInt();

      // ✨ Fetch owner data using ownerUid
      final ownerUid = _postData!['ownerUid'] as String?;
      if (ownerUid != null) {
        _ownerFuture = _firestoreService.getUserProfile(ownerUid);
      }

    } else {
      _postData = {};
      _likeCount = 0;
      _isLiked = false;
      _imageUrls = [];
      _commentCount = 0;
    }
  }

  Future<void> _toggleLike() async {
    _commentFocusNode.unfocus();
    if (_currentUserUid == null) return;

    setState(() {
      _isLiked = !_isLiked;
      _isLiked ? _likeCount++ : _likeCount--;
    });

    final postRef = widget.postSnapshot.reference;
    if (_isLiked) {
      await postRef.update({
        'likedBy': FieldValue.arrayUnion([_currentUserUid]),
      });
    } else {
      await postRef.update({
        'likedBy': FieldValue.arrayRemove([_currentUserUid]),
      });
    }
  }

  Future<void> _postComment() async {
    final commentText = _commentController.text.trim();
    if (commentText.isEmpty || _currentUserUid == null) return;

    final postRef = widget.postSnapshot.reference;
    await postRef.collection('comments').add({
      'commentText': commentText,
      'commenterUID': _currentUserUid,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await postRef.update({'commentCount': FieldValue.increment(1)});

    setState(() {
      _commentCount++;
    });

    _commentController.clear();
    _commentFocusNode.unfocus();
  }

  Future<Map<String, String>> _getCommenterInfo(String uid) async {
    if (_commenterInfoCache.containsKey(uid)) {
      return _commenterInfoCache[uid]!;
    }
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (userDoc.exists) {
      final data = userDoc.data() as Map<String, dynamic>;
      final info = {
        'displayName': (data['displayName'] as String?) ?? 'Unknown',
        'profileURL': (data['profileURL'] as String?) ?? '',
      };
      _commenterInfoCache[uid] = info;
      return info;
    }
    return {'displayName': 'Unknown', 'profileURL': ''};
  }

  Future<void> _deletePost() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: const Text('คุณแน่ใจหรือไม่ว่าต้องการลบโพสต์นี้? การกระทำนี้ไม่สามารถย้อนกลับได้'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('ลบ', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final List<String> imageUrls = List<String>.from(_postData?['imageUrls'] ?? []);

      if (imageUrls.isNotEmpty) {
        List<Future<void>> deleteImageTasks = [];
        for (final url in imageUrls) {
          final ref = FirebaseStorage.instance.refFromURL(url);
          deleteImageTasks.add(ref.delete());
        }
        await Future.wait(deleteImageTasks);
      }

      final commentsSnapshot = await widget.postSnapshot.reference.collection('comments').get();
      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (final doc in commentsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      await widget.postSnapshot.reference.delete();

      widget.onDelete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("โพสต์ถูกลบแล้ว"), backgroundColor: Colors.green),
        );
      }

    } catch (e) {
      print("Error deleting post from client: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาดในการลบ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showCommentsSheet() {
    _commentFocusNode.unfocus();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            builder: (_, controller) {
              return Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF2d292a),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const Text("Comments", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const Divider(color: Colors.grey, height: 24),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: widget.postSnapshot.reference.collection('comments').orderBy('timestamp').snapshots(),
                        builder: (context, commentSnapshot) {
                          if (commentSnapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (!commentSnapshot.hasData || commentSnapshot.data!.docs.isEmpty) {
                            return const Center(child: Text("ยังไม่มีการคอมเม้นท์", style: TextStyle(color: Colors.grey)));
                          }
                          return ListView.builder(
                            controller: controller,
                            itemCount: commentSnapshot.data!.docs.length,
                            itemBuilder: (context, index) {
                              final commentData = commentSnapshot.data!.docs[index].data() as Map<String, dynamic>;
                              final commenterUid = commentData['commenterUID'] as String? ?? '';
                              final commentText = commentData['commentText'] as String? ?? '[No Text]';
                              final commentTimestamp = commentData['timestamp'] as Timestamp?;
                              final commentTimeAgo = formatTimestamp(commentTimestamp);
                              if (commenterUid.isEmpty) return const SizedBox.shrink();
                              return FutureBuilder<Map<String, String>>(
                                future: _getCommenterInfo(commenterUid),
                                builder: (context, userInfoSnapshot) {
                                  if (userInfoSnapshot.connectionState == ConnectionState.waiting) {
                                    return ListTile(
                                      leading: const CircleAvatar(),
                                      title: Container(width: 100, height: 12, color: Colors.grey.shade700),
                                      subtitle: Container(width: 150, height: 10, color: Colors.grey.shade800),
                                    );
                                  }
                                  final commenterInfo = userInfoSnapshot.data ?? {'displayName': 'Unknown', 'profileURL': ''};
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundImage: commenterInfo['profileURL']!.isNotEmpty ? NetworkImage(commenterInfo['profileURL']!) : null,
                                      child: commenterInfo['profileURL']!.isEmpty ? const Icon(Icons.person) : null,
                                    ),
                                    title: Row(
                                      children: [
                                        Flexible(
                                          child: Text(commenterInfo['displayName']!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(commentTimeAgo, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                      ],
                                    ),
                                    subtitle: Text(commentText, style: const TextStyle(color: Colors.white70)),
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                    const Divider(color: Colors.grey, height: 1),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _commentController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'Add a comment...',
                                hintStyle: TextStyle(color: Colors.grey.shade500),
                                filled: true,
                                fillColor: Colors.black.withOpacity(0.2),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              ),
                              onSubmitted: (text) => _postComment(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(Icons.send, color: Colors.yellow.shade700),
                            onPressed: _postComment,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showPostOptions() {
    _commentFocusNode.unfocus();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2d292a),
      builder: (context) {
        final bool isOwner = _postData?['ownerUid'] == _currentUserUid;
        return Wrap(
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.visibility_off, color: Colors.white),
              title: const Text('Hide Post', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _hidePost();
              },
            ),
            if (isOwner)
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text('Delete Post', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _deletePost();
                },
              ),
          ],
        );
      },
    );
  }

  Future<void> _hidePost() async {
    if (_currentUserUid == null) return;
    final postId = widget.postSnapshot.id;
    try {
      await FirebaseFirestore.instance.collection('users').doc(_currentUserUid).update({
        'hiddenPosts': FieldValue.arrayUnion([postId]),
      });
      if (mounted) {
        widget.onDelete();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text("Post hidden."),
          action: SnackBarAction(
            label: 'UNDO',
            onPressed: () {
              FirebaseFirestore.instance.collection('users').doc(_currentUserUid).update({
                'hiddenPosts': FieldValue.arrayRemove([postId]),
              });
            },
          ),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to hide post. Please try again.")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_postData == null || _postData!.isEmpty) {
      return const Card(
        color: Colors.red,
        child: ListTile(
          leading: Icon(Icons.error),
          title: Text("Could not load post data"),
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final caption = _postData!['caption'] as String? ?? '';
    final postTimestamp = _postData!['timestamp'] as Timestamp?;
    final timeAgo = formatTimestamp(postTimestamp);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: screenWidth * 0.025),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: const Color(0xFF2d292a),
        ),
        // ✨ Use FutureBuilder to display owner info
        child: FutureBuilder<UserModel>(
          future: _ownerFuture,
          builder: (context, ownerSnapshot) {

            // --- UI States for FutureBuilder ---
            Widget leadingWidget;
            String ownerDisplayName = 'Loading...';

            if (ownerSnapshot.connectionState == ConnectionState.done && ownerSnapshot.hasData) {
              final owner = ownerSnapshot.data!;
              ownerDisplayName = owner.displayName;
              leadingWidget = InkWell(
                onTap: () {}, // TODO: Navigate to owner's profile page
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: owner.profileURL.isNotEmpty
                      ? Image.network(owner.profileURL, width: 40, height: 40, fit: BoxFit.cover)
                      : Container(
                    width: 40,
                    height: 40,
                    color: const Color(0xFFF3B716),
                    child: const Icon(Icons.person, color: Colors.black),
                  ),
                ),
              );
            } else if (ownerSnapshot.hasError) {
              ownerDisplayName = 'Error';
              leadingWidget = const Icon(Icons.error_outline, color: Colors.red);
            } else {
              // Loading state
              leadingWidget = Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: Colors.grey.shade800,
                    borderRadius: BorderRadius.circular(8.0)
                ),
              );
            }

            // --- Main Column ---
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04, vertical: 8.0),
                  leading: leadingWidget,
                  title: Row(
                    children: [
                      Text(ownerDisplayName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(width: 8),
                      Text(timeAgo, style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.more_horiz, color: Colors.white),
                    onPressed: _showPostOptions,
                  ),
                ),
                if (_imageUrls.isNotEmpty)
                  Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: PageView(
                              controller: _pageController,
                              onPageChanged: (index) {
                                setState(() { _currentPageIndex = index; });
                              },
                              children: _imageUrls.map((imageUrl) {
                                final index = _imageUrls.indexOf(imageUrl);
                                final heroTag = '${widget.postSnapshot.id}-$index';

                                return GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => PhotoGalleryPage(
                                          imageUrls: _imageUrls,
                                          initialIndex: index,
                                          heroTagPrefix: widget.postSnapshot.id,
                                        ),
                                      ),
                                    );
                                  },
                                  child: KeepAlivePage(
                                    child: Hero(
                                      tag: heroTag,
                                      child: CachedNetworkImage(
                                        imageUrl: imageUrl,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => Container(
                                          color: Colors.grey[850],
                                          child: const Center(
                                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.0),
                                          ),
                                        ),
                                        errorWidget: (context, url, error) => Container(
                                          color: Colors.grey[850],
                                          child: const Icon(Icons.broken_image, color: Colors.grey, size: 50),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                      if (_imageUrls.length > 1)
                        Positioned(
                          top: 10,
                          right: 25,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(20)),
                            child: Text('${_currentPageIndex + 1}/${_imageUrls.length}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                          ),
                        ),
                    ],
                  )
                else
                  AspectRatio(
                    aspectRatio: 1,
                    child: Container(color: Colors.grey[800], child: const Center(child: Icon(Icons.image_not_supported, color: Colors.grey, size: 50))),
                  ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.02, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(_isLiked ? Icons.favorite : Icons.favorite_border, color: _isLiked ? Colors.red : Colors.white),
                        onPressed: _toggleLike,
                      ),
                      IconButton(
                        icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
                        onPressed: _showCommentsSheet,
                      ),
                      Expanded(
                        child: SizedBox(
                          height: 40,
                          child: TextField(
                            controller: _commentController,
                            focusNode: _commentFocusNode,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Add a comment...',
                              hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                              filled: true,
                              fillColor: Colors.grey.shade800,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                              suffixIcon: IconButton(
                                icon: Icon(Icons.send, color: Colors.yellow.shade700, size: 20),
                                onPressed: _postComment,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
                  child: Text('$_likeCount likes', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: "$ownerDisplayName ", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        TextSpan(text: _isExpanded ? caption : truncateText(caption, 60), style: const TextStyle(color: Colors.white70)),
                        if (caption.length > 100)
                          TextSpan(
                            text: _isExpanded ? ' \nย่อข้อความ' : ' \nอ่านเพิ่มเติม',
                            style: const TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold),
                            recognizer: _readMoreRecognizer,
                          ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04, vertical: 8),
                  child: InkWell(
                    onTap: _showCommentsSheet,
                    child: StreamBuilder<QuerySnapshot>(
                      stream: widget.postSnapshot.reference.collection('comments').snapshots(),
                      builder: (context, snapshot) {
                        final count = snapshot.data?.docs.length ?? _commentCount;
                        if (count == 0) return const SizedBox.shrink();
                        return Text('View all $count comments', style: const TextStyle(color: Colors.grey));
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

