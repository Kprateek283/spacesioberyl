import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import '../network/mock_upload_service.dart';
import '../utils/ui_feedback.dart';

/// Captures a client signature and returns a mock upload URL for the backend.
class SignatureCanvasWidget extends StatefulWidget {
  final ValueChanged<String> onSignatureComplete;

  const SignatureCanvasWidget({
    super.key,
    required this.onSignatureComplete,
  });

  @override
  State<SignatureCanvasWidget> createState() => _SignatureCanvasWidgetState();
}

class _SignatureCanvasWidgetState extends State<SignatureCanvasWidget> {
  late SignatureController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SignatureController(
      penStrokeWidth: 5,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Signature(
            controller: _controller,
            height: 200,
            backgroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            OutlinedButton.icon(
              onPressed: _controller.clear,
              icon: const Icon(Icons.delete),
              label: const Text('Clear'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                if (_controller.isEmpty) {
                  UiFeedback.error(context, 'Please draw a signature');
                  return;
                }
                final mockPath =
                    'signature_${DateTime.now().millisecondsSinceEpoch}.png';
                widget.onSignatureComplete(
                  MockUploadService.toMockUrl(mockPath, bucket: 'signatures'),
                );
              },
              icon: const Icon(Icons.check_circle),
              label: const Text('Use Signature'),
            ),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
