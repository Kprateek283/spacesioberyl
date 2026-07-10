import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:signature/signature.dart';
import '../utils/ui_feedback.dart';

/// Captures a client signature, persists it as a local PNG file, and returns
/// the local file path. The real upload happens during offline-queue sync
/// (see SyncService), consistent with how other captured photos are handled.
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
  bool _isSaving = false;

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
              onPressed: _isSaving ? null : () => _saveSignature(context),
              icon: const Icon(Icons.check_circle),
              label: const Text('Use Signature'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _saveSignature(BuildContext context) async {
    if (_controller.isEmpty) {
      UiFeedback.error(context, 'Please draw a signature');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final bytes = await _controller.toPngBytes();
      if (bytes == null) {
        if (context.mounted) UiFeedback.error(context, 'Failed to capture signature');
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final fileName = 'signature_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(p.join(tempDir.path, fileName));
      await file.writeAsBytes(bytes);

      widget.onSignatureComplete(file.path);
    } catch (e) {
      if (context.mounted) UiFeedback.error(context, 'Failed to save signature: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
