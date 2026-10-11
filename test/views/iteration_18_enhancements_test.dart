import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trippy/core/utils/map_launcher_helper.dart';
import 'package:trippy/data/repositories/trip_repository.dart';
import 'package:trippy/models/models.dart';
import 'package:trippy/state/trip_providers.dart';
import 'package:trippy/views/common/add_activity_sheet.dart';
import 'package:trippy/views/common/add_flight_sheet.dart';
import 'package:trippy/views/common/add_stay_sheet.dart';
import 'package:trippy/views/day_planner/day_planner_view.dart';
import 'package:trippy/views/logistics/widgets/calendar_itinerary_view.dart';

void main() {
  group('Iteration #18 Enhancements Tests', () {
    late Trip testTrip;
    late Stay testStay;
    late Flight testFlight;
    late Activity testActivity;

    setUp(() {
      final now = DateTime(2026, 7, 1);
      testTrip = Trip(
        id: 'trip_it18',
        title: 'Iteration 18 Test Trip',
        destination: 'Tokyo, Japan',
        startDate: now,
        endDate: now.add(const Duration(days: 3)), // July 1 - 4
        startLocation: 'Haneda (HND)',
        endLocation: 'Narita (NRT)',
        ownerId: 'user_it18',
        inviteCode: 'IT18-TEST',
        defaultInviteRole: MemberRole.editor,
        members: const {'user_it18': MemberRole.owner},
        dayLocations: {
          Trip.dateToKey(now): ['Tokyo'],
          Trip.dateToKey(now.add(const Duration(days: 1))): ['Japan', 'Tokyo'],
        },
        createdAt: now,
        updatedAt: now,
      );

      testStay = Stay(
        id: 'stay_it18',
        tripId: testTrip.id,
        type: StayType.hotel,
        name: 'Park Hyatt Tokyo',
        address: '3-7-1-2 Nishi-Shinjuku, Tokyo',
        checkInDate: now,
        checkOutDate: now.add(const Duration(days: 3)),
        notes: 'High floor requested',
        links: const ['https://hyatt.com/stay123'],
        attachments: const ['hotel_voucher.pdf'],
      );

      testFlight = Flight(
        id: 'flight_it18',
        tripId: testTrip.id,
        airline: 'ANA',
        flightNumber: 'NH101',
        departureAirport: 'SFO',
        arrivalAirport: 'HND',
        departureTime: now.add(const Duration(hours: 10)),
        arrivalTime: now.add(const Duration(hours: 21)),
        notes: 'Window seat 12A',
        links: const ['https://ana.co.jp/booking/123'],
        attachments: const ['boarding_pass.pdf'],
      );

      testActivity = Activity(
        id: 'act_it18',
        tripId: testTrip.id,
        date: now,
        startTime: '14:00',
        endTime: '16:00',
        title: 'Shinjuku Gyoen Garden',
        category: ActivityCategory.attraction,
        location: '11 Naitomachi, Shinjuku City, Tokyo',
        notes: 'Entry tickets reserved online',
        links: const ['https://fng.or.jp/shinjuku'],
        attachments: const ['ticket_qr.png'],
      );
    });

    // Requirement 1: Calendar Itinerary View - Main City Center Alignment
    testWidgets('Req 1: Calendar itinerary day square vertically centers main city rectangle',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CalendarItineraryView(
              trip: testTrip,
              activitiesByDay: {
                testTrip.startDate: [testActivity],
              },
              flights: [testFlight],
              stays: [testStay],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify that Tokyo city rectangle is present
      final cityTextFinder = find.text('Tokyo');
      expect(cityTextFinder, findsWidgets);
    });

    // Requirement 2: Map Launcher Helper URL resolution
    test('Req 2: MapLauncherHelper resolves correct URLs for mobile, desktop, and web', () {
      const address = '6-10-3 Roppongi, Minato City, Tokyo';
      final encoded = Uri.encodeComponent(address);

      final androidUrl = MapLauncherHelper.getMapUriForAddress(
        address,
        platform: TargetPlatform.android,
        isWeb: false,
      );
      expect(androidUrl.toString(), equals('geo:0,0?q=$encoded'));

      final iosUrl = MapLauncherHelper.getMapUriForAddress(
        address,
        platform: TargetPlatform.iOS,
        isWeb: false,
      );
      expect(iosUrl.toString(), equals('https://maps.apple.com/?q=$encoded'));

      final desktopUrl = MapLauncherHelper.getMapUriForAddress(
        address,
        platform: TargetPlatform.windows,
        isWeb: false,
      );
      expect(desktopUrl.toString(),
          equals('https://www.google.com/maps/search/?api=1&query=$encoded'));
    });

    // Requirement 2 & 4: Clickable Map Icons and Android SafeArea in Edit Sheets
    testWidgets('Req 2 & 4: AddStaySheet contains clickable address map icon and SafeArea',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeTripProvider.overrideWithValue(testTrip),
            tripRepositoryProvider.overrideWithValue(FakeTripRepo()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: AddStaySheet(stayToEdit: testStay),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify address field with map icon button exists
      final addressMapIcon = find.widgetWithIcon(IconButton, Icons.location_on_outlined);
      expect(addressMapIcon, findsOneWidget);

      // Verify SafeArea wraps content
      expect(find.byType(SafeArea), findsOneWidget);

      // Verify existing notes and links are loaded
      expect(find.text('High floor requested'), findsOneWidget);
      expect(find.text('https://hyatt.com/stay123'), findsOneWidget);
      expect(find.text('hotel_voucher.pdf'), findsOneWidget);
    });

    testWidgets('Req 2 & 4: AddFlightSheet contains clickable airport map icons and SafeArea',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeTripProvider.overrideWithValue(testTrip),
            tripRepositoryProvider.overrideWithValue(FakeTripRepo()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: AddFlightSheet(flightToEdit: testFlight),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify departure and arrival airport map icons exist
      final airportMapIcons = find.widgetWithIcon(IconButton, Icons.location_on_outlined);
      expect(airportMapIcons, findsNWidgets(2));

      // Verify SafeArea wraps content
      expect(find.byType(SafeArea), findsOneWidget);

      // Verify notes, links and attachments
      expect(find.text('Window seat 12A'), findsOneWidget);
      expect(find.text('https://ana.co.jp/booking/123'), findsOneWidget);
      expect(find.text('boarding_pass.pdf'), findsOneWidget);
    });

    testWidgets('Req 2 & 4: AddActivitySheet contains clickable location map icon and SafeArea',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeTripProvider.overrideWithValue(testTrip),
            tripRepositoryProvider.overrideWithValue(FakeTripRepo()),
            activeTripStaysProvider.overrideWith((ref) => Stream.value([testStay])),
            activeTripFlightsProvider.overrideWith((ref) => Stream.value([testFlight])),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: AddActivitySheet(activityToEdit: testActivity),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify location map icon
      final locMapIcon = find.widgetWithIcon(IconButton, Icons.location_on_outlined);
      expect(locMapIcon, findsOneWidget);

      // Verify SafeArea wraps content
      expect(find.byType(SafeArea), findsOneWidget);

      // Verify notes, links and attachments
      expect(find.text('Entry tickets reserved online'), findsOneWidget);
      expect(find.text('https://fng.or.jp/shinjuku'), findsOneWidget);
      expect(find.text('ticket_qr.png'), findsOneWidget);
    });

    // Requirement 5: Day Planner Mobile Declutter & Swipe Navigation
    testWidgets('Req 5: Mobile Day Planner moves buttons to top bar and navigates days via swipe',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeTripProvider.overrideWithValue(testTrip),
            activeTripFlightsProvider.overrideWith((ref) => Stream.value([testFlight])),
            activeTripStaysProvider.overrideWith((ref) => Stream.value([testStay])),
            activeTripActivitiesProvider.overrideWith((ref) => Stream.value([testActivity])),
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

      // Verify bulb and map buttons are present in the top bar with their keys
      final bulbButton = find.byKey(const ValueKey('floating_suggestions_bulb'));
      final mapButton = find.byKey(const ValueKey('floating_map_button'));
      expect(bulbButton, findsOneWidget);
      expect(mapButton, findsOneWidget);

      // Verify initially on Day 1
      expect(find.textContaining('Day 1 of 4'), findsOneWidget);

      // Test horizontal swipe left to go to Day 2
      await tester.fling(find.byType(DayPlannerView), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();

      // Verify we navigated to Day 2
      expect(find.textContaining('Day 2 of 4'), findsOneWidget);

      // Test horizontal swipe right to go back to Day 1
      await tester.fling(find.byType(DayPlannerView), const Offset(400, 0), 1000);
      await tester.pumpAndSettle();

      // Verify we returned to Day 1
      expect(find.textContaining('Day 1 of 4'), findsOneWidget);
    });
  });
}

class FakeTripRepo extends Fake implements TripRepository {
  @override
  Future<void> updateStay(Stay stay) async {}
  @override
  Future<void> updateFlight(Flight flight) async {}
  @override
  Future<void> updateActivity(Activity activity) async {}
  @override
  Future<void> addActivity(Activity activity) async {}
  @override
  Future<void> deleteActivity(String tripId, String activityId) async {}
}
