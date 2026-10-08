import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trippy/data/repositories/mock_trip_repository.dart';
import 'package:trippy/models/models.dart';
import 'package:trippy/state/trip_providers.dart';
import 'package:trippy/views/attractions/attractions_view.dart';
import 'package:trippy/views/common/app_nav_scaffold.dart';
import 'package:trippy/views/dashboard/trip_dashboard_screen.dart';
import 'package:trippy/views/flights/flights_view.dart';

class FakeActiveTripIdNotifier extends ActiveTripIdNotifier {
  final String? initial;
  FakeActiveTripIdNotifier([this.initial = 'deletable_trip_1']);
  @override
  String? build() => initial;
}

void main() {
  group('Flight & Ground Transfer Bi-directional Linking & Cascading Delete', () {
    late MockTripRepository repo;
    late Trip trip;
    late Flight flight;
    late Activity transferActivity;

    setUp(() async {
      repo = MockTripRepository();
      final now = DateTime.now();

      trip = Trip(
        id: 'test_trip_100',
        title: 'European Summer',
        destination: 'Paris & Rome',
        startDate: now,
        endDate: now.add(const Duration(days: 7)),
        ownerId: 'user_current',
        inviteCode: 'EUR-100',
        defaultInviteRole: MemberRole.editor,
        members: const {'user_current': MemberRole.owner},
        createdAt: now,
        updatedAt: now,
      );
      await repo.createTrip(trip);

      flight = Flight(
        id: 'flt_af_100',
        tripId: trip.id,
        airline: 'Air France',
        flightNumber: 'AF123',
        departureAirport: 'CDG (Paris)',
        arrivalAirport: 'FCO (Rome)',
        departureTime: now.add(const Duration(days: 2, hours: 10)),
        arrivalTime: now.add(const Duration(days: 2, hours: 12)),
        linkedActivityIds: const ['act_xfer_100'],
      );
      await repo.addFlight(flight);

      transferActivity = Activity(
        id: 'act_xfer_100',
        tripId: trip.id,
        flightId: flight.id,
        date: now.add(const Duration(days: 2)),
        startTime: '08:00',
        title: 'Transport: Hotel to CDG Airport',
        category: ActivityCategory.transport,
        location: 'CDG Airport',
      );
      await repo.addActivity(transferActivity);
    });

    test('Flight preserves linkedActivityIds and Activity preserves flightId', () async {
      final fetchedFlight = await repo.getFlights(trip.id);
      expect(fetchedFlight.first.linkedActivityIds, contains('act_xfer_100'));

      final fetchedActivities = await repo.getActivities(trip.id);
      expect(fetchedActivities.first.flightId, 'flt_af_100');
    });

    test('Deleting an activity unlinks it from the flight', () async {
      await repo.deleteActivity(trip.id, 'act_xfer_100');

      final fetchedFlight = await repo.getFlights(trip.id);
      expect(fetchedFlight.first.linkedActivityIds, isNot(contains('act_xfer_100')));
    });

    test('Deleting a flight automatically cascades and deletes linked transfer activities', () async {
      final initialActivities = await repo.getActivities(trip.id);
      expect(initialActivities.length, 1);

      await repo.deleteFlight(trip.id, 'flt_af_100');

      final remainingFlights = await repo.getFlights(trip.id);
      expect(remainingFlights, isEmpty);

      final remainingActivities = await repo.getActivities(trip.id);
      expect(remainingActivities, isEmpty);
    });

    test('Deleting a trip removes the trip, its flights, stays, and activities', () async {
      await repo.deleteTrip(trip.id);

      final trips = await repo.getTripsForUser('user_current');
      expect(trips.where((t) => t.id == trip.id), isEmpty);

      final flights = await repo.getFlights(trip.id);
      expect(flights, isEmpty);

      final activities = await repo.getActivities(trip.id);
      expect(activities, isEmpty);
    });

    testWidgets('FlightsView displays linked Ground Transfer and navigation chip', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(repo),
            activeTripProvider.overrideWithValue(trip),
            activeTripFlightsProvider.overrideWith((ref) => Stream.value([flight])),
            activeTripActivitiesProvider.overrideWith((ref) => Stream.value([transferActivity])),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: FlightsView(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Ground Transfers section is shown on Flight Card
      expect(find.textContaining('Airport Ground Transfers'), findsOneWidget);
      expect(find.text('Transport: Hotel to CDG Airport'), findsOneWidget);
      expect(find.text('Link Transfer'), findsOneWidget);
    });

    testWidgets('AttractionsView displays linked flight badge with flight number', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(repo),
            activeTripProvider.overrideWithValue(trip),
            activeTripFlightsProvider.overrideWith((ref) => Stream.value([flight])),
            activeTripActivitiesProvider.overrideWith((ref) => Stream.value([transferActivity])),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AttractionsView(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify linked flight badge is rendered
      expect(find.textContaining('AF123 (Air France)'), findsOneWidget);
    });
  });

  group('Trip Dashboard Deletion & FAB Restriction Tests', () {
    late MockTripRepository repo;
    late Trip trip;

    setUp(() async {
      repo = MockTripRepository();
      final now = DateTime.now();

      trip = Trip(
        id: 'deletable_trip_1',
        title: 'Delete Me Trip',
        destination: 'Nowhere',
        startDate: now,
        endDate: now.add(const Duration(days: 3)),
        ownerId: 'user_current',
        inviteCode: 'DEL-001',
        defaultInviteRole: MemberRole.editor,
        members: const {'user_current': MemberRole.owner},
        createdAt: now,
        updatedAt: now,
      );
      await repo.createTrip(trip);
    });


    testWidgets('TripDashboardScreen renders Delete Trip icon button for owner and deletes trip upon confirmation',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(repo),
            userTripsProvider.overrideWith((ref) => Stream.value([trip])),
            activeTripProvider.overrideWithValue(trip),
            activeTripIdProvider.overrideWith(() => FakeActiveTripIdNotifier()),
          ],
          child: const MaterialApp(
            home: TripDashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find Delete Trip IconButton
      final deleteBtn = find.byTooltip('Delete Trip');
      expect(deleteBtn, findsOneWidget);

      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      // Confirm dialog appears
      expect(find.text('Delete Trip'), findsWidgets);
      expect(find.textContaining('Are you sure you want to delete'), findsOneWidget);

      // Tap Delete in dialog
      await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
      await tester.pumpAndSettle();

      // Verify trip was deleted from repository
      final remaining = await repo.getTripsForUser('user_current');
      expect(remaining.where((t) => t.id == 'deletable_trip_1'), isEmpty);
    });

    testWidgets('AppNavScaffold only displays quick-add FAB on Itinerary tab (index 0)', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(repo),
            activeTripProvider.overrideWithValue(trip),
            canEditActiveTripProvider.overrideWithValue(true),
            activeTripStaysProvider.overrideWith((ref) => Stream.value([])),
            activeTripFlightsProvider.overrideWith((ref) => Stream.value([])),
            activeTripActivitiesProvider.overrideWith((ref) => Stream.value([])),
            userTripsProvider.overrideWith((ref) => Stream.value([trip])),
          ],
          child: const MaterialApp(
            home: AppNavScaffold(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tab 0: Day Planner tab - FAB should NOT be present (removed per Req 7)
      expect(find.byType(FloatingActionButton), findsNothing);

      // Switch to Itinerary - FAB should be present
      await tester.tap(find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.text('Itinerary'),
      ));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Add Booking or Activity'), findsOneWidget);

      // Switch to Flights - FAB should be hidden
      await tester.tap(find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.text('Flights'),
      ));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Add Booking or Activity'), findsNothing);

      // Switch to Stays - FAB should be hidden
      await tester.tap(find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.text('Stays'),
      ));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Add Booking or Activity'), findsNothing);

      // Switch to Activities - FAB should be hidden
      await tester.tap(find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.text('Activities'),
      ));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Add Booking or Activity'), findsNothing);

      // Switch back to Day Planner - FAB should be hidden
      await tester.tap(find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.text('Day Planner'),
      ));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Add Booking or Activity'), findsNothing);
    });
  });
}
