import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trippy/core/utils/attachment_upload_helper.dart';
import 'package:trippy/core/utils/map_launcher_helper.dart';
import 'package:trippy/data/repositories/mock_trip_repository.dart';
import 'package:trippy/data/repositories/trip_repository.dart';
import 'package:trippy/models/models.dart';
import 'package:trippy/state/trip_providers.dart';
import 'package:trippy/views/common/add_activity_sheet.dart';
import 'package:trippy/views/common/add_flight_sheet.dart';
import 'package:trippy/views/common/add_stay_sheet.dart';
import 'package:trippy/views/common/notes_and_attachments_section.dart';
import 'package:trippy/views/day_planner/day_planner_view.dart';

void main() {
  group('Iteration #20 Enhancements Tests', () {
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
      final r = repo ?? MockTripRepository();

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

    group('1. Transport Directions Button', () {
      test('MapLauncherHelper.getDirectionsUri constructs valid Google Maps URL', () {
        final uri = MapLauncherHelper.getDirectionsUri(
          origin: 'Bangkok Airport, Thailand',
          destination: 'Mandarin Oriental Bangkok, Thailand',
        );

        expect(uri.scheme, 'https');
        expect(uri.host, 'www.google.com');
        expect(uri.path, '/maps/dir/');
        expect(uri.queryParameters['api'], '1');
        expect(uri.queryParameters['origin'], 'Bangkok Airport, Thailand');
        expect(uri.queryParameters['destination'], 'Mandarin Oriental Bangkok, Thailand');
      });

      testWidgets('AddActivitySheet for transport displays Get Directions button and handles tap',
          (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final transportAct = thaiBundle.activities.firstWhere(
          (a) => a.category == ActivityCategory.transport,
        );

        await tester.pumpWidget(
          createProviderScope(
            child: AddActivitySheet(
              activityToEdit: transportAct,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Check if transport direction button is visible
        final directionsBtn = find.byKey(const ValueKey('transport_get_directions_button'));
        expect(directionsBtn, findsOneWidget);

        // Verify button text or icon
        expect(find.text('Directions in Maps'), findsOneWidget);
        expect(find.byIcon(Icons.directions_rounded), findsWidgets);

        // Tap the directions button
        await tester.tap(directionsBtn);
        await tester.pump();
      });
    });

    group('2. Day Planner Drag & Drop Activity Ordering and Timing', () {
      testWidgets('DayPlannerView contains DragTarget and draggable handles for activities',
          (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final targetDay = thaiBundle.trip.startDate;
        final dayActivities = thaiBundle.activities.where((a) {
          return a.date.year == targetDay.year &&
              a.date.month == targetDay.month &&
              a.date.day == targetDay.day;
        }).toList();

        await tester.pumpWidget(
          createProviderScope(
            activities: dayActivities,
            child: const DayPlannerView(),
          ),
        );
        await tester.pumpAndSettle();

        // Verify timeline DragTarget exists
        final dragTarget = find.byKey(const ValueKey('timeline_drag_target'));
        expect(dragTarget, findsOneWidget);

        // Verify at least one activity card has a draggable key
        if (dayActivities.isNotEmpty) {
          final firstAct = dayActivities.first;
          final draggableHandle = find.byKey(ValueKey('activity_drag_handle_${firstAct.id}'));
          expect(draggableHandle, findsOneWidget);
        }
      });

      testWidgets('Dragging activity card adjusts start time and preserves duration',
          (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final testDate = thaiBundle.trip.startDate;
        final initialAct = Activity(
          id: 'drag_test_activity',
          tripId: thaiBundle.trip.id,
          title: 'Drag Test Tour',
          category: ActivityCategory.attraction,
          date: testDate,
          startTime: '10:00',
          endTime: '11:30', // 90 min duration
        );

        Activity? updatedActivity;
        final mockRepo = _CapturingTripRepository((act) {
          updatedActivity = act;
        });

        await tester.pumpWidget(
          createProviderScope(
            activities: [initialAct],
            repo: mockRepo,
            child: const DayPlannerView(),
          ),
        );
        await tester.pumpAndSettle();

        final dragHandle = find.byKey(const ValueKey('activity_drag_handle_drag_test_activity'));
        expect(dragHandle, findsOneWidget);

        // Drag handle down by 240 pixels (4 hours down, hourHeight = 60 px/hr)
        final gesture = await tester.startGesture(tester.getCenter(dragHandle));
        await tester.pump();
        await gesture.moveBy(const Offset(0, 240));
        await tester.pump();
        await gesture.up();
        await tester.pumpAndSettle();

        // Verify repository received an updated activity with preserved duration
        expect(updatedActivity, isNotNull);
        expect(updatedActivity!.id, 'drag_test_activity');

        // Initial duration was 90 minutes. Verify new end time is exactly 90 minutes after start time
        final startParts = updatedActivity!.startTime.split(':');
        final endParts = updatedActivity!.endTime!.split(':');
        final startMin = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
        final endMin = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
        final duration = endMin - startMin;
        expect(duration, 90);
      });
    });

    group('3. Attachments (Upload, Paste & Display)', () {
      test('AttachmentUploadHelper helper methods format labels and detect URLs', () {
        expect(
          AttachmentUploadHelper.formatAttachmentLabel('https://firebasestorage.googleapis.com/v0/b/bucket/o/trips%2F123%2Fattachments%2F1728000000_boarding_pass.pdf?alt=media'),
          'boarding_pass.pdf',
        );

        expect(
          AttachmentUploadHelper.formatAttachmentLabel('hotel_booking_voucher.pdf'),
          'hotel_booking_voucher.pdf',
        );

        expect(
          AttachmentUploadHelper.isUrl('https://firebasestorage.googleapis.com/test'),
          isTrue,
        );

        expect(
          AttachmentUploadHelper.isUrl('http://example.com/file.jpg'),
          isTrue,
        );

        expect(
          AttachmentUploadHelper.isUrl('local_document.pdf'),
          isFalse,
        );
      });

      testWidgets('NotesAndAttachmentsSection renders Upload and Paste buttons and manages attachments',
          (WidgetTester tester) async {
        final notesController = TextEditingController();
        List<String> links = ['https://trippy.app'];
        List<String> attachments = ['sample_attachment.pdf', 'https://example.com/receipt.png'];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return NotesAndAttachmentsSection(
                    notesController: notesController,
                    links: links,
                    attachments: attachments,
                    tripId: 'trip_japan_2026',
                    onLinksChanged: (l) => setState(() => links = l),
                    onAttachmentsChanged: (a) => setState(() => attachments = a),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify Upload and Paste buttons exist
        final uploadBtn = find.byKey(const ValueKey('attachment_upload_button'));
        final pasteBtn = find.byKey(const ValueKey('attachment_paste_button'));
        expect(uploadBtn, findsOneWidget);
        expect(pasteBtn, findsOneWidget);

        // Verify attachment chips are displayed
        expect(find.text('sample_attachment.pdf'), findsOneWidget);
        expect(find.text('receipt.png'), findsOneWidget);

        // Verify delete icon on chips
        final deleteAttachmentBtn =
            find.byKey(const ValueKey('attachment_chip_delete_0'));
        expect(deleteAttachmentBtn, findsOneWidget);

        // Remove the first attachment
        await tester.tap(deleteAttachmentBtn);
        await tester.pumpAndSettle();

        // Only one attachment should remain
        expect(attachments.length, 1);
        expect(attachments.first, 'https://example.com/receipt.png');
      });

      testWidgets('AddFlightSheet and AddStaySheet contain NotesAndAttachmentsSection with Upload and Paste',
          (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        // Check AddFlightSheet
        await tester.pumpWidget(
          createProviderScope(
            child: const AddFlightSheet(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('attachment_upload_button')), findsOneWidget);
        expect(find.byKey(const ValueKey('attachment_paste_button')), findsOneWidget);

        // Check AddStaySheet
        await tester.pumpWidget(
          createProviderScope(
            child: const AddStaySheet(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('attachment_upload_button')), findsOneWidget);
        expect(find.byKey(const ValueKey('attachment_paste_button')), findsOneWidget);
      });
    });
  });
}

class _CapturingTripRepository extends MockTripRepository {
  final void Function(Activity) onUpdateActivity;

  _CapturingTripRepository(this.onUpdateActivity);

  @override
  Future<void> updateActivity(Activity activity) async {
    onUpdateActivity(activity);
    await super.updateActivity(activity);
  }
}
