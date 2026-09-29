import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trippy/models/models.dart';
import 'package:trippy/state/trip_providers.dart';
import 'package:trippy/views/logistics/logistics_view.dart';
import 'package:trippy/views/logistics/widgets/compact_itinerary_view.dart';
import 'package:trippy/views/logistics/widgets/day_column_widget.dart';

void main() {
  group('Compact Itinerary View & Switcher Tests', () {
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

    testWidgets('Renders SegmentedButton switcher and starts in Full View by default',
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

      // Check view switcher exists
      expect(find.byType(SegmentedButton<ItineraryViewMode>), findsOneWidget);
      expect(find.text('Full View'), findsOneWidget);
      expect(find.text('Compact View'), findsOneWidget);

      // Verify Full View widgets are present by default
      expect(find.byType(DayColumnWidget), findsWidgets);
      expect(find.byType(CompactItineraryView), findsNothing);
    });

    testWidgets('Tapping Compact View switches to vertical tabular summary with 25 rows',
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

      // Tap on Compact View
      await tester.tap(find.text('Compact View'));
      await tester.pumpAndSettle();

      // Verify CompactItineraryView is now active and Full View widgets are gone
      expect(find.byType(CompactItineraryView), findsOneWidget);
      expect(find.byType(DayColumnWidget), findsNothing);

      // Verify Table Column Headers
      expect(find.text('Date'), findsOneWidget);
      expect(find.text('Day of the Week'), findsOneWidget);
      expect(find.text('Places to Visit'), findsOneWidget);
      expect(find.text('Sleep At'), findsOneWidget);
      expect(find.text('Notes'), findsOneWidget);

      // Verify specific data rows
      expect(find.text('1-Nov'), findsOneWidget);
      expect(find.text('Sunday'), findsWidgets);
      expect(find.text('Fly'), findsOneWidget);
      expect(find.text('Flight'), findsWidgets);

      expect(find.text('2-Nov'), findsOneWidget);
      expect(find.text('Monday'), findsWidgets);
      expect(find.text('Flight, Tokyo'), findsOneWidget);
      expect(find.text('Tokyo'), findsWidgets);

      expect(find.text('3-Nov'), findsOneWidget);
      expect(find.text('Tuesday'), findsWidgets);
      expect(find.text('Tokyo, Nikko'), findsOneWidget);
      expect(find.text('Nikko'), findsWidgets);

      expect(find.text('7-Nov'), findsOneWidget);
      expect(find.text('Saturday'), findsWidgets);
      expect(find.text('Halong Bay Cruise'), findsWidgets);

      expect(find.text('14-Nov'), findsOneWidget);
      expect(find.text('Siem Reap, Bangkok'), findsOneWidget);
      expect(find.text('Bangkok'), findsWidgets);

      expect(find.text('19-Nov'), findsOneWidget);
      expect(find.text('Bangkok, Singapore'), findsOneWidget);
      expect(find.text('Singapore'), findsWidgets);

      expect(find.text('21-Nov'), findsOneWidget);
      expect(find.text('Singapore, Seoul'), findsOneWidget);
      expect(find.text('Seoul'), findsWidgets);

      expect(find.text('25-Nov'), findsOneWidget);
      expect(find.text('Wednesday'), findsWidgets);
      expect(find.text('Seoul, Flight, Seattle'), findsOneWidget);
      expect(find.text('Seattle'), findsOneWidget);
    });

    testWidgets('Tapping Full View switches back to horizontal DayColumn board',
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

      // Switch to Compact View
      await tester.tap(find.text('Compact View'));
      await tester.pumpAndSettle();
      expect(find.byType(CompactItineraryView), findsOneWidget);

      // Switch back to Full View
      await tester.tap(find.text('Full View'));
      await tester.pumpAndSettle();

      expect(find.byType(CompactItineraryView), findsNothing);
      expect(find.byType(DayColumnWidget), findsWidgets);
    });

    testWidgets('Tapping on a Stay in Compact View triggers onStayTap callback',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      Stay? tappedStay;

      await tester.pumpWidget(
        createTestApp(
          trip: thaiBundle.trip,
          stays: thaiBundle.stays,
          flights: thaiBundle.flights,
          activities: thaiBundle.activities,
          onStayTap: (s) => tappedStay = s,
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Compact View
      await tester.tap(find.text('Compact View'));
      await tester.pumpAndSettle();

      // Tap on a Tokyo sleep at cell (e.g. day 2 hotel)
      final tokyoStayCell = find.text('Tokyo').first;
      await tester.tap(tokyoStayCell);
      await tester.pumpAndSettle();

      expect(tappedStay, isNotNull);
      expect(tappedStay!.name, 'APA Hotel Asakusa Tawaramachi Ekimae');
    });
  });
}
