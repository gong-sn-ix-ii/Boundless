// functions/index.js

const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onRequest } = require("firebase-functions/v2/https"); // ✅ 1. Import onRequest
const admin = require("firebase-admin");
const { logger } = require("firebase-functions");
const express = require('express');
const cors = require('cors');
const { RtcTokenBuilder, RtcRole } = require('agora-access-token');

admin.initializeApp();
const db = admin.firestore();

// =================================================================
// ✨ 1. SCHEDULED FUNCTION (โค้ดเดิมของคุณ)
// =================================================================
exports.checkEndedAuctions = onSchedule("every 1 minutes", async (event) => {
  logger.info("Running scheduled function to check for ended auctions...");
  const now = admin.firestore.Timestamp.now();
  const query = db.collection("auctions").where("status", "==", "active").where("endTime", "<=", now);
  const endedAuctionsSnapshot = await query.get();

  if (endedAuctionsSnapshot.empty) {
    logger.info("No auctions ended in the last minute.");
    return null;
  }

  const promises = endedAuctionsSnapshot.docs.map(async (auctionDoc) => {
    // ... (โค้ดในฟังก์ชันนี้ของคุณเหมือนเดิมทุกประการ) ...
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
    bidderIds.add(artistId);

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


const app = express();
app.use(cors({ origin: true }));
app.use(express.json());

const APP_ID = 'c4f4a3ec132d4408b386ec03a2ec7820';
const APP_CERTIFICATE = '7ad36696f70b4aacb99ee03726bc45ee';

app.post('/', (req, res) => {
  logger.info("Request to /agora token generator received", { body: req.body });

  const channelName = req.body.channelName;
  const uid = req.body.uid ?? 0;

  if (!channelName) {
    return res.status(400).json({ error: 'channelName is required' });
  }

  const role = RtcRole.PUBLISHER;
  const expireTime = 3600;
  const currentTimestamp = Math.floor(Date.now() / 1000);
  const privilegeExpireTime = currentTimestamp + expireTime;

  const token = RtcTokenBuilder.buildTokenWithUid(
    APP_ID,
    APP_CERTIFICATE,
    channelName,
    uid,
    role,
    privilegeExpireTime
  );

  return res.json({ token });
});

exports.agora = onRequest(app);