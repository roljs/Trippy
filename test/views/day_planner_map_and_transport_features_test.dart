import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trippy/core/utils/trip_map_helper.dart';
import 'package:trippy/data/samples/thailandia_sample_trip.dart';
import 'package:trippy/models/models.dart';
import 'package:trippy/state/trip_providers.dart';
import 'package:trippy/views/common/add_activity_sheet.dart';
import 'package:trippy/views/common/add_flight_sheet.dart';
import 'package:trippy/views/day_planner/day_planner_view.dart';
import 'package:trippy/views/day_planner/widgets/day_planner_map_panel.dart';

void main() {
  group('Req 1: Edit Flight Dialog Duration Graphic Visual Centering', () {
    testWidgets('Duration line and icon are centered between Departure and Arrival date pickers',
        (WidgetTester tester) async {
      final flight = Flight(
        id: 'flight_test_1',
        tripId: 'trip_1',
        airline: 'Thai Airways',
        flightNumber: 'TG600',
        departureAirport: 'BKK',
        arrivalAirport: 'HND',
        departureTime: DateTime(2026, 6, 1, 8, 0),
        arrivalTime: DateTime(2026, 6, 1, 16, 30),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: AddFlightSheet(flightToEdit: flight),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find departure and arrival airport text fields
      expect(find.widgetWithText(TextField, 'TG600'), findsOneWidget);

      // Verify duration line/airplane graphic exists
      expect(find.byIcon(Icons.flight), findsWidgets);
      expect(find.text('6h 30m'), findsOneWidget);

      // Verify layout geometry: the duration column is centered between departure and arrival
      final depFinder = find.text('Departure');
      final arrFinder = find.text('Arrival');
      final durFinder = find.text('6h 30m');

      expect(depFinder, findsOneWidget);
      expect(arrFinder, findsOneWidget);
      expect(durFinder, findsOneWidget);

      final depCenter = tester.getCenter(depFinder);
      final arrCenter = tester.getCenter(arrFinder);
      final durCenter = tester.getCenter(durFinder);

      // Center of duration must be between departure and arrival horizontally
      expect(durCenter.dx, greaterThan(depCenter.dx));
      expect(durCenter.dx, lessThan(arrCenter.dx));

      // The midpoint between dep and arr should be centered with the duration center
      final midPoint = (depCenter.dx + arrCenter.dx) / 2;
      expect((durCenter.dx - midPoint).abs(), lessThan(40.0));
    });
  });

  group('Req 2: Transport Activity Flight Transfer Toggle & Positioning', () {
    testWidgets('Toggle controls flight link visibility and is positioned between times and route locations',
        (WidgetTester tester) async {
      final now = DateTime(2026, 6, 1);
      final trip = Trip(
        id: 'trip_transport_test',
        title: 'Bangkok Adventure',
        destination: 'Bangkok',
        startDate: now,
        endDate: now.add(const Duration(days: 5)),
        ownerId: 'user_1',
        inviteCode: 'TRIP-X',
        defaultInviteRole: MemberRole.editor,
        members: const {'user_1': MemberRole.owner},
        createdAt: now,
        updatedAt: now,
      );

      final flight = Flight(
        id: 'flight_1',
        tripId: trip.id,
        airline: 'Singapore Airlines',
        flightNumber: 'SQ970',
        departureAirport: 'SIN',
        arrivalAirport: 'BKK',
        departureTime: now.add(const Duration(hours: 10)),
        arrivalTime: now.add(const Duration(hours: 12)),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeTripProvider.overrideWithValue(trip),
            activeTripFlightsProvider.overrideWith((ref) => Stream.value([flight])),
            activeTripActivitiesProvider.overrideWith((ref) => Stream.value([])),
            canEditActiveTripProvider.overrideWithValue(true),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: AddActivitySheet(
                initialDate: now,
                initialCategory: ActivityCategory.transport,
                initialTitle: 'Airport Taxi',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify "Flight Transfer" switch tile is present
      final switchFinder = find.widgetWithText(SwitchListTile, 'Flight Transfer');
      expect(switchFinder, findsOneWidget);

      // Initially, switch is OFF, so flight link dropdown is NOT shown
      expect(find.text('Select Flight'), findsNothing);
      expect(find.text('Transfer Direction'), findsNothing);

      // Verify positioning: Switch must appear before Transport Route Locations
      final switchCenter = tester.getCenter(switchFinder);
      final routeHeaderFinder = find.text('Transport Route Locations');
      expect(routeHeaderFinder, findsOneWidget);
      final routeCenter = tester.getCenter(routeHeaderFinder);

      expect(switchCenter.dy, lessThan(routeCenter.dy));

      // Turn ON the flight transfer toggle
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // Now the flight selector and transfer direction buttons are visible
      expect(find.text('Select Flight'), findsOneWidget);
      expect(find.text('To Airport'), findsOneWidget);
      expect(find.text('From Airport'), findsOneWidget);
    });
  });

  group('Req 4: Suggestions Panel Flags Transport Activities Missing To and/or From', () {
    late Trip trip;

    setUp(() {
      final now = DateTime(2026, 6, 1);
      trip = Trip(
        id: 'trip_sugg_test',
        title: 'Route Validation Trip',
        destination: 'Bangkok, Thailand',
        startDate: now,
        endDate: now.add(const Duration(days: 3)),
        startLocation: 'BKK',
        endLocation: 'BKK',
        ownerId: 'user_test',
        inviteCode: 'SUGG-01',
        defaultInviteRole: MemberRole.editor,
        members: const {'user_test': MemberRole.owner},
        createdAt: now,
        updatedAt: now,
      );
    });

    testWidgets('Flags transport missing both From & To, missing From only, and missing To only',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final date = DateTime(2026, 6, 1);

      // 1. Missing both from & to
      final actMissingBoth = Activity(
        id: 'act_missing_both',
        tripId: trip.id,
        date: date,
        startTime: '10:00',
        endTime: '11:00',
        title: 'Morning Express Shuttle',
        category: ActivityCategory.transport,
      );

      // 2. Missing from only
      final actMissingFrom = Activity(
        id: 'act_missing_from',
        tripId: trip.id,
        date: date,
        startTime: '14:00',
        endTime: '15:00',
        title: 'Afternoon Bus',
        category: ActivityCategory.transport,
        toLocation: 'Grand Palace, Bangkok',
      );

      // 3. Missing to only
      final actMissingTo = Activity(
        id: 'act_missing_to',
        tripId: trip.id,
        date: date,
        startTime: '16:00',
        endTime: '17:00',
        title: 'Evening Ferry',
        category: ActivityCategory.transport,
        fromLocation: 'Sathorn Pier, Bangkok',
      );

      final stay = Stay(
        id: 'stay_1',
        tripId: trip.id,
        type: StayType.hotel,
        name: 'The Peninsula Bangkok',
        address: 'Bangkok',
        checkInDate: date,
        checkOutDate: date.add(const Duration(days: 3)),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeTripProvider.overrideWithValue(trip),
            activeTripFlightsProvider.overrideWith((ref) => Stream.value([])),
            activeTripStaysProvider.overrideWith((ref) => Stream.value([stay])),
            activeTripActivitiesProvider.overrideWith(
                (ref) => Stream.value([actMissingBoth, actMissingFrom, actMissingTo])),
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

      // Verify that suggestions pane flags all 3 transport activities (searching with skipOffstage: false in scrollable list)
      expect(
        find.text('Missing Route Locations: Morning Express Shuttle', skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.text('Missing Departure Location: Afternoon Bus', skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.text('Missing Destination Location: Evening Ferry', skipOffstage: false),
        findsOneWidget,
      );
    });
  });

  group('Req 3: Day Planner Google Maps Panel Tests', () {
    late Trip trip;
    late Stay stay;

    setUp(() {
      final now = DateTime(2026, 6, 1);
      trip = Trip(
        id: 'trip_map_test',
        title: 'Bangkok Explorer',
        destination: 'Bangkok, Thailand',
        startDate: now,
        endDate: now.add(const Duration(days: 4)),
        startLocation: 'BKK',
        endLocation: 'BKK',
        ownerId: 'user_map',
        inviteCode: 'MAP-01',
        defaultInviteRole: MemberRole.editor,
        members: const {'user_map': MemberRole.owner},
        createdAt: now,
        updatedAt: now,
      );

      stay = Stay(
        id: 'stay_map_hotel',
        tripId: trip.id,
        type: StayType.hotel,
        name: 'Shangri-La Bangkok',
        address: 'Charoen Krung Rd, Bangkok',
        checkInDate: now,
        checkOutDate: now.add(const Duration(days: 4)),
      );
    });

    testWidgets('Desktop view: map panel toggles on/off and shows all pins by default',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final date = DateTime(2026, 6, 1);

      final actTemple = Activity(
        id: 'act_temple',
        tripId: trip.id,
        date: date,
        startTime: '09:00',
        endTime: '11:00',
        title: 'Wat Phra Kaew',
        location: 'Grand Palace, Bangkok',
        category: ActivityCategory.attraction,
      );

      final actLunch = Activity(
        id: 'act_lunch',
        tripId: trip.id,
        date: date,
        startTime: '12:00',
        endTime: '13:00',
        title: 'Riverfront Dining',
        location: 'Chao Phraya River, Bangkok',
        category: ActivityCategory.dining,
        mealType: 'lunch',
      );

      final actTransport = Activity(
        id: 'act_boat',
        tripId: trip.id,
        date: date,
        startTime: '14:00',
        endTime: '14:45',
        title: 'Chao Phraya Express Boat',
        fromLocation: 'Tha Chang Pier, Bangkok',
        toLocation: 'Wat Arun, Bangkok',
        category: ActivityCategory.transport,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeTripProvider.overrideWithValue(trip),
            activeTripFlightsProvider.overrideWith((ref) => Stream.value([])),
            activeTripStaysProvider.overrideWith((ref) => Stream.value([stay])),
            activeTripActivitiesProvider.overrideWith(
                (ref) => Stream.value([actTemple, actLunch, actTransport])),
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

      // Map panel is initially hidden
      expect(find.byType(DayPlannerMapPanel), findsNothing);

      // Find and click the Map button in the header
      final mapToggleBtn = find.byTooltip('Show Day Map');
      expect(mapToggleBtn, findsOneWidget);
      await tester.tap(mapToggleBtn);
      await tester.pumpAndSettle();

      // Now DayPlannerMapPanel is visible
      expect(find.byType(DayPlannerMapPanel), findsOneWidget);

      // Verify Google Maps attribution
      expect(find.text('Google'), findsOneWidget);

      // Verify "All Pins" chip exists and shows count of locations
      expect(find.textContaining('All Pins'), findsOneWidget);

      // Select transport activity by tapping its chip in the map panel
      final transportChip = find.byKey(const ValueKey('map_chip_act_boat'));
      expect(transportChip, findsOneWidget);
      await tester.ensureVisible(transportChip);
      await tester.tap(transportChip);
      await tester.pumpAndSettle();

      // Directions details should appear
      expect(find.text('DIRECTIONS'), findsOneWidget);
      expect(find.textContaining('Tha Chang Pier'), findsWidgets);
      expect(find.textContaining('Wat Arun'), findsWidgets);

      // Select single-location attraction: should highlight single location card
      final templeChip = find.byKey(const ValueKey('map_chip_act_temple'));
      expect(templeChip, findsOneWidget);
      await tester.ensureVisible(templeChip);
      await tester.tap(templeChip);
      await tester.pumpAndSettle();

      expect(find.text('Wat Phra Kaew'), findsWidgets);
      expect(find.textContaining('Grand Palace'), findsWidgets);

      // Toggle off map panel
      final hideMapBtn = find.byTooltip('Hide Day Map');
      expect(hideMapBtn, findsOneWidget);
      await tester.tap(hideMapBtn);
      await tester.pumpAndSettle();

      expect(find.byType(DayPlannerMapPanel), findsNothing);
    });

    testWidgets('Mobile view: map panel pops up on top in a modal sheet',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844); // Mobile portrait
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final date = DateTime(2026, 6, 1);

      final actTemple = Activity(
        id: 'act_temple_mobile',
        tripId: trip.id,
        date: date,
        startTime: '10:00',
        endTime: '12:00',
        title: 'Wat Pho',
        location: 'Wat Pho, Bangkok',
        category: ActivityCategory.attraction,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeTripProvider.overrideWithValue(trip),
            activeTripFlightsProvider.overrideWith((ref) => Stream.value([])),
            activeTripStaysProvider.overrideWith((ref) => Stream.value([stay])),
            activeTripActivitiesProvider.overrideWith(
                (ref) => Stream.value([actTemple])),
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

      // On phone, map panel is not initially showing
      expect(find.byType(DayPlannerMapPanel), findsNothing);

      // Tap the floating map button
      final floatingMapBtn = find.byKey(const ValueKey('floating_map_button'));
      expect(floatingMapBtn, findsOneWidget);
      await tester.tap(floatingMapBtn);
      await tester.pumpAndSettle();

      // Map panel pops up in the bottom modal sheet!
      expect(find.byType(DayPlannerMapPanel), findsOneWidget);
      expect(find.text('Google'), findsOneWidget);

      // Close modal
      final closeBtn = find.byTooltip('Close map');
      expect(closeBtn, findsOneWidget);
      await tester.tap(closeBtn);
      await tester.pumpAndSettle();

      expect(find.byType(DayPlannerMapPanel), findsNothing);
    });

    testWidgets(
        'Regression: Opening Day Planner map on thailandia_2026_trip does not freeze and limits tiles <= 64',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final bundle = TripBundle.fromMap(
          jsonDecode(thailandiaSampleJson) as Map<String, dynamic>);
      final trip = bundle.trip;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeTripProvider.overrideWithValue(trip),
            activeTripFlightsProvider
                .overrideWith((ref) => Stream.value(bundle.flights)),
            activeTripStaysProvider
                .overrideWith((ref) => Stream.value(bundle.stays)),
            activeTripActivitiesProvider
                .overrideWith((ref) => Stream.value(bundle.activities)),
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

      // Tap show map icon on Day 1
      final showMapBtn = find.byTooltip('Show Day Map');
      expect(showMapBtn, findsOneWidget);
      await tester.tap(showMapBtn);
      await tester.pumpAndSettle();

      // DayPlannerMapPanel should be visible and responsive immediately
      expect(find.byType(DayPlannerMapPanel), findsOneWidget);
      expect(find.text('Google'), findsOneWidget);

      // Verify that the tile layer does not blow up (> 64 tiles)
      final tileImages = find.descendant(
        of: find.byType(DayPlannerMapPanel),
        matching: find.byType(Image),
      );
      expect(tileImages.evaluate().length, lessThanOrEqualTo(64));

      // Verify that every tile is rendered as an exact 1:1 square with no aspect-ratio distortion
      for (final element in tileImages.evaluate()) {
        final img = element.widget as Image;
        expect(img.width, isNotNull);
        expect(img.height, isNotNull);
        expect(img.width, equals(img.height));
      }

      // Navigate to Day 2 with map remaining open
      final nextDayBtn = find.byTooltip('Next Day');
      expect(nextDayBtn, findsOneWidget);
      await tester.tap(nextDayBtn);
      await tester.pumpAndSettle();

      expect(find.byType(DayPlannerMapPanel), findsOneWidget);
      final day2Tiles = find.descendant(
        of: find.byType(DayPlannerMapPanel),
        matching: find.byType(Image),
      );
      expect(day2Tiles.evaluate().length, lessThanOrEqualTo(64));

      // Navigate to Day 6 (International Flight Tokyo -> Hanoi)
      for (int i = 0; i < 4; i++) {
        await tester.tap(nextDayBtn);
        await tester.pumpAndSettle();
      }

      expect(find.byType(DayPlannerMapPanel), findsOneWidget);
      final day6Tiles = find.descendant(
        of: find.byType(DayPlannerMapPanel),
        matching: find.byType(Image),
      );
      expect(day6Tiles.evaluate().length, lessThanOrEqualTo(64));
    });
  });

  group('Iteration #14: Itinerary Map View & Day Planner Improvements', () {
    test('Req 3: 3942 West Lake Sammish Pkwy SE, Bellevue WA resolves to Bellevue/Lake Sammamish, NOT Seattle Arboretum', () {
      final addr = '3942 West Lake Sammish Pkwy SE, Bellevue WA 98008, USA';
      final coords = TripMapHelper.resolveCoordinates(addr);

      // Bellevue / Lake Sammamish coordinates: (47.5747, -122.1093)
      expect(coords.lat, closeTo(47.5747, 0.05));
      expect(coords.lng, closeTo(-122.1093, 0.05));

      // Seattle Arboretum coordinates: (47.63, -122.29)
      final distToArboretumLat = (coords.lat - 47.63).abs();
      final distToArboretumLng = (coords.lng - (-122.29)).abs();
      expect(distToArboretumLat > 0.04 || distToArboretumLng > 0.1, isTrue);
    });

    testWidgets('Req 2: Day planner ignores activities without locations when rendering the map view',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final date = DateTime(2026, 6, 1);
      final trip = Trip(
        id: 'trip_no_loc_test',
        title: 'Location Test Trip',
        destination: 'Bangkok, Thailand',
        startDate: date,
        endDate: date.add(const Duration(days: 2)),
        startLocation: 'BKK',
        endLocation: 'BKK',
        ownerId: 'user_loc',
        inviteCode: 'LOC-01',
        members: const {'user_loc': MemberRole.owner},
        createdAt: date,
        updatedAt: date,
      );

      final actWithLoc = Activity(
        id: 'act_with_loc',
        tripId: trip.id,
        date: date,
        startTime: '09:00',
        title: 'Wat Pho Temple',
        location: 'Sanam Chai Rd, Bangkok',
        category: ActivityCategory.attraction,
      );

      final actNoLoc = Activity(
        id: 'act_no_loc',
        tripId: trip.id,
        date: date,
        startTime: '10:30',
        title: 'Review Packing List',
        location: null, // No location!
        category: ActivityCategory.custom,
      );

      final actEmptyLoc = Activity(
        id: 'act_empty_loc',
        tripId: trip.id,
        date: date,
        startTime: '11:00',
        title: 'Relax at hotel',
        location: '   ', // Empty whitespace location!
        category: ActivityCategory.custom,
      );

      final actTransport = Activity(
        id: 'act_transfer',
        tripId: trip.id,
        date: date,
        startTime: '14:00',
        title: 'Express Shuttle',
        fromLocation: 'Grand Palace, Bangkok',
        toLocation: 'Chao Phraya Pier, Bangkok',
        category: ActivityCategory.transport,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DayPlannerMapPanel(
              trip: trip,
              date: date,
              dayNumber: 1,
              dayActivities: [actWithLoc, actNoLoc, actEmptyLoc, actTransport],
              defaultCountry: 'Thailand',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Only activities WITH locations should have pins
      // actWithLoc has 1 pin, actTransport has 2 pins (from and to) -> total 3 pins
      expect(find.textContaining('3 locations on map'), findsOneWidget);
      expect(find.text('All Pins (3)'), findsOneWidget);

      // Activities without locations should NOT have header filter chips
      expect(find.byKey(const ValueKey('map_chip_act_with_loc')), findsOneWidget);
      expect(find.byKey(const ValueKey('map_chip_act_transfer')), findsOneWidget);
      expect(find.byKey(const ValueKey('map_chip_act_no_loc')), findsNothing);
      expect(find.byKey(const ValueKey('map_chip_act_empty_loc')), findsNothing);
    });

    testWidgets('Req 4: Selecting transport activity in day planner displays Google Maps directions',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final date = DateTime(2026, 6, 1);
      final trip = Trip(
        id: 'trip_dirs_test',
        title: 'West Lake to SeaTac Trip',
        destination: 'Seattle, USA',
        startDate: date,
        endDate: date.add(const Duration(days: 2)),
        startLocation: 'SEA',
        endLocation: 'SEA',
        ownerId: 'user_dirs',
        inviteCode: 'DIRS-01',
        members: const {'user_dirs': MemberRole.owner},
        createdAt: date,
        updatedAt: date,
      );

      final actTransport = Activity(
        id: 'act_bellevue_to_sea',
        tripId: trip.id,
        date: date,
        startTime: '08:00',
        endTime: '08:35',
        title: 'Transfer to SeaTac Airport',
        fromLocation: '3942 West Lake Sammish Pkwy SE, Bellevue WA 98008, USA',
        toLocation: 'Seattle-Tacoma International Airport (SEA)',
        category: ActivityCategory.transport,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DayPlannerMapPanel(
              trip: trip,
              date: date,
              dayNumber: 1,
              dayActivities: [actTransport],
              defaultCountry: 'USA',
              selectedActivity: actTransport,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Google Maps directions badge and duration/distance
      expect(find.text('DIRECTIONS'), findsOneWidget);
      expect(find.text('Google Maps Route'), findsOneWidget);
      expect(find.textContaining('via I-405 S'), findsOneWidget);
      expect(find.textContaining('30 mins'), findsOneWidget);
      expect(find.textContaining('18.9 mi'), findsOneWidget);

      // Verify origin and destination in detail card
      expect(find.textContaining('3942 West Lake Sammish'), findsOneWidget);
      expect(find.textContaining('Seattle-Tacoma'), findsOneWidget);

      // Verify transport directions painter is rendered on canvas
      final customPaints = find.byType(CustomPaint);
      expect(customPaints, findsWidgets);
    });
  });
}

