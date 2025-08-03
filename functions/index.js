// functions/index.js

const {onSchedule} = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const {logger} = require("firebase-functions");

admin.initializeApp();
const db = admin.firestore();

// Function นี้จะทำงานทุกๆ 1 นาที เพื่อตรวจหาการประมูลที่เพิ่งจบไป (v2 Syntax)
exports.checkEndedAuctions = onSchedule("every 1 minutes", async (event) => {
  logger.info("Running scheduled function to check for ended auctions...");

  const now = admin.firestore.Timestamp.now();

  // 1. ค้นหาการประมูลทั้งหมดที่ 'status' ยังเป็น 'active' และ 'endTime' ผ่านไปแล้ว
  const query = db.collection("auctions")
      .where("status", "==", "active")
      .where("endTime", "<=", now);

  const endedAuctionsSnapshot = await query.get();

  if (endedAuctionsSnapshot.empty) {
    logger.info("No auctions ended in the last minute.");
    return null;
  }

  // 2. สำหรับแต่ละการประมูลที่จบไป...
  const promises = endedAuctionsSnapshot.docs.map(async (auctionDoc) => {
    const auctionId = auctionDoc.id;
    const auctionData = auctionDoc.data();
    logger.info(`Processing ended auction: ${auctionData.title} (ID: ${auctionId})`);

    const winnerId = auctionData.highestBidderUid;
    const artistId = auctionData.ownerUid;

    let winnerName = "ไม่มีผู้ชนะ";
    if (winnerId) {
      const winnerDoc = await db.collection("users").doc(winnerId).get();
      winnerName = winnerDoc.exists ? winnerDoc.data().displayName : "Unknown Winner";
    }

    const artistDoc = await db.collection("users").doc(artistId).get();
    const artistName = artistDoc.exists ? artistDoc.data().displayName : "Unknown Artist";

    const bidsSnapshot = await db.collection("auctions").doc(auctionId).collection("bids").get();
    const bidderIds = new Set();
    bidsSnapshot.forEach((doc) => {
      bidderIds.add(doc.data().bidderUid);
    });

    const notificationPayload = {
      auctionId: auctionId,
      auctionTitle: auctionData.title,
      artistName: artistName,
      winnerName: winnerName,
      winningPrice: auctionData.currentBid,
      imageUrls: auctionData.imageUrls || [],
      isRead: false,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    };

    const batch = db.batch();

    bidderIds.forEach((uid) => {
      logger.info(`Creating notification for user: ${uid}`);
      const userNotificationsRef = db.collection("users").doc(uid).collection("notifications").doc();
      batch.set(userNotificationsRef, notificationPayload);
    });

    batch.update(db.collection("auctions").doc(auctionId), {status: "ended"});

    return batch.commit();
  });

  await Promise.all(promises);
  logger.info(`Finished processing ${endedAuctionsSnapshot.size} auctions.`);
  return null;
});