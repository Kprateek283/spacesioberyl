import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class FileHelper {
  static Future<String?> persistFile(String? tempPath) async {
    if (tempPath == null || tempPath.isEmpty) return null;
    
    final file = File(tempPath);
    if (!await file.exists()) return tempPath; // Might already be a remote URL or missing

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = p.basename(tempPath);
      final newPath = p.join(appDir.path, fileName);
      
      final newFile = await file.copy(newPath);
      return newFile.path;
    } catch (e) {
      return tempPath;
    }
  }
}
