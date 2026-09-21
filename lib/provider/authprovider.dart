import 'package:e_comerce_appliction/screens/home_screen.dart';
import 'package:e_comerce_appliction/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AthenDiction extends ChangeNotifier {
  final SupabaseClient supabase = Supabase.instance.client;
  var errorMessage = '';

  Future<void> login(BuildContext context, String email, String pass) async {
    errorMessage = ''; // Clear previous errors
    notifyListeners();
    try {
      final respons = await supabase.auth.signInWithPassword(
        email: email.trim(),
        password: pass,
      );
      if (respons.user != null && respons.session != null) {
        if (context.mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
      print(e);
      // Optional: show a snackbar here
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login Failed: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> signUp(
    BuildContext context,
    String email,
    String pass,
    String name,
    String phone,
    String address,
    String country,
    String state,
    String city,
    String role,
  ) async {
    errorMessage = ''; // Clear previous errors
    notifyListeners();
    try {
      final response = await supabase.auth.signUp(
        email: email.trim(),
        password: pass,
        data: {
          'name': name,
          'phone': phone,
          'address': address,
          'country': country,
          'state': state,
          'city': city,
          'role': role,
        },
      );
      if (response.user != null && response.session != null) {
        if (context.mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
      print(e);
      // Optional: show a snackbar here
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign up Failed: ${e.toString()}')),
        );
      }
    }
  }

  void checkUserisLogin(BuildContext context) {
    final user = supabase.auth.currentUser;
    if (user != null) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
        (route) => false,
      );
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> logOut(BuildContext context) async {
    await supabase.auth.signOut();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
      (context) => false,
    );
  }
}
