import 'dart:io';

void downloadFile(String filename, String content) {
  try {
    // Attempt writing to the user's Downloads directory or current directory
    String path = filename;
    final userProfile = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
    if (userProfile != null) {
      final downloadsDir = Directory('$userProfile\\Downloads');
      if (downloadsDir.existsSync()) {
        path = '${downloadsDir.path}\\$filename';
      }
    }
    final file = File(path);
    file.writeAsStringSync(content);
  } catch (_) {
    // Fallback: silently ignore or let caller handle clipboard
  }
}
