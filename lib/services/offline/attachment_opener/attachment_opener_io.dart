import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

Future<bool> openAttachmentPlatform({
  String? localFilePath,
  Uint8List? fileBytes,
  String? fileName,
  String? mimeType,
}) async {
  try {
    String? pathToOpen = localFilePath;

    // If local file path is missing or does not exist, write bytes to a temp file
    if ((pathToOpen == null || !File(pathToOpen).existsSync()) &&
        fileBytes != null &&
        fileBytes.isNotEmpty) {
      final tempDir = await getTemporaryDirectory();
      final safeName = (fileName != null && fileName.isNotEmpty)
          ? fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
          : 'document_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final tempFile = File('${tempDir.path}/$safeName');
      await tempFile.writeAsBytes(fileBytes, flush: true);
      pathToOpen = tempFile.path;
    }

    if (pathToOpen != null && File(pathToOpen).existsSync()) {
      final result = await OpenFilex.open(pathToOpen, type: mimeType);
      return result.type == ResultType.done;
    }
  } catch (e) {
    debugPrint('AttachmentOpenerIo error: $e');
  }
  return false;
}
