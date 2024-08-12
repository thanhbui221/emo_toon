import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'login_screen.dart';
import 'home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Load environment variables
  try {
    // Explicitly set the path to the .env file in the lib directory
    const envPath = 'lib/.env';
    await dotenv.load(fileName: envPath);
  } catch (e) {
    print("Error loading .env file: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Check login status from Firebase Authentication
  Future<bool> checkLoginStatus() async {
    // User? user = FirebaseAuth.instance.currentUser;
    // return user != null;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Comic App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: FutureBuilder(
        future: checkLoginStatus(),
        builder: (context, snapshot) {
          // Show a loading indicator while waiting for the future to complete
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else {
            // Navigate to the appropriate screen based on the login status
            if (snapshot.data == true) {
              return const HomeScreen(isGuest: false);
            } else {
              return const LoginScreen();
            }
          }
        },
      ),
    );
  }
}
