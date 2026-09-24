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
      body: Consumer<AthenDiction>(
        builder: (context, authProvider, child) {
          if (authProvider.errorMessage.isNotEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_outlined,
                      size: 64,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      authProvider.errorMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: lodFlasheScreen,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
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
          );
        },
      ),
    );
  }

  Future<void> lodFlasheScreen() async {
    final authProvider = context.read<AthenDiction>();
    authProvider.clearError();
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    await authProvider.checkUserisLogin(context);
  }
}
