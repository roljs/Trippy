import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/trip_repository.dart';
import '../../models/models.dart';
import '../../state/trip_providers.dart';
import 'attachment_cache_service.dart';

/// Summary of a trip's offline availability and cached assets.
class TripOfflineStatus {
  final String tripId;
  final bool isDownloaded;
  final DateTime? lastSyncedAt;
  final int staysCount;
  final int flightsCount;
  final int activitiesCount;
  final int totalAttachments;
  final int cachedAttachments;
  final int totalBytes;

  const TripOfflineStatus({
    required this.tripId,
    required this.isDownloaded,
    this.lastSyncedAt,
    this.staysCount = 0,
    this.flightsCount = 0,
    this.activitiesCount = 0,
    this.totalAttachments = 0,
    this.cachedAttachments = 0,
    this.totalBytes = 0,
  });

  bool get hasMissingAttachments => cachedAttachments < totalAttachments;
  int get totalItems => 1 + staysCount + flightsCount + activitiesCount;

  TripOfflineStatus copyWith({
    bool? isDownloaded,
    DateTime? lastSyncedAt,
    int? staysCount,
    int? flightsCount,
    int? activitiesCount,
    int? totalAttachments,
    int? cachedAttachments,
    int? totalBytes,
  }) {
    return TripOfflineStatus(
      tripId: tripId,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      staysCount: staysCount ?? this.staysCount,
      flightsCount: flightsCount ?? this.flightsCount,
      activitiesCount: activitiesCount ?? this.activitiesCount,
      totalAttachments: totalAttachments ?? this.totalAttachments,
      cachedAttachments: cachedAttachments ?? this.cachedAttachments,
      totalBytes: totalBytes ?? this.totalBytes,
    );
  }
}

/// Service that coordinates prefetching structured Firestore documents
/// and caching all external attachments locally for 100% offline access.
class OfflineSyncService {
  final TripRepository repo;
  final AttachmentCacheService _attachmentCache;

  // In-memory status map of known synced trips
  final Map<String, TripOfflineStatus> _statusCache = {};
  final _statusController = StreamController<Map<String, TripOfflineStatus>>.broadcast();

  OfflineSyncService({
    required this.repo,
    AttachmentCacheService? attachmentCache,
  })  : _attachmentCache = attachmentCache ?? AttachmentCacheService();

  Stream<Map<String, TripOfflineStatus>> get statusStream => _statusController.stream;

  /// Check offline status and count of cached items for a given trip.
  Future<TripOfflineStatus> checkTripStatus(String tripId) async {
    if (tripId.isEmpty) {
      return const TripOfflineStatus(tripId: '', isDownloaded: false);
    }

    try {
      final trip = await repo.getTripById(tripId);
      if (trip == null) {
        return TripOfflineStatus(tripId: tripId, isDownloaded: false);
      }

      final stays = await repo.getStays(tripId);
      final flights = await repo.getFlights(tripId);
      final activities = await repo.getActivities(tripId);

      final allAttachments = _collectAttachments(trip, stays, flights, activities);
      int cachedCount = 0;
      for (final att in allAttachments) {
        if (await _attachmentCache.isCached(att)) {
          cachedCount++;
        }
      }

      final isDownloaded = stays.isNotEmpty || flights.isNotEmpty || activities.isNotEmpty;
      final status = TripOfflineStatus(
        tripId: tripId,
        isDownloaded: isDownloaded,
        lastSyncedAt: _statusCache[tripId]?.lastSyncedAt ?? DateTime.now(),
        staysCount: stays.length,
        flightsCount: flights.length,
        activitiesCount: activities.length,
        totalAttachments: allAttachments.length,
        cachedAttachments: cachedCount,
        totalBytes: await _attachmentCache.getCacheSizeBytes(),
      );

      _statusCache[tripId] = status;
      _statusController.add(Map.unmodifiable(_statusCache));
      return status;
    } catch (_) {
      return _statusCache[tripId] ??
          TripOfflineStatus(tripId: tripId, isDownloaded: false);
    }
  }

