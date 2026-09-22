import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trippy/data/repositories/mock_trip_repository.dart';
import 'package:trippy/models/models.dart';
import 'package:trippy/state/trip_providers.dart';
import 'package:trippy/views/flights/flights_view.dart';

class _FakeActiveTripIdNotifier extends ActiveTripIdNotifier {
  final String? _initialId;
  _FakeActiveTripIdNotifier(this._initialId);

  @override
  String? build() => _initialId;
}

void main() {
  group('Flight Model & Serialization Tests', () {
    test('Flight correctly serializes and deserializes isNightStay, isMainArrival, isMainDeparture', () {
      final nightFlight = Flight(
        id: 'flt_night_test',
        tripId: 'trip_flags',
        airline: 'Delta Air Lines',
        flightNumber: 'DL101',
        departureAirport: 'JFK',
        arrivalAirport: 'HND',
        departureTime: DateTime(2026, 5, 1, 10, 0),
        arrivalTime: DateTime(2026, 5, 2, 14, 0),
        isOvernight: true,
        isNightStay: true,
        isMainArrival: false,
        isMainDeparture: false,
      );

      final map = nightFlight.toMap();
      expect(map['isNightStay'], isTrue);
      expect(map['isMainArrival'], isFalse);
      expect(map['isMainDeparture'], isFalse);

      final restored = Flight.fromMap(map);
      expect(restored.isNightStay, isTrue);
      expect(restored.isMainArrival, isFalse);
      expect(restored.isMainDeparture, isFalse);
      expect(restored.spansAcrossDays, isTrue);

      // Verify mutual exclusivity: arrival or departure flight cannot be night stay
      final arrivalFlight = Flight(
        id: 'flt_arr_test',
        tripId: 'trip_flags',
        airline: 'ANA',
        flightNumber: 'NH200',
        departureAirport: 'SFO',
        arrivalAirport: 'HND',
        departureTime: DateTime(2026, 5, 1, 11, 0),
        arrivalTime: DateTime(2026, 5, 1, 15, 0),
        isNightStay: true, // Should be normalized to false because isMainArrival is true
        isMainArrival: true,
      );
      expect(arrivalFlight.isMainArrival, isTrue);
      expect(arrivalFlight.isNightStay, isFalse);
    });

    test('Flight fromMap handles missing boolean flags gracefully', () {
      final minimalMap = {
        'id': 'flt_legacy',
        'tripId': 'trip_01',
        'airline': 'Legacy Air',
        'flightNumber': 'L100',
        'departureAirport': 'LAX',
        'arrivalAirport': 'SFO',
        'departureTime': '2026-06-01T08:00:00.000',
        'arrivalTime': '2026-06-01T09:30:00.000',
      };

      final flight = Flight.fromMap(minimalMap);
      expect(flight.isNightStay, isFalse);
      expect(flight.isMainArrival, isFalse);
      expect(flight.isMainDeparture, isFalse);
      expect(flight.isOvernight, isFalse);
    });
  });

  group('TripRepository Flights CRUD Tests', () {
    test('Can add, update, and delete flights', () async {
      final repo = MockTripRepository();
      const tripId = 'trip_test_crud';

      final flight = Flight(
        id: 'flt_crud_01',
        tripId: tripId,
        airline: 'United Airlines',
        flightNumber: 'UA200',
        departureAirport: 'ORD',
        arrivalAirport: 'NRT',
        departureTime: DateTime(2026, 7, 1, 11, 0),
        arrivalTime: DateTime(2026, 7, 2, 14, 30),
        isNightStay: true,
      );

      // Add
      await repo.addFlight(flight);
      var list = await repo.getFlights(tripId);
      expect(list.length, 1);
      expect(list.first.flightNumber, 'UA200');
      expect(list.first.isNightStay, isTrue);
      expect(list.first.isMainArrival, isFalse);

      // Update
      final updated = flight.copyWith(
        flightNumber: 'UA201',
        isMainDeparture: true,
      );
      await repo.updateFlight(updated);
      list = await repo.getFlights(tripId);
      expect(list.first.flightNumber, 'UA201');
      expect(list.first.isMainDeparture, isTrue);
      expect(list.first.isNightStay, isFalse); // Cleared by isMainDeparture

      // Delete
      await repo.deleteFlight(tripId, 'flt_crud_01');
      list = await repo.getFlights(tripId);
      expect(list.isEmpty, isTrue);
    });
  });

  group('sortedActiveTripStaysProvider Night Flight Integration Tests', () {
    test('Synthesizes Stay for flight marked isNightStay', () async {
      final repo = MockTripRepository();
      const tripId = 'trip_integration_test';
      final container = ProviderContainer(
        overrides: [
          tripRepositoryProvider.overrideWithValue(repo),
          activeTripIdProvider.overrideWith(() => _FakeActiveTripIdNotifier(tripId)),
        ],
      );

      final trip = Trip(
        id: tripId,
        title: 'Night Flight Test Trip',
        destination: 'London, UK',
        startDate: DateTime(2026, 8, 1),
        endDate: DateTime(2026, 8, 5),
        ownerId: 'user_test',
        inviteCode: 'LDN-001',
        members: const {'user_test': MemberRole.owner},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repo.createTrip(trip);

      // Add night flight
      final nightFlight = Flight(
        id: 'flt_red_eye',
        tripId: tripId,
        airline: 'British Airways',
        flightNumber: 'BA178',
        departureAirport: 'JFK',
        arrivalAirport: 'LHR',
        departureTime: DateTime(2026, 8, 1, 22, 0),
        arrivalTime: DateTime(2026, 8, 2, 10, 0),
        isOvernight: true,
        isNightStay: true,
        bookingRef: 'BA-9922',
      );
      await repo.addFlight(nightFlight);

      container.listen(sortedActiveTripStaysProvider, (previous, next) {});
      await container.read(activeTripFlightsProvider.future);
      await container.read(activeTripStaysProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final staysAsync = container.read(sortedActiveTripStaysProvider);
      final stays = staysAsync.value ?? [];

      expect(stays.any((s) => s.type == StayType.overnightFlight), isTrue);
      final synthesizedStay = stays.firstWhere((s) => s.type == StayType.overnightFlight);
      expect(synthesizedStay.name, contains('BA178'));
      expect(synthesizedStay.confirmationCode, 'BA-9922');
      expect(synthesizedStay.checkInDate, DateTime(2026, 8, 1));
      expect(synthesizedStay.checkOutDate, DateTime(2026, 8, 2));

      container.dispose();
    });
  });

  group('FlightsView UI & Status Badges Tests', () {
    testWidgets('Renders flight card with NIGHT STAY and MAIN ARRIVAL badges and Add Flight FAB',
        (WidgetTester tester) async {
      final repo = MockTripRepository();
      const tripId = 'trip_ui_test';

      final trip = Trip(
        id: tripId,
        title: 'Flights View Test Trip',
        destination: 'Paris, France',
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 5),
        ownerId: 'user_current',
        inviteCode: 'PAR-123',
        members: const {'user_current': MemberRole.owner},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repo.createTrip(trip);

      final flightArrival = Flight(
        id: 'flt_ui_01',
        tripId: tripId,
        airline: 'Air France',
        flightNumber: 'AF007',
        departureAirport: 'JFK',
        arrivalAirport: 'CDG',
        departureTime: DateTime(2026, 9, 1, 19, 0),
        arrivalTime: DateTime(2026, 9, 2, 8, 30),
        isOvernight: true,
        isNightStay: false,
        isMainArrival: true,
        isMainDeparture: false,
        terminal: '1',
        seat: '12A',
        bookingRef: 'AF-7711',
      );
      await repo.addFlight(flightArrival);

      final flightNight = Flight(
        id: 'flt_ui_02',
        tripId: tripId,
        airline: 'Lufthansa',
        flightNumber: 'LH400',
        departureAirport: 'FRA',
        arrivalAirport: 'JFK',
        departureTime: DateTime(2026, 9, 3, 22, 0),
        arrivalTime: DateTime(2026, 9, 4, 6, 0),
        isOvernight: true,
        isNightStay: true,
        isMainArrival: false,
        isMainDeparture: false,
      );
      await repo.addFlight(flightNight);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(repo),
            activeTripIdProvider.overrideWith(() => _FakeActiveTripIdNotifier(tripId)),
          ],
          child: const MaterialApp(
            home: FlightsView(),
          ),
        ),
      );

      // Pump for stream emission
      await tester.pumpAndSettle();

      expect(find.text('Air France'), findsOneWidget);
      expect(find.text('AF007'), findsOneWidget);
      expect(find.text('MAIN ARRIVAL'), findsOneWidget);
      expect(find.text('Lufthansa'), findsOneWidget);
      expect(find.text('NIGHT STAY'), findsOneWidget);
      expect(find.text('Add Flight'), findsOneWidget);
    });
  });
}
