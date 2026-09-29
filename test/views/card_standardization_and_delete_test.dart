import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trippy/data/repositories/mock_trip_repository.dart';
import 'package:trippy/models/models.dart';
import 'package:trippy/state/trip_providers.dart';
import 'package:trippy/views/attractions/attractions_view.dart';
import 'package:trippy/views/logistics/logistics_view.dart';
import 'package:trippy/views/logistics/widgets/flight_day_card_widget.dart';
import 'package:trippy/views/stays/stays_view.dart';

class _FakeActiveTripIdNotifier extends ActiveTripIdNotifier {
  final String? _initialId;
  _FakeActiveTripIdNotifier(this._initialId);

  @override
  String? build() => _initialId;
}

void main() {
  group('Card Standardization & 3-Dots Menu Tests', () {
    testWidgets('StaysView renders 3-dots menu with Edit and Delete options',
        (WidgetTester tester) async {
      final repo = MockTripRepository();
      const tripId = 'trip_japan_2026';

      bool editTapped = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(repo),
            activeTripIdProvider.overrideWith(() => _FakeActiveTripIdNotifier(tripId)),
            canEditActiveTripProvider.overrideWithValue(true),
          ],
          child: MaterialApp(
            home: StaysView(
              onStayTap: (s) => editTapped = true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Card is displayed
      expect(find.text('Grand Hyatt Tokyo'), findsOneWidget);
      expect(find.text('Add Stay'), findsOneWidget); // FAB exists

      // Find the 3-dots menu button on the card
      final moreButtons = find.byIcon(Icons.more_vert);
      expect(moreButtons, findsWidgets);

      // Tap the first more_vert button
      await tester.tap(moreButtons.first);
      await tester.pumpAndSettle();

      // Verify menu options
      expect(find.text('Edit Stay'), findsOneWidget);
      expect(find.text('Delete Stay'), findsOneWidget);

      // Tap Edit Stay
      await tester.tap(find.text('Edit Stay'));
      await tester.pumpAndSettle();
      expect(editTapped, isTrue);
    });

    testWidgets('AttractionsView renders 3-dots menu with Edit and Delete options',
        (WidgetTester tester) async {
      final repo = MockTripRepository();
      const tripId = 'trip_japan_2026';

      bool editTapped = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(repo),
            activeTripIdProvider.overrideWith(() => _FakeActiveTripIdNotifier(tripId)),
            canEditActiveTripProvider.overrideWithValue(true),
          ],
          child: MaterialApp(
            home: AttractionsView(
              onActivityTap: (a) => editTapped = true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find 3-dots menu on activity card
      final moreButtons = find.byIcon(Icons.more_vert);
      expect(moreButtons, findsWidgets);

      await tester.tap(moreButtons.first);
      await tester.pumpAndSettle();

      expect(find.text('Edit Activity'), findsOneWidget);
      expect(find.text('Delete Activity'), findsOneWidget);

      await tester.tap(find.text('Edit Activity'));
      await tester.pumpAndSettle();
      expect(editTapped, isTrue);
    });
  });

  group('Arrival and Departure Header Direct Edit Linking Tests', () {
    testWidgets('Tapping Arrival header calls onFlightTap with arrival flight',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repo = MockTripRepository();
      const tripId = 'trip_japan_2026';

      Flight? tappedFlight;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(repo),
            activeTripIdProvider.overrideWith(() => _FakeActiveTripIdNotifier(tripId)),
            canEditActiveTripProvider.overrideWithValue(true),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: LogisticsView(
                onFlightTap: (f) => tappedFlight = f,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find Arrival Flight Card inside the day column
      final arrivalFlightCardFinder = find.textContaining('NH203');
      expect(arrivalFlightCardFinder, findsOneWidget);

      // Tap on the Arrival Flight Card
      await tester.tap(arrivalFlightCardFinder);
      await tester.pumpAndSettle();

      expect(tappedFlight, isNotNull);
      expect(tappedFlight!.flightNumber, 'NH203');
      expect(tappedFlight!.isMainArrival, isTrue);
    });

    testWidgets('Tapping Departure flight card calls onFlightTap with departure flight',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repo = MockTripRepository();
      const tripId = 'trip_japan_2026';

      Flight? tappedFlight;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(repo),
            activeTripIdProvider.overrideWith(() => _FakeActiveTripIdNotifier(tripId)),
            canEditActiveTripProvider.overrideWithValue(true),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: LogisticsView(
                onFlightTap: (f) => tappedFlight = f,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find Departure Flight Card inside the day column
      final departureFlightCardFinder = find.descendant(
        of: find.byType(FlightDayCardWidget),
        matching: find.textContaining('JL060'),
      );
      expect(departureFlightCardFinder, findsOneWidget);

      // Tap on the Departure Flight Card
      await tester.tap(departureFlightCardFinder);
      await tester.pumpAndSettle();

      expect(tappedFlight, isNotNull);
      expect(tappedFlight!.flightNumber, 'JL060');
      expect(tappedFlight!.isMainDeparture, isTrue);
    });
  });

  group('Stay Deletion Integration Tests', () {
    test('Deleting a flight-backed stay updates flight isNightStay to false', () async {
      final repo = MockTripRepository();
      const tripId = 'trip_delete_test';

      final flight = Flight(
        id: 'flt_night_del',
        tripId: tripId,
        airline: 'Korean Air',
        flightNumber: 'KE011',
        departureAirport: 'ICN',
        arrivalAirport: 'LAX',
        departureTime: DateTime(2026, 11, 1, 20, 0),
        arrivalTime: DateTime(2026, 11, 2, 10, 0),
        isOvernight: true,
        isNightStay: true,
      );
      await repo.addFlight(flight);

      var flights = await repo.getFlights(tripId);
      expect(flights.first.isNightStay, isTrue);

      // Delete by synthesized stay ID
      await repo.deleteStay(tripId, 'stay_flight_flt_night_del');

      flights = await repo.getFlights(tripId);
      expect(flights.first.isNightStay, isFalse);
    });
  });
}
