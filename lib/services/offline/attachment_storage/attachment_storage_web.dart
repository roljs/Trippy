import 'dart:typed_data';
import 'attachment_storage_platform.dart';

AttachmentStorage createAttachmentStorage() => AttachmentStorageWeb();

class AttachmentStorageWeb implements AttachmentStorage {
  final Map<String, Uint8List> _memoryCache = {};

  @override
  Future<bool> hasFile(String key) async {
    return _memoryCache.containsKey(key);
  }

  @override
  Future<Uint8List?> getFileBytes(String key) async {
    return _memoryCache[key];
  }

  @override
  Future<String?> saveFile(String key, Uint8List bytes, {String? extension}) async {
    _memoryCache[key] = bytes;
    return key;
  }

  @override
  Future<String?> getFilePath(String key, {String? extension}) async {
    if (_memoryCache.containsKey(key)) {
      return key;
    }
    return null;
  }

  @override
  Future<void> deleteFile(String key) async {
    _memoryCache.remove(key);
  }

  @override
  Future<void> clearAll() async {
    _memoryCache.clear();
  }

  @override
  Future<int> getTotalSizeBytes() async {
    int total = 0;
    for (final bytes in _memoryCache.values) {
      total += bytes.lengthInBytes;
    }
    return total;
  }
}
