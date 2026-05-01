import 'package:flutter/material.dart';

class DocHomeScreen extends StatelessWidget {
  const DocHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Documents'),
        backgroundColor: const Color(0xFF0B0D12),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.folder_outlined,
              size: 64,
              color: Color(0xFF2A2C38),
            ),
            const SizedBox(height: 16),
            const Text(
              'Doc Feature Coming Soon',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Store and manage your documents',
              style: TextStyle(
                color: Color(0xFF5A5A6A),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
