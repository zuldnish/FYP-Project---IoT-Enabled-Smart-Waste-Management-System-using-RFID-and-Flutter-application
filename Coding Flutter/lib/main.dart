import 'package:flutter/material.dart';
import 'dart:async'; // Import Timer for periodic updates
import 'splash_screen.dart';
import 'dashboard.dart'; // Import the Dashboard screen

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const SplashToDashboard(), // Set the initial screen
    );
  }
}

class SplashToDashboard extends StatefulWidget {
  const SplashToDashboard({super.key});

  @override
  State<SplashToDashboard> createState() => _SplashToDashboardState();
}

class _SplashToDashboardState extends State<SplashToDashboard> {
  double _progressValue = 0.0; // Initial progress value

  @override
  void initState() {
    super.initState();
    // Simulate progress and navigate to Dashboard
    Timer.periodic(const Duration(milliseconds: 50), (timer) {
      setState(() {
        _progressValue += 0.02; // Increment progress
        if (_progressValue >= 1.0) {
          _progressValue = 1.0;
          timer.cancel(); // Stop the timer when progress is complete
          Future.delayed(const Duration(milliseconds: 500), () {
            // Add a slight delay before transitioning
            _navigateToDashboard(); // Smooth transition to Dashboard
          });
        }
      });
    });
  }

  void _navigateToDashboard() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(seconds: 1), // Set fade duration to 1 second
        pageBuilder: (context, animation, secondaryAnimation) => const Dashboard(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          var fadeAnimation = animation.drive(
            Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)),
          );

          return FadeTransition(
            opacity: fadeAnimation,
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SplashScreen(progressValue: _progressValue); // Pass progress value to SplashScreen
  }
}