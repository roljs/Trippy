import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'attachment_storage_platform.dart';

AttachmentStorage createAttachmentStorage() => AttachmentStorageIo();

class AttachmentStorageIo implements AttachmentStorage {
  Directory? _cacheDir;

  Future<Directory> _getDir() async {
    if (_cacheDir != null) return _cacheDir!;
    Directory baseDir;
    try {
      baseDir = await getApplicationDocumentsDirectory().timeout(
        const Duration(milliseconds: 300),
        onTimeout: () => Directory.systemTemp,
      );
    } catch (_) {
      baseDir = Directory.systemTemp;
    }
    final dir = Directory('${baseDir.path}/trippy_attachments_cache');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _cacheDir = dir;
    return dir;
  }

  File _resolveFile(Directory dir, String key, String? extension) {
    final ext = (extension != null && extension.isNotEmpty)
        ? (extension.startsWith('.') ? extension : '.$extension')
        : '';
    return File('${dir.path}/$key$ext');
  }

  Future<File?> _findFile(String key) async {
    final dir = await _getDir();
    final exact = File('${dir.path}/$key');
    if (await exact.exists()) return exact;

    // Search for matching file with any extension (e.g. key.png, key.pdf)
    final entities = await dir.list().toList();
    for (final e in entities) {
      if (e is File) {
        final filename = e.uri.pathSegments.last;
        if (filename.startsWith(key)) {
          return e;
        }
      }
    }
    return null;
  }

  @override
  Future<bool> hasFile(String key) async {
    try {
      final file = await _findFile(key);
      return file != null && await file.exists();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<Uint8List?> getFileBytes(String key) async {
    try {
      final file = await _findFile(key);
      if (file != null && await file.exists()) {
        return await file.readAsBytes();
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<String?> saveFile(String key, Uint8List bytes, {String? extension}) async {
    try {
      final dir = await _getDir();
      final file = _resolveFile(dir, key, extension);
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> getFilePath(String key, {String? extension}) async {
    try {
      final file = await _findFile(key);
      if (file != null && await file.exists()) {
        return file.path;
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<void> deleteFile(String key) async {
    try {
      final file = await _findFile(key);
      if (file != null && await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  @override
  Future<void> clearAll() async {
    try {
      final dir = await _getDir();
      if (await dir.exists()) {
        final entities = await dir.list().toList();
        for (final e in entities) {
          if (e is File) {
            await e.delete();
          }
        }
      }
    } catch (_) {}
  }

  @override
  Future<int> getTotalSizeBytes() async {
    int total = 0;
    try {
      final dir = await _getDir();
      if (await dir.exists()) {
        final entities = await dir.list().toList();
        for (final e in entities) {
          if (e is File) {
            total += await e.length();
          }
        }
      }
    } catch (_) {}
    return total;
  }
}
