import 'package:flutter/material.dart';

// Stub for Background Service initialization
Future<void> initializeService() async {
  debugPrint('Background service not supported on this platform.');
}

// Stub for Uploader Screen
class UploaderScreen extends StatelessWidget {
  const UploaderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Phone 2')),
      body: const Center(
        child: Text('Uploader mode is only available on Android.'),
      ),
    );
  }
}
