// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/ui_feedback.dart';
import '../../../shared/widgets/async_error_view.dart';
import '../../../shared/widgets/dialog_action_buttons.dart';
import '../../../shared/widgets/dialog_fields.dart';
import '../services/iam_service.dart';

final usersListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(iamServiceProvider).getUsers();
});

class IamUsersScreen extends ConsumerStatefulWidget {
  const IamUsersScreen({super.key});

  @override
  ConsumerState<IamUsersScreen> createState() => _IamUsersScreenState();
}

class _IamUsersScreenState extends ConsumerState<IamUsersScreen> {
  bool _creating = false;

  Future<void> _showCreateUserDialog() async {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    var role = 'staff';
    var department = 'operations';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModal) => AlertDialog(
          title: const Text('Create User'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DialogTextField(controller: nameCtrl, labelText: 'Full Name'),
                const SizedBox(height: 12),
                DialogTextField(
                  controller: emailCtrl,
                  labelText: 'Email',
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                DialogTextField(
                  controller: passCtrl,
                  labelText: 'Temporary Password',
                  obscureText: true,
                ),
                const SizedBox(height: 12),
                DialogDropdownField<String>(
                  value: role,
                  items: const [
                    DropdownMenuItem(value: 'staff', child: Text('Staff')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                    DropdownMenuItem(
                        value: 'super_admin', child: Text('Super Admin')),
                  ],
                  onChanged: (v) => setModal(() => role = v ?? role),
                ),
                const SizedBox(height: 12),
                DialogDropdownField<String>(
                  value: department,
                  items: const [
                    DropdownMenuItem(
                        value: 'management', child: Text('Management')),
                    DropdownMenuItem(
                        value: 'operations', child: Text('Operations')),
                    DropdownMenuItem(value: 'hr', child: Text('HR')),
                    DropdownMenuItem(value: 'sales', child: Text('Sales')),
                  ],
                  onChanged: (v) => setModal(() => department = v ?? department),
                ),
              ],
            ),
          ),
          actions: [
            DialogActionButtons(
              onCancel: () => Navigator.pop(ctx),
              isSubmitting: _creating,
              submitText: 'Create',
              onSubmit: () async {
                if (nameCtrl.text.isEmpty ||
                    emailCtrl.text.isEmpty ||
                    passCtrl.text.isEmpty) {
                  UiFeedback.error(context, 'All fields are required');
                  return;
                }
                setModal(() => _creating = true);
                try {
                  await ref.read(iamServiceProvider).createUser(
                        name: nameCtrl.text.trim(),
                        email: emailCtrl.text.trim(),
                        password: passCtrl.text,
                        role: role,
                        department: department,
                      );
                  if (mounted) {
                    Navigator.pop(ctx);
                    ref.invalidate(usersListProvider);
                    UiFeedback.success(context, 'User created');
                  }
                } catch (e) {
                  UiFeedback.parsedError(context, e);
                } finally {
                  setModal(() => _creating = false);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(usersListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateUserDialog,
        child: const Icon(Icons.person_add),
      ),
      body: usersAsync.when(
        data: (users) {
          if (users.isEmpty) {
            return const Center(child: Text('No users found'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(usersListProvider),
            child: ListView.separated(
              itemCount: users.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final u = users[i];
                final name = (u['name'] ?? u['Name'] ?? 'User').toString();
                final email = (u['email'] ?? u['Email'] ?? '').toString();
                final role = (u['role'] ?? u['role_name'] ?? 'staff').toString();
                final dept = (u['department'] ?? '').toString();
                final active = u['is_active'] != false;
                return ListTile(
                  leading: CircleAvatar(child: Text(name.isNotEmpty ? name[0] : '?')),
                  title: Text(name),
                  subtitle: Text('$email · $dept'),
                  trailing: Chip(
                    label: Text(role),
                    backgroundColor: active ? Colors.green.shade50 : Colors.red.shade50,
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AsyncErrorView(
          error: e,
          onRetry: () => ref.invalidate(usersListProvider),
        ),
      ),
    );
  }
}
