import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/models.dart';
import 'trip_repository.dart';

class FirestoreTripRepository implements TripRepository {
  final FirebaseFirestore _firestore;

  FirestoreTripRepository([FirebaseFirestore? firestore])
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _tripsCollection =>
      _firestore.collection('trips');

  DocumentReference<Map<String, dynamic>> _tripDoc(String tripId) =>
      _tripsCollection.doc(tripId);

  CollectionReference<Map<String, dynamic>> _staysCollection(String tripId) =>
      _tripDoc(tripId).collection('stays');

  DocumentReference<Map<String, dynamic>> _stayDoc(
    String tripId,
    String stayId,
  ) =>
      _staysCollection(tripId).doc(stayId);

  CollectionReference<Map<String, dynamic>> _flightsCollection(String tripId) =>
      _tripDoc(tripId).collection('flights');

  DocumentReference<Map<String, dynamic>> _flightDoc(
    String tripId,
    String flightId,
  ) =>
      _flightsCollection(tripId).doc(flightId);

  CollectionReference<Map<String, dynamic>> _activitiesCollection(
    String tripId,
  ) =>
      _tripDoc(tripId).collection('activities');

  DocumentReference<Map<String, dynamic>> _activityDoc(
    String tripId,
    String activityId,
  ) =>
      _activitiesCollection(tripId).doc(activityId);

