import 'package:flutter_test/flutter_test.dart';
import 'package:trippy/data/repositories/mock_trip_repository.dart';
import 'package:trippy/models/models.dart';

void main() {
  group('MockTripRepository Tests', () {
    late MockTripRepository repository;

    setUp(() {
      repository = MockTripRepository();
    });

    test('Initial seeded data loads both test trips correctly', () async {
      final trips = await repository.getTripsForUser('user_current');
      expect(trips.length, 2);

      // Trip 1: Japan Odyssey
      final trip1 = trips.firstWhere((t) => t.id == 'trip_japan_2026');
      expect(trip1.destination, contains('Tokyo & Kyoto'));
      final stays1 = await repository.getStays(trip1.id);
      expect(stays1.length, 2); // 2 hotels (no overlap with departure flight)
      final activities1 = await repository.getActivities(trip1.id);
      expect(activities1.length, greaterThanOrEqualTo(10));
      final flights1 = await repository.getFlights(trip1.id);
      expect(flights1.length, 2);

      // Trip 2: Italian Dolce Vita
      final trip2 = trips.firstWhere((t) => t.id == 'trip_italy_2026');
      expect(trip2.destination, contains('Rome, Florence & Positano'));
      final stays2 = await repository.getStays(trip2.id);
      expect(stays2.length, 3);
      final activities2 = await repository.getActivities(trip2.id);
      expect(activities2.length, greaterThanOrEqualTo(8));
      final flights2 = await repository.getFlights(trip2.id);
      expect(flights2.length, 2);
    });

    test('Joining a trip with valid invite code succeeds and assigns default role', () async {
      final trip = await repository.getTripByInviteCode('TYO-8821');
      expect(trip, isNotNull);

      final joined = await repository.joinTripWithCode('tyo-8821', 'new_guest_user');
      expect(joined, isTrue);

      final updatedTrip = await repository.getTripById(trip!.id);
      expect(updatedTrip?.members['new_guest_user'], MemberRole.editor);
    });

    test('Joining with invalid invite code returns false', () async {
      final joined = await repository.joinTripWithCode('INVALID-99', 'guest');
      expect(joined, isFalse);
    });

    test('Adding an activity triggers update in activities list', () async {
      final trips = await repository.getTripsForUser('user_current');
      final tripId = trips.first.id;

      final newAct = Activity(
        id: 'new_act_test',
        tripId: tripId,
        date: DateTime.now(),
        startTime: '12:00',
        title: 'Ramen Tasting',
        category: ActivityCategory.dining,
      );

      await repository.addActivity(newAct);

      final activities = await repository.getActivities(tripId);
      expect(activities.any((a) => a.id == 'new_act_test'), isTrue);
    });

    test('updateDayLocations persists custom locations for a day', () async {
      final trips = await repository.getTripsForUser('user_current');
      final trip = trips.first;
      final targetDate = trip.startDate;

      await repository.updateDayLocations(trip.id, targetDate, ['Japan', 'Shibuya', 'Harajuku']);

      final updatedTrip = await repository.getTripById(trip.id);
      expect(updatedTrip, isNotNull);
      final locs = updatedTrip!.getCustomLocationsForDate(targetDate);
      expect(locs, ['Japan', 'Shibuya', 'Harajuku']);
    });
  });
}
