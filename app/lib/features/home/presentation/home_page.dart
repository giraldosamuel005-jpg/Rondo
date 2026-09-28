import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shield_outlined, size: 48),
              SizedBox(height: 16),
              Text('Rondó', style: TextStyle(fontSize: 28)),
              SizedBox(height: 8),
              Text('Tu seguridad, más cerca.'),
            ],
          ),
        ),
      ),
    );
  }
}