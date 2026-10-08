import 'dart:convert';
import '../../data/repositories/trip_repository.dart';
import '../../models/models.dart';
import 'file_download_helper.dart';

class ImportResult {
  final int tripsCount;
  final int staysCount;
  final int activitiesCount;
  final int flightsCount;
  final String message;
  final List<String> importedTripTitles;

  const ImportResult({
    required this.tripsCount,
    required this.staysCount,
    required this.activitiesCount,
    required this.flightsCount,
    required this.message,
    required this.importedTripTitles,
  });
}

class TripExportService {
  static Future<TripBundle?> exportSingleTrip(
      TripRepository repo, String tripId) async {
    final trip = await repo.getTripById(tripId);
    if (trip == null) return null;

    final stays = await repo.getStays(tripId);
    final activities = await repo.getActivities(tripId);
    final flights = await repo.getFlights(tripId);

    return TripBundle(
      trip: trip,
      stays: stays,
      activities: activities,
      flights: flights,
    );
  }

  static Future<TripDatabaseBundle> exportAllTrips(
      TripRepository repo, String userId) async {
    final trips = await repo.getTripsForUser(userId);
    final bundles = <TripBundle>[];

    for (final trip in trips) {
      final stays = await repo.getStays(trip.id);
      final activities = await repo.getActivities(trip.id);
      final flights = await repo.getFlights(trip.id);

      bundles.add(
        TripBundle(
          trip: trip,
          stays: stays,
          activities: activities,
          flights: flights,
        ),
      );
    }

    return TripDatabaseBundle(
      exportedAt: DateTime.now(),
      trips: bundles,
    );
  }

  static void downloadSingleTrip(TripBundle bundle) {
    final slug = bundle.trip.title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final filename = 'trip_${slug.isEmpty ? 'details' : slug}.json';
    downloadFile(filename, bundle.toJson(pretty: true));
  }

  static void downloadAllTrips(TripDatabaseBundle dbBundle) {
    final timestamp = DateTime.now().toIso8601String().split('T').first;
    final filename = 'trippy_all_trips_$timestamp.json';
    downloadFile(filename, dbBundle.toJson(pretty: true));
  }

  static Future<ImportResult> importFromJson(
      TripRepository repo, String jsonString, String currentUserId) async {
    final trimmed = jsonString.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Import content is empty');
    }

    final decoded = jsonDecode(trimmed);
    final bundles = <TripBundle>[];

    if (decoded is List) {
      for (final item in decoded) {
        bundles.add(TripBundle.fromMap(item as Map<String, dynamic>));
      }
    } else if (decoded is Map<String, dynamic>) {
      if (decoded.containsKey('trips') && decoded['trips'] is List) {
        final dbBundle = TripDatabaseBundle.fromMap(decoded);
        bundles.addAll(dbBundle.trips);
      } else {
        // Single trip bundle or raw trip object
        bundles.add(TripBundle.fromMap(decoded));
      }
    } else {
      throw const FormatException('Unrecognized JSON format for trip import');
    }

    if (bundles.isEmpty) {
      throw const FormatException('No valid trips found in JSON');
    }

    int totalStays = 0;
    int totalActivities = 0;
    int totalFlights = 0;
    final importedTitles = <String>[];

    for (final bundle in bundles) {
      // Ensure the importing user has access/ownership
      var tripToSave = bundle.trip;
      final members = Map<String, MemberRole>.from(tripToSave.members);
      if (currentUserId.isNotEmpty) {
        members.remove('user_current');
        members[currentUserId] = MemberRole.owner;
      }
      tripToSave = tripToSave.copyWith(
        ownerId: currentUserId.isNotEmpty ? currentUserId : tripToSave.ownerId,
        members: members,
        updatedAt: DateTime.now(),
      );

      // Save trip (create or update)
      final existingTrip = await repo.getTripById(tripToSave.id);
      if (existingTrip != null) {
        if (currentUserId.isNotEmpty && existingTrip.ownerId != currentUserId) {
          // If existing trip belongs to another user, import as a new copy with a unique ID
          final newTripId = 'trip_${DateTime.now().millisecondsSinceEpoch}';
          tripToSave = tripToSave.copyWith(id: newTripId);
          await repo.createTrip(tripToSave);
        } else {
          // Preserve createdAt to avoid tripping Firestore createdAt immutability rule
          tripToSave = tripToSave.copyWith(createdAt: existingTrip.createdAt);
          await repo.updateTrip(tripToSave);
        }
      } else {
        await repo.createTrip(tripToSave);
      }

      final targetTripId = tripToSave.id;

      // Add stays
      for (final stay in bundle.stays) {
        await repo.addStay(stay.copyWith(tripId: targetTripId));
        totalStays++;
      }

      // Add activities
      for (final act in bundle.activities) {
        await repo.addActivity(act.copyWith(tripId: targetTripId));
        totalActivities++;
      }

      // Add flights
      for (final flight in bundle.flights) {
        await repo.addFlight(flight.copyWith(tripId: targetTripId));
        totalFlights++;
      }

      importedTitles.add(tripToSave.title);
    }

    return ImportResult(
      tripsCount: bundles.length,
      staysCount: totalStays,
      activitiesCount: totalActivities,
      flightsCount: totalFlights,
      message:
          'Successfully imported ${bundles.length} trip(s), $totalStays stay(s), $totalActivities activitie(s), and $totalFlights flight(s).',
      importedTripTitles: importedTitles,
    );
  }
}
