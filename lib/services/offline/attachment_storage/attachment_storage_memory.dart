import 'dart:typed_data';
import 'attachment_storage_platform.dart';

/// Pure in-memory AttachmentStorage implementation for tests and environments
/// without disk or IndexedDB access.
class AttachmentStorageMemory implements AttachmentStorage {
  final Map<String, Uint8List> _cache = {};

  @override
  Future<bool> hasFile(String key) async => _cache.containsKey(key);

  @override
  Future<Uint8List?> getFileBytes(String key) async => _cache[key];

  @override
  Future<String?> saveFile(String key, Uint8List bytes, {String? extension}) async {
    _cache[key] = bytes;
    return key;
  }

  @override
  Future<String?> getFilePath(String key, {String? extension}) async {
    if (_cache.containsKey(key)) return key;
    return null;
  }

  @override
  Future<void> deleteFile(String key) async => _cache.remove(key);

  @override
  Future<void> clearAll() async => _cache.clear();

  @override
  Future<int> getTotalSizeBytes() async {
    int total = 0;
    for (final b in _cache.values) {
      total += b.lengthInBytes;
    }
    return total;
  }
}
