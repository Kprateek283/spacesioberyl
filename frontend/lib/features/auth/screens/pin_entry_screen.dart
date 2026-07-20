import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ui_feedback.dart';
import '../providers/auth_provider.dart';

/// PIN verify screen: minimalist numpad lock-screen matching the wireframe.
/// Normal PIN is exactly 4 digits, the Ghost Mode PIN is exactly 6 digits, so
/// this auto-submits after a short pause at 4 digits (giving the user a
/// window to keep typing a 6-digit PIN instead) or immediately at 6 digits.
class PinEntryScreen extends ConsumerStatefulWidget {
  const PinEntryScreen({super.key});

  @override
  ConsumerState<PinEntryScreen> createState() => _PinEntryScreenState();
}

class _PinEntryScreenState extends ConsumerState<PinEntryScreen> {
  String _pin = '';
  Timer? _autoSubmitTimer;
  bool _isVerifying = false;

  static const _maxLength = 6;
  static const _autoSubmitLength = 4;

  @override
  void dispose() {
    _autoSubmitTimer?.cancel();
    super.dispose();
  }

  void _onDigitPressed(String digit) {
    if (_isVerifying || _pin.length >= _maxLength) return;
    _autoSubmitTimer?.cancel();
    setState(() => _pin += digit);

    if (_pin.length == _maxLength) {
      _handleVerify();
    } else if (_pin.length == _autoSubmitLength) {
      _autoSubmitTimer = Timer(const Duration(milliseconds: 600), _handleVerify);
    }
  }

  void _onBackspace() {
    if (_isVerifying || _pin.isEmpty) return;
    _autoSubmitTimer?.cancel();
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  void _onClear() {
    _autoSubmitTimer?.cancel();
    setState(() => _pin = '');
  }

  Future<void> _handleVerify() async {
    _autoSubmitTimer?.cancel();
    if (_pin.isEmpty || _isVerifying) return;

    setState(() => _isVerifying = true);
    try {
      await ref.read(authProvider.notifier).verifyPin(_pin);
    } catch (e) {
      if (mounted) {
        setState(() => _pin = '');
        UiFeedback.parsedError(context, e);
      }
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: AppColors.primaryContainer,
                    child: Icon(Icons.person, size: 36, color: AppColors.onPrimaryContainer),
                  ),
                  const SizedBox(height: 20),
                  const Text('Session Locked', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text('Enter PIN to access your workspace', style: TextStyle(color: AppColors.onSurfaceVariant)),
                  const SizedBox(height: 32),
                  _PinDots(length: _pin.length, maxLength: _maxLength),
                  const SizedBox(height: 32),
                  if (_isVerifying)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: CircularProgressIndicator(),
                    )
                  else
                    _Numpad(onDigit: _onDigitPressed, onBackspace: _onBackspace),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _isVerifying ? null : _onClear,
                    child: const Text('Clear'),
                  ),
                  TextButton(
                    onPressed: () => ref.read(authProvider.notifier).logout(),
                    child: Text('Logout', style: TextStyle(color: AppColors.error)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PinDots extends StatelessWidget {
  final int length;
  final int maxLength;

  const _PinDots({required this.length, required this.maxLength});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(maxLength, (i) {
        final filled = i < length;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 6),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? AppColors.primary : Colors.transparent,
            border: Border.all(color: filled ? AppColors.primary : AppColors.outlineVariant, width: 2),
          ),
        );
      }),
    );
  }
}

class _Numpad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  const _Numpad({required this.onDigit, required this.onBackspace});

  @override
  Widget build(BuildContext context) {
    Widget key(String label, {VoidCallback? onTap, Widget? child}) {
      return Expanded(
        child: AspectRatio(
          aspectRatio: 1,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Material(
              color: AppColors.surfaceContainerLow,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onTap,
                child: Center(
                  child: child ?? Text(label, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(children: [key('1', onTap: () => onDigit('1')), key('2', onTap: () => onDigit('2')), key('3', onTap: () => onDigit('3'))]),
        Row(children: [key('4', onTap: () => onDigit('4')), key('5', onTap: () => onDigit('5')), key('6', onTap: () => onDigit('6'))]),
        Row(children: [key('7', onTap: () => onDigit('7')), key('8', onTap: () => onDigit('8')), key('9', onTap: () => onDigit('9'))]),
        Row(children: [
          const Expanded(child: SizedBox()),
          key('0', onTap: () => onDigit('0')),
          key(
            '',
            onTap: onBackspace,
            child: Icon(Icons.backspace_outlined, color: AppColors.onSurfaceVariant),
          ),
        ]),
      ],
    );
  }
}
