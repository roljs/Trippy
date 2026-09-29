import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trippy/models/models.dart';
import 'package:trippy/state/trip_providers.dart';
import 'package:trippy/views/common/add_activity_sheet.dart';
import 'package:trippy/views/day_planner/day_planner_view.dart';
import 'package:trippy/views/logistics/logistics_view.dart';
import 'package:trippy/views/logistics/widgets/flight_day_card_widget.dart';
import 'package:trippy/views/logistics/widgets/stay_header_bridge_widget.dart';
import 'package:trippy/views/logistics/widgets/trip_endcap_stay_bridge_widget.dart';

void main() {
  group('1. Itinerary Full View Redesign Tests', () {
    late Trip testTrip;
    late Flight sameDayFlight;
    late Flight overnightFlight;
    late Stay hotelStay;

    setUp(() {
      final now = DateTime(2026, 6, 1);
      testTrip = Trip(
        id: 'redesign_trip_1',
        title: 'Redesign Test Trip',
        destination: 'Tokyo, Japan',
        startDate: now,
        endDate: now.add(const Duration(days: 4)), // June 1 to June 5 (5 days)
        startLocation: 'San Francisco, CA (SFO)',
        endLocation: 'San Francisco, CA (SFO)',
        ownerId: 'user_test',
        inviteCode: 'TEST-01',
        defaultInviteRole: MemberRole.editor,
        members: const {'user_test': MemberRole.owner},
        createdAt: now,
        updatedAt: now,
      );

      // Same-day flight on Day 1
      sameDayFlight = Flight(
        id: 'flt_sameday',
        tripId: testTrip.id,
        airline: 'ANA',
        flightNumber: 'NH007',
        departureAirport: 'SFO',
        arrivalAirport: 'HND',
        departureTime: DateTime(2026, 6, 1, 11, 0),
        arrivalTime: DateTime(2026, 6, 1, 15, 30),
        isOvernight: false,
      );

      // Multi-day flight spanning Day 4 to Day 5
      overnightFlight = Flight(
        id: 'flt_overnight',
        tripId: testTrip.id,
        airline: 'JAL',
        flightNumber: 'JL002',
        departureAirport: 'HND',
        arrivalAirport: 'SFO',
        departureTime: DateTime(2026, 6, 4, 18, 0),
        arrivalTime: DateTime(2026, 6, 5, 11, 0),
        isOvernight: true,
      );

      hotelStay = Stay(
        id: 'stay_hotel',
        tripId: testTrip.id,
        type: StayType.hotel,
        name: 'Grand Hyatt Tokyo',
        address: 'Roppongi Hills, Tokyo',
        checkInDate: DateTime(2026, 6, 1),
        checkOutDate: DateTime(2026, 6, 4),
      );
    });

    testWidgets('1a: Same-day flights appear as cards inside day column, multi-day flights appear horizontally',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      Flight? clickedFlight;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeTripProvider.overrideWithValue(testTrip),
            activeTripFlightsProvider.overrideWith((ref) => Stream.value([sameDayFlight, overnightFlight])),
            activeTripStaysProvider.overrideWith((ref) => Stream.value([hotelStay])),
            activeTripActivitiesProvider.overrideWith((ref) => Stream.value([])),
            canEditActiveTripProvider.overrideWithValue(true),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: LogisticsView(
                onFlightTap: (f) => clickedFlight = f,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Same-day flight rendered as FlightDayCardWidget inside Day 1 column
      final sameDayCardFinder = find.descendant(
        of: find.byType(FlightDayCardWidget),
        matching: find.textContaining('NH007'),
      );
      expect(sameDayCardFinder, findsOneWidget);

      // Tapping same-day flight card triggers onFlightTap
      await tester.tap(sameDayCardFinder);
      await tester.pumpAndSettle();
      expect(clickedFlight, isNotNull);
      expect(clickedFlight!.flightNumber, 'NH007');

      // Overnight flight appears as horizontal StayHeaderBridgeWidget
      final overnightBridgeFinder = find.byWidgetPredicate(
        (w) => w is StayHeaderBridgeWidget && w.stay?.id == 'stay_flight_flt_overnight',
      );
      expect(overnightBridgeFinder, findsOneWidget);
    });

    testWidgets('1b: Distinctive Gray Start and Finish endcap stay bridge cards render at Day 1 and Last Day',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeTripProvider.overrideWithValue(testTrip),
            activeTripFlightsProvider.overrideWith((ref) => Stream.value([])),
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

      // Exactly 2 TripEndcapStayBridgeWidget endcaps: Start and Finish
      final endcapFinder = find.byType(TripEndcapStayBridgeWidget);
      expect(endcapFinder, findsNWidgets(2));

      // START endcap displays start location and START badge
      expect(find.text('START'), findsOneWidget);
      expect(find.text('San Francisco, CA (SFO)'), findsWidgets);

      // FINISH endcap displays finish location and FINISH badge
      expect(find.text('FINISH'), findsOneWidget);

      // Verify geometry: width is half column (145.0 dp)
      final endcaps = tester.widgetList<TripEndcapStayBridgeWidget>(endcapFinder).toList();
      expect(endcaps[0].type.isStart, isTrue);
      expect(endcaps[0].width, 145.0);
      expect(endcaps[1].type.isStart, isFalse);
      expect(endcaps[1].width, 145.0);
    });
  });

  group('2. Day Planner View Tests', () {
    late Trip plannerTrip;
    late Stay hotelStay;
    late Activity breakfastActivity;

    setUp(() {
      final now = DateTime(2026, 6, 1);
      plannerTrip = Trip(
        id: 'planner_trip_1',
        title: 'Day Planner Test Trip',
        destination: 'Rome, Italy',
        startDate: now,
        endDate: now.add(const Duration(days: 3)), // June 1 to June 4
        startLocation: 'Rome FCO Airport',
        endLocation: 'Rome FCO Airport',
        ownerId: 'user_planner',
        inviteCode: 'PLAN-01',
        defaultInviteRole: MemberRole.editor,
        members: const {'user_planner': MemberRole.owner},
        createdAt: now,
        updatedAt: now,
      );

      hotelStay = Stay(
        id: 'stay_hotel_rome',
        tripId: plannerTrip.id,
        type: StayType.hotel,
        name: 'Hotel Eden Rome',
        address: 'Via Ludovisi 49, Rome',
        checkInDate: DateTime(2026, 6, 1),
        checkOutDate: DateTime(2026, 6, 4),
      );

      breakfastActivity = Activity(
        id: 'act_breakfast',
        tripId: plannerTrip.id,
        date: DateTime(2026, 6, 1),
        startTime: '08:30',
        endTime: '09:30',
        title: 'Breakfast at Piazza Navona',
        category: ActivityCategory.dining,
        location: 'Piazza Navona',
      );
    });

    testWidgets('2a & 2b: Renders Wake-up sub-header, Sleep At footer, and meal suggestions',
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
            activeTripActivitiesProvider.overrideWith((ref) => Stream.value([breakfastActivity])),
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

      // Main Header: Day #, Date and Trip info
      expect(find.textContaining('Day 1 of 4'), findsOneWidget);
      expect(find.textContaining('DAY PLANNER'), findsOneWidget);

      // Sub-header: Wake-up Location
      expect(find.text('WAKE UP AT'), findsOneWidget);

      // Footer: Sleep At Location
      expect(find.text('SLEEP AT'), findsOneWidget);
      expect(find.textContaining('Hotel Eden Rome'), findsWidgets);

      // Suggestions Engine:
      // Breakfast was provided, so Lunch and Dinner should be suggested!
      expect(find.text('SUGGESTIONS FOR TODAY'), findsOneWidget);
      expect(find.text('Missing Lunch'), findsOneWidget);
      expect(find.text('Missing Dinner'), findsOneWidget);
      expect(find.text('Missing Breakfast'), findsNothing); // Breakfast is fulfilled!
    });

    testWidgets('2c: Clicking meal suggestion opens AddActivitySheet with prefilled title and time',
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
            activeTripActivitiesProvider.overrideWith((ref) => Stream.value([breakfastActivity])),
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

      // Tap on "Add Lunch (1:00 PM)" action
      final addLunchBtn = find.text('Add Lunch (1:00 PM)');
      expect(addLunchBtn, findsOneWidget);

      await tester.tap(addLunchBtn);
      await tester.pumpAndSettle();

      // Verify AddActivitySheet opened with Lunch prefilled
      expect(find.byType(AddActivitySheet), findsOneWidget);
      expect(find.text('Lunch'), findsWidgets);
    });

    testWidgets('2f & 2g: Day navigation controls allow next/previous day and jump picker',
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

      // Initial state: Day 1
      expect(find.textContaining('Day 1 of 4'), findsOneWidget);

      // Navigate to Next Day
      final nextDayBtn = find.byTooltip('Next Day');
      expect(nextDayBtn, findsOneWidget);

      await tester.tap(nextDayBtn);
      await tester.pumpAndSettle();

      // Now at Day 2
      expect(find.textContaining('Day 2 of 4'), findsOneWidget);

      // Navigate to Previous Day
      final prevDayBtn = find.byTooltip('Previous Day');
      await tester.tap(prevDayBtn);
      await tester.pumpAndSettle();

      // Back to Day 1
      expect(find.textContaining('Day 1 of 4'), findsOneWidget);
    });
  });

  group('3. JSON Backward Compatibility Tests', () {
    test('Trip serialization and deserialization with startLocation & endLocation', () {
      final trip = Trip(
        id: 'trip_compat_1',
        title: 'Compatibility Trip',
        destination: 'Kyoto, Japan',
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 10),
        startLocation: 'Tokyo Narita (NRT)',
        endLocation: 'Osaka Kansai (KIX)',
        ownerId: 'user_compat',
        inviteCode: 'CMP-01',
        defaultInviteRole: MemberRole.editor,
        members: const {'user_compat': MemberRole.owner},
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final map = trip.toMap();
      expect(map['startLocation'], 'Tokyo Narita (NRT)');
      expect(map['endLocation'], 'Osaka Kansai (KIX)');

      final restored = Trip.fromMap(map);
      expect(restored.startLocation, 'Tokyo Narita (NRT)');
      expect(restored.endLocation, 'Osaka Kansai (KIX)');
    });

    test('Trip deserialization from legacy JSON without startLocation or endLocation succeeds', () {
      final legacyMap = <String, dynamic>{
        'id': 'legacy_trip_id',
        'title': 'Legacy Trip 2025',
        'destination': 'Paris, France',
        'startDate': '2025-05-01T00:00:00.000',
        'endDate': '2025-05-10T00:00:00.000',
        'ownerId': 'user_legacy',
        'inviteCode': 'LEGACY-01',
        'defaultInviteRole': 'editor',
        'members': {'user_legacy': 'owner'},
        'createdAt': '2025-01-01T00:00:00.000',
        'updatedAt': '2025-01-01T00:00:00.000',
      };

      final restored = Trip.fromMap(legacyMap);
      expect(restored.title, 'Legacy Trip 2025');
      expect(restored.destination, 'Paris, France');
      expect(restored.startLocation, isNull);
      expect(restored.endLocation, isNull);
    });
  });
}
