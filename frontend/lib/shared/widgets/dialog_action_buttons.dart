import 'package:flutter/material.dart';

class DialogActionButtons extends StatelessWidget {
  final VoidCallback onCancel;
  final VoidCallback? onSubmit;
  final bool isSubmitting;
  final String submitText;
  final String cancelText;

  const DialogActionButtons({
    super.key,
    required this.onCancel,
    required this.onSubmit,
    this.isSubmitting = false,
    required this.submitText,
    this.cancelText = 'Cancel',
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: isSubmitting ? null : onCancel,
          child: Text(cancelText),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: isSubmitting ? null : onSubmit,
          child: isSubmitting
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(submitText),
        ),
      ],
    );
  }
}
