import 'dart:typed_data';
import 'attachment_opener_stub.dart'
    if (dart.library.html) 'attachment_opener_web.dart'
    if (dart.library.js_interop) 'attachment_opener_web.dart'
    if (dart.library.io) 'attachment_opener_io.dart';

/// Platform-agnostic opener for cached offline attachments and documents.
abstract class AttachmentOpener {
  /// Opens a local or cached attachment in the default system viewer,
  /// external application (via OpenFilex on mobile/desktop), or a browser blob tab on Web.
  ///
  /// Returns `true` if the attachment was successfully launched.
  static Future<bool> openAttachment({
    String? localFilePath,
    Uint8List? fileBytes,
    String? fileName,
    String? mimeType,
  }) {
    return openAttachmentPlatform(
      localFilePath: localFilePath,
      fileBytes: fileBytes,
      fileName: fileName,
      mimeType: mimeType,
    );
  }
}
