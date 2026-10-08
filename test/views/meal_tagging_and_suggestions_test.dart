import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trippy/models/models.dart';
import 'package:trippy/state/trip_providers.dart';
import 'package:trippy/views/day_planner/day_planner_view.dart';
import 'package:trippy/views/logistics/logistics_view.dart';
import 'package:trippy/views/logistics/widgets/stay_header_bridge_widget.dart';

void main() {
  group('Meal Tagging & Day Planner Suggestions Tests', () {
    late Trip plannerTrip;
    late Stay hotelStay;

    setUp(() {
      final now = DateTime(2026, 6, 1);
      plannerTrip = Trip(
        id: 'meal_test_trip',
        title: 'Meal Test Trip',
        destination: 'Bangkok, Thailand',
        startDate: now,
        endDate: now.add(const Duration(days: 3)), // 4 days: June 1 - 4
        startLocation: 'Bangkok Suvarnabhumi (BKK)',
        endLocation: 'Bangkok Suvarnabhumi (BKK)',
        ownerId: 'user_test',
        inviteCode: 'MEAL-01',
        defaultInviteRole: MemberRole.editor,
        members: const {'user_test': MemberRole.owner},
        createdAt: now,
        updatedAt: now,
      );

      hotelStay = Stay(
        id: 'stay_hotel',
        tripId: plannerTrip.id,
        type: StayType.hotel,
        name: 'The Peninsula Bangkok',
        address: 'Charoen Nakhon Rd, Bangkok',
        checkInDate: DateTime(2026, 6, 1),
        checkOutDate: DateTime(2026, 6, 4),
      );
    });

    test('Activity serialization and deserialization with mealType', () {
      final activity = Activity(
        id: 'act_1',
        tripId: 'trip_1',
        date: DateTime(2026, 6, 1),
        startTime: '19:30',
        endTime: '21:00',
        title: 'Jay Fai Street Food',
        category: ActivityCategory.dining,
        mealType: 'dinner',
      );

      final map = activity.toMap();
      expect(map['mealType'], 'dinner');

      final restored = Activity.fromMap(map);
      expect(restored.mealType, 'dinner');

      // Legacy map without mealType
      final legacyMap = Map<String, dynamic>.from(map)..remove('mealType');
      final legacyRestored = Activity.fromMap(legacyMap);
      expect(legacyRestored.mealType, isNull);
    });

    testWidgets('Dinner dining activity does not falsely satisfy Breakfast suggestion',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Activity is Dining at 20:00 (Dinner time), NOT breakfast
      final dinnerActivity = Activity(
        id: 'act_dinner',
        tripId: plannerTrip.id,
        date: DateTime(2026, 6, 1),
        startTime: '20:00',
        endTime: '21:30',
        title: 'Street Food Tour',
        category: ActivityCategory.dining,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeTripProvider.overrideWithValue(plannerTrip),
            activeTripFlightsProvider.overrideWith((ref) => Stream.value([])),
            activeTripStaysProvider.overrideWith((ref) => Stream.value([hotelStay])),
            activeTripActivitiesProvider.overrideWith((ref) => Stream.value([dinnerActivity])),
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

      // Previously, any dining activity caused hasBreakfast to be true.
      // Now, Missing Breakfast MUST be suggested!
      expect(find.text('Missing Breakfast'), findsOneWidget);
      // Missing Lunch should also be suggested
      expect(find.text('Missing Lunch'), findsOneWidget);
      // Dinner is satisfied (by 20:00 dining activity)
      expect(find.text('Missing Dinner'), findsNothing);
    });

    testWidgets('Activity tagged with mealType: breakfast satisfies Breakfast and leaves Dinner suggested',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final taggedBreakfast = Activity(
        id: 'act_breakfast',
        tripId: plannerTrip.id,
        date: DateTime(2026, 6, 1),
        startTime: '08:00',
        title: 'Morning Market Snacks',
        category: ActivityCategory.custom,
        mealType: 'breakfast',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeTripProvider.overrideWithValue(plannerTrip),
            activeTripFlightsProvider.overrideWith((ref) => Stream.value([])),
            activeTripStaysProvider.overrideWith((ref) => Stream.value([hotelStay])),
            activeTripActivitiesProvider.overrideWith((ref) => Stream.value([taggedBreakfast])),
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

      // Breakfast is fulfilled by tagged meal
      expect(find.text('Missing Breakfast'), findsNothing);
      // Lunch and Dinner are still missing
      expect(find.text('Missing Lunch'), findsOneWidget);
      expect(find.text('Missing Dinner'), findsOneWidget);

      // Verify the BREAKFAST tag badge appears in the timeline
      expect(find.text('BREAKFAST'), findsWidgets);
    });

    testWidgets('Activity tagged with mealType: dinner satisfies Dinner and leaves Breakfast suggested',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final taggedDinner = Activity(
        id: 'act_dinner',
        tripId: plannerTrip.id,
        date: DateTime(2026, 6, 1),
        startTime: '19:00',
        title: 'Riverside Feast',
        category: ActivityCategory.attraction,
        mealType: 'dinner',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeTripProvider.overrideWithValue(plannerTrip),
            activeTripFlightsProvider.overrideWith((ref) => Stream.value([])),
            activeTripStaysProvider.overrideWith((ref) => Stream.value([hotelStay])),
            activeTripActivitiesProvider.overrideWith((ref) => Stream.value([taggedDinner])),
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

      expect(find.text('Missing Breakfast'), findsOneWidget);
      expect(find.text('Missing Lunch'), findsOneWidget);
      expect(find.text('Missing Dinner'), findsNothing);
      expect(find.text('DINNER'), findsWidgets);
    });
  });

  group('Logistics View Overnight Flight Single-Row Track Allocation Tests', () {
    testWidgets('Overnight flight on Day 1 is placed in track 0 alongside subsequent hotel stay',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final now = DateTime(2026, 6, 1);
      final trip = Trip(
        id: 'flight_row_trip',
        title: 'Flight Row Test Trip',
        destination: 'Bangkok, Thailand',
        startDate: now,
        endDate: now.add(const Duration(days: 6)), // 7 days: June 1 - 7
        startLocation: 'San Francisco (SFO)',
        endLocation: 'San Francisco (SFO)',
        ownerId: 'user_test',
        inviteCode: 'ROW-01',
        defaultInviteRole: MemberRole.editor,
        members: const {'user_test': MemberRole.owner},
        createdAt: now,
        updatedAt: now,
      );

      // Overnight flight on Day 1: departs June 1 at 23:00, arrives June 2 at 06:00
      final overnightFlight = Flight(
        id: 'flt_overnight_d1',
        tripId: trip.id,
        airline: 'EVA Air',
        flightNumber: 'BR027',
        departureAirport: 'SFO',
        arrivalAirport: 'BKK',
        departureTime: DateTime(2026, 6, 1, 23, 0),
        arrivalTime: DateTime(2026, 6, 2, 6, 0),
        isOvernight: true,
      );

      // Hotel stay starts on Day 2: check-in June 2, check-out June 6
      final hotelStay = Stay(
        id: 'stay_hotel_d2',
        tripId: trip.id,
        type: StayType.hotel,
        name: 'The Peninsula Bangkok',
        address: 'Bangkok',
        checkInDate: DateTime(2026, 6, 2),
        checkOutDate: DateTime(2026, 6, 6),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeTripProvider.overrideWithValue(trip),
            activeTripFlightsProvider.overrideWith((ref) => Stream.value([overnightFlight])),
            activeTripStaysProvider.overrideWith((ref) => Stream.value([hotelStay])),
            activeTripActivitiesProvider.overrideWith((ref) => Stream.value([])),
            canEditActiveTripProvider.overrideWithValue(true),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: LogisticsView(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find StayHeaderBridgeWidget Positioned widgets
      final stayBridgeWidgets = find.byType(StayHeaderBridgeWidget);
      expect(stayBridgeWidgets, findsWidgets);

      // Find Positioned parent widgets of the StayHeaderBridgeWidgets
      final flightBridgeFinder = find.ancestor(
        of: find.textContaining('EVA Air BR027'),
        matching: find.byType(Positioned),
      );
      expect(flightBridgeFinder, findsOneWidget);

      final hotelBridgeFinder = find.ancestor(
        of: find.textContaining('The Peninsula Bangkok'),
        matching: find.byType(Positioned),
      );
      expect(hotelBridgeFinder, findsOneWidget);

      final Positioned flightPositioned = tester.widget(flightBridgeFinder);
      final Positioned hotelPositioned = tester.widget(hotelBridgeFinder);

      // Both the overnight flight and the hotel stay must have top: 0 (trackIndex 0, main row)
      expect(flightPositioned.top, 0.0,
          reason: 'Overnight flight must be rendered in the main/first row (top: 0)');
      expect(hotelPositioned.top, 0.0,
          reason: 'Hotel stay must also be in the main/first row (top: 0)');
    });
  });
}
