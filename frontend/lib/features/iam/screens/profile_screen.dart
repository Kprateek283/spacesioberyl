// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/ui_feedback.dart';
import '../../../shared/widgets/dialog_action_buttons.dart';
import '../../../shared/widgets/dialog_fields.dart';
import '../../../shared/widgets/async_error_view.dart';
import '../../auth/providers/auth_provider.dart';
import '../services/iam_service.dart';

final profileProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.watch(iamServiceProvider).getProfile();
});

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _changePassword(BuildContext context, WidgetRef ref) async {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
  var submitting = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModal) => AlertDialog(
          title: const Text('Change Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DialogTextField(
                controller: oldCtrl,
                labelText: 'Current Password',
                obscureText: true,
              ),
              const SizedBox(height: 12),
              DialogTextField(
                controller: newCtrl,
                labelText: 'New Password',
                obscureText: true,
              ),
            ],
          ),
          actions: [
            DialogActionButtons(
              onCancel: () => Navigator.pop(ctx),
              isSubmitting: submitting,
              submitText: 'Update',
              onSubmit: () async {
                if (oldCtrl.text.isEmpty || newCtrl.text.length < 8) {
                  UiFeedback.error(
                      context, 'New password must be at least 8 characters');
                  return;
                }
                setModal(() => submitting = true);
                try {
                  await ref.read(iamServiceProvider).changePassword(
                        oldCtrl.text,
                        newCtrl.text,
                      );
                  if (context.mounted) {
                    Navigator.pop(ctx);
                    UiFeedback.success(context, 'Password updated');
                  }
                } catch (e) {
                  UiFeedback.parsedError(context, e);
                } finally {
                  setModal(() => submitting = false);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final auth = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: const Color(0xFF0061a4),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: profileAsync.when(
        data: (profile) {
          final name = (profile['name'] ?? 'User').toString();
          final email = (profile['email'] ?? '').toString();
          final role = (profile['role'] ?? auth.userRole ?? 'staff').toString();
          final dept = (profile['department'] ?? '').toString();

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: const Color(0xFF0061a4),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 32, color: Colors.white),
                ),
              ),
              const SizedBox(height: 16),
              Text(name,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold)),
              Text(email, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              _infoTile('Role', role),
              _infoTile('Department', dept),
              _infoTile('Ghost Mode', auth.isGhostMode ? 'Active' : 'Inactive'),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _changePassword(context, ref),
                icon: const Icon(Icons.lock),
                label: const Text('Change Password'),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AsyncErrorView(
          error: e,
          onRetry: () => ref.invalidate(profileProvider),
        ),
      ),
    );
  }

  Widget _infoTile(String label, String value) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      subtitle: Text(value, style: const TextStyle(fontSize: 16)),
    );
  }
}
