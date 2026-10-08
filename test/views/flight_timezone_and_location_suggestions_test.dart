import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trippy/data/repositories/mock_trip_repository.dart';
import 'package:trippy/models/models.dart';
import 'package:trippy/state/trip_providers.dart';
import 'package:trippy/views/common/add_flight_sheet.dart';
import 'package:trippy/views/day_planner/day_planner_view.dart';
import 'package:trippy/views/flights/flights_view.dart';

void main() {
  group('Flight Timezone, Duration Visual, and Location Coverage Tests', () {
    late MockTripRepository mockRepo;
    late Trip testTrip;
    late Flight seaToHndFlight;

    setUp(() async {
      mockRepo = MockTripRepository();
      final now = DateTime(2026, 11, 1);

      testTrip = Trip(
        id: 'trip_sea_hnd',
        title: 'Asia Tour 2026',
        destination: 'Tokyo, Japan',
        startDate: now,
        endDate: now.add(const Duration(days: 10)),
        startLocation: 'Seattle (SEA)',
        endLocation: 'Seattle (SEA)',
        ownerId: 'user_1',
        inviteCode: 'TRIP-ASIA',
        defaultInviteRole: MemberRole.editor,
        members: const {'user_1': MemberRole.owner},
        createdAt: now,
        updatedAt: now,
      );
      await mockRepo.createTrip(testTrip);

      // SEA (UTC-8) dep Nov 1 11:25 AM -> HND (UTC+9) arr Nov 2 3:05 PM
      seaToHndFlight = Flight(
        id: 'flt_sea_hnd',
        tripId: testTrip.id,
        airline: 'Delta Air Lines',
        flightNumber: 'DL0167',
        departureAirport: 'SEA (Seattle)',
        arrivalAirport: 'HND (Tokyo Haneda)',
        departureTime: DateTime(2026, 11, 1, 11, 25),
        arrivalTime: DateTime(2026, 11, 2, 15, 5),
        isOvernight: true,
      );
      await mockRepo.addFlight(seaToHndFlight);
    });

    test('1) Flight model duration calculates timezone-aware 10h 40m for SEA to HND', () {
      expect(seaToHndFlight.duration.inHours, 10);
      expect(seaToHndFlight.duration.inMinutes.remainder(60), 40);
      expect(seaToHndFlight.duration.inMinutes, 640);
    });

    testWidgets('1b) FlightsView displays timezone-aware duration "10h 40m" instead of 27h 40m',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeTripProvider.overrideWithValue(testTrip),
            activeTripFlightsProvider.overrideWith((ref) => Stream.value([seaToHndFlight])),
            tripRepositoryProvider.overrideWithValue(mockRepo),
            canEditActiveTripProvider.overrideWithValue(true),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: FlightsView(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('10h 40m'), findsOneWidget);
      expect(find.text('27h 40m'), findsNothing);
    });

    testWidgets('2) Flight edit dialog displays visual duration graphic between editable departure & arrival fields',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeTripProvider.overrideWithValue(testTrip),
            activeTripActivitiesProvider.overrideWith((ref) => Stream.value([])),
            tripRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: AddFlightSheet(flightToEdit: seaToHndFlight),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Editable departure and arrival fields exist
      expect(find.text('Departure'), findsOneWidget);
      expect(find.text('Arrival'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Nov 1 11:25 AM'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Nov 2 3:05 PM'), findsOneWidget);

      // Visual duration graphic between them displays 10h 40m with flight icon
      expect(find.text('10h 40m'), findsOneWidget);
      expect(find.byIcon(Icons.flight), findsWidgets);
    });

    testWidgets('3) Flight edit dialog removes duplicate checkbox panel, keeps Linked Airport Ground Transfers, and filters Link Transfer to transport only',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Add two activities: one transport and one attraction
      final transportAct = Activity(
        id: 'act_xfer_train',
        tripId: testTrip.id,
        date: DateTime(2026, 11, 2),
        startTime: '16:00',
        title: 'Tokyo Monorail to Hotel',
        category: ActivityCategory.transport,
      );
      final museumAct = Activity(
        id: 'act_museum',
        tripId: testTrip.id,
        date: DateTime(2026, 11, 2),
        startTime: '17:30',
        title: 'Mori Art Museum',
        category: ActivityCategory.attraction,
      );
      await mockRepo.addActivity(transportAct);
      await mockRepo.addActivity(museumAct);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeTripProvider.overrideWithValue(testTrip),
            activeTripActivitiesProvider.overrideWith((ref) => Stream.value([transportAct, museumAct])),
            tripRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: AddFlightSheet(flightToEdit: seaToHndFlight),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The duplicate checkbox panel at the bottom must NOT be shown when editing
      expect(find.widgetWithText(CheckboxListTile, 'Transfer: Hotel to SEA Airport'), findsNothing);

      // "Linked Airport Ground Transfers" section is present with "Link Transfer" button
      expect(find.textContaining('Linked Airport Ground Transfers'), findsOneWidget);
      final linkBtn = find.text('Link Transfer');
      expect(linkBtn, findsOneWidget);

      // Tap Link Transfer button
      await tester.tap(linkBtn);
      await tester.pumpAndSettle();

      // In the Link Transfer dialog:
      // Only the transport activity should be selectable, NOT the museum attraction
      expect(find.text('Tokyo Monorail to Hotel'), findsOneWidget);
      expect(find.text('Mori Art Museum'), findsNothing);
    });

    testWidgets('6) Day Planner suggests adding missing location when activity takes place in location not covered by Day locations',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Trip has Day 1 with custom locations only containing 'Tokyo'
      final day1Key = Trip.dateToKey(DateTime(2026, 11, 1));
      final tripWithLocations = testTrip.copyWith(
        dayLocations: {
          day1Key: ['Tokyo'],
        },
      );
      await mockRepo.updateTrip(tripWithLocations);

      // Activity 1: in Tokyo (covered)
      final tokyoAct = Activity(
        id: 'act_tokyo',
        tripId: testTrip.id,
        date: DateTime(2026, 11, 1),
        startTime: '10:00',
        endTime: '11:30',
        title: 'Asakusa Sensoji Temple',
        category: ActivityCategory.attraction,
        location: 'Asakusa, Tokyo',
      );

      // Activity 2: in Kamakura (NOT in Day locations!)
      final kamakuraAct = Activity(
        id: 'act_kamakura',
        tripId: testTrip.id,
        date: DateTime(2026, 11, 1),
        startTime: '14:00',
        endTime: '15:30',
        title: 'Kotoku-in Great Buddha',
        category: ActivityCategory.attraction,
        location: 'Kamakura Great Buddha, Kamakura',
      );

      await mockRepo.addActivity(tokyoAct);
      await mockRepo.addActivity(kamakuraAct);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeTripProvider.overrideWithValue(tripWithLocations),
            activeTripFlightsProvider.overrideWith((ref) => Stream.value([seaToHndFlight])),
            activeTripStaysProvider.overrideWith((ref) => Stream.value([])),
            activeTripActivitiesProvider.overrideWith((ref) => Stream.value([tokyoAct, kamakuraAct])),
            tripRepositoryProvider.overrideWithValue(mockRepo),
            canEditActiveTripProvider.overrideWithValue(true),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DayPlannerView(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Suggestions panel suggests adding missing location 'Kamakura'
      expect(find.text('Add missing location: Kamakura'), findsOneWidget);
      expect(find.text('+ Add "Kamakura"'), findsOneWidget);

      // Tap + Add "Kamakura" button
      await tester.tap(find.text('+ Add "Kamakura"'));
      await tester.pumpAndSettle();

      // Verify that Kamakura was added to Day 1 locations in repository
      final updatedTrip = await mockRepo.getTripById(testTrip.id);
      expect(updatedTrip!.dayLocations[day1Key], contains('Kamakura'));
    });
  });
}
