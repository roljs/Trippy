import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trippy/data/repositories/mock_trip_repository.dart';
import 'package:trippy/models/models.dart';
import 'package:trippy/state/trip_providers.dart';
import 'package:trippy/views/attractions/attractions_view.dart';
import 'package:trippy/views/common/add_flight_sheet.dart';
import 'package:trippy/views/logistics/widgets/calendar_itinerary_view.dart';

class _FakeActiveTripIdNotifier extends ActiveTripIdNotifier {
  final String? _initialId;
  _FakeActiveTripIdNotifier(this._initialId);

  @override
  String? build() => _initialId;
}

void main() {
  group('Iteration #17 Requirements Tests', () {
    late MockTripRepository mockRepo;
    late Trip testTrip;
    final day1 = DateTime(2026, 11, 1);
    final day2 = DateTime(2026, 11, 2);
    final day3 = DateTime(2026, 11, 3);
    final day4 = DateTime(2026, 11, 4);
    final day5 = DateTime(2026, 11, 5);

    setUp(() async {
      mockRepo = MockTripRepository();
      testTrip = Trip(
        id: 'trip_iter17',
        title: 'Japan Odyssey Exploration',
        destination: 'Tokyo, Japan',
        startDate: day1,
        endDate: day5,
        ownerId: 'user_1',
        inviteCode: 'TRIP17',
        members: {'user_1': MemberRole.owner},
        dayLocations: {
          Trip.dateToKey(day1): ['Japan', 'Tokyo'],
          Trip.dateToKey(day2): ['Tokyo'],
          Trip.dateToKey(day3): ['Tokyo', 'Nikko'],
        },
        createdAt: DateTime(2026, 10, 1),
        updatedAt: DateTime(2026, 10, 1),
      );
      await mockRepo.createTrip(testTrip);
    });

    testWidgets('Req 1: Calendar view renders main stay city in rectangle and other locations in small gray font on top',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final stayTokyo = Stay(
        id: 'stay_tokyo_1',
        tripId: testTrip.id,
        type: StayType.hotel,
        name: 'Grand Hyatt Tokyo',
        address: 'Roppongi Hills, Tokyo, Japan',
        checkInDate: day1,
        checkOutDate: day3,
      );

      final stayNikko = Stay(
        id: 'stay_nikko_2',
        tripId: testTrip.id,
        type: StayType.hotel,
        name: 'Nikko Ryokan',
        address: 'Nikko, Tochigi Prefecture, Japan',
        checkInDate: day3,
        checkOutDate: day4,
      );

      await mockRepo.addStay(stayTokyo);
      await mockRepo.addStay(stayNikko);

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
                stays: [stayTokyo, stayNikko],
                flights: const [],
                activitiesByDay: const {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1) On Day 1: dayLocations has ['Japan', 'Tokyo']. Stay is in Tokyo.
      // 'Tokyo' is in bigger font inside a rectangle.
      // 'Japan' is in small grayed-out font on top of the Tokyo rectangle.
      expect(
        find.byWidgetPredicate((w) =>
            w is Text &&
            w.data == 'Japan' &&
            w.style?.fontSize == 10 &&
            w.style?.color == const Color(0xFF64748B)),
        findsWidgets,
      );

      expect(
        find.byWidgetPredicate((w) =>
            w is Text &&
            w.data == 'Tokyo' &&
            w.style?.fontSize == 13.5 &&
            w.style?.fontWeight == FontWeight.w800),
        findsWidgets,
      );

      // 2) On Day 3 (baseDate + 2 days): dayLocations has ['Tokyo', 'Nikko']. Stay is in Nikko (Nikko Ryokan).
      // 'Nikko' is the city where you are staying -> inside the rectangle with bigger font.
      // 'Tokyo' is the other city -> on top in small gray font.
      expect(
        find.byWidgetPredicate((w) =>
            w is Text &&
            w.data == 'Nikko' &&
            w.style?.fontSize == 13.5 &&
            w.style?.fontWeight == FontWeight.w800),
        findsWidgets,
      );
      expect(
        find.byWidgetPredicate((w) =>
            w is Text &&
            w.data == 'Tokyo' &&
            w.style?.fontSize == 10 &&
            w.style?.color == const Color(0xFF64748B)),
        findsWidgets,
      );

      // 3) On Day 2 (baseDate + 1 day): dayLocations has single location ['Tokyo'].
      // Only Tokyo inside rectangle is rendered, no gray text on top.
      expect(find.text('Day 2'), findsOneWidget);
    });

    testWidgets('Req 2: Transfer activity flight icon takes minimal UI real estate so activity title is shown fully',
        (tester) async {
      // Test under a compact/mobile screen width (e.g. 390x844 iPhone width)
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final testFlight = Flight(
        id: 'flt_nh_11',
        tripId: testTrip.id,
        airline: 'All Nippon Airways',
        flightNumber: 'NH11',
        departureAirport: 'NRT',
        arrivalAirport: 'ORD',
        departureTime: day1.add(const Duration(hours: 10)),
        arrivalTime: day1.add(const Duration(hours: 22)),
      );
      await mockRepo.addFlight(testFlight);

      const fullTransferTitle = 'Airport Ground Transfer: Hotel to Narita International Airport Terminal 1';
      final transferActivity = Activity(
        id: 'act_transfer_1',
        tripId: testTrip.id,
        flightId: testFlight.id,
        date: day1,
        startTime: '07:30',
        title: fullTransferTitle,
        category: ActivityCategory.transport,
        location: 'Narita Terminal 1',
      );
      await mockRepo.addActivity(transferActivity);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(mockRepo),
            activeTripProvider.overrideWithValue(testTrip),
            activeTripFlightsProvider.overrideWith((ref) => Stream.value([testFlight])),
            activeTripActivitiesProvider.overrideWith((ref) => Stream.value([transferActivity])),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AttractionsView(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the activity title is present and rendered fully in the card
      expect(find.text(fullTransferTitle), findsOneWidget);

      // Verify the title row does NOT contain the full flight badge text in the title Row
      // Previously, the title row contained 'NH11 (All Nippon Airways)' taking ~200px width.
      // Now, the flight details row is cleanly rendered in the subtitle:
      expect(find.text('NH11 (All Nippon Airways)'), findsOneWidget);

      // Verify a minimal flight icon container is rendered in the title row
      final flightIconFinder = find.byIcon(Icons.flight_takeoff_rounded);
      expect(flightIconFinder, findsWidgets);

      // Verify the flight icon container has compact padding
      final containerFinder = find.ancestor(
        of: flightIconFinder.first,
        matching: find.byType(Container),
      );
      expect(containerFinder, findsWidgets);

      // Tapping the flight icon opens the flight details sheet
      await tester.tap(flightIconFinder.first);
      await tester.pumpAndSettle();
      expect(find.byType(AddFlightSheet), findsOneWidget);
    });
  });
}
