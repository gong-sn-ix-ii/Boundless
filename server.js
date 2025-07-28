// server.js
console.log("--- ✅ กำลังรันไฟล์ server.js เวอร์ชันล่าสุด ---");
const express = require('express');
const cors = require('cors');
const { RtcTokenBuilder, RtcRole } = require('agora-access-token');

const app = express();
app.use(cors());
app.use(express.json());

const APP_ID = 'c4f4a3ec132d4408b386ec03a2ec7820';
const APP_CERTIFICATE = '7ad36696f70b4aacb99ee03726bc45ee';
//const token = '007eJxTYDBN8tjmV3zo93WLxHlJO2Z7T/7AutSKMVroakG8T+7KRn0FhmSTNJNE49RkQ2OjFBMTA4skYwuz1GQD40Sj1GRzCyMDV/vGjIZARgZnQ01WRgYIBPHZGUpSi0sMjYwZGABAsR2y'; // หาก Agora project ของคุณต้องใช้ Token ให้ใส่ที่นี่

app.post('/agora/token', (req, res) => {
  console.log("✅ Received request to /agora/token");
  console.log("📦 Request body:", req.body);

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

const PORT = 3000;
app.listen(PORT, () => {
  console.log(`🚀 Server listening on port ${PORT}`);
});
