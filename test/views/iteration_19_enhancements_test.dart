import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trippy/models/models.dart';
import 'package:trippy/state/trip_providers.dart';
import 'package:trippy/views/attractions/attractions_view.dart';
import 'package:trippy/views/common/add_activity_sheet.dart';
import 'package:trippy/views/common/add_flight_sheet.dart';
import 'package:trippy/views/common/add_stay_sheet.dart';
import 'package:trippy/views/day_planner/day_planner_view.dart';
import 'package:trippy/views/flights/flights_view.dart';
import 'package:trippy/views/logistics/widgets/map_itinerary_view.dart';
import 'package:trippy/views/stays/stays_view.dart';

void main() {
  group('Iteration #19 Enhancements Tests', () {
    late TripBundle thaiBundle;

    setUp(() {
      final file = File('thailandia_2026_trip.json');
      final jsonString = file.readAsStringSync();
      thaiBundle = TripBundle.fromJson(jsonString);
    });

    Widget createProviderScope({
      required Widget child,
      Trip? trip,
      List<Stay>? stays,
      List<Flight>? flights,
      List<Activity>? activities,
      bool canEdit = true,
    }) {
      final t = trip ?? thaiBundle.trip;
      final s = stays ?? thaiBundle.stays;
      final f = flights ?? thaiBundle.flights;
      final a = activities ?? thaiBundle.activities;

      return ProviderScope(
        overrides: [
          activeTripProvider.overrideWithValue(t),
          activeTripStaysProvider.overrideWith((ref) => Stream.value(s)),
          activeTripFlightsProvider.overrideWith((ref) => Stream.value(f)),
          activeTripActivitiesProvider.overrideWith((ref) => Stream.value(a)),
          canEditActiveTripProvider.overrideWithValue(canEdit),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: child,
          ),
        ),
      );
    }

    testWidgets('MapItineraryView renders clean pins, city names and floating stats dialog',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final Map<DateTime, List<Activity>> activitiesByDay = {};
      for (final a in thaiBundle.activities) {
        final d = DateTime(a.date.year, a.date.month, a.date.day);
        activitiesByDay.putIfAbsent(d, () => []).add(a);
      }

      await tester.pumpWidget(
        createProviderScope(
          child: MapItineraryView(
            trip: thaiBundle.trip,
            stays: thaiBundle.stays,
            flights: thaiBundle.flights,
            activitiesByDay: activitiesByDay,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify stats button exists
      final statsBtn = find.byKey(const ValueKey('map_itinerary_stats_button'));
      expect(statsBtn, findsOneWidget);

      // Verify city nodes and pins render
      expect(find.text('Bangkok'), findsWidgets);

      // Tap stats button
      await tester.tap(statsBtn);
      await tester.pumpAndSettle();

      // Verify stats dialog opens with correct summary metrics
      expect(find.text('Trip Itinerary Stats'), findsOneWidget);
      expect(find.text('Flights'), findsOneWidget);
      expect(find.text('Flight Travel Time'), findsOneWidget);
      expect(find.text('Destinations'), findsOneWidget);
      expect(find.text('Stays'), findsOneWidget);
      expect(find.text('Total Days'), findsOneWidget);
      expect(find.text('Activities'), findsOneWidget);

      // Verify close button dismisses dialog
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Trip Itinerary Stats'), findsNothing);
    });

    testWidgets('DayPlannerView mobile layout renders FAB and omits full-row button',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createProviderScope(
          child: const DayPlannerView(),
        ),
      );
      await tester.pumpAndSettle();

      // In mobile mode, floating add activity FAB should exist
      expect(find.byKey(const ValueKey('day_planner_add_activity_fab')), findsOneWidget);

      // Full-row button should NOT exist
      expect(find.text('Add Activity for this Day'), findsNothing);
    });

    testWidgets('DayPlannerView desktop layout renders full-row button and omits mobile FAB',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createProviderScope(
          child: const DayPlannerView(),
        ),
      );
      await tester.pumpAndSettle();

      // In desktop mode, full-row button should exist
      expect(find.text('Add Activity for this Day'), findsOneWidget);

      // Mobile FAB should NOT exist
      expect(find.byKey(const ValueKey('day_planner_add_activity_fab')), findsNothing);
    });

    testWidgets('DayPlannerView double tap on timeline opens AddActivitySheet with prefilled hour',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createProviderScope(
          child: const DayPlannerView(),
          activities: const [],
          flights: const [],
          stays: const [],
        ),
      );
      await tester.pumpAndSettle();

      final timelineDetector = find.byKey(const ValueKey('timeline_double_tap_detector'));
      expect(timelineDetector, findsWidgets);

      await tester.tap(timelineDetector.first);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(timelineDetector.first);
      await tester.pumpAndSettle();

      // Verify AddActivitySheet opened
      expect(find.byType(AddActivitySheet), findsOneWidget);
    });

    testWidgets('FlightsView FAB is icon-only on mobile (<600) and extended on wide screens',
        (WidgetTester tester) async {
      // Mobile screen (<600)
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createProviderScope(
          child: const FlightsView(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.text('Add Flight'), findsNothing);

      // Desktop screen (>=600)
      tester.view.physicalSize = const Size(800, 800);
      await tester.pumpWidget(
        createProviderScope(
          child: const FlightsView(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add Flight'), findsOneWidget);
    });

    testWidgets('StaysView FAB is icon-only on mobile (<600) and extended on wide screens',
        (WidgetTester tester) async {
      // Mobile screen (<600)
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createProviderScope(
          child: const StaysView(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.text('Add Stay'), findsNothing);

      // Desktop screen (>=600)
      tester.view.physicalSize = const Size(800, 800);
      await tester.pumpWidget(
        createProviderScope(
          child: const StaysView(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add Stay'), findsOneWidget);
    });

    testWidgets('AttractionsView FAB is icon-only on mobile (<600) and extended on wide screens',
        (WidgetTester tester) async {
      // Mobile screen (<600)
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createProviderScope(
          child: const AttractionsView(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.text('Add Activity'), findsNothing);

      // Desktop screen (>=600)
      tester.view.physicalSize = const Size(800, 800);
      await tester.pumpWidget(
        createProviderScope(
          child: const AttractionsView(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add Activity'), findsOneWidget);
    });

    testWidgets('AddActivitySheet shows validation error if title is empty',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createProviderScope(
          child: const AddActivitySheet(),
        ),
      );
      await tester.pumpAndSettle();

      final saveActivityBtn = find.text('Add to Day');
      expect(saveActivityBtn, findsOneWidget);
      await tester.ensureVisible(saveActivityBtn);
      await tester.pumpAndSettle();
      await tester.tap(saveActivityBtn);
      await tester.pumpAndSettle();
      expect(find.text('Please enter an activity title.'), findsOneWidget);
    });

    testWidgets('AddFlightSheet shows validation error if airline is empty',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createProviderScope(
          child: const AddFlightSheet(),
        ),
      );
      await tester.pumpAndSettle();

      final saveFlightBtn = find.text('Add Flight');
      expect(saveFlightBtn, findsOneWidget);
      await tester.ensureVisible(saveFlightBtn);
      await tester.pumpAndSettle();
      await tester.tap(saveFlightBtn);
      await tester.pumpAndSettle();
      expect(find.text('Please enter an airline name.'), findsOneWidget);
    });

    testWidgets('AddStaySheet shows validation error if lodging name is empty',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createProviderScope(
          child: const AddStaySheet(),
        ),
      );
      await tester.pumpAndSettle();

      final saveStayBtn = find.text('Add Stay Bridge');
      expect(saveStayBtn, findsOneWidget);
      await tester.ensureVisible(saveStayBtn);
      await tester.pumpAndSettle();
      await tester.tap(saveStayBtn);
      await tester.pumpAndSettle();
      expect(find.text('Please enter a stay name.'), findsOneWidget);
    });
  });
}
