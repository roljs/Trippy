import 'package:flutter_test/flutter_test.dart';
import 'package:trippy/core/utils/location_inference_helper.dart';
import 'package:trippy/models/models.dart';

void main() {
  group('Trip Model Tests', () {
    test('Calculates daysCount and daysList correctly across multiple days', () {
      final start = DateTime(2026, 10, 12);
      final end = DateTime(2026, 10, 16);

      final trip = Trip(
        id: 'test_trip',
        title: 'Test Journey',
        destination: 'Kyoto',
        startDate: start,
        endDate: end,
        ownerId: 'user_1',
        inviteCode: 'TYO-1234',
        defaultInviteRole: MemberRole.editor,
        members: {
          'user_1': MemberRole.owner,
          'user_2': MemberRole.viewer,
        },
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(trip.daysCount, 5); // Oct 12, 13, 14, 15, 16
      final days = trip.daysList;
      expect(days.length, 5);
      expect(days[0], DateTime(2026, 10, 12));
      expect(days[4], DateTime(2026, 10, 16));
    });

    test('Calculates daysList correctly across November 1 DST transition without duplicating dates', () {
      final start = DateTime(2026, 11, 1);
      final end = DateTime(2026, 11, 25);

      final trip = Trip(
        id: 'test_nov_trip',
        title: 'November Journey',
        destination: 'Thailand',
        startDate: start,
        endDate: end,
        ownerId: 'user_1',
        inviteCode: 'NOV-1234',
        defaultInviteRole: MemberRole.editor,
        members: {'user_1': MemberRole.owner},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(trip.daysCount, 25);
      final days = trip.daysList;
      expect(days.length, 25);
      expect(days[0], DateTime(2026, 11, 1));
      expect(days[1], DateTime(2026, 11, 2)); // Day 2 must be Nov 2, NOT Nov 1!
      expect(days[2], DateTime(2026, 11, 3));
      expect(days[24], DateTime(2026, 11, 25));

      // Ensure every consecutive day has distinct consecutive calendar days
      for (int i = 0; i < days.length - 1; i++) {
        expect(days[i].day, isNot(equals(days[i + 1].day)));
      }
    });

    test('Validates role permissions for Owner, Editor, and Viewer', () {
      final trip = Trip(
        id: 'test_trip',
        title: 'Test Journey',
        destination: 'Tokyo',
        startDate: DateTime(2026, 10, 12),
        endDate: DateTime(2026, 10, 14),
        ownerId: 'owner_user',
        inviteCode: 'TYO-1234',
        defaultInviteRole: MemberRole.editor,
        members: {
          'owner_user': MemberRole.owner,
          'editor_user': MemberRole.editor,
          'viewer_user': MemberRole.viewer,
        },
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(trip.canUserEdit('owner_user'), isTrue);
      expect(trip.canUserEdit('editor_user'), isTrue);
      expect(trip.canUserEdit('viewer_user'), isFalse);
      expect(trip.canUserEdit('stranger_user'), isFalse);
    });

    test('JSON serialization round-trip retains all properties', () {
      final original = Trip(
        id: 'trip_100',
        title: 'Alpine Tour',
        destination: 'Switzerland',
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2026, 7, 8),
        ownerId: 'user_alp',
        inviteCode: 'ALP-9988',
        defaultInviteRole: MemberRole.viewer,
        members: {'user_alp': MemberRole.owner},
        createdAt: DateTime.parse('2026-01-01T00:00:00Z'),
        updatedAt: DateTime.parse('2026-01-02T00:00:00Z'),
      );

      final map = original.toMap();
      final restored = Trip.fromMap(map);

      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.destination, original.destination);
      expect(restored.inviteCode, original.inviteCode);
      expect(restored.defaultInviteRole, MemberRole.viewer);
      expect(restored.members['user_alp'], MemberRole.owner);
    });
  });

  group('Stay Model Tests', () {
    test('coversTransition accurately matches consecutive days', () {
      final stay = Stay(
        id: 'stay_hotel',
        tripId: 'trip_1',
        type: StayType.hotel,
        name: 'Park Hyatt',
        checkInDate: DateTime(2026, 10, 12),
        checkInTime: '15:00',
        checkOutDate: DateTime(2026, 10, 14),
        checkOutTime: '11:00',
      );

      // Night 1 (Oct 12 -> Oct 13): Stay covers this transition!
      expect(stay.coversTransition(DateTime(2026, 10, 12), DateTime(2026, 10, 13)), isTrue);

      // Night 2 (Oct 13 -> Oct 14): Stay covers this transition!
      expect(stay.coversTransition(DateTime(2026, 10, 13), DateTime(2026, 10, 14)), isTrue);

      // Night 3 (Oct 14 -> Oct 15): Check-out was morning of Oct 14, does not cover!
      expect(stay.coversTransition(DateTime(2026, 10, 14), DateTime(2026, 10, 15)), isFalse);

      // Nights before check-in: does not cover
      expect(stay.coversTransition(DateTime(2026, 10, 11), DateTime(2026, 10, 12)), isFalse);
    });

    test('Overnight flight stays are detected properly', () {
      final overnightFlight = Flight(
        id: 'flt_red_eye',
        tripId: 'trip_1',
        airline: 'Delta',
        flightNumber: 'DL12',
        departureAirport: 'LAX',
        arrivalAirport: 'HND',
        departureTime: DateTime(2026, 10, 12, 23, 0),
        arrivalTime: DateTime(2026, 10, 14, 5, 0),
        isOvernight: true,
      );

      final stay = Stay(
        id: 'stay_flight',
        tripId: 'trip_1',
        type: StayType.overnightFlight,
        name: 'Delta 12 Red-Eye',
        checkInDate: DateTime(2026, 10, 12),
        checkOutDate: DateTime(2026, 10, 13),
        overnightFlight: overnightFlight,
      );

      expect(stay.type, StayType.overnightFlight);
      expect(stay.overnightFlight?.spansAcrossDays, isTrue);
      expect(stay.coversTransition(DateTime(2026, 10, 12), DateTime(2026, 10, 13)), isTrue);
    });
  });

  group('Activity Model Tests', () {
    test('Calculates startDateTime and sorts chronologically', () {
      final act1 = Activity(
        id: 'act1',
        tripId: 't1',
        date: DateTime(2026, 10, 12),
        startTime: '14:30',
        title: 'Afternoon Tea',
      );

      final act2 = Activity(
        id: 'act2',
        tripId: 't1',
        date: DateTime(2026, 10, 12),
        startTime: '09:00',
        title: 'Morning Run',
      );

      final act3 = Activity(
        id: 'act3',
        tripId: 't1',
        date: DateTime(2026, 10, 12),
        startTime: '19:45',
        title: 'Dinner',
      );

      final list = [act1, act2, act3];
      list.sort((a, b) => a.startDateTime.compareTo(b.startDateTime));

      expect(list[0].title, 'Morning Run');
      expect(list[1].title, 'Afternoon Tea');
      expect(list[2].title, 'Dinner');
    });
  });

  group('Day Locations & LocationInferenceHelper Tests', () {
    test('Trip model serializes and restores dayLocations map correctly', () {
      final trip = Trip(
        id: 't_loc',
        title: 'Japan Adventure',
        destination: 'Tokyo & Kyoto, Japan',
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 3),
        ownerId: 'u1',
        inviteCode: 'JPN-1234',
        members: {'u1': MemberRole.owner},
        dayLocations: {
          '2026-10-01': ['Japan', 'Tokyo'],
          '2026-10-02': ['Japan', 'Kyoto'],
        },
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final map = trip.toMap();
      final restored = Trip.fromMap(map);

      expect(restored.dayLocations.length, 2);
      expect(restored.getCustomLocationsForDate(DateTime(2026, 10, 1)), ['Japan', 'Tokyo']);
      expect(restored.getCustomLocationsForDate(DateTime(2026, 10, 2)), ['Japan', 'Kyoto']);
      expect(restored.getCustomLocationsForDate(DateTime(2026, 10, 3)), isNull);
    });

    test('LocationInferenceHelper infers target country from most recent flight', () {
      final flight = Flight(
        id: 'f1',
        tripId: 't1',
        airline: 'ANA',
        flightNumber: 'NH105',
        departureAirport: 'SFO (San Francisco)',
        arrivalAirport: 'HND (Tokyo)',
        departureTime: DateTime(2026, 10, 1, 10, 0),
        arrivalTime: DateTime(2026, 10, 1, 14, 0),
      );

      final inferred = LocationInferenceHelper.inferTargetCountryForDay(
        date: DateTime(2026, 10, 2),
        flights: [flight],
        activities: [],
        tripDestination: 'Tokyo, Japan',
      );

      expect(inferred, 'Japan');
    });

    test('LocationInferenceHelper falls back to trip destination country when no flights', () {
      final inferred = LocationInferenceHelper.inferTargetCountryForDay(
        date: DateTime(2026, 10, 1),
        flights: [],
        activities: [],
        tripDestination: 'Rome, Florence & Positano, Italy',
      );

      expect(inferred, 'Italy');
    });
  });
}
