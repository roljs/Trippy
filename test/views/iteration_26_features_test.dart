import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trippy/data/repositories/mock_trip_repository.dart';
import 'package:trippy/models/models.dart';
import 'package:trippy/state/trip_providers.dart';
import 'package:trippy/views/common/add_activity_sheet.dart';
import 'package:trippy/views/common/app_nav_scaffold.dart';
import 'package:trippy/views/common/user_account_button.dart';
import 'package:trippy/views/day_planner/day_planner_view.dart';
import 'package:trippy/views/settings/settings_screen.dart';
import 'package:trippy/views/dashboard/trip_dashboard_screen.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:trippy/services/auth/auth_service.dart';

class _FakeActiveTripIdNotifier extends ActiveTripIdNotifier {
  final String? _initialId;
  _FakeActiveTripIdNotifier(this._initialId);

  @override
  String? build() => _initialId;
}

class _FakeUser extends Fake implements User {
  @override
  final String uid = 'user_1';
  @override
  final String email = 'user@example.com';
  @override
  final String? displayName = 'Test User';
  @override
  final String? photoURL = null;
  @override
  final bool isAnonymous = false;
}

class _FakeAuthService extends Fake implements AuthService {
  final User? _user;
  _FakeAuthService([this._user]);

  @override
  User? get currentUser => _user;
}

