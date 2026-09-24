import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:e_comerce_appliction/utils/error_handling.dart';

class UserProvider extends ChangeNotifier {
  final SupabaseClient supabase = Supabase.instance.client;

  Map<String, dynamic> userData = {};
  bool isLoading = false;
  String? errorMessage;

  Future<void> loadUser() async {
    final authUser = supabase.auth.currentUser;
    if (authUser == null) return;

    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final response = await supabase
          .from('users')
          .select()
          .eq('id', authUser.id)
          .maybeSingle();
      userData = {
        ...?response,
        'email': response?['email'] ?? authUser.email ?? '',
      };
    } catch (error) {
      debugPrint('Error loading user details: $error');
      errorMessage = providerErrorMessage(error);
      userData = {};
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  String getValue(String key) => userData[key]?.toString() ?? '';

  Future<bool> updateProfile(Map<String, String> values) async {
    final user = supabase.auth.currentUser;
    if (user == null) return false;
    try {
      await supabase.from('users').update(values).eq('id', user.id);
      userData = {...userData, ...values};
      notifyListeners();
      return true;
    } catch (error) {
      errorMessage = providerErrorMessage(error);
      debugPrint('Error updating profile: $error');
      return false;
    }
  }

  Future<bool> updatePassword(String password) async {
    if (password.trim().length < 6) return false;
    try {
      await supabase.auth.updateUser(UserAttributes(password: password.trim()));
      return true;
    } catch (error) {
      errorMessage = providerErrorMessage(error);
      debugPrint('Error updating password: $error');
      return false;
    }
  }

  Future<bool> deleteAccount() async {
    if (supabase.auth.currentUser == null) return false;
    try {
      await supabase.rpc('delete_my_account');
      await supabase.auth.signOut();
      userData = {};
      notifyListeners();
      return true;
    } catch (error) {
      errorMessage = providerErrorMessage(error);
      debugPrint('Error deleting account: $error');
      return false;
    }
  }
}
