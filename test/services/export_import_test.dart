import 'package:flutter_test/flutter_test.dart';
import 'package:trippy/data/repositories/mock_trip_repository.dart';
import 'package:trippy/models/models.dart';
import 'package:trippy/services/export_import/trip_export_service.dart';

void main() {
  group('Trip Export & Import Service Tests', () {
    late MockTripRepository repository;

    setUp(() {
      repository = MockTripRepository();
    });

    test('Single trip export produces complete TripBundle', () async {
      final bundle = await TripExportService.exportSingleTrip(
        repository,
        'trip_japan_2026',
      );

      expect(bundle, isNotNull);
      expect(bundle!.trip.id, 'trip_japan_2026');
      expect(bundle.stays.length, 2);
      expect(bundle.activities.length, greaterThanOrEqualTo(10));
      expect(bundle.flights.length, 2);

      // Verify JSON serialization roundtrip
      final jsonStr = bundle.toJson(pretty: true);
      expect(jsonStr, contains('"trip_japan_2026"'));
      expect(jsonStr, contains('"Grand Hyatt Tokyo"'));

      final deserialized = TripBundle.fromJson(jsonStr);
      expect(deserialized.trip.id, 'trip_japan_2026');
      expect(deserialized.stays.length, 2);
      expect(deserialized.stays.first.name, 'Grand Hyatt Tokyo');
      expect(deserialized.flights.length, 2);
    });

    test('All trips export produces TripDatabaseBundle with both test trips',
        () async {
      final dbBundle = await TripExportService.exportAllTrips(
        repository,
        'user_current',
      );

      expect(dbBundle.trips.length, 2);
      expect(
        dbBundle.trips.any((b) => b.trip.id == 'trip_japan_2026'),
        isTrue,
      );
      expect(
        dbBundle.trips.any((b) => b.trip.id == 'trip_italy_2026'),
        isTrue,
      );

      final jsonStr = dbBundle.toJson(pretty: true);
      expect(jsonStr, contains('"trip_italy_2026"'));
      expect(jsonStr, contains('"Hotel Artemide"'));

      final deserialized = TripDatabaseBundle.fromJson(jsonStr);
      expect(deserialized.trips.length, 2);
    });

    test('Importing single trip JSON correctly persists trip and children',
        () async {
      const singleTripJson = '''
{
  "version": 1,
  "trip": {
    "id": "trip_iceland_2027",
    "title": "Iceland Ring Road Adventure",
    "destination": "Reykjavik, Iceland",
    "startDate": "2027-06-01T00:00:00.000",
    "endDate": "2027-06-05T00:00:00.000",
    "ownerId": "user_current",
    "inviteCode": "ICE-9921",
    "defaultInviteRole": "editor",
    "members": {
      "user_current": "owner"
    },
    "createdAt": "2027-01-01T00:00:00.000",
    "updatedAt": "2027-01-01T00:00:00.000"
  },
  "stays": [
    {
      "id": "stay_ice_01",
      "tripId": "trip_iceland_2027",
      "type": "hotel",
      "name": "ION Adventure Hotel",
      "address": "Nesjavellir, Iceland",
      "checkInDate": "2027-06-01T00:00:00.000",
      "checkInTime": "15:00",
      "checkOutDate": "2027-06-03T00:00:00.000",
      "checkOutTime": "11:00",
      "confirmationCode": "ION-4411"
    }
  ],
  "activities": [
    {
      "id": "act_ice_01",
      "tripId": "trip_iceland_2027",
      "date": "2027-06-01T00:00:00.000",
      "startTime": "14:00",
      "title": "Blue Lagoon Geothermal Spa",
      "category": "attraction",
      "bookingStatus": "booked"
    }
  ],
  "flights": []
}
''';

      final result = await TripExportService.importFromJson(
        repository,
        singleTripJson,
        'user_current',
      );

      expect(result.tripsCount, 1);
      expect(result.staysCount, 1);
      expect(result.activitiesCount, 1);

      final importedTrip = await repository.getTripById('trip_iceland_2027');
      expect(importedTrip, isNotNull);
      expect(importedTrip!.title, 'Iceland Ring Road Adventure');

      final importedStays = await repository.getStays('trip_iceland_2027');
      expect(importedStays.length, 1);
      expect(importedStays.first.name, 'ION Adventure Hotel');
    });

    test('Importing JSON reassigns ownerId and members to active user', () async {
      const mockImportJson = '''{
  "version": 1,
  "trip": {
    "id": "trip_sample_transfer",
    "title": "Transfer Test Trip",
    "destination": "Paris, France",
    "startDate": "2027-01-01T00:00:00.000",
    "endDate": "2027-01-05T00:00:00.000",
    "ownerId": "user_current",
    "inviteCode": "PARIS-27",
    "defaultInviteRole": "editor",
    "members": {
      "user_current": "owner"
    },
    "createdAt": "2026-01-01T00:00:00.000",
    "updatedAt": "2026-01-01T00:00:00.000"
  },
  "stays": [],
  "activities": [],
  "flights": []
}''';

      final result = await TripExportService.importFromJson(
        repository,
        mockImportJson,
        'firebase_auth_user_123',
      );

      expect(result.tripsCount, 1);
      final savedTrip = await repository.getTripById('trip_sample_transfer');
      expect(savedTrip, isNotNull);
      expect(savedTrip!.ownerId, 'firebase_auth_user_123');
      expect(savedTrip.members.containsKey('firebase_auth_user_123'), isTrue);
      expect(savedTrip.members['firebase_auth_user_123'], MemberRole.owner);
      expect(savedTrip.members.containsKey('user_current'), isFalse);
    });

    test('Empty or invalid JSON throws FormatException', () async {
      expect(
        () => TripExportService.importFromJson(
          repository,
          '',
          'user_current',
        ),
        throwsA(isA<FormatException>()),
      );

      expect(
        () => TripExportService.importFromJson(
          repository,
          '{ not valid json }',
          'user_current',
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
