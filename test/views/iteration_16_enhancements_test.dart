import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trippy/core/utils/trip_map_helper.dart';
import 'package:trippy/data/repositories/mock_trip_repository.dart';
import 'package:trippy/models/models.dart';
import 'package:trippy/state/trip_providers.dart';
import 'package:trippy/views/attractions/attractions_view.dart';
import 'package:trippy/views/common/app_nav_scaffold.dart';
import 'package:trippy/views/flights/flights_view.dart';
import 'package:trippy/views/logistics/widgets/calendar_itinerary_view.dart';
import 'package:trippy/views/logistics/widgets/compact_itinerary_view.dart';

class _FakeActiveTripIdNotifier extends ActiveTripIdNotifier {
  final String? _initialId;
  _FakeActiveTripIdNotifier(this._initialId);

  @override
  String? build() => _initialId;
}

void main() {
  group('Iteration #16 Requirements Tests', () {
    late MockTripRepository mockRepo;
    late Trip testTrip;
    final baseDate = DateTime(2026, 11, 1);

    setUp(() async {
      mockRepo = MockTripRepository();
      testTrip = Trip(
        id: 'trip_iter16',
        title: 'Pacific Northwest & Beyond Grand Tour',
        destination: 'Bellevue, WA',
        startDate: baseDate,
        endDate: baseDate.add(const Duration(days: 9)),
        ownerId: 'user_1',
        inviteCode: 'TRIP16',
        members: {'user_1': MemberRole.owner},
        createdAt: DateTime(2026, 10, 1),
        updatedAt: DateTime(2026, 10, 1),
      );
      await mockRepo.createTrip(testTrip);
    });

    testWidgets('Req 1 & 7: "Day" navigation label and mobile trip code hiding in AppNavScaffold',
        (tester) async {
      // 1) Test Desktop view (width 1200): Trip code chip is visible and "Day" label is shown
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeTripIdProvider.overrideWith(() => _FakeActiveTripIdNotifier(testTrip.id)),
            activeTripProvider.overrideWith((ref) => testTrip),
            tripRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: AppNavScaffold(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Req 1: Label of "Day Planner" tab changed to "Day"
      expect(find.text('Day'), findsOneWidget);
      expect(find.text('Day Planner'), findsNothing);

      // Desktop: Trip code chip should be visible
      expect(find.textContaining('TRIP16'), findsOneWidget);

      // 2) Test Mobile view (width 400): Trip code chip is hidden so title is not truncated
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeTripIdProvider.overrideWith(() => _FakeActiveTripIdNotifier(testTrip.id)),
            activeTripProvider.overrideWith((ref) => testTrip),
            tripRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: AppNavScaffold(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Mobile: Trip code chip is removed from AppBar
      expect(find.textContaining('TRIP16'), findsNothing);
      expect(find.text('Day'), findsOneWidget);
    });

    test('Req 4: 3942 W Lake Sammamish Pkwy SE coordinates resolve accurately to West Shore', () {
      final coords1 = TripMapHelper.resolveCoordinates(
        '3942 W Lake Sammamish Pkwy SE, Bellevue, WA 98008, USA',
        contextCountry: 'United States',
      );
      expect(coords1.lat, closeTo(47.5747, 0.01));
      // West shore is around -122.1235 (not the east shore -122.0356 / -122.1093)
      expect(coords1.lng, closeTo(-122.1235, 0.01));

      final coords2 = TripMapHelper.resolveCoordinates(
        '3942 West Lake Sammamish Parkway SE, Bellevue, WA 98008',
      );
      expect(coords2.lat, closeTo(47.5747, 0.01));
      expect(coords2.lng, closeTo(-122.1235, 0.01));
    });

    testWidgets('Req 2: Calendar view removes stay overlay and shows stay icon in bottom right corner',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final testStay = Stay(
        id: 'stay_1',
        tripId: testTrip.id,
        type: StayType.hotel,
        name: 'Bellevue Club Hotel',
        address: 'Bellevue, WA',
        checkInDate: baseDate,
        checkOutDate: baseDate.add(const Duration(days: 2)),
      );
      await mockRepo.addStay(testStay);

      Stay? tappedStay;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeTripIdProvider.overrideWith(() => _FakeActiveTripIdNotifier(testTrip.id)),
            activeTripProvider.overrideWith((ref) => testTrip),
            tripRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: CalendarItineraryView(
                trip: testTrip,
                stays: [testStay],
                flights: const [],
                activitiesByDay: const {},
                onStayTap: (s) => tappedStay = s,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Stay overlays are removed: hotel name does not clutter the day square
      expect(find.text('Bellevue Club Hotel'), findsNothing);

      // Small stay icon is shown on the bottom right corner
      final stayIconFinder = find.byIcon(Icons.hotel_rounded);
      expect(stayIconFinder, findsWidgets);

      // Tapping the stay icon triggers onStayTap to show Stay details
      await tester.tap(stayIconFinder.first);
      await tester.pumpAndSettle();
      expect(tappedStay, equals(testStay));

      // City / location name is rendered inside subtle rounded outline rectangle
      expect(find.text('WA'), findsWidgets);
    });

    testWidgets('Req 3: Compact view consolidates Day of the Week under Date and shows Sleep At after Date',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeTripIdProvider.overrideWith(() => _FakeActiveTripIdNotifier(testTrip.id)),
            activeTripProvider.overrideWith((ref) => testTrip),
            tripRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: CompactItineraryView(
                trip: testTrip,
                stays: const [],
                flights: const [],
                activitiesByDay: const {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Header row check:
      // "Date" exists, "Day of the Week" header does NOT exist as a separate header column
      expect(find.text('Date'), findsOneWidget);
      expect(find.text('Day of the Week'), findsNothing);

      // "Sleep At" should be present
      expect(find.text('Sleep At'), findsOneWidget);
      expect(find.text('Places to Visit'), findsOneWidget);

      // Verify day of the week label is shown under the date in the table cells (e.g., Sunday, Monday)
      expect(find.text('Sunday'), findsWidgets);
    });

    testWidgets('Req 5: Flight card renders Origin, Graphic, and Destination with responsive flex on mobile',
        (tester) async {
      // Test mobile screen width 360
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final flight = Flight(
        id: 'flt_1',
        tripId: testTrip.id,
        airline: 'Delta Air Lines',
        flightNumber: 'DL0167',
        departureAirport: 'Seattle-Tacoma International Airport (SEA)',
        arrivalAirport: 'Tokyo Haneda International Airport (HND)',
        departureTime: baseDate.add(const Duration(hours: 11, minutes: 25)),
        arrivalTime: baseDate.add(const Duration(days: 1, hours: 15, minutes: 5)),
        isOvernight: true,
      );
      await mockRepo.addFlight(flight);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeTripIdProvider.overrideWith(() => _FakeActiveTripIdNotifier(testTrip.id)),
            activeTripProvider.overrideWith((ref) => testTrip),
            tripRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: FlightsView(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Flight card duration graphic and non-stop text render cleanly without overflow
      expect(find.text('DL0167'), findsOneWidget);
      expect(find.text('Non-stop'), findsOneWidget);
      expect(find.byIcon(Icons.flight), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Req 6: Activities tab excludes stay check-ins/check-outs, flight entries, and Stays filter chip',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // 1. Real activity: Attraction
      final actAttraction = Activity(
        id: 'act_attract_1',
        tripId: testTrip.id,
        date: baseDate.add(const Duration(days: 1)),
        startTime: '10:00',
        title: 'Space Needle Observation Deck',
        category: ActivityCategory.attraction,
      );
      // 2. Real activity: Dining
      final actDining = Activity(
        id: 'act_dining_1',
        tripId: testTrip.id,
        date: baseDate.add(const Duration(days: 1)),
        startTime: '13:00',
        title: 'Pike Place Chowder Lunch',
        category: ActivityCategory.dining,
      );
      // 3. Real activity: Ground Transfer
      final actTransfer = Activity(
        id: 'act_xfer_1',
        tripId: testTrip.id,
        date: baseDate,
        startTime: '08:00',
        title: 'Transport: Bellevue to SEA Airport',
        category: ActivityCategory.transport,
        transportDirection: 'to_airport',
      );
      // 4. Non-real activity: Stay check-in
      final actCheckIn = Activity(
        id: 'act_stay_1',
        tripId: testTrip.id,
        date: baseDate,
        startTime: '15:00',
        title: 'Check-in: Bellevue Club Hotel',
        category: ActivityCategory.stay,
      );
      // 5. Non-real activity: Flight entry
      final actFlight = Activity(
        id: 'act_flt_entry_1',
        tripId: testTrip.id,
        date: baseDate,
        startTime: '11:25',
        title: 'DL0167 Departure Flight: SEA to HND',
        category: ActivityCategory.transport,
      );

      await mockRepo.addActivity(actAttraction);
      await mockRepo.addActivity(actDining);
      await mockRepo.addActivity(actTransfer);
      await mockRepo.addActivity(actCheckIn);
      await mockRepo.addActivity(actFlight);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeTripIdProvider.overrideWith(() => _FakeActiveTripIdNotifier(testTrip.id)),
            activeTripProvider.overrideWith((ref) => testTrip),
            tripRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AttractionsView(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Real activities should be displayed
      expect(find.text('Space Needle Observation Deck'), findsOneWidget);
      expect(find.text('Pike Place Chowder Lunch'), findsOneWidget);
      expect(find.text('Transport: Bellevue to SEA Airport'), findsOneWidget);

      // Stays and Flight entries should NOT be displayed
      expect(find.text('Check-in: Bellevue Club Hotel'), findsNothing);
      expect(find.text('DL0167 Departure Flight: SEA to HND'), findsNothing);

      // Stays category filter chip should be removed
      expect(find.widgetWithText(FilterChip, 'Stays'), findsNothing);
      // Other category chips should still be present
      expect(find.widgetWithText(FilterChip, 'Attractions'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'Dining'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'Transport'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'Entertainment'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'Other'), findsOneWidget);
    });
  });
}
