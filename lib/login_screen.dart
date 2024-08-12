import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  void _signInWithGoogle() async {
    // Google Sign-In logic here
    // After successful login, navigate to the HomeScreen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen(isGuest: false)),
    );
  }

  void _continueAsGuest() {
    // Navigate to the HomeScreen as a guest
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen(isGuest: true)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'Login',
          style: TextStyle(
            fontFamily: 'ComicSans',
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Welcome!',
              style: TextStyle(
                fontFamily: 'ComicSans',
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 50),
            ElevatedButton.icon(
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all<Color>(Colors.white),
                foregroundColor: WidgetStateProperty.all<Color>(Colors.black),
                textStyle: WidgetStateProperty.all<TextStyle>(
                  const TextStyle(fontFamily: 'ComicSans', fontSize: 16),
                ),
                side: WidgetStateProperty.all<BorderSide>(
                  const BorderSide(color: Colors.black, width: 2),
                ),
                shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                padding: WidgetStateProperty.all<EdgeInsets>(
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              icon: Image.asset('assets/google_logo.png', height: 24), // Add Google logo asset
              label: const Text('Sign in with Google'),
              onPressed: _signInWithGoogle,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all<Color>(Colors.blueAccent),
                foregroundColor: WidgetStateProperty.all<Color>(Colors.white),
                textStyle: WidgetStateProperty.all<TextStyle>(
                  const TextStyle(fontFamily: 'ComicSans', fontSize: 16),
                ),
                shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                padding: WidgetStateProperty.all<EdgeInsets>(
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              onPressed: _continueAsGuest,
              child: const Text('Continue as Guest'),
            ),
          ],
        ),
      ),
    );
  }
}
