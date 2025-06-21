import 'package:flutter/material.dart';

import 'Services/Service.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  // ฟังก์ชั่นสำหรับตัดคำเกินให้เป็น Hello World...


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: Colors.black,
        title: Padding(
          padding: EdgeInsets.only(left: 0),
          child: Text(
            'Boundless Messages',
            style: TextStyle(
              fontSize: 20,
              color: Colors.yellow,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      body: ListView.builder(
        itemCount: 7,
        itemBuilder: (context, index) {
          return ElevatedButton(
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.black,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            ),
            // ปุ่มกด
            onPressed: () {
              print("Button${index} Clicked");
            },
            child: Container(
              height: 70, // กำหนดความสูง
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 24,
                    backgroundImage: AssetImage(
                      "assets/Logo_boundless_original.png",
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        truncateText("username_${index + 100}", 23),
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        truncateText(
                          "Hello World asdasdasdasdasdaasdasdasdasd",
                          25,
                        ),
                        style: TextStyle(fontSize: 14, color: Colors.white70),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
      //
      // bottomNavigationBar: BottomAppBar(
      //   color: Colors.black,
      //   child: FloatingActionButton(
      //     backgroundColor: Colors.black,
      //     onPressed: () {},
      //     child: Icon(
      //       Icons.add_circle_outline_outlined,
      //       size: 50,
      //       color: Colors.white,
      //     ),
      //     shape: CircleBorder(),
      //   ),
      // ),
    );
  }
}
