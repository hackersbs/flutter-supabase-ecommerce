import 'package:e_comerce_appliction/screens/home_screen.dart';
import 'package:e_comerce_appliction/screens/login_screen.dart';
import 'package:e_comerce_appliction/screens/sellerscreen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:e_comerce_appliction/utils/error_handling.dart';

class AthenDiction extends ChangeNotifier {
  SupabaseClient get supabase => Supabase.instance.client;
  var errorMessage = '';
  String currentUserRole = '';

  void clearError() {
    if (errorMessage.isEmpty) return;
    errorMessage = '';
    notifyListeners();
  }

  String _authErrorMessage(
    Object error, {
    required bool signingUp,
    bool passwordReset = false,
  }) {
    final errorString = error.toString().toLowerCase();

    if (error is AuthException) {
      final message = error.message.toLowerCase();
      if (message.contains('already registered') ||
          message.contains('already exists') ||
          message.contains('user already')) {
        return 'This email is already registered. Please log in instead.';
      }
      if (message.contains('invalid email') ||
          message.contains('valid email')) {
        return 'Please enter a valid email address.';
      }
      if (passwordReset) {
        if (message.contains('user not found') ||
            message.contains('no user found') ||
            (message.contains('not found') && message.contains('user')) ||
            message.contains('email not found')) {
          return 'This email is not registered. Please sign up first.';
        }
        if (message.contains('no user found')) {
          return 'This email is not registered. Please sign up first.';
        }
        return 'We could not send the password reset email. Please try again later.';
      }
      if (message.contains('password')) {
        return 'Password must be at least 6 characters.';
      }
      if (signingUp && message.contains('rate limit')) {
        return 'Too many signup attempts. Please try again later.';
      }
      if (message.contains('invalid login credentials') ||
          message.contains('wrong password') ||
          message.contains('password is incorrect')) {
        return 'This email is not registered or the password is wrong. Please check and try again.';
      }
      if (message.contains('user not found') ||
          message.contains('no user found') ||
          (message.contains('not found') && message.contains('user'))) {
        return 'This email is not registered. Please sign up first.';
      }
      return providerErrorMessage(error);
    } else if (error is PostgrestException) {
      if (error.message.toLowerCase().contains('permission') ||
          error.code == '42501') {
        return 'You do not have permission to perform this action.';
      }
      return 'The server could not complete that request. Please try again.';
    } else if (errorString.contains('failed host lookup') ||
        errorString.contains('no such host') ||
        errorString.contains('dns')) {
      return 'The Supabase server address could not be found. Check the SUPABASE_URL in the app configuration and your internet connection.';
    } else if (errorString.contains('socket') ||
        errorString.contains('network') ||
        errorString.contains('clientexception')) {
      return 'No internet connection. Please check your network and try again.';
    } else if (errorString.contains('permission') ||
        errorString.contains('unauthorized')) {
      return 'You do not have permission to perform this action.';
    }

    return signingUp
        ? 'Could not create the account. Please try again.'
        : 'Login failed. Please check your email and try again.';
  }

  Future<void> sendPasswordReset(BuildContext context, String email) async {
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty) {
      errorMessage = 'Please enter your email address to reset your password.';
      notifyListeners();
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage)));
      }
      return;
    }

    errorMessage = '';
    notifyListeners();

    try {
      await supabase.auth.resetPasswordForEmail(trimmedEmail);
      errorMessage = 'Password reset email sent. Please check your inbox.';
      notifyListeners();
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage)));
      }
    } catch (e) {
      errorMessage = _authErrorMessage(
        e,
        signingUp: false,
        passwordReset: true,
      );
      notifyListeners();
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage)));
      }
    }
  }

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
      errorMessage = _authErrorMessage(e, signingUp: false);
      notifyListeners();
      debugPrint('Login failed: $e');
      // Optional: show a snackbar here
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage)));
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
      } else if (response.user?.identities?.isEmpty ?? false) {
        errorMessage =
            'This email is already registered. Please log in instead.';
        notifyListeners();
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(errorMessage)));
        }
      } else if (response.user != null) {
        errorMessage = 'Account created. Check your email to confirm your account, then log in.';
        notifyListeners();
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(errorMessage)));
        }
      }
    } catch (e) {
      errorMessage = _authErrorMessage(e, signingUp: true);
      notifyListeners();
      debugPrint('Sign up failed: $e');
      // Optional: show a snackbar here
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage)));
      }
    }
  }

  Future<void> checkUserisLogin(BuildContext context) async {
    errorMessage = '';
    notifyListeners();
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
        debugPrint('Error fetching role: $e');
        errorMessage = _authErrorMessage(e, signingUp: false);
        notifyListeners();
        if (context.mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        }
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
