import 'package:boundless/MessagesPage.dart';
import 'package:boundless/PostPage.dart';
import 'package:boundless/SigninPage.dart';
import 'package:boundless/SignupPage.dart';
import 'package:boundless/main_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Boundless App',
      theme: ThemeData(primarySwatch: Colors.yellow),

      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

           if (snapshot.hasData) {
             return MainPage();
           }

          return const SignInPage();
        },
      ),
    );
  }
}
