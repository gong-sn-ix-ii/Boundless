import 'package:flutter/material.dart';

class EditProfilePage extends StatefulWidget {
  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  TextEditingController coverController = TextEditingController();
  TextEditingController profileController = TextEditingController();

  @override
  void initState() {
    super.initState();
    coverController.text = 'https://images.unsplash.com/photo-1607746882042-944635dfe10e';
    profileController.text = 'https://i.pravatar.cc/150?img=10';
  }

  @override
  void dispose() {
    coverController.dispose();
    profileController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Edit Profile'),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: coverController,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Cover Image URL',
                labelStyle: TextStyle(color: Colors.white70),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: profileController,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Profile Image URL',
                labelStyle: TextStyle(color: Colors.white70),
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, {
                  'cover': coverController.text,
                  'profile': profileController.text,
                });
              },
              child: Text('Save'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
