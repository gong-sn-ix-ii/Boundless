const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();
const storage = admin.storage();

// --- Callable Function สำหรับลบโพสต์ ---
exports.deletePost = functions.https.onCall(async (data, context) => {
  // 1. ตรวจสอบว่าผู้ใช้ล็อกอินหรือไม่
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "You must be logged in to delete a post."
    );
  }

  const postId = data.postId;
  const uid = context.auth.uid;

  if (!postId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "The function must be called with one argument 'postId'."
    );
  }

  const postRef = db.collection("posts").doc(postId);

  try {
    const postDoc = await postRef.get();

    // 2. ตรวจสอบว่าโพสต์มีอยู่จริง และผู้ใช้เป็นเจ้าของโพสต์
    if (!postDoc.exists) {
      throw new functions.https.HttpsError("not-found", "Post not found.");
    }

    const postData = postDoc.data();
    if (postData.ownerUid !== uid) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "You are not the owner of this post."
      );
    }

    // 3. ลบรูปภาพทั้งหมดใน Storage ที่เกี่ยวกับโพสต์นี้
    const imageUrls = postData.imageUrls;
    if (imageUrls && imageUrls.length > 0) {
      const deletePromises = imageUrls.map((url) => {
        // แปลง URL กลับเป็น Path ของไฟล์ใน Storage แล้วสั่งลบ
        const fileRef = storage.bucket().file(
          decodeURIComponent(new URL(url).pathname.split("/o/")[1])
        );
        return fileRef.delete();
      });
      await Promise.all(deletePromises);
      console.log(`Deleted ${imageUrls.length} images from Storage.`);
    }

    // 4. ลบ Subcollections ทั้งหมด (เช่น comments)
    // (ส่วนนี้เป็นโค้ดมาตรฐานสำหรับการลบ subcollection)
    const collections = await postRef.listCollections();
    for (const collection of collections) {
      const docs = await collection.get();
      const batch = db.batch();
      docs.forEach((doc) => batch.delete(doc.ref));
      await batch.commit();
      console.log(`Deleted subcollection: ${collection.id}`);
    }

    // 5. ลบ Document ของโพสต์หลัก
    await postRef.delete();
    console.log(`Successfully deleted post ${postId}`);

    return { success: true, message: "Post deleted successfully." };
  } catch (error) {
    console.error("Error deleting post:", error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError(
      "internal",
      "An internal error occurred."
    );
  }
});