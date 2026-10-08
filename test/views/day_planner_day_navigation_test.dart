import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trippy/data/repositories/mock_trip_repository.dart';
import 'package:trippy/models/models.dart';
import 'package:trippy/state/trip_providers.dart';
import 'package:trippy/views/common/app_nav_scaffold.dart';
import 'package:trippy/views/day_planner/day_planner_view.dart';
import 'package:trippy/views/logistics/logistics_view.dart';

void main() {
  group('Day Planner Navigation After Calendar Visit (Regression Test for Bug #3)', () {
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
      ProviderContainer? container,
      Widget? child,
    }) {
      return UncontrolledProviderScope(
        container: container ??
            ProviderContainer(
              overrides: [
                tripRepositoryProvider.overrideWithValue(repo),
                activeTripProvider.overrideWithValue(thaiBundle.trip),
                activeTripStaysProvider.overrideWith((ref) => Stream.value(thaiBundle.stays)),
                activeTripFlightsProvider.overrideWith((ref) => Stream.value(thaiBundle.flights)),
                activeTripActivitiesProvider.overrideWith((ref) => Stream.value(thaiBundle.activities)),
                canEditActiveTripProvider.overrideWithValue(true),
              ],
            ),
        child: MaterialApp(
          home: Scaffold(
            body: child ?? const AppNavScaffold(),
          ),
        ),
      );
    }

    testWidgets('After visiting Calendar and setting focused date, Day Planner can navigate next, prev, and jump without reverting', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final container = ProviderContainer(
        overrides: [
          tripRepositoryProvider.overrideWithValue(repo),
          activeTripProvider.overrideWithValue(thaiBundle.trip),
          activeTripStaysProvider.overrideWith((ref) => Stream.value(thaiBundle.stays)),
          activeTripFlightsProvider.overrideWith((ref) => Stream.value(thaiBundle.flights)),
          activeTripActivitiesProvider.overrideWith((ref) => Stream.value(thaiBundle.activities)),
          canEditActiveTripProvider.overrideWithValue(true),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(createTestApp(container: container));
      await tester.pumpAndSettle();

      // Initially on Day Planner (tab 0), starts at Day 1
      expect(find.byType(DayPlannerView), findsOneWidget);
      expect(find.textContaining('Day 1 of 25'), findsWidgets);

      // 1. Simulate visiting the calendar or selecting a day (e.g. Day 3: Nov 3, 2026)
      final days = thaiBundle.trip.daysList;
      final targetDate = days[2]; // Day 3
      container.read(focusedTripDateProvider.notifier).setDate(targetDate);
      await tester.pumpAndSettle();

      // Verify Day Planner reconciled to Day 3
      expect(find.textContaining('Day 3 of 25'), findsWidgets);

      // 2. Click "Next Day" button (tooltip: 'Next Day')
      final nextDayButton = find.byTooltip('Next Day');
      expect(nextDayButton, findsOneWidget);
      await tester.tap(nextDayButton);
      await tester.pumpAndSettle();

      // Should now be on Day 4 and NOT reverted back to Day 3!
      expect(find.textContaining('Day 4 of 25'), findsWidgets);

      // 3. Click "Next Day" again -> Day 5
      await tester.tap(nextDayButton);
      await tester.pumpAndSettle();
      expect(find.textContaining('Day 5 of 25'), findsWidgets);

      // 4. Click "Previous Day" button (tooltip: 'Previous Day') -> back to Day 4
      final prevDayButton = find.byTooltip('Previous Day');
      expect(prevDayButton, findsOneWidget);
      await tester.tap(prevDayButton);
      await tester.pumpAndSettle();
      expect(find.textContaining('Day 4 of 25'), findsWidgets);

      // 5. Jump to a specific day via the PopupMenuButton
      final jumpDropdown = find.byTooltip('Jump to specific day');
      expect(jumpDropdown, findsOneWidget);
      await tester.tap(jumpDropdown);
      await tester.pumpAndSettle();

      // Select Day 10 in the menu
      final day10Item = find.text('Day 10').last;
      await tester.tap(day10Item);
      await tester.pumpAndSettle();

      // Should now be on Day 10
      expect(find.textContaining('Day 10 of 25'), findsWidgets);

      // 6. Navigate next from Day 10 -> Day 11
      await tester.tap(nextDayButton);
      await tester.pumpAndSettle();
      expect(find.textContaining('Day 11 of 25'), findsWidgets);
    });

    testWidgets('Full View day navigator works consistently with Day Planner', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final container = ProviderContainer(
        overrides: [
          tripRepositoryProvider.overrideWithValue(repo),
          activeTripProvider.overrideWithValue(thaiBundle.trip),
          activeTripStaysProvider.overrideWith((ref) => Stream.value(thaiBundle.stays)),
          activeTripFlightsProvider.overrideWith((ref) => Stream.value(thaiBundle.flights)),
          activeTripActivitiesProvider.overrideWith((ref) => Stream.value(thaiBundle.activities)),
          canEditActiveTripProvider.overrideWithValue(true),
        ],
      );
      addTearDown(container.dispose);

      // Set to Itinerary tab (index 1)
      container.read(navTabIndexProvider.notifier).setTab(1);

      await tester.pumpWidget(createTestApp(container: container));
      await tester.pumpAndSettle();

      expect(find.byType(LogisticsView), findsOneWidget);

      // Verify the day navigator exists in Full View
      expect(find.byTooltip('Previous Day'), findsOneWidget);
      expect(find.byTooltip('Next Day'), findsOneWidget);
      expect(find.byTooltip('Jump to specific day'), findsOneWidget);
      expect(find.textContaining('Day 1 of 25'), findsWidgets);

      // Tap Next Day in Full View
      await tester.tap(find.byTooltip('Next Day'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Day 2 of 25'), findsWidgets);
    });
  });
}
