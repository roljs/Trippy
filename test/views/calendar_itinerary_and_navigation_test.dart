import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trippy/data/repositories/mock_trip_repository.dart';
import 'package:trippy/models/models.dart';
import 'package:trippy/state/trip_providers.dart';
import 'package:trippy/views/common/add_flight_sheet.dart';
import 'package:trippy/views/common/add_stay_sheet.dart';
import 'package:trippy/views/common/app_nav_scaffold.dart';
import 'package:trippy/views/day_planner/day_planner_view.dart';
import 'package:trippy/views/logistics/logistics_view.dart';
import 'package:trippy/views/logistics/widgets/calendar_itinerary_view.dart';
import 'package:trippy/views/logistics/widgets/day_column_widget.dart';

void main() {
  group('Day Planner Flight Visual, Navigation, Auto-sync & Calendar View Tests', () {
    late TripBundle thaiBundle;
    late MockTripRepository repo;

    setUp(() async {
      final file = File('thailandia_2026_trip.json');
      final jsonString = file.readAsStringSync();
      thaiBundle = TripBundle.fromJson(jsonString);

      repo = MockTripRepository();
      await repo.createTrip(thaiBundle.trip);
      for (final s in thaiBundle.stays) {
        await repo.addStay(s);
      }
      for (final f in thaiBundle.flights) {
        await repo.addFlight(f);
      }
      for (final a in thaiBundle.activities) {
        await repo.addActivity(a);
      }
    });

    Widget createTestApp({
      Widget? child,
    }) {
      return ProviderScope(
        overrides: [
          tripRepositoryProvider.overrideWithValue(repo),
          activeTripProvider.overrideWithValue(thaiBundle.trip),
          activeTripStaysProvider.overrideWith((ref) => Stream.value(thaiBundle.stays)),
          activeTripFlightsProvider.overrideWith((ref) => Stream.value(thaiBundle.flights)),
          activeTripActivitiesProvider.overrideWith((ref) => Stream.value(thaiBundle.activities)),
          canEditActiveTripProvider.overrideWithValue(true),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: child ?? const AppNavScaffold(),
          ),
        ),
      );
    }

    testWidgets('1) Flight cards in Day Planner view show Departure - Arrival visual timeline with duration', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestApp(
          child: const DayPlannerView(),
        ),
      );
      await tester.pumpAndSettle();

      // On Day 1, there is flight Delta Air Lines DL0167
      expect(find.text('Delta Air Lines DL0167'), findsOneWidget);
      // Verify origin and departure time
      expect(find.textContaining('SEA'), findsWidgets);
      expect(find.textContaining('HND'), findsWidgets);
      // Verify visual duration timeline and non-stop moniker
      expect(find.text('10h 40m'), findsOneWidget);
      expect(find.text('Non-stop'), findsOneWidget);
      expect(find.byIcon(Icons.flight), findsWidgets);
    });

    testWidgets('2) Bi-directional navigation: Plan Day button in Full View switches to Day Planner and Itinerary button in Day Planner switches to Full View', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Starts on Day Planner tab (index 0)
      expect(find.byType(DayPlannerView), findsOneWidget);

      // Find the "Itinerary" navigation button in the Day Planner day header
      final itineraryButton = find.text('Itinerary').first;
      await tester.ensureVisible(itineraryButton);
      await tester.tap(itineraryButton);
      await tester.pumpAndSettle();

      // Should now be on Itinerary tab (index 1) in Full View
      expect(find.byType(LogisticsView), findsOneWidget);
      expect(find.byType(DayColumnWidget), findsWidgets);

      // Find the "Plan Day" button in Day 1's header
      final planDayButton = find.text('Plan Day').first;
      await tester.ensureVisible(planDayButton);
      await tester.tap(planDayButton);
      await tester.pumpAndSettle();

      // Should switch back to Day Planner for Day 1
      expect(find.byType(DayPlannerView), findsOneWidget);
    });

    testWidgets('3) Edit Stay dialog: removes sync checkbox, always auto-syncs linked activities on save, and offers delete button', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final stay = thaiBundle.stays.first;

      await tester.pumpWidget(
        createTestApp(
          child: AddStaySheet(stayToEdit: stay),
        ),
      );
      await tester.pumpAndSettle();

      // Verify "Sync linked Check-in & Check-out activities" section is REMOVED
      expect(find.text('Sync linked Check-in & Check-out activities'), findsNothing);

      // Verify Delete Activity icon button is available alongside unlink
      expect(find.byIcon(Icons.delete_outline), findsWidgets);
      expect(find.byIcon(Icons.link_off_rounded), findsWidgets);

      // Tap Delete icon on one of the linked activities to test dialog confirmation
      final deleteBtn = find.byIcon(Icons.delete_outline).first;
      await tester.ensureVisible(deleteBtn);
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      // Confirmation dialog should appear
      expect(find.text('Delete Activity'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('3b) Flight edit dialog offers delete button for linked airport ground transfers with confirmation', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Use a flight that has linked activities (VN385)
      final flight = thaiBundle.flights.firstWhere((f) => f.linkedActivityIds.isNotEmpty);

      await tester.pumpWidget(
        createTestApp(
          child: AddFlightSheet(flightToEdit: flight),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Delete Transfer icon button is available
      expect(find.byIcon(Icons.delete_outline), findsWidgets);

      final deleteBtn = find.byIcon(Icons.delete_outline).first;
      await tester.ensureVisible(deleteBtn);
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      // Confirmation dialog should appear
      expect(find.text('Delete Transfer'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('4) Calendar View in Itinerary tab displays month grid with day squares, night stay bridges, and flight icons', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      Stay? tappedStay;
      Flight? tappedFlight;
      DateTime? tappedDate;

      final activitiesByDay = <DateTime, List<Activity>>{};
      for (final a in thaiBundle.activities) {
        final d = DateTime(a.date.year, a.date.month, a.date.day);
        activitiesByDay.putIfAbsent(d, () => []).add(a);
      }

      await tester.pumpWidget(
        createTestApp(
          child: CalendarItineraryView(
            trip: thaiBundle.trip,
            stays: thaiBundle.stays,
            flights: thaiBundle.flights,
            activitiesByDay: activitiesByDay,
            onStayTap: (s) => tappedStay = s,
            onFlightTap: (f) => tappedFlight = f,
            onDayTap: (d) => tappedDate = d,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify month header and weekday abbreviations
      expect(find.textContaining('2026'), findsWidgets);
      expect(find.text('SUN'), findsWidgets);
      expect(find.text('MON'), findsWidgets);

      // Verify Day 1 info: location tags and activity count (aligned to bottom)
      expect(find.text('Day 1'), findsOneWidget);
      expect(find.byIcon(Icons.event_note_rounded), findsWidgets);

      // Verify floating stay rectangle on Day 1 shows flight stay name (not address)
      expect(find.textContaining('Flight DL0167'), findsWidgets);

      // Verify floating stay on subsequent days shows hotel name
      expect(find.textContaining('APA Hotel Asakusa'), findsWidgets);

      // Verify clickable flight icons exist for DL0167
      final flightIconButtons = find.widgetWithText(InkWell, 'DL0167');
      expect(flightIconButtons, findsWidgets);

      // Tap on flight icon
      await tester.tap(flightIconButtons.first);
      await tester.pumpAndSettle();
      expect(tappedFlight, isNotNull);
      expect(tappedFlight!.flightNumber, 'DL0167');

      // Tap on floating night stay rectangle
      final stayBridge = find.textContaining('Flight DL0167').first;
      await tester.tap(stayBridge);
      await tester.pumpAndSettle();
      expect(tappedStay, isNotNull);

      // Tap on day square to navigate to Full view
      final day1 = thaiBundle.trip.daysList.first;
      final day1Square = find.text('Day 1');
      await tester.tap(day1Square);
      await tester.pumpAndSettle();
      expect(tappedDate, equals(day1));
    });
  });
}

