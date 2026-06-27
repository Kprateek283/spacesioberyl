import 'package:path/path.dart' as p;

/// Temporary frontend-only helper for environments where backend file upload
/// routes are not available yet.
class MockUploadService {
  static String toMockUrl(String localPath, {String bucket = 'mock-uploads'}) {
    final fileName = p.basename(localPath).replaceAll(' ', '_');
    final safeName = fileName.isEmpty ? 'file.bin' : fileName;
    return 'https://mock.local/$bucket/$safeName';
  }

  static bool isHttpUrl(String? value) {
    if (value == null) return false;
    return value.startsWith('http://') || value.startsWith('https://');
  }
}
