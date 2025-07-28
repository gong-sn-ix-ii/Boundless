import 'package:agora_rtc_engine/agora_rtc_engine.dart';
// import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:boundless/Chat.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:boundless/config/agora_config.dart';
// //import 'package:agora_uikit/agora_uikit.dart';

// class CallPage extends StatefulWidget {
//   final String chatRoomId;
//   final bool isVideo;
//   final String callerName;
//   final String token; // Optional: ใช้สำหรับ token ที่สร้างจาก Agora

//   const CallPage({
//     super.key,
//     required this.chatRoomId,
//     required this.isVideo,
//     required this.callerName,
//     required this.token,
//   });

//   @override
//   State<CallPage> createState() => _CallPageState();
// }

// class _CallPageState extends State<CallPage> {
//   late final RtcEngine _engine;
//   int? _remoteUid;
//   bool _joined = false;

//   static const String appId = 'c4f4a3ec132d4408b386ec03a2ec7820'; // 👈 เปลี่ยนเป็น App ID จริงของคุณ
//   //static const String token = '007eJxTYHjMJdMh3r5ywuyMLdNf5F2Om+RyWH7/i1D1N/Muimorph1SYEg2STNJNE5NNjQ2SjExMbBIMrYwS002ME40Sk02tzAy2DyvIaMhkJHh3K9kRkYGCATx2RlKUotLDI2MGRgA6dIhWA=='; // หรือใส่ token ชั่วคราวที่สร้างจาก Agora

//   @override
//   void initState() {
//     super.initState();
//     initAgora();
//   }

//   Future<void> initAgora() async {
//     // ✅ ขอ permission ก่อน
//     await [
//       Permission.microphone,
//       if (widget.isVideo) Permission.camera,
//     ].request();

//     // ✅ สร้าง Agora engine
//     _engine = createAgoraRtcEngine();
//     await _engine.initialize(
//       RtcEngineContext(
//         appId: appId,
//         channelProfile: ChannelProfileType.channelProfileCommunication,
//       ),
//     );

//     // ✅ ลงทะเบียน event handler
//     // _engine.registerEventHandler(
//     //   RtcEngineEventHandler(
//     //     onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
//     //       setState(() => _joined = true);
//     //     },
//     //     onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
//     //       setState(() => _remoteUid = remoteUid);
//     //     },
//     //     onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
//     //       setState(() => _remoteUid = null);
//     //     },
//     //   ),
//     // );

//     _engine.registerEventHandler(
//   RtcEngineEventHandler(
//     onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
//       print("✅ Joined channel: ${connection.channelId}, uid: ${connection.localUid}");
//       setState(() => _joined = true);
//     },
//     onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
//       print("✅ Remote user joined: $remoteUid");
//       setState(() => _remoteUid = remoteUid);
//     },
//     onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
//       print("⚠️ Remote user left: $remoteUid");
//       setState(() => _remoteUid = null);
//     },
//   ),
// );

//     // ✅ ตั้งค่าวิดีโอ/เสียง
//     if (widget.isVideo) {
//       await _engine.enableVideo();
//     } else {
//       await _engine.disableVideo();
//     }

//     // ✅ เข้าช่อง
//     await _engine.joinChannel(
//       token: widget.token,
//       channelId: widget.chatRoomId,
//       uid: 0,
//       options: const ChannelMediaOptions(),
//     );
//   }

//   @override
//   void dispose() {
//     _engine.leaveChannel();
//     _engine.release();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.black,
//       body: Stack(
//         children: [
//           // ✅ แสดงวิดีโอหรือข้อความ
//           widget.isVideo
//               ? _renderVideo()
//               : _renderVoice(),

