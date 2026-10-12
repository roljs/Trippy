import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/attachment_upload_helper.dart';
import '../../services/offline/attachment_cache_service.dart';

/// Interactive in-app attachment preview dialog with offline support.
class AttachmentPreviewDialog extends StatefulWidget {
  final String rawAttachment;
  final String? title;

  const AttachmentPreviewDialog({
    super.key,
    required this.rawAttachment,
    this.title,
  });

  static Future<void> show(
    BuildContext context, {
    required String rawAttachment,
    String? title,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => AttachmentPreviewDialog(
        rawAttachment: rawAttachment,
        title: title,
      ),
    );
  }

  @override
  State<AttachmentPreviewDialog> createState() => _AttachmentPreviewDialogState();
}

class _AttachmentPreviewDialogState extends State<AttachmentPreviewDialog> {
  final _cacheService = AttachmentCacheService();
  bool _isLoading = true;
  bool _isDownloading = false;
  bool _isCached = false;
  Uint8List? _cachedBytes;
  String? _localFilePath;

  String get _cleanUrl =>
      AttachmentUploadHelper.extractUrlOrPath(widget.rawAttachment);

  String get _displayName =>
      widget.title ??
      AttachmentUploadHelper.formatAttachmentLabel(widget.rawAttachment);

  bool get _isImage => AttachmentCacheService.isImage(_cleanUrl);
  bool get _isPdf => AttachmentCacheService.isPdf(_cleanUrl);

  @override
  void initState() {
    super.initState();
    _loadAttachment();
  }

  Future<void> _loadAttachment() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final cached = await _cacheService.isCached(_cleanUrl);
      Uint8List? bytes;
      String? filePath;

      if (cached) {
        bytes = await _cacheService.getCachedBytes(_cleanUrl);
        filePath = await _cacheService.getCachedFilePath(_cleanUrl);
      } else if (_cleanUrl.startsWith('http')) {
        // Automatically attempt to cache if online
        bytes = await _cacheService.downloadAndCache(_cleanUrl);
        if (bytes != null) {
          filePath = await _cacheService.getCachedFilePath(_cleanUrl);
        }
      }

      if (mounted) {
        setState(() {
          _isCached = bytes != null;
          _cachedBytes = bytes;
          _localFilePath = filePath;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('AttachmentPreviewDialog load error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _manualDownload() async {
    setState(() => _isDownloading = true);
    final bytes = await _cacheService.downloadAndCache(_cleanUrl);
    final path = await _cacheService.getCachedFilePath(_cleanUrl);
    if (mounted) {
      setState(() {
        _isDownloading = false;
        _isCached = bytes != null;
        _cachedBytes = bytes;
        _localFilePath = path;
      });
      if (bytes != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Attachment downloaded for offline viewing!'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _openExternal() async {
    if (_localFilePath != null && !kIsWeb) {
      try {
        final uri = Uri.file(_localFilePath!);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
          return;
        }
      } catch (_) {}
    }

    if (AttachmentUploadHelper.isUrl(_cleanUrl)) {
      try {
        final uri = Uri.parse(_cleanUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E222D) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 680,
          maxHeight: 740,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 12, 10),
              child: Row(
                children: [
                  Icon(
                    _isImage
                        ? Icons.image_rounded
                        : (_isPdf
                            ? Icons.picture_as_pdf_rounded
                            : Icons.attach_file_rounded),
                    color: AppColors.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _displayName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: _isCached
                                    ? AppColors.success.withValues(alpha: 0.15)
                                    : Colors.orange.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _isCached
                                        ? Icons.cloud_done_rounded
                                        : Icons.cloud_outlined,
                                    size: 11,
                                    color: _isCached
                                        ? AppColors.success
                                        : Colors.orange,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _isCached ? 'Offline Ready' : 'Online Only',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: _isCached
                                          ? AppColors.success
                                          : Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_cachedBytes != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                '${(_cachedBytes!.lengthInBytes / 1024).toStringAsFixed(1)} KB',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Content Area
            Expanded(
              child: Container(
                color: isDark ? const Color(0xFF13161C) : const Color(0xFFF7F8FA),
                child: _buildBody(),
              ),
            ),

            const Divider(height: 1),

            // Footer Actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  if (!_isCached)
                    TextButton.icon(
                      onPressed: _isDownloading ? null : _manualDownload,
                      icon: _isDownloading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cloud_download_outlined, size: 16),
                      label: Text(_isDownloading ? 'Downloading...' : 'Download Offline'),
                    ),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: _openExternal,
                    icon: const Icon(Icons.open_in_new_rounded, size: 15),
                    label: const Text('Open External'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Loading attachment...', style: TextStyle(fontSize: 13)),
          ],
        ),
      );
    }

    if (_cachedBytes != null && _isImage) {
      return Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.memory(
            _cachedBytes!,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => _buildFallbackCard(),
          ),
        ),
      );
    }

    if (_cachedBytes == null && _isImage && AttachmentUploadHelper.isUrl(_cleanUrl)) {
      return Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.network(
            _cleanUrl,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => _buildOfflineNoticeCard(),
          ),
        ),
      );
    }

    return _buildFallbackCard();
  }

  Widget _buildFallbackCard() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isPdf
                      ? Icons.picture_as_pdf_rounded
                      : Icons.insert_drive_file_rounded,
                  size: 48,
                  color: _isPdf ? Colors.red.shade600 : AppColors.primary,
                ),
                const SizedBox(height: 14),
                Text(
                  _displayName,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _isCached
                      ? 'This file is stored in your local offline cache.'
                      : 'File is hosted in Cloud Storage.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _openExternal,
                  icon: const Icon(Icons.open_in_browser_rounded, size: 16),
                  label: const Text('View Document'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOfflineNoticeCard() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.orange.shade300),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.orange),
                const SizedBox(height: 14),
                const Text(
                  'Attachment Not Downloaded',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'You appear to be offline and this file was not cached.\n'
                  'Connect to the internet and tap "Make Available Offline" to download all trip assets.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
