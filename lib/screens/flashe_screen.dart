import 'package:e_comerce_appliction/provider/authprovider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FlasheScreen extends StatefulWidget {
  const FlasheScreen({super.key});

  @override
  State<FlasheScreen> createState() => _FlasheScreenState();
}

class _FlasheScreenState extends State<FlasheScreen> {
  @override
  void initState() {
    super.initState();
    lodFlasheScreen();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2874F0),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(
              Icons.shopping_bag_outlined,
              size: 80,
              color: Colors.white,
            ),
            SizedBox(height: 16),
            Text(
              'E-Commerce',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
              ),
            ),
            SizedBox(height: 48),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFB641B)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> lodFlasheScreen() async {
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    
    // Checks if user is logged in, and navigates appropriately
    context.read<AthenDiction>().checkUserisLogin(context);
  }
}
