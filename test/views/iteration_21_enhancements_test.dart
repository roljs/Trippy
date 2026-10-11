import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trippy/core/utils/attachment_upload_helper.dart';
import 'package:trippy/data/repositories/mock_trip_repository.dart';
import 'package:trippy/data/repositories/trip_repository.dart';
import 'package:trippy/models/models.dart';
import 'package:trippy/state/trip_providers.dart';
import 'package:trippy/views/common/add_activity_sheet.dart';
import 'package:trippy/views/common/notes_and_attachments_section.dart';
import 'package:trippy/views/day_planner/day_planner_view.dart';
import 'package:trippy/views/logistics/widgets/stay_header_bridge_widget.dart';

class TestTripRepository extends MockTripRepository {
  final List<Activity> updatedActivities = [];

  @override
  Future<void> updateActivity(Activity activity) async {
    updatedActivities.add(activity);
    await super.updateActivity(activity);
  }
}

void main() {
  group('Iteration #21 Enhancements Tests', () {
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
      bool canEdit = true,
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
          canEditActiveTripProvider.overrideWithValue(canEdit),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: child,
          ),
        ),
      );
    }

    group('1. AddActivitySheet Redundancy Cleanup', () {
      testWidgets('Hides Booking Status, Confirmation Ref, and Location field for Stay activities with linked stay',
          (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        // Find or create a Stay activity linked to a stay
        final stay = thaiBundle.stays.first;
        final stayActivity = Activity(
          id: 'stay_act_1',
          tripId: thaiBundle.trip.id,
          date: thaiBundle.trip.startDate,
          startTime: '15:00',
          title: 'Hotel Check-in',
          category: ActivityCategory.stay,
          stayId: stay.id,
          location: stay.address ?? stay.name,
        );

        await tester.pumpWidget(
          createProviderScope(
            child: AddActivitySheet(
              activityToEdit: stayActivity,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Booking Status section should be hidden
        expect(find.text('Booking Status'), findsNothing);
        expect(find.text('Confirmation / Booking Reference'), findsNothing);

        // 2. Redundant "Location / Address (Linked Stay)" field should NOT be displayed
        expect(find.text('Location / Address (Linked Stay)'), findsNothing);
      });

      testWidgets('Shows Booking Status and Confirmation Ref for standard attraction activities',
          (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final attraction = thaiBundle.activities.firstWhere(
          (a) => a.category == ActivityCategory.attraction,
        );

        await tester.pumpWidget(
          createProviderScope(
            child: AddActivitySheet(
              activityToEdit: attraction,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Booking Status and Confirmation Ref should be present for attractions
        expect(find.text('Booking Status'), findsOneWidget);
        expect(find.text('Confirmation / Booking Reference'), findsOneWidget);
        expect(find.text('Location / Address'), findsOneWidget);
      });
    });

    group('2. Friendly Names for Links & Attachments', () {
      test('AttachmentUploadHelper encoding and extracting friendly names', () {
        // Plain URL
        expect(AttachmentUploadHelper.extractFriendlyName('https://example.com'), isNull);
        expect(AttachmentUploadHelper.extractUrlOrPath('https://example.com'), 'https://example.com');
        expect(AttachmentUploadHelper.formatLinkLabel('https://example.com'), 'https://example.com');

        // Encoded Friendly Name + URL
        final encodedLink = AttachmentUploadHelper.encodeNamedEntry(
          urlOrPath: 'https://example.com/tickets/12345',
          friendlyName: 'My Event Tickets',
        );
        expect(encodedLink, 'My Event Tickets|https://example.com/tickets/12345');
        expect(AttachmentUploadHelper.extractFriendlyName(encodedLink), 'My Event Tickets');
        expect(AttachmentUploadHelper.extractUrlOrPath(encodedLink), 'https://example.com/tickets/12345');
        expect(AttachmentUploadHelper.formatLinkLabel(encodedLink), 'My Event Tickets');

        // Encoded Friendly Name + Attachment file path
        final encodedAttachment = AttachmentUploadHelper.encodeNamedEntry(
          urlOrPath: 'hotel_voucher_final.pdf',
          friendlyName: 'Hotel Voucher',
        );
        expect(encodedAttachment, 'Hotel Voucher|hotel_voucher_final.pdf');
        expect(AttachmentUploadHelper.extractFriendlyName(encodedAttachment), 'Hotel Voucher');
        expect(AttachmentUploadHelper.extractUrlOrPath(encodedAttachment), 'hotel_voucher_final.pdf');
        expect(AttachmentUploadHelper.formatAttachmentLabel(encodedAttachment), 'Hotel Voucher');
      });

      testWidgets('NotesAndAttachmentsSection displays friendly names and allows editing',
          (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        List<String> links = <String>['My Booking Guide|https://example.com/guide'];
        List<String> attachments = <String>['Passport Copy|passport_scan.png'];
        final notesController = TextEditingController();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return NotesAndAttachmentsSection(
                    notesController: notesController,
                    links: links,
                    onLinksChanged: (updated) => setState(() => links = updated),
                    attachments: attachments,
                    onAttachmentsChanged: (updated) => setState(() => attachments = updated),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Should display friendly names, not raw URLs
        expect(find.text('My Booking Guide'), findsOneWidget);
        expect(find.text('Passport Copy'), findsOneWidget);
        expect(find.text('https://example.com/guide'), findsNothing);

        // 2. Edit link dialog test: tap edit button on link chip
        final editLinkBtn = find.byKey(const ValueKey('link_chip_edit_0'));
        expect(editLinkBtn, findsOneWidget);
        await tester.tap(editLinkBtn);
        await tester.pumpAndSettle();

        expect(find.text('Edit Link'), findsOneWidget);
        expect(find.text('My Booking Guide'), findsWidgets); // TextField value
        expect(find.text('https://example.com/guide'), findsWidgets); // TextField value

        // Enter new friendly name
        final nameField = find.byKey(const ValueKey('edit_link_name_field'));
        await tester.enterText(nameField, 'Updated Guide');
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        expect(find.text('Updated Guide'), findsOneWidget);
        expect(links.first, 'Updated Guide|https://example.com/guide');
      });
    });

    group('3. Itinerary Full View Stay Header Badge Removal', () {
      testWidgets('StayHeaderBridgeWidget does not show redundant hotel-1N badge',
          (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final stay = thaiBundle.stays.first;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StayHeaderBridgeWidget(
                stay: stay,
                cityName: 'Bangkok',
                width: 600.0,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify Stay name is displayed
        expect(find.text(stay.name), findsOneWidget);

        // Verify the old badge like "HOTEL • 1N" or "RESORT • 2N" is NOT displayed
        expect(find.text('${stay.type.displayName.toUpperCase()} • ${stay.nights}N'), findsNothing);
      });
    });

    group('4. Day Planner 15-Minute Snapping, Ghost Card & Resize Handle', () {
      testWidgets('Cards have resize handle with resizeUpDown cursor and 15-min increments',
          (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final testActivity = Activity(
          id: 'test_act_1',
          tripId: thaiBundle.trip.id,
          date: thaiBundle.trip.startDate,
          startTime: '10:00',
          endTime: '11:00',
          title: 'Morning Market Visit',
          category: ActivityCategory.attraction,
        );

        final repo = TestTripRepository();

        await tester.pumpWidget(
          createProviderScope(
            repo: repo,
            activities: [testActivity],
            child: const DayPlannerView(),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Verify resize handle exists on the activity card
        final resizeHandleFinder = find.byKey(ValueKey('activity_resize_handle_${testActivity.id}'));
        expect(resizeHandleFinder, findsOneWidget);

        // 2. Drag resize handle down (tester.drag applies slop + delta)
        // Dragging down extends duration by 15-min increment (10:00-11:00 -> 10:00-11:15)
        await tester.drag(resizeHandleFinder, const Offset(0, 30));
        await tester.pumpAndSettle();

        expect(repo.updatedActivities.isNotEmpty, isTrue);
        final updatedAct = repo.updatedActivities.last;
        expect(updatedAct.startTime, '10:00');
        expect(updatedAct.endTime, '11:15');
      });

      testWidgets('DragTarget aligns drops to 15-minute increments',
          (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final testActivity = Activity(
          id: 'drag_act_1',
          tripId: thaiBundle.trip.id,
          date: thaiBundle.trip.startDate,
          startTime: '09:00',
          endTime: '10:00', // 60 min duration
          title: 'Temple Tour',
          category: ActivityCategory.attraction,
        );

        final repo = TestTripRepository();

        await tester.pumpWidget(
          createProviderScope(
            repo: repo,
            activities: [testActivity],
            child: const DayPlannerView(),
          ),
        );
        await tester.pumpAndSettle();

        // Locate timeline drag target
        final dragTargetFinder = find.byKey(const ValueKey('timeline_drag_target'));
        expect(dragTargetFinder, findsOneWidget);

        final dragTarget = tester.widget<DragTarget<Activity>>(dragTargetFinder);
        final targetBox = tester.renderObject(dragTargetFinder) as RenderBox;

        // Test 1: Drop at minute 860 (14:20) -> snaps to 14:15
        final dropPos1 = targetBox.localToGlobal(const Offset(100, 860.0));
        dragTarget.onAcceptWithDetails!(
          DragTargetDetails<Activity>(
            data: testActivity,
            offset: dropPos1,
          ),
        );
        await tester.pumpAndSettle();

        expect(repo.updatedActivities.isNotEmpty, isTrue);
        expect(repo.updatedActivities.last.startTime, '14:15');
        expect(repo.updatedActivities.last.endTime, '15:15');

        // Test 2: Drop at minute 865 (14:25) -> snaps to 14:30
        final dropPos2 = targetBox.localToGlobal(const Offset(100, 865.0));
        dragTarget.onAcceptWithDetails!(
          DragTargetDetails<Activity>(
            data: testActivity,
            offset: dropPos2,
          ),
        );
        await tester.pumpAndSettle();

        expect(repo.updatedActivities.last.startTime, '14:30');
        expect(repo.updatedActivities.last.endTime, '15:30');
      });

      testWidgets('DragTarget onMove renders timeline_ghost_card with 15-min snapped indicator',
          (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final testActivity = Activity(
          id: 'ghost_act_1',
          tripId: thaiBundle.trip.id,
          date: thaiBundle.trip.startDate,
          startTime: '09:00',
          endTime: '10:00',
          title: 'River Cruise',
          category: ActivityCategory.attraction,
        );

        final repo = TestTripRepository();

        await tester.pumpWidget(
          createProviderScope(
            repo: repo,
            activities: [testActivity],
            child: const DayPlannerView(),
          ),
        );
        await tester.pumpAndSettle();

        final dragTargetFinder = find.byKey(const ValueKey('timeline_drag_target'));
        final dragTarget = tester.widget<DragTarget<Activity>>(dragTargetFinder);

        final targetBox = tester.renderObject(dragTargetFinder) as RenderBox;
        // Hover at 11:38 (698 minutes) -> snaps to 11:45 (705 minutes)
        final globalHoverPos = targetBox.localToGlobal(const Offset(100, 698.0));

        dragTarget.onMove!(
          DragTargetDetails<Activity>(
            data: testActivity,
            offset: globalHoverPos,
          ),
        );
        await tester.pump();

        // Verify ghost card appears
        final ghostCard = find.byKey(const ValueKey('timeline_ghost_card'));
        expect(ghostCard, findsOneWidget);
        expect(find.text('Drop here (15m)'), findsOneWidget);
        expect(find.text('11:45 – 12:45'), findsOneWidget);

        // onLeave clears the ghost card
        dragTarget.onLeave!(testActivity);
        await tester.pump();
        expect(find.byKey(const ValueKey('timeline_ghost_card')), findsNothing);
      });
    });
  });
}
