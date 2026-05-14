import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting

class SplashScreen extends StatelessWidget {
  final double progressValue; // Progress value passed from main.dart

  const SplashScreen({super.key, required this.progressValue});

  @override
  Widget build(BuildContext context) {
    final String todayDate = DateFormat('d MMMM, EEEE').format(DateTime.now());

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.flutter_dash,
                    size: 100,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Wardiere Inc.',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[300],
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Text(
                  todayDate,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 10,
                    width: 200,
                    color: Colors.grey[800],
                    child: LinearProgressIndicator(
                      value: progressValue, // Use the progress value
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.grey),
                      backgroundColor: Colors.transparent,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Loading database...',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}