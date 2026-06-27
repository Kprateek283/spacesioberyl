import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/ui_feedback.dart';
import '../../features/auth/providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _loginIdController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _keepSignedIn = false;

  @override
  void dispose() {
    _loginIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    try {
      await ref.read(authProvider.notifier).login(
        _loginIdController.text.trim(),
        _passwordController.text,
      );
      
      // Routing is handled automatically by AuthWrapper in main.dart
      // based on the authState changes. We don't need to pushReplacement here.
    } catch (e) {
      if (mounted) {
        UiFeedback.parsedError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.isLoading;
    return Scaffold(
      backgroundColor: const Color(0xFFFEF9F2), // Tailwind bg-background
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 420,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Brand Header
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2196f3), // primary-container
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.domain, color: Colors.white, size: 28),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Studio CRM',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w600, letterSpacing: -0.5),
                ),
                const Text(
                  'Secure operational portal',
                  style: TextStyle(fontSize: 14, color: Color(0xFF404752)),
                ),
                const SizedBox(height: 32),

                // Login Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 24, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Email / Username
                      const Text('Email / Username', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _loginIdController,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.person_outline, size: 20, color: Color(0xFF707883)),
                          hintText: 'Enter your email or corporate ID',
                          hintStyle: const TextStyle(color: Colors.black38),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFbfc7d4)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF0061a4), width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Password
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Password', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                          TextButton(
                            onPressed: () => UiFeedback.info(
                              context,
                              'Password reset is not configured yet. Contact your admin.',
                            ),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('Forgot?', style: TextStyle(fontSize: 12, color: Color(0xFF0061a4))),
                          )
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.lock_outline, size: 20, color: Color(0xFF707883)),
                          hintText: '••••••••',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFbfc7d4)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF0061a4), width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Checkbox
                      Row(
                        children: [
                          SizedBox(
                            height: 24,
                            width: 24,
                            child: Checkbox(
                              value: _keepSignedIn,
                              activeColor: const Color(0xFF0061a4),
                              onChanged: (val) => setState(() => _keepSignedIn = val!),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('Keep me signed in', style: TextStyle(fontSize: 14, color: Color(0xFF404752))),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Login Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0061a4),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                          child: isLoading
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Log In', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Footer
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: Text.rich(
                    TextSpan(
                      text: 'SYSTEM STATUS: ',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black54),
                      children: [
                        TextSpan(text: 'OPERATIONAL', style: TextStyle(color: Color(0xFF006e1c))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}