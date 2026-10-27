import 'package:e_comerce_appliction/provider/authprovider.dart';
import 'package:e_comerce_appliction/provider/cardeprovider.dart';
import 'package:e_comerce_appliction/provider/productprovider.dart';
import 'package:e_comerce_appliction/provider/orderditiyalce.dart';
import 'package:e_comerce_appliction/provider/userprovider.dart';
import 'package:e_comerce_appliction/provider/messageprovider.dart';
import 'package:e_comerce_appliction/provider/themeprovider.dart';
import 'package:e_comerce_appliction/provider/reviewprovider.dart';
import 'package:e_comerce_appliction/provider/razorpayprovider.dart';
import 'package:e_comerce_appliction/screens/flashe_screen.dart';
import 'package:e_comerce_appliction/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String? startupError;
  try {
    await dotenv.load(fileName: '.env');
    final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
    final publishableKey = dotenv.env['SUPABASE_PUBLISHABLE_KEY'] ?? '';
    if (supabaseUrl.isEmpty || publishableKey.isEmpty) {
      startupError = 'The app is not configured correctly. Please contact the developer for help.';
    } else {
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: publishableKey,
      );
      await NotificationService.instance.initialize();
    }
  } catch (error) {
    startupError =
        'The app could not start. Please contact the developer for help.';
  }

  if (startupError != null) {
    runApp(StartupErrorApp(message: startupError));
    return;
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (contex) => AthenDiction()),
        ChangeNotifierProvider(create: (contex) => CardeProvider()),
        ChangeNotifierProvider(create: (contex) => Productprovider()),
        ChangeNotifierProvider(create: (contex) => OrderDitiyalce()),
        ChangeNotifierProvider(create: (contex) => UserProvider()),
        ChangeNotifierProvider(create: (contex) => MessageProvider()),
        ChangeNotifierProvider(create: (contex) => ThemeProvider()),
        ChangeNotifierProvider(create: (contex) => ReviewProvider()),
        ChangeNotifierProvider(create: (context) => RazorpayProvider()),
      ],
      child: MyApp(),
    ),
  );
}

class StartupErrorApp extends StatelessWidget {
  final String message;

  const StartupErrorApp({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 56, color: Colors.red),
                const SizedBox(height: 16),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                const Text(
                  'Please contact the developer and share this message.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  ThemeData _buildTheme({required bool dark}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2874F0),
      brightness: dark ? Brightness.dark : Brightness.light,
    );
    return ThemeData(
      colorScheme: scheme,
      brightness: dark ? Brightness.dark : Brightness.light,
      useMaterial3: true,
      scaffoldBackgroundColor: dark
          ? const Color(0xFF10151D)
          : const Color(0xFFF5F7FB),
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? const Color(0xFF172231) : scheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: dark ? const Color(0xFF192431) : Colors.white,
        elevation: dark ? 0 : 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.symmetric(vertical: 6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF18222E) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          minimumSize: const Size(0, 48),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          minimumSize: const Size(0, 48),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: dark ? const Color(0xFF172231) : Colors.white,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontWeight: FontWeight.w600, color: scheme.onSurface),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: dark ? const Color(0xFF172231) : Colors.white,
        selectedItemColor: scheme.primary,
        unselectedItemColor: scheme.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'E-Commerce',
          scaffoldMessengerKey: NotificationService.messengerKey,
          theme: _buildTheme(dark: false),
          darkTheme: _buildTheme(dark: true),
          themeMode: themeProvider.themeMode,
          home: const FlasheScreen(),
        );
      },
    );
  }
}