void main() {
  group('Iteration #26 Requirements Tests', () {
    late MockTripRepository mockRepo;
    late Trip testTrip;
    final testDate = DateTime(2026, 11, 1);

    setUp(() async {
      mockRepo = MockTripRepository();
      testTrip = Trip(
        id: 'trip_iter26',
        title: 'Japan Adventure',
        destination: 'Tokyo, Japan',
        startDate: testDate,
        endDate: DateTime(2026, 11, 5),
        ownerId: 'user_1',
        inviteCode: 'TYO-26',
        members: {'user_1': MemberRole.owner},
        dayLocations: {
          Trip.dateToKey(testDate): ['Tokyo'],
        },
        createdAt: DateTime(2026, 10, 1),
        updatedAt: DateTime(2026, 10, 1),
      );
      await mockRepo.createTrip(testTrip);
    });

    testWidgets(
        'Req 1: Day Planner displays 15-min activity adjacent to another activity without covering title',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Activity 1: 15-minute quick activity at 10:00 - 10:15
      final act1 = Activity(
        id: 'act_quick_15m',
        tripId: testTrip.id,
        date: testDate,
        startTime: '10:00',
        endTime: '10:15',
        title: 'Quick Matcha Tea',
        category: ActivityCategory.dining,
      );

      // Activity 2: Adjacent activity starting immediately at 10:15
      final act2 = Activity(
        id: 'act_adjacent_walk',
        tripId: testTrip.id,
        date: testDate,
        startTime: '10:15',
        endTime: '11:15',
        title: 'Garden Walking Tour',
        category: ActivityCategory.attraction,
      );

      await mockRepo.addActivity(act1);
      await mockRepo.addActivity(act2);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeTripIdProvider.overrideWith(() => _FakeActiveTripIdNotifier(testTrip.id)),
            activeTripProvider.overrideWith((ref) => testTrip),
            tripRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DayPlannerView(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify both activity titles are rendered and visible on screen
      expect(find.text('Quick Matcha Tea'), findsOneWidget);
      expect(find.text('Garden Walking Tour'), findsOneWidget);

      // Verify horizontal positions do not completely occlude each other
      final card1 = find.byKey(const ValueKey('activity_card_act_quick_15m'));
      final card2 = find.byKey(const ValueKey('activity_card_act_adjacent_walk'));
      expect(card1, findsOneWidget);
      expect(card2, findsOneWidget);

      final topLeft1 = tester.getTopLeft(card1);
      final topLeft2 = tester.getTopLeft(card2);

      // Visual lanes split or adjust positions so the 15-min title is not occluded
      expect(topLeft1.dx != topLeft2.dx, isTrue);
    });

    testWidgets(
        'Req 2: Top-level buttons order and web trip share chip next to trip title',
        (tester) async {
      // 1. Web / Desktop view
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
            home: AppNavScaffold(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Trip share button (code 'TYO-26') should be visible on web next to trip title
      expect(find.text('TYO-26'), findsOneWidget);

      // Verify actions order:
      // 1) Trip notes icon
      // 2) Offline icon
      // 3) Settings icon
      // 4) Account button
      final notesIcon = find.byIcon(Icons.description_outlined);
      final offlineIcon = find.byIcon(Icons.cloud_sync_outlined);
      final settingsIcon = find.byIcon(Icons.settings_outlined);
      final accountBtn = find.byType(UserAccountButton);

      expect(notesIcon, findsOneWidget);
      expect(offlineIcon, findsOneWidget);
      expect(settingsIcon, findsOneWidget);
      expect(accountBtn, findsOneWidget);

      final notesX = tester.getCenter(notesIcon).dx;
      final offlineX = tester.getCenter(offlineIcon).dx;
      final settingsX = tester.getCenter(settingsIcon).dx;
      final accountX = tester.getCenter(accountBtn).dx;

      expect(notesX < offlineX, isTrue, reason: 'Notes should be to the left of Offline');
      expect(offlineX < settingsX, isTrue, reason: 'Offline should be to the left of Settings');
      expect(settingsX < accountX, isTrue, reason: 'Settings should be to the left of Account');

      // 2. Mobile view (share chip hidden)
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();

      expect(find.text('TYO-26'), findsNothing);
    });

    testWidgets(
        'Req 3: Adding activity in a new place prompts to add to Day locations, supports rejection',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Open AddActivitySheet for testDate (currently only has 'Tokyo' in dayLocations)
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeTripIdProvider.overrideWith(() => _FakeActiveTripIdNotifier(testTrip.id)),
            activeTripProvider.overrideWith((ref) => testTrip),
            tripRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: AddActivitySheet(initialDate: testDate),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter activity title & location in Kamakura (a new city for this day)
      final titleField = find.widgetWithText(TextField, 'Activity Title');
      await tester.enterText(titleField, 'Great Buddha Visit');

      final locationField = find.widgetWithText(TextField, 'Location / Address');
      await tester.enterText(locationField, 'Kotoku-in Temple, Kamakura');

      // Tap save button
      final saveBtn = find.text('Add to Day');
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Verify dialog appears asking to add 'Kamakura'
      expect(find.text('Add to Day Locations?'), findsOneWidget);
      expect(find.textContaining('Kamakura'), findsWidgets);

      // User rejects via "No, Thanks"
      final rejectBtn = find.text('No, Thanks');
      expect(rejectBtn, findsOneWidget);
      await tester.tap(rejectBtn);
      await tester.pumpAndSettle();

      // Verify activity was saved but dayLocations was NOT changed
      final activities = await mockRepo.getActivities(testTrip.id);
      expect(activities.any((a) => a.title == 'Great Buddha Visit'), isTrue);

      final updatedTrip = await mockRepo.getTripById(testTrip.id);
      final dateKey = Trip.dateToKey(testDate);
      expect(updatedTrip?.dayLocations[dateKey], ['Tokyo']);
      expect(updatedTrip?.dayLocations[dateKey]?.contains('Kamakura'), isFalse);
    });

    testWidgets(
        'Req 3: Adding activity in a new place allows accepting into Day locations',
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
          child: MaterialApp(
            home: Scaffold(
              body: AddActivitySheet(initialDate: testDate),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter activity in Nikko
      final titleField = find.widgetWithText(TextField, 'Activity Title');
      await tester.enterText(titleField, 'Toshogu Shrine');

      final locationField = find.widgetWithText(TextField, 'Location / Address');
      await tester.enterText(locationField, 'Nikko Toshogu, Nikko');

      final saveBtn = find.text('Add to Day');
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Verify dialog appears
      expect(find.text('Add to Day Locations?'), findsOneWidget);

      // User accepts via "Add Location"
      final acceptBtn = find.text('Add Location');
      expect(acceptBtn, findsOneWidget);
      await tester.tap(acceptBtn);
      await tester.pumpAndSettle();

      // Verify 'Nikko' was added to dayLocations
      final updatedTrip = await mockRepo.getTripById(testTrip.id);
      final dateKey = Trip.dateToKey(testDate);
      expect(updatedTrip?.dayLocations[dateKey], contains('Nikko'));
    });

    testWidgets(
        'Req 4: Day Planner mobile drag & resize handles require hold gesture',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final act = Activity(
        id: 'act_drag_test',
        tripId: testTrip.id,
        date: testDate,
        startTime: '10:00',
        endTime: '11:00',
        title: 'Shinjuku Walk',
        category: ActivityCategory.attraction,
      );
      await mockRepo.addActivity(act);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeTripIdProvider.overrideWith(() => _FakeActiveTripIdNotifier(testTrip.id)),
            activeTripProvider.overrideWith((ref) => testTrip),
            tripRepositoryProvider.overrideWithValue(mockRepo),
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

      // On mobile, top-right drag handle uses LongPressDraggable to prevent accidental drags when scrolling
      final dragHandleFinder = find.byKey(const ValueKey('activity_drag_handle_act_drag_test'));
      expect(dragHandleFinder, findsOneWidget);

      final lpd = tester.widget<LongPressDraggable<Activity>>(dragHandleFinder);
      expect(lpd.delay, equals(const Duration(milliseconds: 600)));

      // Resize handle at bottom of activity card is present
      final resizeHandle = find.byKey(const ValueKey('activity_resize_handle_act_drag_test'));
      expect(resizeHandle, findsOneWidget);
    });

    testWidgets(
        'Req 5: Settings screen mobile layout stacks PAT text above Generate Token button',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(mockRepo),
            authServiceProvider.overrideWithValue(_FakeAuthService(_FakeUser())),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // In mobile mode, the PAT section has text above the button
      final patTitle = find.text('Personal Access Tokens (AI Assistants)');
      final generateBtn = find.text('Generate Token');

      expect(patTitle, findsOneWidget);
      expect(generateBtn, findsOneWidget);

      final patTitleY = tester.getTopLeft(patTitle).dy;
      final generateBtnY = tester.getTopLeft(generateBtn).dy;
      expect(patTitleY < generateBtnY, isTrue,
          reason: 'PAT title text should be stacked on top of Generate Token button on mobile');
    });

    testWidgets(
        'Req 6: Day Planner collapsible header toggles via double-tap',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
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
              body: DayPlannerView(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Expanded mode initially shows day locations or Wake up at
      expect(find.text('WAKE UP AT'), findsWidgets);
      expect(find.text('SLEEP AT'), findsWidgets);

      // Double tap on header to collapse
      final headerGesture = find.byKey(const ValueKey('day_planner_header_double_tap_gesture'));
      await tester.tap(headerGesture);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(headerGesture);
      await tester.pumpAndSettle();

      // Compact mode hides Wake up at and Sleep at
      expect(find.text('WAKE UP AT'), findsNothing);
      expect(find.text('SLEEP AT'), findsNothing);
      expect(find.text('Itinerary'), findsWidgets);

      // Double tap again to expand back
      await tester.tap(headerGesture);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(headerGesture);
      await tester.pumpAndSettle();

      // Expanded mode returns
      expect(find.text('WAKE UP AT'), findsWidgets);
      expect(find.text('SLEEP AT'), findsWidgets);
    });

    testWidgets(
        'Req 7: Trips tab has FloatingActionButton and compact action icons on trip cards',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(mockRepo),
            userTripsProvider.overrideWith((ref) => Stream.value([testTrip])),
            currentUserIdProvider.overrideWith((ref) => 'user_1'),
          ],
          child: const MaterialApp(
            home: TripDashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // FAB is present on Trips tab
      final fabFinder = find.byKey(const ValueKey('create_trip_fab'));
      expect(fabFinder, findsOneWidget);

      // The top AppBar action '+' button is removed
      final addIconInAppBar = find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.add_rounded),
      );
      expect(addIconInAppBar, findsNothing);

      // Action icons on the card do not overflow and are present
      expect(find.byIcon(Icons.edit_note_rounded), findsOneWidget);
      expect(find.byIcon(Icons.cloud_sync_outlined), findsOneWidget);
      expect(find.byIcon(Icons.share_rounded), findsOneWidget);
      expect(find.byIcon(Icons.file_download_outlined), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets(
        'Req 8: Edit Activity dialog has single-line Category dropdown on mobile and Day Planner navigation button',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final editAct = Activity(
        id: 'act_edit_test',
        tripId: testTrip.id,
        date: testDate,
        startTime: '14:30',
        endTime: '15:30',
        title: 'Afternoon Tea',
        category: ActivityCategory.dining,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeTripIdProvider.overrideWith(() => _FakeActiveTripIdNotifier(testTrip.id)),
            activeTripProvider.overrideWith((ref) => testTrip),
            tripRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: AddActivitySheet(
                activityToEdit: editAct,
                initialDate: testDate,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Mobile single-line category dropdown is rendered instead of multiple chip rows
      final dropdownFinder = find.byKey(const ValueKey('activity_category_dropdown_ActivityCategory.dining'));
      expect(dropdownFinder, findsOneWidget);
      expect(find.byKey(const ValueKey('activity_category_chips')), findsNothing);

      // Day Planner navigation button is rendered
      final navBtnFinder = find.byKey(const ValueKey('navigate_to_day_planner_button'));
      expect(navBtnFinder, findsOneWidget);
      expect(find.byIcon(Icons.open_in_new_rounded), findsOneWidget);
    });
  });
}
