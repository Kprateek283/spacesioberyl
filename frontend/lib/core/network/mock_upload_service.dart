import 'package:path/path.dart' as p;

/// Temporary frontend-only helper for environments where backend file upload
/// routes are not available yet. A generic `POST /api/v1/uploads` endpoint is
/// needed to replace this — see issue/01-backend-issues.md.
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
