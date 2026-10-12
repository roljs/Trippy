import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trippy/data/repositories/mock_trip_repository.dart';
import 'package:trippy/models/models.dart';
import 'package:trippy/services/offline/attachment_cache_service.dart';
import 'package:trippy/services/offline/attachment_storage/attachment_storage_platform.dart';
import 'package:trippy/services/offline/attachment_storage/attachment_storage_web.dart';
import 'package:trippy/state/trip_providers.dart';
import 'package:trippy/views/common/offline_sync_dialog.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return Directory.systemTemp.path;
      },
    );
  });

  group('OfflineSyncDialog Widget Tests', () {
    late Trip testTrip;

    setUp(() async {
      AttachmentStorage.testOverride = AttachmentStorageWeb();
      await AttachmentCacheService().cacheBytesDirectly(
        'https://example.com/japan_pass.pdf',
        Uint8List.fromList([1, 2, 3]),
      );

      testTrip = Trip(
        id: 'trip_japan_2026',
        title: 'Japan Cherry Blossom 2026',
        destination: 'Tokyo, Kyoto, Osaka',
        startDate: DateTime(2026, 4, 1),
        endDate: DateTime(2026, 4, 15),
        inviteCode: 'JAPN-26',
        ownerId: 'user_current',
        members: const {'user_current': MemberRole.owner},
        attachments: ['https://example.com/japan_pass.pdf'],
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
    });

    testWidgets('Renders offline dialog with trip details and sync button', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(MockTripRepository()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => OfflineSyncDialog.show(context, trip: testTrip),
                  child: const Text('Open Sync'),
                ),
              ),
            ),
          ),
        ),
      );

      // Tap button to open dialog
      await tester.tap(find.text('Open Sync'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify dialog elements
      expect(find.text('Offline Travel Mode'), findsOneWidget);
      expect(find.text('Japan Cherry Blossom 2026'), findsOneWidget);
      expect(find.text('Stays & Lodgings'), findsOneWidget);
      expect(find.text('Flights & Transportation'), findsOneWidget);
      expect(find.text('Daily Activities'), findsOneWidget);
      expect(find.text('Files & Attachments'), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);

      // Tap sync button
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify completion
      expect(find.text('Ready for Offline Travel'), findsOneWidget);
    });
  });
}
