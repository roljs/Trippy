import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trippy/models/models.dart';
import 'package:trippy/state/trip_providers.dart';
import 'package:trippy/views/day_planner/day_planner_view.dart';

void main() {
  group('Day Planner Suggestions & Overlap Management Tests', () {
    late Trip plannerTrip;
    late Stay hotelStay;

    setUp(() {
      final now = DateTime(2026, 6, 1);
      plannerTrip = Trip(
        id: 'overlap_test_trip',
        title: 'Overlap Test Trip',
        destination: 'Bangkok, Thailand',
        startDate: now,
        endDate: now.add(const Duration(days: 3)), // 4 days: June 1 - 4
        startLocation: 'Bangkok Suvarnabhumi (BKK)',
        endLocation: 'Bangkok Suvarnabhumi (BKK)',
        ownerId: 'user_test',
        inviteCode: 'OVERLAP-01',
        defaultInviteRole: MemberRole.editor,
        members: const {'user_test': MemberRole.owner},
        createdAt: now,
        updatedAt: now,
      );

      hotelStay = Stay(
        id: 'stay_peninsula',
        tripId: plannerTrip.id,
        type: StayType.hotel,
        name: 'The Peninsula Bangkok',
        address: 'Charoen Nakhon Rd, Bangkok',
        checkInDate: DateTime(2026, 6, 1),
        checkOutDate: DateTime(2026, 6, 4),
      );
    });

    testWidgets('Desktop view: suggestions panel shows on the side and Day header displays Start and End activity times',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final act1 = Activity(
        id: 'act_1',
        tripId: plannerTrip.id,
        date: DateTime(2026, 6, 1),
        startTime: '09:00',
        endTime: '10:30',
        title: 'Morning Temple Tour',
        category: ActivityCategory.attraction,
      );

      final act2 = Activity(
        id: 'act_2',
        tripId: plannerTrip.id,
        date: DateTime(2026, 6, 1),
        startTime: '19:30',
        endTime: '21:00',
        title: 'Rooftop Dinner',
        category: ActivityCategory.dining,
        mealType: 'dinner',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeTripProvider.overrideWithValue(plannerTrip),
            activeTripFlightsProvider.overrideWith((ref) => Stream.value([])),
            activeTripStaysProvider.overrideWith((ref) => Stream.value([hotelStay])),
            activeTripActivitiesProvider.overrideWith((ref) => Stream.value([act1, act2])),
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

      // Suggestions pane is visible on the side
      expect(find.byKey(const ValueKey('suggestions_pane')), findsOneWidget);
      expect(find.text('SUGGESTIONS FOR TODAY'), findsOneWidget);

      // Day header shows start time of first activity (9:00 AM) and end time of last activity (9:00 PM) as Start and End
      expect(find.textContaining('Start: 9:00 AM • End: 9:00 PM'), findsOneWidget);
    });

    testWidgets('Header shows "No activities scheduled" when day has no activities',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeTripProvider.overrideWithValue(plannerTrip),
            activeTripFlightsProvider.overrideWith((ref) => Stream.value([])),
            activeTripStaysProvider.overrideWith((ref) => Stream.value([hotelStay])),
            activeTripActivitiesProvider.overrideWith((ref) => Stream.value([])),
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

      expect(find.textContaining('No activities scheduled'), findsOneWidget);
    });

    testWidgets('Desktop view: can hide suggestions panel into floating bulb icon and restore it',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeTripProvider.overrideWithValue(plannerTrip),
            activeTripFlightsProvider.overrideWith((ref) => Stream.value([])),
            activeTripStaysProvider.overrideWith((ref) => Stream.value([hotelStay])),
            activeTripActivitiesProvider.overrideWith((ref) => Stream.value([])),
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

      // Suggestions pane is visible
      expect(find.byKey(const ValueKey('suggestions_pane')), findsOneWidget);
      expect(find.byKey(const ValueKey('floating_suggestions_bulb')), findsNothing);

      // Click the close button on the suggestions header
      final closeBtn = find.byTooltip('Hide suggestions');
      expect(closeBtn, findsOneWidget);
      await tester.tap(closeBtn);
      await tester.pumpAndSettle();

      // Suggestions pane is now hidden, floating bulb is shown
      expect(find.byKey(const ValueKey('suggestions_pane')), findsNothing);
      expect(find.byKey(const ValueKey('floating_suggestions_bulb')), findsOneWidget);

      // Click the floating bulb to restore suggestions panel to the side
      await tester.tap(find.byKey(const ValueKey('floating_suggestions_bulb')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('suggestions_pane')), findsOneWidget);
    });

    testWidgets('Mobile view: day view occupies entire screen, bulb icon floats, opens suggestions sheet on tap',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeTripProvider.overrideWithValue(plannerTrip),
            activeTripFlightsProvider.overrideWith((ref) => Stream.value([])),
            activeTripStaysProvider.overrideWith((ref) => Stream.value([hotelStay])),
            activeTripActivitiesProvider.overrideWith((ref) => Stream.value([])),
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

      // Suggestions pane is NOT on screen initially
      expect(find.byKey(const ValueKey('suggestions_pane')), findsNothing);

      // Day view is full screen and floating bulb icon is displayed
      final bulbFinder = find.byKey(const ValueKey('floating_suggestions_bulb'));
      expect(bulbFinder, findsOneWidget);

      // Tap the floating bulb icon
      await tester.tap(bulbFinder);
      await tester.pumpAndSettle();

      // Suggestions pane is now shown on top in the modal bottom sheet
      expect(find.byKey(const ValueKey('suggestions_pane')), findsOneWidget);
      expect(find.text('SUGGESTIONS FOR TODAY'), findsOneWidget);
    });

    testWidgets('Overlap detection lists conflicting activities and allows individual selection',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Two overlapping activities:
      // Act 1: 10:00 - 11:30
      // Act 2: 11:00 - 12:30
      final act1 = Activity(
        id: 'overlap_act_1',
        tripId: plannerTrip.id,
        date: DateTime(2026, 6, 1),
        startTime: '10:00',
        endTime: '11:30',
        title: 'Grand Palace Tour',
        category: ActivityCategory.attraction,
      );

      final act2 = Activity(
        id: 'overlap_act_2',
        tripId: plannerTrip.id,
        date: DateTime(2026, 6, 1),
        startTime: '11:00',
        endTime: '12:30',
        title: 'River Cruise',
        category: ActivityCategory.attraction,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeTripProvider.overrideWithValue(plannerTrip),
            activeTripFlightsProvider.overrideWith((ref) => Stream.value([])),
            activeTripStaysProvider.overrideWith((ref) => Stream.value([hotelStay])),
            activeTripActivitiesProvider.overrideWith((ref) => Stream.value([act1, act2])),
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

      // Overlap group card must be rendered
      expect(find.byKey(const ValueKey('overlap_group_1')), findsOneWidget);
      expect(find.text('CONFLICT'), findsWidgets);
      expect(find.textContaining('Overlap Conflict • Group 1'), findsOneWidget);

      // Both activities are listed individually within the group
      expect(find.byKey(const ValueKey('overlap_activity_overlap_act_1')), findsOneWidget);
      expect(find.byKey(const ValueKey('overlap_activity_overlap_act_2')), findsOneWidget);
      expect(find.text('Grand Palace Tour'), findsWidgets);
      expect(find.text('River Cruise'), findsWidgets);

      // Clicking an activity opens the edit activity sheet
      await tester.tap(find.byKey(const ValueKey('overlap_activity_overlap_act_1')));
      await tester.pumpAndSettle();

      expect(find.text('Edit Activity'), findsOneWidget);
    });

    testWidgets('Consecutive activities touching at boundary (10:00-11:00 and 11:00-12:00) do NOT overlap',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final act1 = Activity(
        id: 'consec_1',
        tripId: plannerTrip.id,
        date: DateTime(2026, 6, 1),
        startTime: '10:00',
        endTime: '11:00',
        title: 'Museum Visit',
        category: ActivityCategory.attraction,
      );

      final act2 = Activity(
        id: 'consec_2',
        tripId: plannerTrip.id,
        date: DateTime(2026, 6, 1),
        startTime: '11:00',
        endTime: '12:00',
        title: 'Lunch Break',
        category: ActivityCategory.dining,
        mealType: 'lunch',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeTripProvider.overrideWithValue(plannerTrip),
            activeTripFlightsProvider.overrideWith((ref) => Stream.value([])),
            activeTripStaysProvider.overrideWith((ref) => Stream.value([hotelStay])),
            activeTripActivitiesProvider.overrideWith((ref) => Stream.value([act1, act2])),
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

      // No overlap conflict group should exist
      expect(find.byKey(const ValueKey('overlap_group_1')), findsNothing);
      expect(find.text('CONFLICT'), findsNothing);
    });
  });
}
