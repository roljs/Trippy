import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/utils/attachment_upload_helper.dart';
import 'attachment_storage/attachment_storage_platform.dart';

class AttachmentCacheService {
  static final AttachmentCacheService _instance = AttachmentCacheService._();
  factory AttachmentCacheService() => _instance;

  AttachmentCacheService._({AttachmentStorage? storage})
      : _storage = storage ?? AttachmentStorage.create();

  final AttachmentStorage _storage;

  /// Generate a consistent, filesystem-safe hash key for any URL or path.
  static String hashKey(String rawUrlOrPath) {
    final clean = AttachmentUploadHelper.extractUrlOrPath(rawUrlOrPath);
    return sha256.convert(utf8.encode(clean.trim())).toString();
  }

  /// Extracts file extension from URL or file name (e.g., ".png", ".pdf").
  static String extractExtension(String rawUrlOrPath) {
    final clean = AttachmentUploadHelper.extractUrlOrPath(rawUrlOrPath);
    try {
      final uri = Uri.parse(clean);
      final path = uri.path;
      final lastDot = path.lastIndexOf('.');
      if (lastDot != -1 && lastDot < path.length - 1) {
        final ext = path.substring(lastDot).toLowerCase();
        // Discard query parameters if any leaked into the segment
        final cleanExt = ext.split('?').first.split('&').first;
        if (cleanExt.length <= 6) {
          return cleanExt;
        }
      }
    } catch (_) {}
    return '';
  }

  /// Determines whether the target attachment is an image.
  static bool isImage(String rawUrlOrPath) {
    final ext = extractExtension(rawUrlOrPath);
    const imageExtensions = {'.png', '.jpg', '.jpeg', '.webp', '.gif', '.bmp'};
    return imageExtensions.contains(ext);
  }

  /// Determines whether the target attachment is a PDF.
  static bool isPdf(String rawUrlOrPath) {
    return extractExtension(rawUrlOrPath) == '.pdf';
  }

  /// Checks if the attachment is available offline in the local cache.
  Future<bool> isCached(String rawUrlOrPath) async {
    final key = hashKey(rawUrlOrPath);
    return await _storage.hasFile(key);
  }

  /// Returns cached bytes if available, or null.
  Future<Uint8List?> getCachedBytes(String rawUrlOrPath) async {
    final key = hashKey(rawUrlOrPath);
    return await _storage.getFileBytes(key);
  }

  /// Returns local filesystem path if available, or null on Web / when not cached.
  Future<String?> getCachedFilePath(String rawUrlOrPath) async {
    final key = hashKey(rawUrlOrPath);
    final ext = extractExtension(rawUrlOrPath);
    return await _storage.getFilePath(key, extension: ext);
  }

  /// Directly saves raw bytes into the offline cache for this attachment URL.
  Future<void> cacheBytesDirectly(
    String rawUrlOrPath,
    Uint8List bytes, {
    String? fileName,
  }) async {
    final key = hashKey(rawUrlOrPath);
    final ext = (fileName != null && fileName.isNotEmpty)
        ? extractExtension(fileName)
        : extractExtension(rawUrlOrPath);
    await _storage.saveFile(key, bytes, extension: ext);
  }

  /// Downloads and caches the attachment from Firebase Storage or HTTP URL.
  /// If already cached, immediately returns cached bytes without network call.
  Future<Uint8List?> downloadAndCache(
    String rawUrlOrPath, {
    String? fileName,
  }) async {
    final cleanUrl = AttachmentUploadHelper.extractUrlOrPath(rawUrlOrPath);
    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      return null;
    }

    final key = hashKey(cleanUrl);

    // 1. Return immediately if already cached
    final existingBytes = await _storage.getFileBytes(key);
    if (existingBytes != null && existingBytes.isNotEmpty) {
      return existingBytes;
    }

    Uint8List? downloadedBytes;

    // 2. Try fetching directly via Firebase Storage ref if it's a firebase URL
    if (cleanUrl.contains('firebasestorage.googleapis.com')) {
      try {
        final ref = FirebaseStorage.instance.refFromURL(cleanUrl);
        downloadedBytes = await ref.getData(15 * 1024 * 1024); // max 15MB
      } catch (e) {
        debugPrint('FirebaseStorage.refFromURL getData fallback: $e');
      }
    }

    // 3. Fallback to standard HTTP GET request
    if (downloadedBytes == null) {
      try {
        final resp = await http.get(Uri.parse(cleanUrl)).timeout(
          const Duration(seconds: 15),
        );
        if (resp.statusCode == 200) {
          downloadedBytes = resp.bodyBytes;
        }
      } catch (e) {
        debugPrint('AttachmentCacheService http download failed: $e');
      }
    }

    // 4. Save to cache
    if (downloadedBytes != null && downloadedBytes.isNotEmpty) {
      final ext = (fileName != null && fileName.isNotEmpty)
          ? extractExtension(fileName)
          : extractExtension(cleanUrl);
      await _storage.saveFile(key, downloadedBytes, extension: ext);
      return downloadedBytes;
    }

    return null;
  }

  /// Delete cached attachment from disk / memory.
  Future<void> removeCached(String rawUrlOrPath) async {
    final key = hashKey(rawUrlOrPath);
    await _storage.deleteFile(key);
  }

  /// Clear entire attachment cache.
  Future<void> clearAll() async {
    await _storage.clearAll();
  }

  /// Total size of all cached attachments in bytes.
  Future<int> getCacheSizeBytes() async {
    return await _storage.getTotalSizeBytes();
  }
}
