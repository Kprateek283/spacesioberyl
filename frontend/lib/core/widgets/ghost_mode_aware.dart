import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/auth/providers/auth_provider.dart';

/// A wrapper widget that conditionally displays or hides content based on ghost mode status.
/// 
/// Use this to wrap any UI elements that should NOT be visible when ghost mode is active.
/// Ghost mode = HIGH-SECURITY PIN used → cash data and sensitive financial fields hidden.
class GhostModeAware extends ConsumerWidget {
  final Widget child;
  final Widget? fallback; // Optional widget to show when in ghost mode (defaults to SizedBox.shrink)
  final bool hideInGhostMode; // If true, hides when ghost mode is active. Default: true.

  const GhostModeAware({
    super.key,
    required this.child,
    this.fallback,
    this.hideInGhostMode = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    // If ghost mode IS active and hideInGhostMode is true, return fallback (or empty)
    if (authState.isGhostMode && hideInGhostMode) {
      return fallback ?? const SizedBox.shrink();
    }

    // Otherwise, show the child widget
    return child;
  }
}

/// A convenience text widget for displaying cash-related labels or values only in normal mode.
class GhostAwareCashText extends ConsumerWidget {
  final String text;
  final TextStyle? style;

  const GhostAwareCashText(
    this.text, {
    super.key,
    this.style,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    if (authState.isGhostMode) {
      return const SizedBox.shrink();
    }

    return Text(text, style: style);
  }
}

/// A convenience widget for cash input fields (TextFormField) that hides in ghost mode.
class GhostAwareCashField extends ConsumerWidget {
  final TextEditingController controller;
  final String label;
  final String hintText;
  final TextInputType keyboardType;
  final InputDecoration decoration;

  const GhostAwareCashField({
    super.key,
    required this.controller,
    required this.label,
    required this.hintText,
    this.keyboardType = TextInputType.number,
    InputDecoration? decoration,
  })  : decoration = decoration ?? const InputDecoration();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    if (authState.isGhostMode) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: decoration.copyWith(
            hintText: hintText,
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}
