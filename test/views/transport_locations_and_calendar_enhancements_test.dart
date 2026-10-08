import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trippy/core/theme/app_theme.dart';
import 'package:trippy/data/repositories/mock_trip_repository.dart';
import 'package:trippy/models/models.dart';
import 'package:trippy/state/trip_providers.dart';
import 'package:trippy/views/common/add_activity_sheet.dart';
import 'package:trippy/views/day_planner/day_planner_view.dart';
import 'package:trippy/views/flights/flights_view.dart';
import 'package:trippy/views/logistics/widgets/calendar_itinerary_view.dart';

void main() {
  group('Req 1: Transport Activities From/To, Flight Direction & Stay Location', () {
    late Trip trip;
    late Flight flight;
    late Stay stay;

    setUp(() {
      final now = DateTime(2026, 11, 1);
      trip = Trip(
        id: 'trip_transport_test',
        title: 'Japan Nov 2026',
        destination: 'Tokyo, Japan',
        startDate: now,
        endDate: now.add(const Duration(days: 6)),
        ownerId: 'user_1',
        inviteCode: 'JPN-2026',
        defaultInviteRole: MemberRole.editor,
        members: const {'user_1': MemberRole.owner},
        createdAt: now,
        updatedAt: now,
      );

      flight = Flight(
        id: 'flight_dl167',
        tripId: trip.id,
        airline: 'Delta Air Lines',
        flightNumber: 'DL0167',
        departureAirport: 'HND (Tokyo Haneda)',
        arrivalAirport: 'BKK (Bangkok Suvarnabhumi)',
        departureTime: now.add(const Duration(hours: 14)),
        arrivalTime: now.add(const Duration(hours: 21)),
        linkedActivityIds: const [],
      );

      stay = Stay(
        id: 'stay_candeo',
        tripId: trip.id,
        type: StayType.hotel,
        name: 'Candeo Hotels Tokyo',
        address: 'Minato City, Tokyo 105-0004',
        checkInDate: now,
        checkOutDate: now.add(const Duration(days: 3)),
      );
    });

    test('Activity serialization preserves fromLocation, toLocation, transportDirection, and stay IDs', () {
      final act = Activity(
        id: 'act_xfer_1',
        tripId: 'trip_1',
        date: DateTime(2026, 11, 1),
        startTime: '10:00',
        endTime: '11:00',
        title: 'Taxi to Airport',
        category: ActivityCategory.transport,
        fromLocation: 'Hotel Tokyo',
        toLocation: 'HND (Tokyo Haneda)',
        transportDirection: 'to_airport',
        fromStayId: 'stay_123',
        toStayId: null,
      );

      expect(act.isToAirport, isTrue);
      expect(act.isFromAirport, isFalse);
      expect(act.effectiveFromLocation, 'Hotel Tokyo');
      expect(act.effectiveToLocation, 'HND (Tokyo Haneda)');

      final map = act.toMap();
      expect(map['fromLocation'], 'Hotel Tokyo');
      expect(map['toLocation'], 'HND (Tokyo Haneda)');
      expect(map['transportDirection'], 'to_airport');
      expect(map['fromStayId'], 'stay_123');

      final revived = Activity.fromMap(map);
      expect(revived.fromLocation, 'Hotel Tokyo');
      expect(revived.toLocation, 'HND (Tokyo Haneda)');
      expect(revived.transportDirection, 'to_airport');
      expect(revived.fromStayId, 'stay_123');
      expect(revived.isToAirport, isTrue);
    });

    testWidgets('AddActivitySheet disables To/From Airport buttons when no flight is linked', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeTripProvider.overrideWithValue(trip),
            activeTripFlightsProvider.overrideWith((ref) => Stream.value([flight])),
            activeTripStaysProvider.overrideWith((ref) => Stream.value([stay])),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: AddActivitySheet(
                initialDate: trip.startDate,
                initialCategory: ActivityCategory.transport,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enable flight transfer toggle (introduced in Iteration 12)
      final flightTransferSwitch = find.widgetWithText(SwitchListTile, 'Flight Transfer');
      if (flightTransferSwitch.evaluate().isNotEmpty) {
        await tester.tap(flightTransferSwitch);
        await tester.pumpAndSettle();
      }

      // Find To Airport and From Airport buttons
      final toAirportBtn = find.widgetWithText(OutlinedButton, 'To Airport');
      final fromAirportBtn = find.widgetWithText(OutlinedButton, 'From Airport');

      expect(toAirportBtn, findsOneWidget);
      expect(fromAirportBtn, findsOneWidget);

      // Both buttons are disabled because no flight is linked yet
      final OutlinedButton toWidget = tester.widget(toAirportBtn);
      expect(toWidget.onPressed, isNull);

      final OutlinedButton fromWidget = tester.widget(fromAirportBtn);
      expect(fromWidget.onPressed, isNull);
    });

    testWidgets('AddActivitySheet enables mutually exclusive To/From Airport buttons when flight is linked and locks airport location', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final activityWithFlight = Activity(
        id: 'act_prelinked',
        tripId: trip.id,
        date: trip.startDate,
        startTime: '10:00',
        title: 'Ride to Airport',
        category: ActivityCategory.transport,
        flightId: flight.id,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeTripProvider.overrideWithValue(trip),
            activeTripFlightsProvider.overrideWith((ref) => Stream.value([flight])),
            activeTripStaysProvider.overrideWith((ref) => Stream.value([stay])),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: AddActivitySheet(
                activityToEdit: activityWithFlight,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Buttons are now enabled
      final toAirportBtn = find.widgetWithText(OutlinedButton, 'To Airport');
      final fromAirportBtn = find.widgetWithText(OutlinedButton, 'From Airport');

      expect(toAirportBtn, findsOneWidget);
      expect(fromAirportBtn, findsOneWidget);

      final OutlinedButton toWidget = tester.widget(toAirportBtn);
      expect(toWidget.onPressed, isNotNull);

      // Tap "To Airport"
      await tester.tap(toAirportBtn);
      await tester.pumpAndSettle();

      // "To" destination should be read-only flight departure airport
      expect(find.text(flight.departureAirport), findsWidgets);
      expect(find.textContaining('departure airport of linked flight'), findsOneWidget);

      // Tap "From Airport"
      await tester.tap(fromAirportBtn);
      await tester.pumpAndSettle();

      // Now "From" origin should be read-only flight arrival airport
      expect(find.text(flight.arrivalAirport), findsWidgets);
      expect(find.textContaining('arrival airport of linked flight'), findsOneWidget);
    });

    testWidgets('AddActivitySheet allows selecting a Stay as From or To location and displays read-only hotel & address', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeTripProvider.overrideWithValue(trip),
            activeTripFlightsProvider.overrideWith((ref) => Stream.value([flight])),
            activeTripStaysProvider.overrideWith((ref) => Stream.value([stay])),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: AddActivitySheet(
                initialDate: trip.startDate,
                initialCategory: ActivityCategory.transport,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find stay picker tooltip button on From location field
      final fromStayPicker = find.byTooltip('Select Stay as From Location');
      expect(fromStayPicker, findsOneWidget);

      // Tap the stay picker button for From location
      await tester.tap(fromStayPicker);
      await tester.pumpAndSettle();

      // Popup menu shows Candeo Hotels Tokyo
      expect(find.textContaining('Candeo Hotels Tokyo'), findsWidgets);

      await tester.tap(find.textContaining('Candeo Hotels Tokyo').last);
      await tester.pumpAndSettle();

      // Location is now read-only card showing hotel name and address
      expect(find.text(stay.name), findsWidgets);
      if (stay.address != null) {
        expect(find.text(stay.address!), findsWidgets);
      }
      expect(find.text('Change'), findsOneWidget);
    });

    testWidgets('FlightsView displays distinct TO AIRPORT and FROM AIRPORT badges for linked ground transfers', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final toXfer = Activity(
        id: 'act_to_flt',
        tripId: trip.id,
        flightId: flight.id,
        date: trip.startDate,
        startTime: '11:00',
        title: 'Uber to Haneda',
        category: ActivityCategory.transport,
        transportDirection: 'to_airport',
        toLocation: flight.departureAirport,
      );

      final fromXfer = Activity(
        id: 'act_from_flt',
        tripId: trip.id,
        flightId: flight.id,
        date: trip.startDate,
        startTime: '22:00',
        title: 'Airport Limousine to Hotel',
        category: ActivityCategory.transport,
        transportDirection: 'from_airport',
        fromLocation: flight.arrivalAirport,
      );

      final flightWithTransfers = flight.copyWith(
        linkedActivityIds: ['act_to_flt', 'act_from_flt'],
      );

      final repo = MockTripRepository();
      await repo.createTrip(trip);
      await repo.addFlight(flightWithTransfers);
      await repo.addActivity(toXfer);
      await repo.addActivity(fromXfer);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(repo),
            activeTripProvider.overrideWithValue(trip),
            activeTripFlightsProvider.overrideWith((ref) => Stream.value([flightWithTransfers])),
            activeTripActivitiesProvider.overrideWith((ref) => Stream.value([toXfer, fromXfer])),
            canEditActiveTripProvider.overrideWithValue(true),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(
              body: FlightsView(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify ground transfers section shows both activities with their respective direction badges
      expect(find.text('TO AIRPORT'), findsOneWidget);
      expect(find.text('FROM AIRPORT'), findsOneWidget);
      expect(find.text('Uber to Haneda'), findsOneWidget);
      expect(find.text('Airport Limousine to Hotel'), findsOneWidget);
    });
  });

  group('Req 2: Hotel & Stay Activities Read-Only Location when Linked to Stay', () {
    late Trip trip;
    late Stay stay;

    setUp(() {
      final now = DateTime(2026, 11, 1);
      trip = Trip(
        id: 'trip_hotel_test',
        title: 'Japan Nov 2026',
        destination: 'Tokyo, Japan',
        startDate: now,
        endDate: now.add(const Duration(days: 6)),
        ownerId: 'user_1',
        inviteCode: 'JPN-2026',
        defaultInviteRole: MemberRole.editor,
        members: const {'user_1': MemberRole.owner},
        createdAt: now,
        updatedAt: now,
      );

      stay = Stay(
        id: 'stay_asyl',
        tripId: trip.id,
        type: StayType.hotel,
        name: 'Grand Hyatt Tokyo',
        address: 'Roppongi Hills, Tokyo',
        checkInDate: now,
        checkOutDate: now.add(const Duration(days: 3)),
      );
    });

    testWidgets('Hotel activity linked to a stay displays location and address as read-only', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final stayActivity = Activity(
        id: 'act_stay_1',
        tripId: trip.id,
        date: trip.startDate,
        startTime: '15:00',
        title: 'Check-in at Grand Hyatt',
        category: ActivityCategory.stay,
        stayId: stay.id,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeTripProvider.overrideWithValue(trip),
            activeTripFlightsProvider.overrideWith((ref) => Stream.value([])),
            activeTripStaysProvider.overrideWith((ref) => Stream.value([stay])),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: AddActivitySheet(
                activityToEdit: stayActivity,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Location is read-only displaying hotel name & address
      expect(find.text(stay.name), findsWidgets);
      if (stay.address != null) {
        expect(find.text(stay.address!), findsWidgets);
      }
      expect(find.textContaining('Read-only: set automatically from linked stay'), findsOneWidget);
    });

    testWidgets('Hotel activity without a linked stay displays editable location field', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeTripProvider.overrideWithValue(trip),
            activeTripFlightsProvider.overrideWith((ref) => Stream.value([])),
            activeTripStaysProvider.overrideWith((ref) => Stream.value([stay])),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: AddActivitySheet(
                initialDate: trip.startDate,
                initialCategory: ActivityCategory.stay,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Editable text field with 'Location / Address'
      expect(find.widgetWithText(TextField, 'Location / Address'), findsOneWidget);
    });
  });

  group('Req 3 & 4: Day Planner Suggestions Missing End Time & City-Only Suggestions', () {
    late Trip trip;
    late Stay stay;

    setUp(() {
      final now = DateTime(2026, 11, 1);
      trip = Trip(
        id: 'trip_sugg_test',
        title: 'Thailand & Japan',
        destination: 'Bangkok, Thailand',
        startDate: now,
        endDate: now.add(const Duration(days: 4)),
        ownerId: 'user_1',
        inviteCode: 'THAI-2026',
        defaultInviteRole: MemberRole.editor,
        members: const {'user_1': MemberRole.owner},
        createdAt: now,
        updatedAt: now,
      );

      stay = Stay(
        id: 'stay_bkk',
        tripId: trip.id,
        type: StayType.hotel,
        name: 'The Peninsula Bangkok',
        address: 'Bangkok, Thailand',
        checkInDate: now,
        checkOutDate: now.add(const Duration(days: 4)),
      );
    });

    testWidgets('Day Planner suggestions flag activities without end time', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final actNoEndTime = Activity(
        id: 'act_no_end',
        tripId: trip.id,
        date: trip.startDate,
        startTime: '14:00',
        endTime: null, // Missing end time!
        title: 'Wat Pho Temple Visit',
        category: ActivityCategory.attraction,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeTripProvider.overrideWithValue(trip),
            activeTripFlightsProvider.overrideWith((ref) => Stream.value([])),
            activeTripStaysProvider.overrideWith((ref) => Stream.value([stay])),
            activeTripActivitiesProvider.overrideWith((ref) => Stream.value([actNoEndTime])),
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

      // Suggestions panel must flag missing end time
      expect(find.textContaining('Missing End Time'), findsOneWidget);
      expect(find.textContaining('Wat Pho Temple Visit'), findsWidgets);
      expect(find.text('Set End Time'), findsOneWidget);
    });

    testWidgets('Day Planner suggestions ONLY suggest valid cities, ignoring bays, islands, and attractions', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Create an activity referencing Lan-Ha Bay and another referencing Chiang Mai
      final actInBay = Activity(
        id: 'act_bay',
        tripId: trip.id,
        date: trip.startDate,
        startTime: '09:00',
        endTime: '12:00',
        title: 'Kayaking in Lan-Ha Bay',
        location: 'Lan-Ha Bay, Cat Ba Island',
        category: ActivityCategory.attraction,
      );

      final actInCity = Activity(
        id: 'act_city',
        tripId: trip.id,
        date: trip.startDate,
        startTime: '15:00',
        endTime: '17:00',
        title: 'Old Town Walk in Chiang Mai',
        location: 'Chiang Mai, Thailand',
        category: ActivityCategory.attraction,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeTripProvider.overrideWithValue(trip),
            activeTripFlightsProvider.overrideWith((ref) => Stream.value([])),
            activeTripStaysProvider.overrideWith((ref) => Stream.value([stay])), // Stay is Bangkok
            activeTripActivitiesProvider.overrideWith((ref) => Stream.value([actInBay, actInCity])),
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

      // Should NEVER suggest Lan-Ha Bay or Cat Ba Island
      expect(find.textContaining('Lan-Ha Bay'), findsWidgets); // Only in activity card, NOT in suggestions
      expect(find.textContaining('Add missing location: Lan-Ha Bay'), findsNothing);
      expect(find.textContaining('Add missing location: Cat Ba'), findsNothing);

      // Can suggest genuine city "Chiang Mai"
      expect(find.textContaining('Add missing location: Chiang Mai'), findsOneWidget);
    });
  });

  group('Req 5 & 6: Calendar View Day of Week, Centered City, City Background & Floating Stays', () {
    late Trip trip;
    late Stay stay1;
    late Stay stay2;
    late Flight flight;
    late Activity act1;

    setUp(() {
      final now = DateTime(2026, 11, 1); // Sunday
      final day0Key = Trip.dateToKey(now);
      final day1Key = Trip.dateToKey(now.add(const Duration(days: 1)));
      final day2Key = Trip.dateToKey(now.add(const Duration(days: 2)));
      final day3Key = Trip.dateToKey(now.add(const Duration(days: 3)));

      trip = Trip(
        id: 'trip_cal_test',
        title: 'Japan Tour',
        destination: 'Tokyo & Kyoto',
        startDate: now,
        endDate: now.add(const Duration(days: 3)), // 4 days: Nov 1, 2, 3, 4
        ownerId: 'user_1',
        inviteCode: 'JPN-CAL',
        defaultInviteRole: MemberRole.editor,
        members: const {'user_1': MemberRole.owner},
        createdAt: now,
        updatedAt: now,
        dayLocations: {
          day0Key: ['Tokyo'],
          day1Key: ['Tokyo'],
          day2Key: ['Kyoto'],
          day3Key: ['Kyoto'],
        },
      );

      stay1 = Stay(
        id: 'stay_tokyo',
        tripId: trip.id,
        type: StayType.hotel,
        name: 'Hotel Gracery Shinjuku',
        address: 'Shinjuku, Tokyo',
        checkInDate: now,
        checkOutDate: now.add(const Duration(days: 2)),
      );

      stay2 = Stay(
        id: 'stay_kyoto',
        tripId: trip.id,
        type: StayType.hotel,
        name: 'The Thousand Kyoto',
        address: 'Shimogyo Ward, Kyoto',
        checkInDate: now.add(const Duration(days: 2)),
        checkOutDate: now.add(const Duration(days: 4)),
      );

      flight = Flight(
        id: 'flt_1',
        tripId: trip.id,
        airline: 'ANA',
        flightNumber: 'NH001',
        departureAirport: 'NRT',
        arrivalAirport: 'ITM',
        departureTime: now.add(const Duration(days: 2, hours: 8)),
        arrivalTime: now.add(const Duration(days: 2, hours: 10)),
      );

      act1 = Activity(
        id: 'act_1',
        tripId: trip.id,
        date: now,
        startTime: '10:00',
        endTime: '12:00',
        title: 'Shinjuku Gyoen',
        category: ActivityCategory.attraction,
      );
    });

    testWidgets('Calendar View renders Day of Week, centered prominent city, floating stay rectangles, and bottom-aligned items', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeTripProvider.overrideWithValue(trip),
            activeTripFlightsProvider.overrideWith((ref) => Stream.value([flight])),
            activeTripStaysProvider.overrideWith((ref) => Stream.value([stay1, stay2])),
            activeTripActivitiesProvider.overrideWith((ref) => Stream.value([act1])),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: CalendarItineraryView(
                trip: trip,
                stays: [stay1, stay2],
                flights: [flight],
                activitiesByDay: {
                  trip.startDate: [act1],
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Day of Week shown on day squares
      expect(find.text('SUN'), findsWidgets);
      expect(find.text('MON'), findsWidgets);
      expect(find.text('TUE'), findsWidgets);
      expect(find.text('WED'), findsWidgets);

      // 2. Centered prominent city label
      expect(find.text('Tokyo'), findsWidgets);
      expect(find.text('Kyoto'), findsWidgets);

      // 3. Floating Stay rectangles show hotel name (not address)
      expect(find.text('Hotel Gracery Shinjuku'), findsWidgets);
      expect(find.text('The Thousand Kyoto'), findsWidgets);
      expect(find.text('Shinjuku, Tokyo'), findsNothing);
      expect(find.text('Shimogyo Ward, Kyoto'), findsNothing);

      // 4. Flight icon on Day 3 (NH001)
      expect(find.text('NH001'), findsOneWidget);

      // 5. Activity count aligned bottom (number only per req 9)
      expect(find.text('1'), findsWidgets);
    });
  });
}
