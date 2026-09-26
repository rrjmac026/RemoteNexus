import 'package:flutter/material.dart';
import 'screens/connection_screen.dart';

void main() {
  runApp(const JamRemoteApp());
}

class JamRemoteApp extends StatelessWidget {
  const JamRemoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JAM Remote',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
      ),
      home: const ConnectionScreen(),
    );
  }
}