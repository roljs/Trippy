import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trippy/services/offline/attachment_cache_service.dart';
import 'package:trippy/services/offline/attachment_storage/attachment_storage_memory.dart';
import 'package:trippy/services/offline/attachment_storage/attachment_storage_platform.dart';
import 'package:trippy/views/common/attachment_preview_dialog.dart';

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

  group('AttachmentPreviewDialog Tests', () {
    late AttachmentCacheService cacheService;

    setUp(() {
      AttachmentStorage.testOverride = AttachmentStorageMemory();
      cacheService = AttachmentCacheService();
    });

    testWidgets('Renders cached PDF dialog with Offline Ready badge and View Document button',
        (tester) async {
      const testUrl =
          'https://firebasestorage.googleapis.com/test_trip/e_visa.pdf';
      final dummyPdfBytes = Uint8List.fromList([37, 80, 68, 70]); // %PDF
      await cacheService.cacheBytesDirectly(testUrl, dummyPdfBytes, fileName: 'e_visa.pdf');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AttachmentPreviewDialog(
              rawAttachment: testUrl,
              title: 'Vietnam eVisa',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify header and badge
      expect(find.text('Vietnam eVisa'), findsNWidgets(2));
      expect(find.text('Offline Ready'), findsOneWidget);

      // Verify document fallback card content
      expect(find.text('This file is stored in your local offline cache.'), findsOneWidget);
      expect(find.text('View Document'), findsOneWidget);
      expect(find.text('Open External'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('Renders uncached URL attachment with Online Only status and Download Offline option',
        (tester) async {
      const testUrl = 'https://example.com/tickets.pdf';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AttachmentPreviewDialog(
              rawAttachment: testUrl,
              title: 'Flight Tickets',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Flight Tickets'), findsNWidgets(2));
      expect(find.text('Online Only'), findsOneWidget);
      expect(find.text('Download Offline'), findsOneWidget);
    });
  });
}
