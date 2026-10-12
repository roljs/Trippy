import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

Future<bool> openAttachmentPlatform({
  String? localFilePath,
  Uint8List? fileBytes,
  String? fileName,
  String? mimeType,
}) async {
  if (fileBytes == null || fileBytes.isEmpty) {
    if (localFilePath != null &&
        (localFilePath.startsWith('blob:') || localFilePath.startsWith('data:'))) {
      web.window.open(localFilePath, '_blank');
      return true;
    }
    return false;
  }

  try {
    final type = (mimeType != null && mimeType.isNotEmpty)
        ? mimeType
        : 'application/pdf';
    final blob =
        web.Blob([fileBytes.toJS].toJS, web.BlobPropertyBag(type: type));
    final blobUrl = web.URL.createObjectURL(blob);

    // Open in new browser tab
    final newWindow = web.window.open(blobUrl, '_blank');
    if (newWindow != null) {
      return true;
    }

    // Fallback: Trigger simulated click via temporary anchor if pop-up blocked
    final anchor = web.HTMLAnchorElement()
      ..href = blobUrl
      ..download = fileName ?? 'document'
      ..target = '_blank'
      ..style.display = 'none';
    web.document.body?.appendChild(anchor);
    anchor.click();
    anchor.remove();
    return true;
  } catch (_) {
    return false;
  }
}
