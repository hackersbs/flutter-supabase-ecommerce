import 'package:e_comerce_appliction/screens/home_screen.dart';
import 'package:e_comerce_appliction/screens/login_screen.dart';
import 'package:e_comerce_appliction/screens/sellerscreen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AthenDiction extends ChangeNotifier {
  final SupabaseClient supabase = Supabase.instance.client;
  var errorMessage = '';
  String currentUserRole = '';

  Future<void> login(BuildContext context, String email, String pass) async {
    errorMessage = ''; // Clear previous errors
    notifyListeners();
    try {
      final respons = await supabase.auth.signInWithPassword(
        email: email.trim(),
        password: pass,
      );
      if (respons.user != null && respons.session != null) {
        // Fetch the user's specific row from the public.users table
        final userData = await supabase
            .from('users')
            .select('role')
            .eq('id', respons.user!.id)
            .maybeSingle();

        // If the table query fails, fallback to the metadata we saved during signup
        currentUserRole = userData != null
            ? userData['role']
            : (respons.user!.userMetadata?['role'] ?? 'Buyer');
        notifyListeners();

        if (context.mounted) {
          print(currentUserRole);
          print('objectkkkkkkkkkkkkkkkkkkkkkkkkkkkk');
          if (currentUserRole == 'Seller') {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const SellerScreen()),
              (route) => false,
            );
          } else {
            // Route to Buyer Screen
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
              (route) => false,
            );
          }
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

  Future<void> checkUserisLogin(BuildContext context) async {
    final user = supabase.auth.currentUser;
    if (user != null) {
      try {
        final userData = await supabase
            .from('users')
            .select('role')
            .eq('id', user.id)
            .maybeSingle();

        currentUserRole = userData != null
            ? userData['role']
            : (user.userMetadata?['role'] ?? 'Buyer');
        notifyListeners();

        if (!context.mounted) return;

        if (currentUserRole == 'Seller') {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const SellerScreen()),
            (route) => false,
          );
        } else {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        print('Error fetching role: $e');
        if (!context.mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
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