  /// Eagerly prefetch and cache an entire trip and all of its assets for offline use.
  /// Reading all Firestore subcollections populates the local disk persistence cache.
  Future<TripOfflineStatus> prefetchTripForOffline(
    String tripId, {
    void Function(String message, double progress)? onProgress,
  }) async {
    onProgress?.call('Loading trip details...', 0.1);
    final trip = await repo.getTripById(tripId);
    if (trip == null) {
      throw Exception('Trip $tripId not found.');
    }

    onProgress?.call('Caching stays and accommodations...', 0.3);
    final stays = await repo.getStays(tripId);

    onProgress?.call('Caching flights and itineraries...', 0.5);
    final flights = await repo.getFlights(tripId);

    onProgress?.call('Caching daily activities...', 0.7);
    final activities = await repo.getActivities(tripId);

    final allAttachments = _collectAttachments(trip, stays, flights, activities);
    int cachedCount = 0;

    if (allAttachments.isNotEmpty) {
      final total = allAttachments.length;
      for (int i = 0; i < total; i++) {
        final att = allAttachments[i];
        final pct = 0.7 + (0.28 * ((i + 1) / total));
        onProgress?.call('Caching attachment ${i + 1} of $total...', pct);
        try {
          final res = await _attachmentCache.downloadAndCache(att);
          if (res != null) {
            cachedCount++;
          }
        } catch (e) {
          debugPrint('Error caching attachment $att: $e');
        }
      }
    }

    onProgress?.call(
      cachedCount == allAttachments.length
          ? 'Trip ready for offline use!'
          : 'Trip details cached ($cachedCount of ${allAttachments.length} files saved)',
      1.0,
    );

    final status = TripOfflineStatus(
      tripId: tripId,
      isDownloaded: true,
      lastSyncedAt: DateTime.now(),
      staysCount: stays.length,
      flightsCount: flights.length,
      activitiesCount: activities.length,
      totalAttachments: allAttachments.length,
      cachedAttachments: cachedCount,
      totalBytes: await _attachmentCache.getCacheSizeBytes(),
    );

    _statusCache[tripId] = status;
    _statusController.add(Map.unmodifiable(_statusCache));
    return status;
  }

  /// Remove cached attachments for a trip from local disk.
  Future<void> removeTripOfflineCache(String tripId) async {
    try {
      final trip = await repo.getTripById(tripId);
      if (trip != null) {
        final stays = await repo.getStays(tripId);
        final flights = await repo.getFlights(tripId);
        final activities = await repo.getActivities(tripId);
        final attachments = _collectAttachments(trip, stays, flights, activities);
        for (final att in attachments) {
          await _attachmentCache.removeCached(att);
        }
      }
    } catch (_) {}

    _statusCache.remove(tripId);
    _statusController.add(Map.unmodifiable(_statusCache));
  }

  /// Extract all unique attachment URLs / paths from a trip and its subcollections.
  List<String> _collectAttachments(
    Trip trip,
    List<Stay> stays,
    List<Flight> flights,
    List<Activity> activities,
  ) {
    final set = <String>{};
    for (final att in trip.attachments) {
      if (att.trim().isNotEmpty) set.add(att.trim());
    }
    for (final stay in stays) {
      for (final att in stay.attachments) {
        if (att.trim().isNotEmpty) set.add(att.trim());
      }
    }
    for (final flight in flights) {
      for (final att in flight.attachments) {
        if (att.trim().isNotEmpty) set.add(att.trim());
      }
    }
    for (final act in activities) {
      for (final att in act.attachments) {
        if (att.trim().isNotEmpty) set.add(att.trim());
      }
    }
    return set.toList();
  }
}

// -----------------------------------------------------------------------------
// Riverpod Providers
// -----------------------------------------------------------------------------

final offlineSyncServiceProvider = Provider<OfflineSyncService>((ref) {
  final repo = ref.watch(tripRepositoryProvider);
  return OfflineSyncService(repo: repo);
});

class SyncingTripsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const <String>{};

  void setSyncing(String tripId, bool isSyncing) {
    if (isSyncing) {
      state = {...state, tripId};
    } else {
      state = state.where((id) => id != tripId).toSet();
    }
  }
}

final syncingTripsProvider =
    NotifierProvider<SyncingTripsNotifier, Set<String>>(
        SyncingTripsNotifier.new);

final isTripSyncingProvider = Provider.family<bool, String>((ref, tripId) {
  final syncing = ref.watch(syncingTripsProvider);
  return syncing.contains(tripId);
});

final tripOfflineStatusProvider =
    FutureProvider.family<TripOfflineStatus, String>((ref, tripId) async {
  final service = ref.watch(offlineSyncServiceProvider);
  return await service.checkTripStatus(tripId);
});

final activeTripOfflineStatusProvider = FutureProvider<TripOfflineStatus?>((ref) async {
  final tripId = ref.watch(effectiveActiveTripIdProvider);
  if (tripId == null || tripId.isEmpty) return null;
  final service = ref.watch(offlineSyncServiceProvider);
  return await service.checkTripStatus(tripId);
});
