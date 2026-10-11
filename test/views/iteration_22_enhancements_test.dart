import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trippy/data/repositories/mock_trip_repository.dart';
import 'package:trippy/data/repositories/trip_repository.dart';
import 'package:trippy/models/models.dart';
import 'package:trippy/state/trip_providers.dart';
import 'package:trippy/views/common/modification_source_badge.dart';
import 'package:trippy/views/day_planner/day_planner_view.dart';

class TestTripRepository extends MockTripRepository {
  final List<Activity> updatedActivities = [];

  @override
  Future<void> updateActivity(Activity activity) async {
    updatedActivities.add(activity);
    await super.updateActivity(activity);
  }
}

void main() {
  group('Iteration #22 - Model & ModificationSourceBadge Tests', () {
    test('Activity tracks lastModifiedAt and lastModifiedSource', () {
      final now = DateTime.now();
      final actMcp = Activity(
        id: 'act_1',
        tripId: 'trip_1',
        date: now,
        startTime: '10:00',
        title: 'Shibuya Sky Tour',
        lastModifiedAt: now,
        lastModifiedSource: 'mcp',
      );

      expect(actMcp.isModifiedByMcp, isTrue);
      expect(actMcp.isModifiedByUi, isFalse);
      expect(actMcp.lastModifiedSource, 'mcp');
      expect(actMcp.lastModifiedAt, now);

      final map = actMcp.toMap();
      expect(map['lastModifiedSource'], 'mcp');
      expect(map['lastModifiedAt'], isNotNull);

      final fromMap = Activity.fromMap(map);
      expect(fromMap.isModifiedByMcp, isTrue);
      expect(fromMap.title, 'Shibuya Sky Tour');

      final actUi = actMcp.copyWith(lastModifiedSource: 'ui');
      expect(actUi.isModifiedByUi, isTrue);
      expect(actUi.isModifiedByMcp, isFalse);
    });

    test('Stay and Flight track lastModifiedAt and lastModifiedSource', () {
      final now = DateTime.now();
      final stay = Stay(
        id: 'stay_1',
        tripId: 'trip_1',
        type: StayType.hotel,
        name: 'The Tokyo Hotel',
        checkInDate: now,
        checkOutDate: now.add(const Duration(days: 2)),
        lastModifiedAt: now,
        lastModifiedSource: 'mcp',
      );
      expect(stay.isModifiedByMcp, isTrue);
      final stayMap = stay.toMap();
      expect(stayMap['lastModifiedSource'], 'mcp');
      final stayFromMap = Stay.fromMap(stayMap);
      expect(stayFromMap.isModifiedByMcp, isTrue);

      final flight = Flight(
        id: 'fl_1',
        tripId: 'trip_1',
        airline: 'ANA',
        flightNumber: 'NH101',
        departureAirport: 'SFO',
        arrivalAirport: 'HND',
        departureTime: now,
        arrivalTime: now.add(const Duration(hours: 10)),
        lastModifiedAt: now,
        lastModifiedSource: 'ui',
      );
      expect(flight.isModifiedByUi, isTrue);
      final flightMap = flight.toMap();
      expect(flightMap['lastModifiedSource'], 'ui');
      final flightFromMap = Flight.fromMap(flightMap);
      expect(flightFromMap.isModifiedByUi, isTrue);
    });

    test('MockTripRepository stamps lastModifiedSource and lastModifiedAt on mutation', () async {
      final repo = MockTripRepository();
      final now = DateTime.now();
      final act = Activity(
        id: 'act_test_stamp',
        tripId: 'trip_japan_2026',
        date: now,
        startTime: '14:00',
        title: 'Temple Visit',
      );

      await repo.addActivity(act);
      final acts = await repo.getActivities('trip_japan_2026');
      final saved = acts.firstWhere((a) => a.id == 'act_test_stamp');
      expect(saved.lastModifiedAt, isNotNull);
      expect(saved.lastModifiedSource, 'ui');

      // Update with MCP source
      await repo.updateActivity(saved.copyWith(lastModifiedSource: 'mcp'));
      final acts2 = await repo.getActivities('trip_japan_2026');
      final saved2 = acts2.firstWhere((a) => a.id == 'act_test_stamp');
      expect(saved2.lastModifiedSource, 'mcp');
      expect(saved2.isModifiedByMcp, isTrue);
    });

    testWidgets('ModificationSourceBadge displays MCP styling when source is mcp', (tester) async {
      final now = DateTime.now();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModificationSourceBadge(
              lastModifiedAt: now,
              lastModifiedSource: 'mcp',
            ),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('modification_badge_mcp')), findsOneWidget);
      expect(find.textContaining('MCP Server'), findsOneWidget);
      expect(find.byIcon(Icons.smart_toy_rounded), findsOneWidget);
    });

    testWidgets('ModificationSourceBadge displays UI styling when source is ui', (tester) async {
      final now = DateTime.now();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModificationSourceBadge(
              lastModifiedAt: now,
              lastModifiedSource: 'ui',
              isCompact: true,
            ),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('modification_badge_ui')), findsOneWidget);
      expect(find.textContaining('UI'), findsOneWidget);
      expect(find.byIcon(Icons.edit_note_rounded), findsOneWidget);
    });
  });

  group('Iteration #22 - Day Planner Drag Dynamic Target Time Tests', () {
    late TripBundle thaiBundle;

    setUp(() {
      final file = File('thailandia_2026_trip.json');
      final jsonString = file.readAsStringSync();
      thaiBundle = TripBundle.fromJson(jsonString);
    });

    Widget createProviderScope({
      required Widget child,
      Trip? trip,
      List<Stay>? stays,
      List<Flight>? flights,
      List<Activity>? activities,
      TripRepository? repo,
    }) {
      final t = trip ?? thaiBundle.trip;
      final s = stays ?? thaiBundle.stays;
      final f = flights ?? thaiBundle.flights;
      final a = activities ?? thaiBundle.activities;
      final r = repo ?? TestTripRepository();

      return ProviderScope(
        overrides: [
          activeTripProvider.overrideWithValue(t),
          activeTripStaysProvider.overrideWith((ref) => Stream.value(s)),
          activeTripFlightsProvider.overrideWith((ref) => Stream.value(f)),
          activeTripActivitiesProvider.overrideWith((ref) => Stream.value(a)),
          tripRepositoryProvider.overrideWithValue(r),
          canEditActiveTripProvider.overrideWithValue(true),
        ],
        child: MaterialApp(
          home: Scaffold(body: child),
        ),
      );
    }

    testWidgets('DayPlannerView renders timeline DragTarget and draggable handles', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createProviderScope(child: const DayPlannerView()),
      );
      await tester.pumpAndSettle();

      // Verify the timeline DragTarget exists
      expect(find.byKey(const ValueKey('timeline_drag_target')), findsOneWidget);

      // Verify draggable activity handles exist
      expect(find.byType(DragTarget<Activity>), findsWidgets);
    });
  });
}
