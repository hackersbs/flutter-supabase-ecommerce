import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:e_comerce_appliction/provider/authprovider.dart';
import 'package:flutter_animate/flutter_animate.dart';

class SingupScreen extends StatefulWidget {
  const SingupScreen({super.key});

  @override
  State<SingupScreen> createState() => _SingupScreenState();
}

class _SingupScreenState extends State<SingupScreen> {
  String _selectedRole = 'Buyer';

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _countryController.dispose();
    _stateController.dispose();
    _cityController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? theme.colorScheme.surface
          : theme.colorScheme.primary,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header Section
            Expanded(
              flex: 2,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_add_alt_1_outlined,
                      size: 60,
                      color: isDark ? theme.colorScheme.primary : Colors.white,
                    ).animate().fade(duration: 400.ms).scale(),
                    const SizedBox(height: 10),
                    Text(
                      'Create an Account',
                      style: TextStyle(
                        color: isDark
                            ? theme.colorScheme.onSurface
                            : Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ).animate().fade(delay: 200.ms).slideY(begin: 0.1),
                  ],
                ),
              ),
            ),
            // Form Section
            Expanded(
              flex: 5,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Looks like you\'re new here!',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ).animate().fade(delay: 300.ms),
                          const SizedBox(height: 4),
                          Text(
                            'Sign up to get started',
                            style: TextStyle(
                              fontSize: 14,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ).animate().fade(delay: 350.ms),
                          const SizedBox(height: 24),
                          TextField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: 'Full Name',
                              prefixIcon: const Icon(Icons.person_outline),
                            ),
                          ).animate().fade(delay: 400.ms).slideX(begin: -0.05),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _emailController,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              prefixIcon: const Icon(Icons.email_outlined),
                            ),
                          ).animate().fade(delay: 450.ms).slideX(begin: -0.05),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                            ),
                          ).animate().fade(delay: 500.ms).slideX(begin: -0.05),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _confirmPasswordController,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: 'Confirm Password',
                              prefixIcon: const Icon(Icons.lock_reset_outlined),
                            ),
                          ).animate().fade(delay: 550.ms).slideX(begin: -0.05),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: 'Phone Number',
                              prefixIcon: const Icon(Icons.phone_outlined),
                            ),
                          ).animate().fade(delay: 500.ms).slideX(begin: -0.05),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _addressController,
                            decoration: InputDecoration(
                              labelText: 'Address',
                              prefixIcon: const Icon(
                                Icons.location_on_outlined,
                              ),
                            ),
                          ).animate().fade(delay: 550.ms).slideX(begin: -0.05),
                          const SizedBox(height: 16),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final fields = [
                                TextField(
                                  controller: _countryController,
                                  decoration: InputDecoration(
                                    labelText: 'Country',
                                  ),
                                ),
                                TextField(
                                  controller: _stateController,
                                  decoration: InputDecoration(
                                    labelText: 'State',
                                  ),
                                ),
                              ];
                              if (constraints.maxWidth < 420) {
                                return Column(
                                  children: [
                                    fields[0],
                                    const SizedBox(height: 16),
                                    fields[1],
                                  ],
                                );
                              }
                              return Row(
                                children: [
                                  Expanded(child: fields[0]),
                                  const SizedBox(width: 16),
                                  Expanded(child: fields[1]),
                                ],
                              );
                            },
                          ).animate().fade(delay: 600.ms).slideX(begin: -0.05),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _cityController,
                            decoration: InputDecoration(
                              labelText: 'City',
                              prefixIcon: const Icon(
                                Icons.location_city_outlined,
                              ),
                            ),
                          ).animate().fade(delay: 650.ms).slideX(begin: -0.05),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedRole,
                            decoration: InputDecoration(
                              labelText: 'Role',
                              prefixIcon: const Icon(Icons.badge_outlined),
                            ),
                            items: ['Buyer', 'Seller']
                                .map(
                                  (role) => DropdownMenuItem(
                                    value: role,
                                    child: Text(role),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _selectedRole = value;
                                });
                              }
                            },
                          ).animate().fade(delay: 700.ms).slideX(begin: -0.05),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: FilledButton(
                              onPressed: () {
                                final password = _passwordController.text;
                                final confirmPassword =
                                    _confirmPasswordController.text;

                                if (password.length < 6) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Password must be at least 6 characters.',
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                if (password != confirmPassword) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Passwords do not match.'),
                                    ),
                                  );
                                  return;
                                }

                                context.read<AthenDiction>().signUp(
                                  context,
                                  _emailController.text,
                                  password,
                                  _nameController.text,
                                  _phoneController.text,
                                  _addressController.text,
                                  _countryController.text,
                                  _stateController.text,
                                  _cityController.text,
                                  _selectedRole,
                                );
                              },
                              style: FilledButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                'Continue',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ).animate().fade(delay: 800.ms).slideY(begin: 0.1),
                          const SizedBox(height: 32),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Existing User?',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                                child: const Text(
                                  'Log in',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ).animate().fade(delay: 900.ms),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
