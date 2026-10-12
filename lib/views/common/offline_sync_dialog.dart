import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../models/models.dart';
import '../../services/offline/offline_sync_service.dart';

/// Modal dialog allowing users to download an entire trip and its attachments
/// for 100% offline access, or inspect its offline cached status.
class OfflineSyncDialog extends ConsumerStatefulWidget {
  final Trip trip;

  const OfflineSyncDialog({
    super.key,
    required this.trip,
  });

  static Future<void> show(BuildContext context, {required Trip trip}) {
    return showDialog(
      context: context,
      builder: (ctx) => OfflineSyncDialog(trip: trip),
    );
  }

  @override
  ConsumerState<OfflineSyncDialog> createState() => _OfflineSyncDialogState();
}

class _OfflineSyncDialogState extends ConsumerState<OfflineSyncDialog> {
  bool _isSyncing = false;
  String? _progressMessage;
  double _progressValue = 0.0;
  TripOfflineStatus? _status;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    setState(() => _isLoading = true);
    final service = ref.read(offlineSyncServiceProvider);
    final status = await service.checkTripStatus(widget.trip.id);
    if (mounted) {
      setState(() {
        _status = status;
        _isLoading = false;
      });
    }
  }

  Future<void> _startSync() async {
    setState(() {
      _isSyncing = true;
      _progressMessage = 'Preparing offline package...';
      _progressValue = 0.05;
    });

    final service = ref.read(offlineSyncServiceProvider);
    try {
      final updatedStatus = await service.prefetchTripForOffline(
        widget.trip.id,
        onProgress: (msg, pct) {
          if (mounted) {
            setState(() {
              _progressMessage = msg;
              _progressValue = pct;
            });
          }
        },
      );

      // Invalidate riverpod providers so UI updates everywhere
      ref.invalidate(tripOfflineStatusProvider(widget.trip.id));
      ref.invalidate(activeTripOfflineStatusProvider);

      if (mounted) {
        setState(() {
          _isSyncing = false;
          _status = updatedStatus;
          _progressMessage = null;
        });

        final hasMissing = updatedStatus.hasMissingAttachments;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              hasMissing
                  ? '⚠️ Trip saved, but ${updatedStatus.totalAttachments - updatedStatus.cachedAttachments} attachments could not be cached.'
                  : '✅ "${widget.trip.title}" is ready for offline travel! (${updatedStatus.totalItems} items, ${updatedStatus.cachedAttachments} attachments cached)',
            ),
            backgroundColor:
                hasMissing ? Colors.orange.shade800 : AppColors.success,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _progressMessage = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error caching trip: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _clearCache() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Offline Cache?'),
        content: Text(
          'Remove cached attachments and offline copies for "${widget.trip.title}"? '
          'Your cloud data will remain safe in Firestore.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final service = ref.read(offlineSyncServiceProvider);
      await service.removeTripOfflineCache(widget.trip.id);
      ref.invalidate(tripOfflineStatusProvider(widget.trip.id));
      ref.invalidate(activeTripOfflineStatusProvider);
      await _refreshStatus();
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
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.cloud_sync_rounded,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Offline Travel Mode',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          widget.trip.title,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
              const SizedBox(height: 16),

              if (_isLoading) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ] else ...[
                // Status Banner
                _buildStatusBanner(),
                const SizedBox(height: 16),

                // Breakdown list
                _buildBreakdownCards(),
                const SizedBox(height: 16),

                // Progress Bar (if syncing)
                if (_isSyncing) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _progressValue,
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade200,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _progressMessage ?? 'Syncing...',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                ],
              ],

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_status?.isDownloaded == true && !_isSyncing)
                    TextButton.icon(
                      onPressed: _clearCache,
                      icon: const Icon(Icons.delete_outline_rounded,
                          size: 16, color: Colors.red),
                      label: const Text(
                        'Clear Cache',
                        style: TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  const SizedBox(width: 8),
                  Flexible(
                    child: FilledButton.icon(
                      onPressed: _isSyncing ? null : _startSync,
                      icon: Icon(
                        _status?.isDownloaded == true
                            ? Icons.refresh_rounded
                            : Icons.download_rounded,
                        size: 17,
                      ),
                      label: Text(
                        _status?.isDownloaded == true
                            ? 'Update Offline Cache'
                            : 'Make Available Offline',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBanner() {
    final isCached = _status?.isDownloaded ?? false;
    final hasMissing = _status?.hasMissingAttachments ?? false;
    final isFullyReady = isCached && !hasMissing;

    Color bannerColor;
    Color borderColor;
    IconData iconData;
    String titleText;
    String subtitleText;

    if (isFullyReady) {
      bannerColor = AppColors.success.withValues(alpha: 0.12);
      borderColor = AppColors.success.withValues(alpha: 0.3);
      iconData = Icons.cloud_done_rounded;
      titleText = 'Ready for Offline Travel';
      subtitleText = 'All stays, flights, daily activities, and attachments are cached.';
    } else if (isCached && hasMissing) {
      bannerColor = Colors.amber.withValues(alpha: 0.15);
      borderColor = Colors.amber.shade600.withValues(alpha: 0.4);
      iconData = Icons.cloud_queue_rounded;
      titleText = 'Partially Cached for Offline';
      subtitleText =
          'All trip details are cached, but some attachments are missing or failed to download.';
    } else {
      bannerColor = Colors.orange.withValues(alpha: 0.12);
      borderColor = Colors.orange.withValues(alpha: 0.3);
      iconData = Icons.cloud_off_rounded;
      titleText = 'Not Downloaded for Offline Use';
      subtitleText = 'Tap the button below to save all trip details and files locally.';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bannerColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(
            iconData,
            color: isFullyReady
                ? AppColors.success
                : (isCached ? Colors.amber.shade900 : Colors.orange),
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titleText,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isFullyReady
                        ? AppColors.success
                        : (isCached ? Colors.amber.shade900 : Colors.orange.shade800),
                  ),
                ),
                Text(
                  subtitleText,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownCards() {
    final status = _status ?? const TripOfflineStatus(tripId: '', isDownloaded: false);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          _buildItemRow(
            Icons.hotel_rounded,
            'Stays & Lodgings',
            '${status.staysCount} stays cached',
          ),
          const Divider(height: 12),
          _buildItemRow(
            Icons.flight_takeoff_rounded,
            'Flights & Transportation',
            '${status.flightsCount} flights cached',
          ),
          const Divider(height: 12),
          _buildItemRow(
            Icons.event_available_rounded,
            'Daily Activities',
            '${status.activitiesCount} activities cached',
          ),
          const Divider(height: 12),
          _buildItemRow(
            Icons.attach_file_rounded,
            'Files & Attachments',
            '${status.cachedAttachments} of ${status.totalAttachments} cached',
            badgeColor: status.cachedAttachments == status.totalAttachments &&
                    status.totalAttachments > 0
                ? AppColors.success
                : (status.totalAttachments > 0 ? Colors.orange : null),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(
    IconData icon,
    String title,
    String detail, {
    Color? badgeColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        Text(
          detail,
          style: TextStyle(
            fontSize: 12,
            fontWeight: badgeColor != null ? FontWeight.w700 : FontWeight.w500,
            color: badgeColor ?? Colors.grey.shade700,
          ),
        ),
      ],
    );
  }
}