//           // ✅ ปุ่มวางสาย
//           Positioned(
//             bottom: 50,
//             left: MediaQuery.of(context).size.width / 2 - 30,
//             child: FloatingActionButton(
//               backgroundColor: Colors.red,
//               child: const Icon(Icons.call_end),
//               onPressed: () {
//                 Navigator.pop(context);
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _renderVideo() {
//     if (!_joined) {
//       return const Center(child: CircularProgressIndicator());
//     }

//     return Stack(
//       children: [
//         _remoteUid != null
//             ? AgoraVideoView(
//                 controller: VideoViewController.remote(
//                   rtcEngine: _engine,
//                   canvas: VideoCanvas(uid: _remoteUid),
//                   connection: RtcConnection(channelId: widget.chatRoomId),
//                 ),
//               )
//             : const Center(child: Text('กำลังรออีกฝ่ายเข้าร่วม...', style: TextStyle(color: Colors.white))),
//         Positioned(
//           top: 30,
//           right: 20,
//           width: 100,
//           height: 150,
//           child: AgoraVideoView(
//             controller: VideoViewController(
//               rtcEngine: _engine,
//               canvas: const VideoCanvas(uid: 0),
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _renderVoice() {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           const Icon(Icons.phone_in_talk, color: Colors.greenAccent, size: 80),
//           const SizedBox(height: 20),
//           Text(
//             _remoteUid != null ? 'กำลังคุยกับ ${widget.callerName}' : 'กำลังรอให้ ${widget.callerName} เข้าร่วม...',
//             style: const TextStyle(color: Colors.white, fontSize: 20),
//             textAlign: TextAlign.center,
//           ),
//         ],
//       ),
//     );
//   }
// }

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

// --- เก็บค่าคงที่ไว้ข้างนอกเพื่อง่ายต่อการแก้ไข ---
const String appId = "c4f4a3ec132d4408b386ec03a2ec7820";
//const String channelName = "test123";
//const String token ="007eJxTYDBN8tjmV3zo93WLxHlJO2Z7T/7AutSKMVroakG8T+7KRn0FhmSTNJNE49RkQ2OjFBMTA4skYwuz1GQD40Sj1GRzCyMDV/vGjIZARgZnQ01WRgYIBPHZGUpSi0sMjYwZGABAsR2y"; // หาก Agora project ของคุณต้องใช้ Token ให้ใส่ที่นี่
const int uid = 0; // uid ของ user นี้ (0 คือให้ Agora กำหนดให้)

class CallPage extends StatefulWidget {
  final String chatRoomId;
  final bool isVideo;
  final String callerName;
  final String token; // Optional: ใช้สำหรับ token ที่สร้างจาก Agora

  const CallPage({
    super.key,
    required this.chatRoomId,
    required this.isVideo,
    required this.callerName,
    required this.token,
  });

  @override
  State<CallPage> createState() => _CallPageState();
}

class _CallPageState extends State<CallPage> {
  late final RtcEngine _engine; // ตัวจัดการหลักของ Agora
  bool _localUserJoined = false; // สถานะการเข้าร่วมของ user เรา
  final Set<int> _remoteUids = {}; // เก็บ uid ของคนอื่นในห้อง
  //int? _remoteUid;

  bool _isMuted = false;
  bool _isCameraOff = false;

  @override
  void initState() {
    super.initState();
    initAgora();
  }

  @override
  void dispose() {
    // เราจะจัดการการ release engine ใน _hangUp() แทน
    // เพื่อป้องกันการเรียกซ้ำซ้อน
    super.dispose();
  }

  Future<void> initAgora() async {
    // ขอ permission กล้องและไมโครโฟน
    await [Permission.microphone, Permission.camera].request();

    // 1. สร้าง Instance ของ Engine
    _engine = createAgoraRtcEngine();
    await _engine.initialize(const RtcEngineContext(appId: appId));

    // 2. กำหนด Event Handlers เพื่อรับเหตุการณ์ต่างๆ
    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          setState(() {
            _localUserJoined = true;
          });
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          setState(() {
            _remoteUids.add(remoteUid);
          });
        },
        onUserOffline:
            (
              RtcConnection connection,
              int remoteUid,
              UserOfflineReasonType reason,
            ) {
              setState(() {
                _remoteUids.remove(remoteUid);
              });
            },
        onError: (ErrorCodeType err, String msg) {
          debugPrint('[onError] err: $err, msg: $msg');
        },
      ),
    );

    // 3. ตั้งค่าพื้นฐานและเข้าร่วม Channel
    await _engine.enableVideo();
    await _engine.startPreview(); // เริ่มแสดงภาพจากกล้องของเรา
    await _engine.joinChannel(
      token: widget.token,
      channelId: widget.chatRoomId,
      uid: uid,
      options: const ChannelMediaOptions(),
    );
  }

  Future<void> _disposeAgora() async {
    await _engine.leaveChannel();
    await _engine.release();
  }

  // --- UI Building ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _localUserJoined
            ? Stack(
                children: [
                  // มุมมองวิดีโอของทุกคน
                  _buildRemoteVideoGrid(),
                  // มุมมองวิดีโอของตัวเอง (ลอยอยู่มุมขวาบน)
                  _buildLocalVideo(),
                  // ปุ่มควบคุม
                  _buildControls(),
                ],
              )
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  // Widget แสดงวิดีโอของตัวเอง
  Widget _buildLocalVideo() {
    return Align(
      alignment: Alignment.topRight,
      child: Container(
        margin: const EdgeInsets.all(16),
        width: 120,
        height: 160,
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(8),
        ),
        child: _isCameraOff
            ? const Icon(Icons.videocam_off, color: Colors.white)
            : AgoraVideoView(
                controller: VideoViewController(
                  rtcEngine: _engine,
                  canvas: const VideoCanvas(uid: 0), // uid: 0 คือ user ตัวเอง
                ),
              ),
      ),
    );
  }

  // Widget แสดงวิดีโอของคนอื่นในรูปแบบ Grid
  Widget _buildRemoteVideoGrid() {
    if (_remoteUids.isEmpty) {
      return const Center(child: Text("กำลังรอคนอื่นเข้าร่วม..."));
    }
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
      ),
      itemCount: _remoteUids.length,
      itemBuilder: (context, index) {
        int remoteUid = _remoteUids.elementAt(index);
        return AgoraVideoView(
          controller: VideoViewController.remote(
            rtcEngine: _engine,
            canvas: VideoCanvas(uid: remoteUid),
            connection: RtcConnection(channelId: widget.chatRoomId),
          ),
        );
      },
    );
  }

  // Widget ปุ่มควบคุมด้านล่าง
  Widget _buildControls() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // ปุ่มปิด/เปิดไมค์
            IconButton(
              onPressed: () {
                setState(() {
                  _isMuted = !_isMuted;
                });
                _engine.muteLocalAudioStream(_isMuted);
              },
              icon: Icon(_isMuted ? Icons.mic_off : Icons.mic),
              iconSize: 32,
              color: Colors.white,
              style: IconButton.styleFrom(backgroundColor: Colors.blue),
            ),
            // ปุ่มวางสาย
            // IconButton(
            //   onPressed: () {
            //     Navigator.of(context).pop();
            //   },
            //   icon: const Icon(Icons.call_end),
            //   iconSize: 32,
            //   color: Colors.white,
            //   style: IconButton.styleFrom(backgroundColor: Colors.red),
            // ),
            // ปุ่มวางสาย
            IconButton(
              onPressed: _hangUp, // 👈 เปลี่ยนจาก Navigator.of(context).pop()
              icon: const Icon(Icons.call_end),
              iconSize: 32,
              color: Colors.white,
              style: IconButton.styleFrom(backgroundColor: Colors.red),
            ),

            // ปุ่มสลับกล้อง
            IconButton(
              onPressed: () {
                _engine.switchCamera();
              },
              icon: const Icon(Icons.flip_camera_android),
              iconSize: 32,
              color: Colors.white,
              style: IconButton.styleFrom(backgroundColor: Colors.blue),
            ),
            // ปุ่มปิด/เปิดกล้อง
            IconButton(
              onPressed: () {
                setState(() {
                  _isCameraOff = !_isCameraOff;
                });

                // สั่งเปิด/ปิดการส่งสตรีมวิดีโอ
                _engine.enableLocalVideo(!_isCameraOff);

                // ถ้าสถานะใหม่คือ "ไม่ได้ปิดกล้อง" (คือการเปิดกล้อง)
                // ให้สั่ง startPreview เพื่อแสดงภาพอีกครั้ง
                if (!_isCameraOff) {
                  _engine.startPreview();
                }
              },
              icon: Icon(_isCameraOff ? Icons.videocam_off : Icons.videocam),
              iconSize: 32,
              color: Colors.white,
              style: IconButton.styleFrom(backgroundColor: Colors.blue),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _hangUp() async {
    await _engine.leaveChannel();
    await _engine.release();

    // ลบข้อมูลการโทรใน Realtime Database
    final dbRef = FirebaseDatabase.instance.ref('calls/${widget.chatRoomId}');
    await dbRef.remove();

    // กลับไปหน้าก่อนหน้า
    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}
