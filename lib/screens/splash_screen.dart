import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'sign_language_detector_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    // Delay 2 detik untuk splash screen
    await Future.delayed(const Duration(seconds: 5));

    // Check if user is logged in
    bool isLoggedIn = await AuthService.isLoggedIn();

    if (!mounted) return;

    if (isLoggedIn) {
      // Navigate to detector screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const SignLanguageDetectorScreen(),
        ),
      );
    } else {
      // Navigate to login screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const LoginScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Icon/Logo
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Icon(
                Icons.pan_tool,
                size: 80,
                color: Colors.deepPurple.shade400,
              ),
            ),
            const SizedBox(height: 30),

            // App Name
            const Text(
              'Sign Language',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const Text(
              'Detector',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w300,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 50),

            // Loading Indicator
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}