import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/ui_feedback.dart';
import '../../core/network/api_client.dart';
import '../../features/auth/providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _loginIdController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _loginIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      await ref.read(authProvider.notifier).login(
        _loginIdController.text.trim(),
        _passwordController.text,
      );
    } catch (e) {
      if (mounted) {
        UiFeedback.parsedError(context, e);
      }
    }
  }

  void _showForgotPasswordDialog(BuildContext context) {
    final emailCtrl = TextEditingController();
    bool loading = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Reset Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter your email to receive an OTP.'),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: loading
                  ? null
                  : () async {
                      if (emailCtrl.text.isEmpty) return;
                      setState(() => loading = true);
                      try {
                        final api = ref.read(apiClientProvider);
                        await api.post('/password/forgot', data: {'email': emailCtrl.text.trim()});
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          _showResetPasswordDialog(context, emailCtrl.text.trim());
                        }
                      } catch (e) {
                        setState(() => loading = false);
                        if (ctx.mounted) {
                          UiFeedback.parsedError(context, e);
                        }
                      }
                    },
              child: loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Send OTP'),
            ),
          ],
        ),
      ),
    );
  }

  void _showResetPasswordDialog(BuildContext context, String email) {
    final otpCtrl = TextEditingController();
    final newPasswordCtrl = TextEditingController();
    bool loading = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Reset Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter the OTP sent to your email and your new password.'),
              const SizedBox(height: 12),
              TextField(
                controller: otpCtrl,
                decoration: const InputDecoration(
                  labelText: 'OTP',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newPasswordCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New Password',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: loading
                  ? null
                  : () async {
                      if (otpCtrl.text.isEmpty || newPasswordCtrl.text.isEmpty) return;
                      setState(() => loading = true);
                      try {
                        final api = ref.read(apiClientProvider);
                        await api.post('/password/reset', data: {
                          'email': email,
                          'token': otpCtrl.text.trim(),
                          'new_password': newPasswordCtrl.text,
                        });
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          UiFeedback.success(context, 'Password reset successfully. You can now log in.');
                        }
                      } catch (e) {
                        setState(() => loading = false);
                        if (ctx.mounted) {
                          UiFeedback.parsedError(context, e);
                        }
                      }
                    },
              child: loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Reset Password'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.isLoading;
    return Scaffold(
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
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.workspaces_outlined, color: AppColors.primary, size: 32),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Enterprise Suite',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, letterSpacing: -0.5),
                ),
                Text(
                  'Secure access to your workspace.',
                  style: TextStyle(fontSize: 14, color: AppColors.onSurfaceVariant),
                ),
                const SizedBox(height: 32),

                // Login Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.outlineVariant),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 24, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Email / Username
                        const Text('Email Address', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _loginIdController,
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.mail_outline, size: 20, color: AppColors.onSurfaceVariant),
                          hintText: 'name@company.com',
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
                            onPressed: () => _showForgotPasswordDialog(context),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('Forgot Password?', style: TextStyle(fontSize: 12)),
                          )
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.lock_outline, size: 20, color: AppColors.onSurfaceVariant),
                          hintText: '••••••••',
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Login Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _handleLogin,
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
                ),

              // Footer
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Text.rich(
                    TextSpan(
                      text: 'SYSTEM STATUS: ',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.onSurfaceVariant),
                      children: [
                        TextSpan(text: 'OPERATIONAL', style: TextStyle(color: AppColors.primary)),
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
