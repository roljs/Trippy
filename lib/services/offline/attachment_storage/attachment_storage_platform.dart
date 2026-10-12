import 'dart:typed_data';

import 'attachment_storage_stub.dart'
    if (dart.library.html) 'attachment_storage_web.dart'
    if (dart.library.js_interop) 'attachment_storage_web.dart'
    if (dart.library.io) 'attachment_storage_io.dart';

abstract class AttachmentStorage {
  Future<bool> hasFile(String key);
  Future<Uint8List?> getFileBytes(String key);
  Future<String?> saveFile(String key, Uint8List bytes, {String? extension});
  Future<String?> getFilePath(String key, {String? extension});
  Future<void> deleteFile(String key);
  Future<void> clearAll();
  Future<int> getTotalSizeBytes();

  static AttachmentStorage? testOverride;
  static AttachmentStorage create() => testOverride ?? createAttachmentStorage();
}
