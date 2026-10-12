import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;
import 'attachment_storage_platform.dart';

AttachmentStorage createAttachmentStorage() => AttachmentStorageWeb();

class AttachmentStorageWeb implements AttachmentStorage {
  static final Map<String, Uint8List> _memoryCache = {};
  static web.IDBDatabase? _cachedDb;

  Future<web.IDBDatabase?> _getDb() async {
    if (_cachedDb != null) return _cachedDb;
    try {
      final completer = Completer<web.IDBDatabase?>();
      final req = web.window.indexedDB.open('trippy_offline_attachments', 1);
      req.onupgradeneeded = (web.IDBVersionChangeEvent e) {
        final db = req.result as web.IDBDatabase;
        if (!db.objectStoreNames.contains('attachments')) {
          db.createObjectStore('attachments');
        }
      }.toJS;
      req.onsuccess = (web.Event e) {
        final db = req.result as web.IDBDatabase;
        _cachedDb = db;
        completer.complete(db);
      }.toJS;
      req.onerror = (web.Event e) {
        debugPrint('AttachmentStorageWeb IDB open error: ${req.error}');
        completer.complete(null);
      }.toJS;
      return await completer.future;
    } catch (e) {
      debugPrint('AttachmentStorageWeb IDB unsupported or failed: $e');
      return null;
    }
  }

  @override
  Future<bool> hasFile(String key) async {
    if (_memoryCache.containsKey(key)) return true;
    final db = await _getDb();
    if (db == null) return false;
    try {
      final completer = Completer<bool>();
      final tx = db.transaction('attachments'.toJS, 'readonly');
      final store = tx.objectStore('attachments');
      final req = store.count(key.toJS);
      req.onsuccess = (web.Event e) {
        final count = (req.result as JSNumber?)?.toDartInt ?? 0;
        completer.complete(count > 0);
      }.toJS;
      req.onerror = (web.Event e) {
        completer.complete(false);
      }.toJS;
      return await completer.future;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<Uint8List?> getFileBytes(String key) async {
    if (_memoryCache.containsKey(key)) {
      return _memoryCache[key];
    }
    final db = await _getDb();
    if (db == null) return null;
    try {
      final completer = Completer<Uint8List?>();
      final tx = db.transaction('attachments'.toJS, 'readonly');
      final store = tx.objectStore('attachments');
      final req = store.get(key.toJS);
      req.onsuccess = (web.Event e) {
        final res = req.result;
        if (res != null) {
          final u8 = (res as JSUint8Array).toDart;
          _memoryCache[key] = u8;
          completer.complete(u8);
        } else {
          completer.complete(null);
        }
      }.toJS;
      req.onerror = (web.Event e) {
        completer.complete(null);
      }.toJS;
      return await completer.future;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> saveFile(String key, Uint8List bytes, {String? extension}) async {
    _memoryCache[key] = bytes;
    final db = await _getDb();
    if (db != null) {
      try {
        final tx = db.transaction('attachments'.toJS, 'readwrite');
        final store = tx.objectStore('attachments');
        store.put(bytes.toJS, key.toJS);
      } catch (e) {
        debugPrint('AttachmentStorageWeb error saving to IDB: $e');
      }
    }
    return key;
  }

  @override
  Future<String?> getFilePath(String key, {String? extension}) async {
    if (_memoryCache.containsKey(key)) {
      return key;
    }
    if (await hasFile(key)) {
      return key;
    }
    return null;
  }

  @override
  Future<void> deleteFile(String key) async {
    _memoryCache.remove(key);
    final db = await _getDb();
    if (db != null) {
      try {
        final tx = db.transaction('attachments'.toJS, 'readwrite');
        final store = tx.objectStore('attachments');
        store.delete(key.toJS);
      } catch (_) {}
    }
  }

  @override
  Future<void> clearAll() async {
    _memoryCache.clear();
    final db = await _getDb();
    if (db != null) {
      try {
        final tx = db.transaction('attachments'.toJS, 'readwrite');
        final store = tx.objectStore('attachments');
        store.clear();
      } catch (_) {}
    }
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
