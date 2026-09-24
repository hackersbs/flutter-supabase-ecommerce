import 'package:e_comerce_appliction/provider/authprovider.dart';
import 'package:flutter/material.dart';
import 'package:e_comerce_appliction/screens/singup_screen.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth < 380 ? 20.0 : 32.0;
            final headerHeight = (constraints.maxHeight * 0.28).clamp(
              150.0,
              220.0,
            );
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  children: [
                    // Header Section
                    SizedBox(
                      height: headerHeight,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.shopping_bag_outlined,
                              size: 60,
                              color: isDark
                                  ? theme.colorScheme.primary
                                  : Colors.white,
                            ).animate().fade(duration: 400.ms).scale(),
                            const SizedBox(height: 10),
                            Text(
                              'Welcome',
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
                    Container(
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
                          child: Padding(
                            padding: EdgeInsets.all(horizontalPadding),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Log in for the best experience',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ).animate().fade(delay: 300.ms),
                                const SizedBox(height: 32),
                                TextField(
                                      controller: _emailController,
                                      decoration: InputDecoration(
                                        labelText: 'Email',
                                        prefixIcon: const Icon(
                                          Icons.person_outline,
                                        ),
                                      ),
                                    )
                                    .animate()
                                    .fade(delay: 400.ms)
                                    .slideX(begin: -0.05),
                                const SizedBox(height: 16),
                                TextField(
                                      controller: _passwordController,
                                      obscureText: _obscurePassword,
                                      decoration: InputDecoration(
                                        labelText: 'Password',
                                        prefixIcon: const Icon(
                                          Icons.lock_outline,
                                        ),
                                        suffixIcon: IconButton(
                                          tooltip: _obscurePassword
                                              ? 'Show password'
                                              : 'Hide password',
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_outlined
                                                : Icons.visibility_off_outlined,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _obscurePassword =
                                                  !_obscurePassword;
                                            });
                                          },
                                        ),
                                      ),
                                    )
                                    .animate()
                                    .fade(delay: 500.ms)
                                    .slideX(begin: -0.05),
                                const SizedBox(height: 8),
                                Consumer<AthenDiction>(
                                  builder: (context, auth, _) {
                                    final error = auth.errorMessage;
                                    if (error.isEmpty) {
                                      return const SizedBox.shrink();
                                    }
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Text(
                                        error,
                                        style: TextStyle(
                                          color: theme.colorScheme.error,
                                          fontSize: 13,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () async {
                                      final email = _emailController.text
                                          .trim();
                                      if (email.isEmpty) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Enter your email first to reset your password.',
                                                ),
                                              ),
                                            );
                                        return;
                                      }
                                      await context
                                          .read<AthenDiction>()
                                          .sendPasswordReset(context, email);
                                    },
                                    child: const Text('Forgot Password?'),
                                  ),
                                ).animate().fade(delay: 600.ms),
                                const SizedBox(height: 24),
                                SizedBox(
                                      width: double.infinity,
                                      height: 56,
                                      child: FilledButton(
                                        onPressed: _isSubmitting
                                            ? null
                                            : () async {
                                                final email = _emailController
                                                    .text
                                                    .trim();
                                                final password =
                                                    _passwordController.text;

                                                if (email.isEmpty ||
                                                    password.isEmpty) {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                        const SnackBar(
                                                          content: Text(
                                                            'Please fill all fields.',
                                                          ),
                                                        ),
                                                      );
                                                  return;
                                                }

                                                setState(
                                                  () => _isSubmitting = true,
                                                );
                                                await context
                                                    .read<AthenDiction>()
                                                    .login(
                                                      context,
                                                      email,
                                                      password,
                                                    );
                                                if (mounted) {
                                                  setState(
                                                    () => _isSubmitting = false,
                                                  );
                                                }
                                              },
                                        style: FilledButton.styleFrom(
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                        ),
                                        child: _isSubmitting
                                            ? const SizedBox(
                                                width: 22,
                                                height: 22,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                              )
                                            : const Text(
                                                'Login',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                      ),
                                    )
                                    .animate()
                                    .fade(delay: 700.ms)
                                    .slideY(begin: 0.1),
                                const SizedBox(height: 32),
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      'New to App?',
                                      style: TextStyle(
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const SingupScreen(),
                                          ),
                                        );
                                      },
                                      child: const Text(
                                        'Sign up',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ).animate().fade(delay: 800.ms),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
