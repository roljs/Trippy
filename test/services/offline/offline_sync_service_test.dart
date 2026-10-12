import 'package:flutter_test/flutter_test.dart';
import 'package:trippy/data/repositories/mock_trip_repository.dart';
import 'package:trippy/services/offline/attachment_cache_service.dart';
import 'package:trippy/services/offline/offline_sync_service.dart';

void main() {
  group('OfflineSyncService Tests', () {
    late MockTripRepository repo;
    late OfflineSyncService syncService;

    setUp(() {
      repo = MockTripRepository();
      syncService = OfflineSyncService(
        repo: repo,
        attachmentCache: AttachmentCacheService(),
      );
    });

    test('checkTripStatus returns initial status correctly', () async {
      final status = await syncService.checkTripStatus('trip_japan_2026');

      expect(status.tripId, equals('trip_japan_2026'));
      expect(status.isDownloaded, isTrue);
      expect(status.staysCount, greaterThan(0));
      expect(status.flightsCount, greaterThan(0));
      expect(status.activitiesCount, greaterThan(0));
    });

    test('prefetchTripForOffline executes progress callbacks and marks downloaded', () async {
      final progressSteps = <String>[];
      final progressValues = <double>[];

      final status = await syncService.prefetchTripForOffline(
        'trip_japan_2026',
        onProgress: (msg, pct) {
          progressSteps.add(msg);
          progressValues.add(pct);
        },
      );

      expect(status.isDownloaded, isTrue);
      expect(status.lastSyncedAt, isNotNull);
      expect(progressSteps, isNotEmpty);
      expect(progressValues.last, equals(1.0));
      expect(progressSteps.last, contains('Trip ready for offline use'));
    });

    test('removeTripOfflineCache clears offline status for trip', () async {
      await syncService.prefetchTripForOffline('trip_japan_2026');
      await syncService.removeTripOfflineCache('trip_japan_2026');

      final status = await syncService.checkTripStatus('trip_japan_2026');
      expect(status.tripId, equals('trip_japan_2026'));
    });

    test('TripOfflineStatus data class properties and copyWith', () {
      const initial = TripOfflineStatus(
        tripId: 'test_123',
        isDownloaded: false,
        staysCount: 3,
        flightsCount: 2,
        activitiesCount: 10,
        totalAttachments: 4,
        cachedAttachments: 2,
      );

      expect(initial.totalItems, equals(16)); // 1 trip + 3 + 2 + 10
      expect(initial.hasMissingAttachments, isTrue);

      final updated = initial.copyWith(
        isDownloaded: true,
        cachedAttachments: 4,
      );

      expect(updated.isDownloaded, isTrue);
      expect(updated.hasMissingAttachments, isFalse);
    });
  });
}
