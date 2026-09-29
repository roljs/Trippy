import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trippy/core/utils/city_color_helper.dart';
import 'package:trippy/data/repositories/mock_trip_repository.dart';
import 'package:trippy/models/models.dart';
import 'package:trippy/state/trip_providers.dart';
import 'package:trippy/views/attractions/attractions_view.dart';
import 'package:trippy/views/common/add_activity_sheet.dart';
import 'package:trippy/views/common/add_flight_sheet.dart';
import 'package:trippy/views/common/add_stay_sheet.dart';

class _FakeActiveTripIdNotifier extends ActiveTripIdNotifier {
  final String? _initialId;
  _FakeActiveTripIdNotifier(this._initialId);

  @override
  String? build() => _initialId;
}

void main() {
  group('New Activity, Stay & Flight Features Tests', () {
    late MockTripRepository mockRepo;
    late Trip testTrip;

    setUp(() async {
      mockRepo = MockTripRepository();
      testTrip = Trip(
        id: 'test_trip_1',
        title: 'Asia Adventure',
        destination: 'Tokyo & Bangkok',
        startDate: DateTime(2026, 11, 1),
        endDate: DateTime(2026, 11, 10),
        ownerId: 'user_1',
        inviteCode: 'ASIA-26',
        members: {'user_1': MemberRole.owner},
        createdAt: DateTime(2026, 10, 1),
        updatedAt: DateTime(2026, 10, 1),
      );
      await mockRepo.createTrip(testTrip);
    });

    testWidgets('1) AddActivitySheet initializes with provided initialDate',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final targetDate = DateTime(2026, 11, 5);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeTripIdProvider.overrideWith(() => _FakeActiveTripIdNotifier(testTrip.id)),
            activeTripProvider.overrideWith((ref) => testTrip),
            tripRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: AddActivitySheet(initialDate: targetDate),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check that Day 5 is selected in dropdown
      expect(find.textContaining('Day 5'), findsWidgets);
    });

    testWidgets(
        '2) ActivityCategory.stay allows selecting stay, quick-filling check-in/out, and saving stayId',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final hotelStay = Stay(
        id: 'stay_hotel_1',
        tripId: testTrip.id,
        type: StayType.hotel,
        name: 'Grand Hyatt Tokyo',
        address: 'Roppongi, Tokyo, Japan',
        checkInDate: DateTime(2026, 11, 2),
        checkInTime: '15:00',
        checkOutDate: DateTime(2026, 11, 5),
        checkOutTime: '11:00',
        confirmationCode: 'GH-8899',
        notes: 'Requested high floor room',
      );
      await mockRepo.addStay(hotelStay);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeTripIdProvider.overrideWith(() => _FakeActiveTripIdNotifier(testTrip.id)),
            activeTripProvider.overrideWith((ref) => testTrip),
            tripRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AddActivitySheet(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Select Stay category chip
      final stayChip = find.text('Hotel & Stay');
      expect(stayChip, findsOneWidget);
      await tester.tap(stayChip);
      await tester.pumpAndSettle();

      // Check stay section is displayed
      expect(find.text('Link to Hotel / Stay'), findsOneWidget);
      expect(find.text('Grand Hyatt Tokyo'), findsWidgets);

      // Tap Quick: Check-in button
      final checkInBtn = find.text('Quick: Check-in');
      expect(checkInBtn, findsOneWidget);
      await tester.tap(checkInBtn);
      await tester.pumpAndSettle();

      // Check fields auto-filled
      expect(find.text('Check-in: Grand Hyatt Tokyo'), findsOneWidget);
      expect(find.text('Roppongi, Tokyo, Japan'), findsWidgets);
      expect(find.text('GH-8899'), findsWidgets);

      // Save activity
      final saveBtn = find.text('Add to Day');
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Verify activity in repository
      final activities = await mockRepo.getActivities(testTrip.id);
      final checkInActivity = activities.where((a) => a.title.contains('Check-in: Grand Hyatt Tokyo')).firstOrNull;
      expect(checkInActivity, isNotNull);
      expect(checkInActivity!.category, ActivityCategory.stay);
      expect(checkInActivity.stayId, hotelStay.id);
      expect(checkInActivity.confirmationRef, 'GH-8899');
    });

    testWidgets(
        '3) AddStaySheet option automatically creates check-in and check-out activities',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
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
            home: Scaffold(
              body: AddStaySheet(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter stay details
      await tester.enterText(
        find.widgetWithText(TextField, 'Lodging Name'),
        'Nikko Ryokan Suites',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Address'),
        'Nikko, Japan',
      );

      // Verify the auto-create activities checkbox is visible and checked
      expect(find.text('Automatically create Check-in & Check-out activities'), findsOneWidget);

      // Tap Add Stay Bridge
      final addBtn = find.text('Add Stay Bridge');
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      // Verify repo has check-in and check-out activities
      final activities = await mockRepo.getActivities(testTrip.id);
      expect(activities.any((a) => a.title == 'Check-in: Nikko Ryokan Suites'), isTrue);
      expect(activities.any((a) => a.title == 'Check-out: Nikko Ryokan Suites'), isTrue);
    });

    testWidgets(
        '4) AddFlightSheet option automatically creates airport ground transfer activities',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
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
            home: Scaffold(
              body: AddFlightSheet(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Airline'),
        'Japan Airlines',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Flight #'),
        'JL0068',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Departure Airport'),
        'SEA',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Arrival Airport'),
        'HND',
      );
      await tester.pumpAndSettle();

      // Check ground transfer section is present
      expect(find.text('Airport Ground Transfers'), findsOneWidget);

      // Check both transfer checkboxes
      final depTransferTile = find.textContaining('Transfer: Hotel to SEA Airport');
      final arrTransferTile = find.textContaining('Transfer: HND Airport to Hotel');
      expect(depTransferTile, findsOneWidget);
      expect(arrTransferTile, findsOneWidget);

      await tester.ensureVisible(depTransferTile);
      await tester.tap(depTransferTile);
      await tester.ensureVisible(arrTransferTile);
      await tester.tap(arrTransferTile);
      await tester.pumpAndSettle();

      // Save flight
      final addFlightBtn = find.text('Add Flight');
      await tester.ensureVisible(addFlightBtn);
      await tester.tap(addFlightBtn);
      await tester.pumpAndSettle();

      // Verify ground transport activities in repo
      final activities = await mockRepo.getActivities(testTrip.id);
      expect(activities.any((a) => a.title.contains('Transport: Hotel to SEA Airport')), isTrue);
      expect(activities.any((a) => a.title.contains('Transport: HND Airport to Hotel')), isTrue);
    });

    testWidgets(
        '5) AttractionsView allows grouping by Day or Category and filtering by date range',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Seed activities across different days and categories
      final act1 = Activity(
        id: 'act_1',
        tripId: testTrip.id,
        date: DateTime(2026, 11, 2),
        startTime: '10:00',
        title: 'Asakusa Sensoji Temple',
        category: ActivityCategory.attraction,
      );
      final act2 = Activity(
        id: 'act_2',
        tripId: testTrip.id,
        date: DateTime(2026, 11, 2),
        startTime: '13:00',
        title: 'Ramen Tasting Lunch',
        category: ActivityCategory.dining,
      );
      final act3 = Activity(
        id: 'act_3',
        tripId: testTrip.id,
        date: DateTime(2026, 11, 4),
        startTime: '15:00',
        title: 'Check-in: Bay Hotel Tokyo',
        category: ActivityCategory.stay,
      );
      await mockRepo.addActivity(act1);
      await mockRepo.addActivity(act2);
      await mockRepo.addActivity(act3);

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

      // By default grouped by Day
      expect(find.textContaining('Day 2'), findsWidgets);
      expect(find.textContaining('Day 4'), findsWidgets);

      // Switch grouping to By Category
      final byCategoryBtn = find.text('By Category');
      await tester.tap(byCategoryBtn);
      await tester.pumpAndSettle();

      // Check category headers
      expect(find.text('Attraction'), findsWidgets);
      expect(find.text('Food & Dining'), findsWidgets);
      expect(find.text('Hotel & Stay'), findsWidgets);
    });

    test('6) CityColorHelper ensures stays in same city have identical color and multi-city rows use first city', () {
      final stayTokyo1 = Stay(
        id: 's1',
        tripId: 't',
        type: StayType.hotel,
        name: 'APA Hotel Asakusa',
        address: 'Tokyo, Japan',
        checkInDate: DateTime(2026, 11, 2),
        checkOutDate: DateTime(2026, 11, 3),
      );
      final stayNikko = Stay(
        id: 's2',
        tripId: 't',
        type: StayType.hotel,
        name: 'Nikko Ryokan',
        address: 'Nikko, Tochigi Prefecture, Japan',
        checkInDate: DateTime(2026, 11, 3),
        checkOutDate: DateTime(2026, 11, 4),
      );
      final stayTokyo2 = Stay(
        id: 's3',
        tripId: 't',
        type: StayType.hotel,
        name: 'Bay Hotel Tokyo Hamamatsucho',
        address: 'Minato-ku, Tokyo, Japan',
        checkInDate: DateTime(2026, 11, 4),
        checkOutDate: DateTime(2026, 11, 5),
      );

      final allStays = [stayTokyo1, stayNikko, stayTokyo2];

      // Stays in Tokyo must have the exact same gradient palette
      final paletteTokyo1 = CityColorHelper.getStayPalette(stay: stayTokyo1, allStaysInTrip: allStays);
      final paletteTokyo2 = CityColorHelper.getStayPalette(stay: stayTokyo2, allStaysInTrip: allStays);
      final paletteNikko = CityColorHelper.getStayPalette(stay: stayNikko, allStaysInTrip: allStays);

      expect(paletteTokyo1.gradient, equals(paletteTokyo2.gradient));
      expect(paletteTokyo1.gradient, isNot(equals(paletteNikko.gradient)));

      // Overnight flight stays get the flight palette
      final overnightFlightStay = Stay(
        id: 's_flt',
        tripId: 't',
        type: StayType.overnightFlight,
        name: 'Flight JL0068',
        checkInDate: DateTime(2026, 11, 1),
        checkOutDate: DateTime(2026, 11, 2),
      );
      final flightPalette = CityColorHelper.getStayPalette(stay: overnightFlightStay, allStaysInTrip: allStays);
      expect(flightPalette, equals(CityColorHelper.flightPalette));

      // Compact view row color uses the FIRST chronologically visited city
      final firstCityTokyoNikko = CityColorHelper.extractFirstCityForDay(
        placesToVisit: 'Tokyo, Nikko',
        sleepAt: 'Nikko Ryokan',
        previousSleepAt: null,
        dayFlights: [],
        dayActivities: [],
      );
      expect(firstCityTokyoNikko, equals('Tokyo'));

      final firstCityNikkoTokyo = CityColorHelper.extractFirstCityForDay(
        placesToVisit: 'Nikko, Tokyo',
        sleepAt: 'Bay Hotel Tokyo',
        previousSleepAt: null,
        dayFlights: [],
        dayActivities: [],
      );
      expect(firstCityNikkoTokyo, equals('Nikko'));

      // If placesToVisit is empty but sleepAt is present
      final firstCityFromStay = CityColorHelper.extractFirstCityForDay(
        placesToVisit: '',
        sleepAt: 'Bangkok',
        previousSleepAt: null,
        dayFlights: [],
        dayActivities: [],
      );
      expect(firstCityFromStay, equals('Bangkok'));

      // If flight transit (e.g. Volar), extractFirstCityForDay returns null, and flight pastel is used
      final flightCity = CityColorHelper.extractFirstCityForDay(
        placesToVisit: 'Volar',
        sleepAt: 'Avión',
        previousSleepAt: null,
        dayFlights: [],
        dayActivities: [],
      );
      expect(flightCity, isNull);
      expect(CityColorHelper.flightPastel, isNotNull);
    });
  });
}
