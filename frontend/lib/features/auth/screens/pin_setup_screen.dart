import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ui_feedback.dart';
import '../providers/auth_provider.dart';

class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  final _normalPinController = TextEditingController();
  final _highSecurityPinController = TextEditingController();

  bool get _pinsMatch =>
      _normalPinController.text.isNotEmpty &&
      _normalPinController.text == _highSecurityPinController.text;

  @override
  void initState() {
    super.initState();
    _normalPinController.addListener(() => setState(() {}));
    _highSecurityPinController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _normalPinController.dispose();
    _highSecurityPinController.dispose();
    super.dispose();
  }

  void _handleSubmit() async {
    final normalPin = _normalPinController.text.trim();
    final highSecurityPin = _highSecurityPinController.text.trim();

    if (normalPin.isEmpty || highSecurityPin.isEmpty) {
      UiFeedback.error(context, 'Please fill all fields');
      return;
    }
    if (normalPin == highSecurityPin) {
      UiFeedback.error(context, 'Normal PIN and High-Security PIN cannot be identical');
      return;
    }

    try {
      await ref.read(authProvider.notifier).setupPins(normalPin, highSecurityPin);
    } catch (e) {
      if (mounted) {
        UiFeedback.parsedError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: Center(
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.outlineVariant),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 24, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'System Initialization',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Set your Security PINs to continue.',
                style: TextStyle(color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              const Text('Standard PIN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              TextField(
                controller: _normalPinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '4 digits',
                  counterText: "",
                ),
              ),
              const SizedBox(height: 16),
              Divider(color: AppColors.outlineVariant),
              const SizedBox(height: 8),
              const Text('High-Security Area', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text('High-Security PIN (Ghost Mode)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              TextField(
                controller: _highSecurityPinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '6 digits',
                  counterText: "",
                ),
              ),
              if (_pinsMatch) ...[
                const SizedBox(height: 8),
                Text(
                  'Normal PIN and High-Security PIN cannot be identical',
                  style: TextStyle(color: AppColors.error, fontSize: 12),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: authState.isLoading || _pinsMatch ? null : _handleSubmit,
                  child: authState.isLoading
                      ? const SizedBox(
                          width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save & Initialize'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
