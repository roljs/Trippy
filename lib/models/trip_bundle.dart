import 'dart:convert';
import 'activity.dart';
import 'flight.dart';
import 'stay.dart';
import 'trip.dart';

class TripBundle {
  final int version;
  final Trip trip;
  final List<Stay> stays;
  final List<Activity> activities;
  final List<Flight> flights;

  const TripBundle({
    this.version = 1,
    required this.trip,
    this.stays = const [],
    this.activities = const [],
    this.flights = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'version': version,
      'trip': trip.toMap(),
      'stays': stays.map((s) => s.toMap()).toList(),
      'activities': activities.map((a) => a.toMap()).toList(),
      'flights': flights.map((f) => f.toMap()).toList(),
    };
  }

  factory TripBundle.fromMap(Map<String, dynamic> map) {
    final tripMap = map['trip'] as Map<String, dynamic>? ?? map;
    final parsedTrip = Trip.fromMap(tripMap);

    final rawStays = map['stays'] as List<dynamic>? ?? [];
    final parsedStays = rawStays
        .map((item) => Stay.fromMap(item as Map<String, dynamic>))
        .toList();

    final rawActivities = map['activities'] as List<dynamic>? ?? [];
    final parsedActivities = rawActivities
        .map((item) => Activity.fromMap(item as Map<String, dynamic>))
        .toList();

    final rawFlights = map['flights'] as List<dynamic>? ?? [];
    final parsedFlights = rawFlights
        .map((item) => Flight.fromMap(item as Map<String, dynamic>))
        .toList();

    return TripBundle(
      version: map['version'] as int? ?? 1,
      trip: parsedTrip,
      stays: parsedStays,
      activities: parsedActivities,
      flights: parsedFlights,
    );
  }

  String toJson({bool pretty = true}) {
    if (pretty) {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(toMap());
    }
    return jsonEncode(toMap());
  }

  factory TripBundle.fromJson(String source) {
    return TripBundle.fromMap(jsonDecode(source) as Map<String, dynamic>);
  }
}

class TripDatabaseBundle {
  final int version;
  final DateTime exportedAt;
  final List<TripBundle> trips;

  const TripDatabaseBundle({
    this.version = 1,
    required this.exportedAt,
    required this.trips,
  });

  Map<String, dynamic> toMap() {
    return {
      'version': version,
      'exportedAt': exportedAt.toIso8601String(),
      'trips': trips.map((t) => t.toMap()).toList(),
    };
  }

  factory TripDatabaseBundle.fromMap(Map<String, dynamic> map) {
    final rawTrips = map['trips'] as List<dynamic>? ?? [];
    final parsedTrips = rawTrips
        .map((t) => TripBundle.fromMap(t as Map<String, dynamic>))
        .toList();

    return TripDatabaseBundle(
      version: map['version'] as int? ?? 1,
      exportedAt: map['exportedAt'] != null
          ? DateTime.parse(map['exportedAt'] as String)
          : DateTime.now(),
      trips: parsedTrips,
    );
  }

  String toJson({bool pretty = true}) {
    if (pretty) {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(toMap());
    }
    return jsonEncode(toMap());
  }

  factory TripDatabaseBundle.fromJson(String source) {
    final decoded = jsonDecode(source);
    if (decoded is List) {
      // Direct list of trip bundles
      final trips = decoded
          .map((item) => TripBundle.fromMap(item as Map<String, dynamic>))
          .toList();
      return TripDatabaseBundle(
        exportedAt: DateTime.now(),
        trips: trips,
      );
    }
    return TripDatabaseBundle.fromMap(decoded as Map<String, dynamic>);
  }
}
