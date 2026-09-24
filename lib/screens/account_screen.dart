import 'package:e_comerce_appliction/provider/authprovider.dart';
import 'package:e_comerce_appliction/provider/themeprovider.dart';
import 'package:e_comerce_appliction/provider/userprovider.dart';
import 'package:e_comerce_appliction/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:e_comerce_appliction/widgets/error_state.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  bool _isSaving = false;

  static const _fields = <(String, String, IconData)>[
    ('name', 'User name', Icons.person_outline),
    ('phone', 'Phone number', Icons.phone_outlined),
    ('address', 'Address', Icons.home_outlined),
    ('country', 'Country', Icons.public_outlined),
    ('state', 'State', Icons.map_outlined),
    ('city', 'City', Icons.location_city_outlined),
  ];

  @override
  void initState() {
    super.initState();
    for (final field in _fields) {
      _controllers[field.$1] = TextEditingController();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<UserProvider>();
      await provider.loadUser();
      if (!mounted) return;
      for (final field in _fields) {
        _controllers[field.$1]!.text = provider.getValue(field.$1);
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final values = {
      for (final field in _fields)
        field.$1: _controllers[field.$1]!.text.trim(),
    };
    final success = await context.read<UserProvider>().updateProfile(values);
    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Profile updated'
              : context.read<UserProvider>().errorMessage ??
                    'Profile update failed',
        ),
      ),
    );
  }

  Future<void> _changePassword() async {
    final controller = TextEditingController();
    final confirmController = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New password'),
            ),
            TextField(
              controller: confirmController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirm password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password cannot be empty.')),
                );
                return;
              }
              if (controller.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Password must be at least 6 characters.'),
                  ),
                );
                return;
              }
              if (controller.text != confirmController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Passwords do not match.')),
                );
                return;
              }
              Navigator.pop(context, controller.text);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
    controller.dispose();
    confirmController.dispose();
    if (password == null || !mounted) return;
    final success = await context.read<UserProvider>().updatePassword(password);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Password updated'
              : context.read<UserProvider>().errorMessage ??
                    'Password update failed',
        ),
      ),
    );
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This permanently deletes your profile, products, orders, and messages.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete account'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final success = await context.read<UserProvider>().deleteAccount();
    if (!mounted) return;
    if (success) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<UserProvider>().errorMessage ??
                'Account could not be deleted.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: userProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : userProvider.errorMessage != null && userProvider.userData.isEmpty
          ? ErrorState(
              message: userProvider.errorMessage!,
              onRetry: userProvider.loadUser,
            )
          : Form(
              key: _formKey,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const CircleAvatar(
                        radius: 42,
                        child: Icon(Icons.person, size: 46),
                      ).animate().fade(duration: 400.ms).scale(),
                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          userProvider.getValue('email'),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ).animate().fade(delay: 100.ms),
                      const SizedBox(height: 20),
                      ..._fields.asMap().entries.map(
                        (entry) =>
                            Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: TextFormField(
                                    controller: _controllers[entry.value.$1],
                                    maxLines: entry.value.$1 == 'address'
                                        ? 2
                                        : 1,
                                    decoration: InputDecoration(
                                      labelText: entry.value.$2,
                                      prefixIcon: Icon(entry.value.$3),
                                    ),
                                    validator: (value) =>
                                        value == null || value.trim().isEmpty
                                        ? 'Enter ${entry.value.$2.toLowerCase()}'
                                        : null,
                                  ),
                                )
                                .animate()
                                .fade(delay: (200 + (entry.key * 50)).ms)
                                .slideX(begin: 0.05),
                      ),
                      SizedBox(
                        height: 50,
                        child: FilledButton.icon(
                          onPressed: _isSaving ? null : _saveProfile,
                          icon: const Icon(Icons.save_outlined),
                          label: Text(_isSaving ? 'Saving...' : 'Save profile'),
                        ),
                      ).animate().fade(delay: 500.ms).slideY(begin: 0.1),
                      const SizedBox(height: 16),
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                        child: Column(
                          children: [
                            ListTile(
                              leading: Icon(
                                Icons.lock_outline,
                                color: theme.colorScheme.primary,
                              ),
                              title: const Text('Change password'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: _changePassword,
                            ),
                            const Divider(height: 1),
                            SwitchListTile.adaptive(
                              secondary: Icon(
                                Icons.dark_mode_outlined,
                                color: theme.colorScheme.primary,
                              ),
                              title: const Text('Dark mode'),
                              value: themeProvider.isDarkMode,
                              onChanged: themeProvider.setDarkMode,
                            ),
                          ],
                        ),
                      ).animate().fade(delay: 600.ms),
                      const SizedBox(height: 24),
                      ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        tileColor: Colors.orange.withValues(alpha: 0.1),
                        leading: const Icon(Icons.logout, color: Colors.orange),
                        title: const Text(
                          'Log out',
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onTap: () =>
                            context.read<AthenDiction>().logOut(context),
                      ).animate().fade(delay: 700.ms),
                      const SizedBox(height: 12),
                      ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        tileColor: theme.colorScheme.errorContainer,
                        leading: Icon(
                          Icons.delete_forever,
                          color: theme.colorScheme.error,
                        ),
                        title: Text(
                          'Delete account',
                          style: TextStyle(
                            color: theme.colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onTap: _deleteAccount,
                      ).animate().fade(delay: 800.ms),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
