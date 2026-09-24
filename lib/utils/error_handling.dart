import 'package:supabase_flutter/supabase_flutter.dart';

String providerErrorMessage(Object error) {
  final rawMessage = error.toString();
  final message = rawMessage.toLowerCase();

  if (message.contains('out_of_stock') ||
      message.contains('not enough stock') ||
      message.contains('out of stock')) {
    return 'This product is out of stock. Please review your cart.';
  }
  if (error is PostgrestException) {
    if (error.code == '42501' || message.contains('permission')) {
      return 'You do not have permission to perform this action.';
    }
    if (error.message.isNotEmpty) {
      return error.message;
    }
    return 'The server could not complete that request. Please try again.';
  }
  if (error is AuthException) {
    final authMessage = error.message.toLowerCase();
    if (authMessage.contains('invalid login credentials') ||
        authMessage.contains('wrong password') ||
        authMessage.contains('password is incorrect')) {
      return 'This email is not registered or the password is wrong. Please check and try again.';
    }
    if (authMessage.contains('user not found') ||
        authMessage.contains('no user found') ||
        authMessage.contains('not found') && authMessage.contains('user')) {
      return 'This email is not registered. Please sign up first.';
    }
    if (authMessage.contains('already registered') ||
        authMessage.contains('already exists')) {
      return 'This email is already registered.';
    }
    if (authMessage.contains('invalid email') ||
        authMessage.contains('valid email')) {
      return 'Please enter a valid email address.';
    }
    if (authMessage.contains('password')) {
      return 'Please check your password and try again.';
    }
    return 'Authentication failed. Please try again.';
  }
  if (message.contains('socket') ||
      message.contains('network') ||
      message.contains('failed host lookup') ||
      message.contains('clientexception') ||
      message.contains('timeout') ||
      message.contains('timed out')) {
    return 'No internet connection. Please check your network and try again.';
  }
  return 'Something went wrong. Please try again.';
}