  // Helper to normalize Firestore timestamps or missing doc IDs
  void _sanitizeTimestamps(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final val = map[key];
      if (val is Timestamp) {
        map[key] = val.toDate().toIso8601String();
      }
    }
  }

  Trip? _tripFromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) return null;
    final map = Map<String, dynamic>.from(data);
    if (map['id'] == null || (map['id'] as String).isEmpty) {
      map['id'] = doc.id;
    }
    _sanitizeTimestamps(map, ['startDate', 'endDate', 'createdAt', 'updatedAt']);
    return Trip.fromMap(map);
  }

  Stay? _stayFromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) return null;
    final map = Map<String, dynamic>.from(data);
    if (map['id'] == null || (map['id'] as String).isEmpty) {
      map['id'] = doc.id;
    }
    _sanitizeTimestamps(map, ['checkInDate', 'checkOutDate']);
    if (map['overnightFlight'] is Map) {
      final flightMap =
          Map<String, dynamic>.from(map['overnightFlight'] as Map);
      _sanitizeTimestamps(flightMap, ['departureTime', 'arrivalTime']);
      map['overnightFlight'] = flightMap;
    }
    return Stay.fromMap(map);
  }

  Flight? _flightFromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) return null;
    final map = Map<String, dynamic>.from(data);
    if (map['id'] == null || (map['id'] as String).isEmpty) {
      map['id'] = doc.id;
    }
    _sanitizeTimestamps(map, ['departureTime', 'arrivalTime']);
    return Flight.fromMap(map);
  }

  Activity? _activityFromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) return null;
    final map = Map<String, dynamic>.from(data);
    if (map['id'] == null || (map['id'] as String).isEmpty) {
      map['id'] = doc.id;
    }
    _sanitizeTimestamps(map, ['date']);
    return Activity.fromMap(map);
  }

  Map<String, dynamic> _cleanMap(Map<String, dynamic> map) {
    final clean = <String, dynamic>{};
    for (final entry in map.entries) {
      if (entry.value != null) {
        if (entry.value is Map<String, dynamic>) {
          clean[entry.key] = _cleanMap(entry.value as Map<String, dynamic>);
        } else {
          clean[entry.key] = entry.value;
        }
      }
    }
    return clean;
  }

  Map<String, dynamic> _tripToFirestore(Trip trip) {
    final map = trip.toMap();
    // Maintain memberIds array for efficient indexed queries
    final memberIds = <String>{trip.ownerId, ...trip.members.keys};
    map['memberIds'] = memberIds.toList();
    return _cleanMap(map);
  }

  // --- Trips ---

  @override
  Stream<List<Trip>> watchTripsForUser(String userId) {
    if (userId.isEmpty) return Stream.value(const <Trip>[]);

    final query = _tripsCollection.where(
      'memberIds',
      arrayContains: userId,
    );

    return query.snapshots().map((snapshot) {
      final trips = snapshot.docs
          .map((doc) => _tripFromSnapshot(doc))
          .whereType<Trip>()
          .toList();
      trips.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return trips;
    });
  }

  @override
  Future<List<Trip>> getTripsForUser(String userId) async {
    if (userId.isEmpty) return const <Trip>[];

    final query = _tripsCollection.where(
      'memberIds',
      arrayContains: userId,
    );

    final snapshot = await query.get();
    final trips = snapshot.docs
        .map((doc) => _tripFromSnapshot(doc))
        .whereType<Trip>()
        .toList();
    trips.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return trips;
  }

  @override
  Future<Trip?> getTripById(String tripId) async {
    final doc = await _tripDoc(tripId).get();
    if (!doc.exists) return null;
    return _tripFromSnapshot(doc);
  }

  @override
  Future<Trip?> getTripByInviteCode(String inviteCode) async {
    final cleanCode = inviteCode.trim().toUpperCase();
    if (cleanCode.isEmpty) return null;

    final query = await _tripsCollection
        .where('inviteCode', isEqualTo: cleanCode)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      return _tripFromSnapshot(query.docs.first);
    }

    final fallbackQuery = await _tripsCollection
        .where('inviteCode', isEqualTo: inviteCode.trim())
        .limit(1)
        .get();

    if (fallbackQuery.docs.isNotEmpty) {
      return _tripFromSnapshot(fallbackQuery.docs.first);
    }

    return null;
  }

  @override
  Future<Trip> createTrip(Trip trip) async {
    final data = _tripToFirestore(trip);
    await _tripDoc(trip.id).set(data, SetOptions(merge: true));
    return trip;
  }

  @override
  Future<void> updateTrip(Trip trip) async {
    final data = _tripToFirestore(trip);
    await _tripDoc(trip.id).set(data, SetOptions(merge: true));
  }

  Future<void> _deleteSubcollection(
    CollectionReference<Map<String, dynamic>> collectionRef,
  ) async {
    final snapshot = await collectionRef.get();
    if (snapshot.docs.isEmpty) return;
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  @override
  Future<void> deleteTrip(String tripId) async {
    await _deleteSubcollection(_staysCollection(tripId));
    await _deleteSubcollection(_flightsCollection(tripId));
    await _deleteSubcollection(_activitiesCollection(tripId));
    await _tripDoc(tripId).delete();
  }

  @override
  Future<bool> joinTripWithCode(String inviteCode, String userId) async {
    final trip = await getTripByInviteCode(inviteCode);
    if (trip == null) return false;

    final updatedMembers = Map<String, MemberRole>.from(trip.members);
    updatedMembers[userId] = trip.defaultInviteRole;

    final updatedTrip = trip.copyWith(
      members: updatedMembers,
      updatedAt: DateTime.now(),
    );
    await updateTrip(updatedTrip);
    return true;
  }

  @override
  Future<void> updateDayLocations(
    String tripId,
    DateTime date,
    List<String> locations,
  ) async {
    final trip = await getTripById(tripId);
    if (trip == null) return;

    final newDayLocations = Map<String, List<String>>.from(trip.dayLocations);
    final key = Trip.dateToKey(date);
    if (locations.isEmpty) {
      newDayLocations.remove(key);
    } else {
      newDayLocations[key] = List<String>.from(locations);
    }

    final updated = trip.copyWith(
      dayLocations: newDayLocations,
      updatedAt: DateTime.now(),
    );
    await updateTrip(updated);
  }

  // --- Stays ---

  @override
  Stream<List<Stay>> watchStays(String tripId) {
    return _staysCollection(tripId).snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => _stayFromSnapshot(doc))
          .whereType<Stay>()
          .toList();
    });
  }

  @override
  Future<List<Stay>> getStays(String tripId) async {
    final snapshot = await _staysCollection(tripId).get();
    return snapshot.docs
        .map((doc) => _stayFromSnapshot(doc))
        .whereType<Stay>()
        .toList();
  }

  @override
  Future<void> addStay(Stay stay) async {
    await _stayDoc(stay.tripId, stay.id).set(
      _cleanMap(stay.toMap()),
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> updateStay(Stay stay) async {
    await _stayDoc(stay.tripId, stay.id).set(
      _cleanMap(stay.toMap()),
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> deleteStay(String tripId, String stayId) async {
    final stayDoc = await _stayDoc(tripId, stayId).get();
    final stay = stayDoc.exists ? _stayFromSnapshot(stayDoc) : null;

    await _stayDoc(tripId, stayId).delete();

    // If stay is backed by a flight, reset flight's isNightStay flag
    String? targetFlightId;
    if (stayId.startsWith('stay_flight_')) {
      targetFlightId = stayId.substring('stay_flight_'.length);
    } else if (stayId.startsWith('flight_stay_')) {
      targetFlightId = stayId.substring('flight_stay_'.length);
    } else if (stay?.overnightFlight != null) {
      targetFlightId = stay!.overnightFlight!.id;
    }

    if (targetFlightId != null) {
      final flightRef = _flightDoc(tripId, targetFlightId);
      final flightDoc = await flightRef.get();
      if (flightDoc.exists) {
        await flightRef.update({'isNightStay': false});
      }
    }

    // Remove linked activities
    final linkedIds = stay?.linkedActivityIds ?? const [];
    final actsByStay = await _activitiesCollection(tripId)
        .where('stayId', isEqualTo: stayId)
        .get();

    final batch = _firestore.batch();
    for (final doc in actsByStay.docs) {
      batch.delete(doc.reference);
    }
    for (final linkedId in linkedIds) {
      batch.delete(_activityDoc(tripId, linkedId));
    }
    await batch.commit();
  }

  // --- Activities ---

  @override
  Stream<List<Activity>> watchActivities(String tripId) {
    return _activitiesCollection(tripId).snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => _activityFromSnapshot(doc))
          .whereType<Activity>()
          .toList();
    });
  }

  @override
  Future<List<Activity>> getActivities(String tripId) async {
    final snapshot = await _activitiesCollection(tripId).get();
    return snapshot.docs
        .map((doc) => _activityFromSnapshot(doc))
        .whereType<Activity>()
        .toList();
  }

  @override
  Future<void> addActivity(Activity activity) async {
    await _activityDoc(activity.tripId, activity.id).set(
      _cleanMap(activity.toMap()),
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> updateActivity(Activity activity) async {
    await _activityDoc(activity.tripId, activity.id).set(
      _cleanMap(activity.toMap()),
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> deleteActivity(String tripId, String activityId) async {
    final actDoc = await _activityDoc(tripId, activityId).get();
    final activity = actDoc.exists ? _activityFromSnapshot(actDoc) : null;

    await _activityDoc(tripId, activityId).delete();

    // If activity was linked to a flight, unlink it
    if (activity?.flightId != null) {
      final flightRef = _flightDoc(tripId, activity!.flightId!);
      final flightDoc = await flightRef.get();
      if (flightDoc.exists) {
        await flightRef.update({
          'linkedActivityIds': FieldValue.arrayRemove([activityId]),
        });
      }
    }

    // If activity was linked to a stay, unlink it
    if (activity?.stayId != null) {
      final stayRef = _stayDoc(tripId, activity!.stayId!);
      final stayDoc = await stayRef.get();
      if (stayDoc.exists) {
        await stayRef.update({
          'linkedActivityIds': FieldValue.arrayRemove([activityId]),
        });
      }
    }
  }

  // --- Flights ---

  @override
  Stream<List<Flight>> watchFlights(String tripId) {
    return _flightsCollection(tripId).snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => _flightFromSnapshot(doc))
          .whereType<Flight>()
          .toList();
    });
  }

  @override
  Future<List<Flight>> getFlights(String tripId) async {
    final snapshot = await _flightsCollection(tripId).get();
    return snapshot.docs
        .map((doc) => _flightFromSnapshot(doc))
        .whereType<Flight>()
        .toList();
  }

  @override
  Future<void> addFlight(Flight flight) async {
    await _flightDoc(flight.tripId, flight.id).set(
      _cleanMap(flight.toMap()),
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> updateFlight(Flight flight) async {
    await _flightDoc(flight.tripId, flight.id).set(
      _cleanMap(flight.toMap()),
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> deleteFlight(String tripId, String flightId) async {
    final flightDoc = await _flightDoc(tripId, flightId).get();
    final flight = flightDoc.exists ? _flightFromSnapshot(flightDoc) : null;

    await _flightDoc(tripId, flightId).delete();

    // Remove linked activities
    final linkedIds = flight?.linkedActivityIds ?? const [];
    final actsByFlight = await _activitiesCollection(tripId)
        .where('flightId', isEqualTo: flightId)
        .get();

    final batch = _firestore.batch();
    for (final doc in actsByFlight.docs) {
      batch.delete(doc.reference);
    }
    for (final linkedId in linkedIds) {
      batch.delete(_activityDoc(tripId, linkedId));
    }
    await batch.commit();
  }
}
