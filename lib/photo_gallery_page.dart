// lib/pages/photo_gallery_page.dart

import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:cached_network_image/cached_network_image.dart';

class PhotoGalleryPage extends StatelessWidget {
  final List<String> imageUrls;
  final int initialIndex;
  final String heroTagPrefix;

  const PhotoGalleryPage({
    super.key,
    required this.imageUrls,
    required this.initialIndex,
    required this.heroTagPrefix,
  });

  @override
  Widget build(BuildContext context) {
    // สร้าง PageController โดยกำหนดหน้าเริ่มต้น
    final PageController pageController = PageController(initialPage: initialIndex);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: PhotoViewGallery.builder(
        pageController: pageController,
        itemCount: imageUrls.length,
        builder: (context, index) {
          final imageUrl = imageUrls[index];
          // สร้าง Hero Tag ที่ไม่ซ้ำกันสำหรับแต่ละภาพ
          final heroTag = '$heroTagPrefix-$index';

          return PhotoViewGalleryPageOptions(
            imageProvider: CachedNetworkImageProvider(imageUrl),
            initialScale: PhotoViewComputedScale.contained,
            minScale: PhotoViewComputedScale.contained * 0.8,
            maxScale: PhotoViewComputedScale.covered * 2.0,
            heroAttributes: PhotoViewHeroAttributes(tag: heroTag),
          );
        },
        scrollPhysics: const BouncingScrollPhysics(),
        backgroundDecoration: const BoxDecoration(
          color: Colors.black,
        ),
        loadingBuilder: (context, event) => const Center(
          child: SizedBox(
            width: 30.0,
            height: 30.0,
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
      ),
    );
  }
}