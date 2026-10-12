import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/offline/attachment_cache_service.dart';
import '../../views/common/attachment_preview_dialog.dart';
import 'attachment_picker/attachment_picker.dart';

/// Helper to pick files, paste images from the clipboard, and upload them
/// to Firebase Storage, with fallback support for offline / testing.
class AttachmentUploadHelper {
  /// Picks a file from the device and uploads it to Firebase Storage.
  /// Returns the download URL or file identifier, or null if cancelled / failed.
  static Future<String?> pickAndUploadFile({
    String? tripId,
  }) async {
    try {
      final picked = await pickAttachmentFilePlatform();
      if (picked == null) {
        return null;
      }

      if (picked.bytes.isEmpty) {
        return picked.name;
      }

      return await uploadBytes(
        bytes: picked.bytes,
        fileName: picked.name,
        tripId: tripId,
      );
    } catch (e) {
      debugPrint('Error picking file: $e');
      return null;
    }
  }

  /// Reads image bytes from system clipboard and uploads them to Firebase Storage.
  /// Returns the download URL or file identifier, or null if no image was found.
  static Future<String?> pasteAndUploadImage({
    String? tripId,
  }) async {
    try {
      final Uint8List? imageBytes = await Pasteboard.image;
      if (imageBytes != null && imageBytes.isNotEmpty) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'clipboard_image_$timestamp.png';
        return await uploadBytes(
          bytes: imageBytes,
          fileName: fileName,
          tripId: tripId,
        );
      }
    } catch (e) {
      debugPrint('Error reading image from pasteboard: $e');
    }
    return null;
  }

  /// Uploads raw bytes to Firebase Storage under `trips/{tripId}/attachments/{fileName}`.
  /// Falls back gracefully to returning [fileName] if Firebase Storage is unavailable.
  static Future<String> uploadBytes({
    required Uint8List bytes,
    required String fileName,
    String? tripId,
  }) async {
    try {
      final sanitizedName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storagePath = (tripId != null && tripId.isNotEmpty)
          ? 'trips/$tripId/attachments/${timestamp}_$sanitizedName'
          : 'attachments/${timestamp}_$sanitizedName';

      final ref = FirebaseStorage.instance.ref().child(storagePath);

      String contentType = 'application/octet-stream';
      final lower = fileName.toLowerCase();
      if (lower.endsWith('.png')) {
        contentType = 'image/png';
      } else if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
        contentType = 'image/jpeg';
      } else if (lower.endsWith('.pdf')) {
        contentType = 'application/pdf';
      } else if (lower.endsWith('.webp')) {
        contentType = 'image/webp';
      }

      final metadata = SettableMetadata(contentType: contentType);
      final uploadTask = await ref.putData(bytes, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      // Immediately cache bytes locally for zero-latency offline access
      try {
        final cache = AttachmentCacheService();
        await cache.cacheBytesDirectly(downloadUrl, bytes, fileName: fileName);
      } catch (_) {}

      return downloadUrl;
    } catch (e) {
      debugPrint('Firebase Storage upload failed: $e, using fileName fallback');
      return fileName;
    }
  }

  /// Extracts the friendly name if encoded in format "Friendly Name|url_or_path",
  /// or null if no custom friendly name was set.
  static String? extractFriendlyName(String raw) {
    final idx = raw.indexOf('|');
    if (idx != -1) {
      final name = raw.substring(0, idx).trim();
      if (name.isNotEmpty) return name;
    }
    return null;
  }

  /// Extracts the target URL or path from format "Friendly Name|url_or_path" or raw.
  static String extractUrlOrPath(String raw) {
    final idx = raw.indexOf('|');
    if (idx != -1) {
      return raw.substring(idx + 1).trim();
    }
    return raw.trim();
  }

  /// Encodes a friendly name and URL or path into a single string.
  /// If [friendlyName] is null or empty, returns just [urlOrPath].
  static String encodeNamedEntry({
    required String urlOrPath,
    String? friendlyName,
  }) {
    final cleanPath = urlOrPath.trim();
    final cleanName = friendlyName?.trim();
    if (cleanName != null && cleanName.isNotEmpty) {
      return '$cleanName|$cleanPath';
    }
    return cleanPath;
  }

  /// Formats an attachment URL or string for clean presentation in chips.
  /// Displays the friendly name if set, otherwise formatted filename/URL label.
  static String formatAttachmentLabel(String attachment) {
    final friendlyName = extractFriendlyName(attachment);
    if (friendlyName != null) return friendlyName;

    final target = extractUrlOrPath(attachment);
    if (!target.startsWith('http://') && !target.startsWith('https://')) {
      return target;
    }
    try {
      final uri = Uri.parse(target);
      final segment =
          uri.pathSegments.isNotEmpty ? uri.pathSegments.last : target;
      final decoded = Uri.decodeComponent(segment);
      final lastSlash = decoded.lastIndexOf('/');
      final fileNameOnly =
          lastSlash != -1 ? decoded.substring(lastSlash + 1) : decoded;
      // Remove any timestamp prefix like "1728000000_"
      final cleanName = fileNameOnly.replaceFirst(RegExp(r'^\d+_'), '');
      if (cleanName.isNotEmpty) {
        return cleanName;
      }
    } catch (_) {}
    return 'Attachment';
  }

  /// Formats a link for clean presentation in chips.
  /// Displays the friendly name if set, otherwise the full URL.
  static String formatLinkLabel(String link) {
    final friendlyName = extractFriendlyName(link);
    if (friendlyName != null) return friendlyName;
    return extractUrlOrPath(link);
  }

  /// Checks if the attachment or link target is a URL.
  static bool isUrl(String raw) {
    final target = extractUrlOrPath(raw);
    return target.startsWith('http://') || target.startsWith('https://');
  }

  /// Opens an attachment or link if it is a URL, optionally showing the in-app preview dialog.
  static Future<bool> openAttachment(String raw, [BuildContext? context]) async {
    final target = extractUrlOrPath(raw);
    if (!isUrl(target)) return false;

    // 1. If context is provided, open the rich interactive preview dialog with zoom & offline support
    if (context != null && context.mounted) {
      await AttachmentPreviewDialog.show(
        context,
        rawAttachment: raw,
      );
      return true;
    }

    // 2. Check if a local cached file exists on disk (native platforms)
    try {
      final cache = AttachmentCacheService();
      final localPath = await cache.getCachedFilePath(target);
      if (localPath != null && !kIsWeb) {
        final uri = Uri.file(localPath);
        if (await canLaunchUrl(uri)) {
          return await launchUrl(uri);
        }
      }
    } catch (_) {}

    // 3. Fallback to launching external URL
    try {
      final uri = Uri.parse(target);
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
    return false;
  }
}
