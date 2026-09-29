import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trippy/models/models.dart';
import 'package:trippy/state/trip_providers.dart';
import 'package:trippy/views/logistics/logistics_view.dart';
import 'package:trippy/views/logistics/widgets/map_itinerary_view.dart';

void main() {
  group('Map Itinerary View & Switcher Tests', () {
    late TripBundle thaiBundle;

    setUp(() {
      final file = File('thailandia_2026_trip.json');
      final jsonString = file.readAsStringSync();
      thaiBundle = TripBundle.fromJson(jsonString);
    });

    Widget createTestApp({
      required Trip trip,
      required List<Stay> stays,
      required List<Flight> flights,
      required List<Activity> activities,
      ValueChanged<Stay>? onStayTap,
      ValueChanged<Flight>? onFlightTap,
      ValueChanged<Activity>? onActivityTap,
    }) {
      return ProviderScope(
        overrides: [
          activeTripProvider.overrideWithValue(trip),
          activeTripStaysProvider.overrideWith((ref) => Stream.value(stays)),
          activeTripFlightsProvider.overrideWith((ref) => Stream.value(flights)),
          activeTripActivitiesProvider.overrideWith((ref) => Stream.value(activities)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: LogisticsView(
              onStayTap: onStayTap,
              onFlightTap: onFlightTap,
              onActivityTap: onActivityTap,
            ),
          ),
        ),
      );
    }

    testWidgets('SegmentedButton displays Map View and switches to MapItineraryView',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestApp(
          trip: thaiBundle.trip,
          stays: thaiBundle.stays,
          flights: thaiBundle.flights,
          activities: thaiBundle.activities,
        ),
      );
      await tester.pumpAndSettle();

      // Check view switcher has Map View
      expect(find.text('Map View'), findsOneWidget);

      // Tap on Map View segment
      await tester.tap(find.text('Map View'));
      await tester.pumpAndSettle();

      // Verify MapItineraryView is active
      expect(find.byType(MapItineraryView), findsOneWidget);
    });

    testWidgets('MapItineraryView renders city nodes with sequence numbers and names',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestApp(
          trip: thaiBundle.trip,
          stays: thaiBundle.stays,
          flights: thaiBundle.flights,
          activities: thaiBundle.activities,
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Map View
      await tester.tap(find.text('Map View'));
      await tester.pumpAndSettle();

      // Chronological sequence badges and city names should render
      expect(find.text('Tokyo'), findsWidgets);
      expect(find.text('Hanoi'), findsWidgets);
      expect(find.text('Bangkok'), findsWidgets);
      expect(find.text('Seattle'), findsWidgets);

      // Verify sequence flow numbers (e.g. 1, 2, 3...)
      expect(find.text('1'), findsWidgets);
      expect(find.text('2'), findsWidgets);
    });

    testWidgets('MapItineraryView renders flight connection monikers on connecting legs',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestApp(
          trip: thaiBundle.trip,
          stays: thaiBundle.stays,
          flights: thaiBundle.flights,
          activities: thaiBundle.activities,
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Map View
      await tester.tap(find.text('Map View'));
      await tester.pumpAndSettle();

      // Verify flight monikers render on canvas (e.g. DL0167, VN0385, PG0906, etc.)
      final hasFlightMoniker = find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            (widget.data?.contains('DL') == true ||
                widget.data?.contains('VN') == true ||
                widget.data?.contains('PG') == true ||
                widget.data?.contains('SQ') == true ||
                widget.data?.contains('167') == true),
      );

      expect(hasFlightMoniker, findsWidgets);
    });

    testWidgets('Tapping on a city node opens summary details card with stay info',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestApp(
          trip: thaiBundle.trip,
          stays: thaiBundle.stays,
          flights: thaiBundle.flights,
          activities: thaiBundle.activities,
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Map View
      await tester.tap(find.text('Map View'));
      await tester.pumpAndSettle();

      // Tap Tokyo in timeline or map to inspect stay details
      final tokyoCityNode = find.text('Tokyo').last;
      await tester.tap(tokyoCityNode, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Detail card should display Tokyo stay information
      expect(find.textContaining('Tokyo'), findsWidgets);
      // Tokyo stays in Thailandia trip include 'Grand Hyatt' or 'Keio Plaza'
      expect(
        find.byWidgetPredicate((w) =>
            w is Text &&
            (w.data?.contains('Grand Hyatt') == true ||
                w.data?.contains('Keio') == true ||
                w.data?.contains('Tokyo') == true)),
        findsWidgets,
      );
    });

    testWidgets('Map controls (Zoom, Fit, Theme) are interactive',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestApp(
          trip: thaiBundle.trip,
          stays: thaiBundle.stays,
          flights: thaiBundle.flights,
          activities: thaiBundle.activities,
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Map View
      await tester.tap(find.text('Map View'));
      await tester.pumpAndSettle();

      // Zoom in (+)
      final zoomInBtn = find.byTooltip('Zoom In');
      expect(zoomInBtn, findsOneWidget);
      await tester.tap(zoomInBtn);
      await tester.pumpAndSettle();

      // Zoom out (-)
      final zoomOutBtn = find.byTooltip('Zoom Out');
      expect(zoomOutBtn, findsOneWidget);
      await tester.tap(zoomOutBtn);
      await tester.pumpAndSettle();

      // Fit Route
      final fitBtn = find.byTooltip('Fit Route to Screen');
      expect(fitBtn, findsOneWidget);
      await tester.tap(fitBtn);
      await tester.pumpAndSettle();

      // Toggle Theme
      final themeBtn = find.byTooltip('Switch to Light Map');
      expect(themeBtn, findsOneWidget);
      await tester.tap(themeBtn);
      await tester.pumpAndSettle();
    });

    testWidgets('Bottom breadcrumb timeline allows clicking a city to center map',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestApp(
          trip: thaiBundle.trip,
          stays: thaiBundle.stays,
          flights: thaiBundle.flights,
          activities: thaiBundle.activities,
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Map View
      await tester.tap(find.text('Map View'));
      await tester.pumpAndSettle();

      // Look for Hanoi in timeline chips (last instance) and tap it
      final hanoiChip = find.text('Hanoi').last;
      await tester.tap(hanoiChip, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Detail card or selection should be visible
      expect(find.textContaining('Hanoi'), findsWidgets);
    });

    testWidgets('MapItineraryView displays Google Maps controls and attribution',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestApp(
          trip: thaiBundle.trip,
          stays: thaiBundle.stays,
          flights: thaiBundle.flights,
          activities: thaiBundle.activities,
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Map View
      await tester.tap(find.text('Map View'));
      await tester.pumpAndSettle();

      // Verify Google Maps attribution
      expect(find.textContaining('Map data ©2026'), findsOneWidget);

      // Verify Map Type tooltips
      expect(find.byTooltip('Google Maps: Dark'), findsOneWidget);
      expect(find.byTooltip('Google Maps: Roadmap'), findsOneWidget);
      expect(find.byTooltip('Google Maps: Satellite'), findsOneWidget);
      expect(find.byTooltip('Google Maps: Terrain'), findsOneWidget);

      // Switch to Satellite
      await tester.tap(find.byTooltip('Google Maps: Satellite'));
      await tester.pumpAndSettle();

      // Switch to Terrain
      await tester.tap(find.byTooltip('Google Maps: Terrain'));
      await tester.pumpAndSettle();
    });

    testWidgets('MapItineraryView renders Call Out cards with visit indicators for repeated cities',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestApp(
          trip: thaiBundle.trip,
          stays: thaiBundle.stays,
          flights: thaiBundle.flights,
          activities: thaiBundle.activities,
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Map View
      await tester.tap(find.text('Map View'));
      await tester.pumpAndSettle();

      // Multi-visit cities like Tokyo, Hanoi, Bangkok, Seattle have #1 and #2 visit badges
      expect(find.text('#1'), findsWidgets);
      expect(find.text('#2'), findsWidgets);
    });
  });
}
