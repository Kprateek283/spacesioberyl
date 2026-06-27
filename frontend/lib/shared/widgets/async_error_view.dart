import 'package:flutter/material.dart';
import '../../core/utils/form_validators.dart';

/// Standard error UI for Riverpod [AsyncValue.error] states.
class AsyncErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;

  const AsyncErrorView({
    super.key,
    required this.error,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final message = ErrorMessageParser.parseError(error);
    final isNetwork = ErrorMessageParser.isNetworkError(error);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isNetwork ? Icons.wifi_off : Icons.error_outline,
              size: 48,
              color: const Color(0xFF707883),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF404752)),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
