import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trippy/data/repositories/mock_trip_repository.dart';
import 'package:trippy/models/models.dart';
import 'package:trippy/state/trip_providers.dart';
import 'package:trippy/views/attractions/attractions_view.dart';
import 'package:trippy/views/common/add_flight_sheet.dart';
import 'package:trippy/views/common/add_stay_sheet.dart';
import 'package:trippy/views/stays/stays_view.dart';

void main() {
  group('Stay & Check-in/out Activity Bi-directional Linking & Cascading Delete', () {
    late MockTripRepository repo;
    late Trip trip;
    late Stay stay;
    late Activity checkInActivity;
    late Activity checkOutActivity;

    setUp(() async {
      repo = MockTripRepository();
      final now = DateTime.now();

      trip = Trip(
        id: 'test_trip_200',
        title: 'Swiss Alps Tour',
        destination: 'Zermatt, Switzerland',
        startDate: now,
        endDate: now.add(const Duration(days: 6)),
        ownerId: 'user_current',
        inviteCode: 'CHE-200',
        defaultInviteRole: MemberRole.editor,
        members: const {'user_current': MemberRole.owner},
        createdAt: now,
        updatedAt: now,
      );
      await repo.createTrip(trip);

      stay = Stay(
        id: 'stay_hotel_200',
        tripId: trip.id,
        type: StayType.hotel,
        name: 'The Chedi Andermatt',
        address: 'Gotthardstrasse 4, 6490 Andermatt',
        checkInDate: now.add(const Duration(days: 1)),
        checkInTime: '15:00',
        checkOutDate: now.add(const Duration(days: 4)),
        checkOutTime: '11:00',
        confirmationCode: 'CHEDI-8899',
        linkedActivityIds: const ['act_checkin_200', 'act_checkout_200'],
      );
      await repo.addStay(stay);

      checkInActivity = Activity(
        id: 'act_checkin_200',
        tripId: trip.id,
        stayId: stay.id,
        date: now.add(const Duration(days: 1)),
        startTime: '15:00',
        title: 'Check-in: The Chedi Andermatt',
        category: ActivityCategory.stay,
        location: 'Gotthardstrasse 4, 6490 Andermatt',
      );
      checkOutActivity = Activity(
        id: 'act_checkout_200',
        tripId: trip.id,
        stayId: stay.id,
        date: now.add(const Duration(days: 4)),
        startTime: '11:00',
        title: 'Check-out: The Chedi Andermatt',
        category: ActivityCategory.stay,
        location: 'Gotthardstrasse 4, 6490 Andermatt',
      );
      await repo.addActivity(checkInActivity);
      await repo.addActivity(checkOutActivity);
    });

    test('Stay preserves linkedActivityIds and Activity preserves stayId', () async {
      final fetchedStays = await repo.getStays(trip.id);
      expect(fetchedStays.first.linkedActivityIds, containsAll(['act_checkin_200', 'act_checkout_200']));

      final fetchedActivities = await repo.getActivities(trip.id);
      expect(fetchedActivities.firstWhere((a) => a.id == 'act_checkin_200').stayId, 'stay_hotel_200');
      expect(fetchedActivities.firstWhere((a) => a.id == 'act_checkout_200').stayId, 'stay_hotel_200');
    });

    test('Stay model serialization includes linkedActivityIds', () {
      final map = stay.toMap();
      expect(map['linkedActivityIds'], ['act_checkin_200', 'act_checkout_200']);

      final restoredStay = Stay.fromMap(map);
      expect(restoredStay.linkedActivityIds, ['act_checkin_200', 'act_checkout_200']);
    });

    test('Deleting an activity unlinks it from the stay', () async {
      await repo.deleteActivity(trip.id, 'act_checkin_200');

      final fetchedStays = await repo.getStays(trip.id);
      expect(fetchedStays.first.linkedActivityIds, isNot(contains('act_checkin_200')));
      expect(fetchedStays.first.linkedActivityIds, contains('act_checkout_200'));
    });

    test('Deleting a stay automatically cascades and deletes linked check-in/out activities', () async {
      final initialActivities = await repo.getActivities(trip.id);
      expect(initialActivities.length, 2);

      await repo.deleteStay(trip.id, 'stay_hotel_200');

      final remainingStays = await repo.getStays(trip.id);
      expect(remainingStays, isEmpty);

      final remainingActivities = await repo.getActivities(trip.id);
      expect(remainingActivities, isEmpty);
    });

    testWidgets('StaysView displays Check-in / Check-out Activities section and Link button', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(repo),
            activeTripProvider.overrideWithValue(trip),
            activeTripStaysProvider.overrideWith((ref) => Stream.value([stay])),
            activeTripActivitiesProvider.overrideWith((ref) => Stream.value([checkInActivity, checkOutActivity])),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: StaysView(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Check-in / Check-out Activities section is rendered
      expect(find.textContaining('Check-in / Check-out Activities (2)'), findsOneWidget);
      expect(find.text('Check-in: The Chedi Andermatt'), findsOneWidget);
      expect(find.text('Check-out: The Chedi Andermatt'), findsOneWidget);
      expect(find.text('Link Activity'), findsOneWidget);
    });

    testWidgets('StaysView unlinks an activity when unlink button is pressed', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(repo),
            activeTripProvider.overrideWithValue(trip),
            activeTripStaysProvider.overrideWith((ref) => Stream.value([stay])),
            activeTripActivitiesProvider.overrideWith((ref) => Stream.value([checkInActivity, checkOutActivity])),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: StaysView(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final unlinkButtons = find.byTooltip('Unlink Activity');
      expect(unlinkButtons, findsNWidgets(2));

      await tester.tap(unlinkButtons.first);
      await tester.pumpAndSettle();

      final updatedStays = await repo.getStays(trip.id);
      expect(updatedStays.first.linkedActivityIds.length, 1);
    });

    testWidgets('AttractionsView displays linked stay badge with stay name', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(repo),
            activeTripProvider.overrideWithValue(trip),
            activeTripStaysProvider.overrideWith((ref) => Stream.value([stay])),
            activeTripActivitiesProvider.overrideWith((ref) => Stream.value([checkInActivity])),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AttractionsView(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the stay badge renders with stay name
      expect(find.text('The Chedi Andermatt'), findsWidgets);
    });

    testWidgets('AddStaySheet displays linked check-in/out activities, link button, and does not duplicate on save', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(repo),
            activeTripProvider.overrideWithValue(trip),
            activeTripStaysProvider.overrideWith((ref) => Stream.value([stay])),
            activeTripActivitiesProvider.overrideWith((ref) => Stream.value([checkInActivity, checkOutActivity])),
            activeTripFlightsProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: AddStaySheet(stayToEdit: stay),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check that linked activities section renders
      expect(find.textContaining('Linked Check-in / Check-out Activities (2)'), findsOneWidget);
      expect(find.text('Check-in: The Chedi Andermatt'), findsOneWidget);
      expect(find.text('Check-out: The Chedi Andermatt'), findsOneWidget);
      expect(find.text('Link Activity'), findsOneWidget);
      expect(find.text('Sync linked Check-in & Check-out activities'), findsOneWidget);

      // Tap "Save Changes"
      final saveButton = find.text('Save Changes');
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Verify that no duplicate activities were created
      final allActivities = await repo.getActivities(trip.id);
      expect(allActivities.length, 2);
    });

    testWidgets('AddFlightSheet displays linked transfers, link button, and does not duplicate on save', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final now = DateTime.now();
      final testFlight = Flight(
        id: 'flt_swiss_200',
        tripId: trip.id,
        airline: 'Swiss Air',
        flightNumber: 'LX123',
        departureAirport: 'ZRH (Zurich)',
        arrivalAirport: 'GVA (Geneva)',
        departureTime: now.add(const Duration(days: 1, hours: 10)),
        arrivalTime: now.add(const Duration(days: 1, hours: 11)),
        linkedActivityIds: const ['act_transfer_200'],
      );
      await repo.addFlight(testFlight);

      final testTransfer = Activity(
        id: 'act_transfer_200',
        tripId: trip.id,
        flightId: testFlight.id,
        date: now.add(const Duration(days: 1)),
        startTime: '08:00',
        title: 'Transport: Hotel to ZRH Airport',
        category: ActivityCategory.transport,
        location: 'ZRH Airport',
      );
      await repo.addActivity(testTransfer);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(repo),
            activeTripProvider.overrideWithValue(trip),
            activeTripStaysProvider.overrideWith((ref) => Stream.value([stay])),
            activeTripActivitiesProvider.overrideWith((ref) => Stream.value([checkInActivity, checkOutActivity, testTransfer])),
            activeTripFlightsProvider.overrideWith((ref) => Stream.value([testFlight])),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: AddFlightSheet(flightToEdit: testFlight),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check that linked transfers section renders
      expect(find.textContaining('Linked Airport Ground Transfers (1)'), findsOneWidget);
      expect(find.text('Transport: Hotel to ZRH Airport'), findsOneWidget);
      expect(find.text('Link Transfer'), findsOneWidget);

      // Tap "Save Changes"
      final saveButton = find.text('Save Changes');
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Verify no duplicate transfer activities created
      final allActivities = await repo.getActivities(trip.id);
      final transfers = allActivities.where((a) => a.category == ActivityCategory.transport).toList();
      expect(transfers.length, 1);
    });
  });
}
