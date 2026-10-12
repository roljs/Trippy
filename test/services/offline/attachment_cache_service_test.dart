import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:trippy/services/offline/attachment_cache_service.dart';

void main() {
  group('AttachmentCacheService Unit Tests', () {
    late AttachmentCacheService service;

    setUp(() {
      service = AttachmentCacheService();
    });

    test('hashKey generates deterministic sha256 hash', () {
      final key1 = AttachmentCacheService.hashKey('https://example.com/receipt.pdf');
      final key2 = AttachmentCacheService.hashKey('https://example.com/receipt.pdf');
      final key3 = AttachmentCacheService.hashKey('https://example.com/other.png');

      expect(key1, isNotEmpty);
      expect(key1, equals(key2));
      expect(key1, isNot(equals(key3)));
    });

    test('extractExtension identifies file extensions correctly', () {
      expect(
        AttachmentCacheService.extractExtension('https://example.com/flight.pdf'),
        equals('.pdf'),
      );
      expect(
        AttachmentCacheService.extractExtension('https://example.com/boarding_pass.png?alt=media&token=123'),
        equals('.png'),
      );
      expect(
        AttachmentCacheService.extractExtension('Receipt|https://example.com/hotel.jpg'),
        equals('.jpg'),
      );
    });

    test('isImage accurately detects image extensions', () {
      expect(AttachmentCacheService.isImage('https://example.com/photo.png'), isTrue);
      expect(AttachmentCacheService.isImage('https://example.com/photo.jpg'), isTrue);
      expect(AttachmentCacheService.isImage('https://example.com/photo.jpeg'), isTrue);
      expect(AttachmentCacheService.isImage('https://example.com/photo.webp'), isTrue);
      expect(AttachmentCacheService.isImage('https://example.com/document.pdf'), isFalse);
    });

    test('isPdf accurately detects PDF files', () {
      expect(AttachmentCacheService.isPdf('https://example.com/tickets.pdf'), isTrue);
      expect(AttachmentCacheService.isPdf('https://example.com/tickets.png'), isFalse);
    });

    test('resolveMimeType accurately maps extensions to MIME types', () {
      expect(AttachmentCacheService.resolveMimeType('https://example.com/file.pdf'), equals('application/pdf'));
      expect(AttachmentCacheService.resolveMimeType('photo.png'), equals('image/png'));
      expect(AttachmentCacheService.resolveMimeType('picture.jpg'), equals('image/jpeg'));
      expect(AttachmentCacheService.resolveMimeType('doc.docx'), equals('application/vnd.openxmlformats-officedocument.wordprocessingml.document'));
      expect(AttachmentCacheService.resolveMimeType('unknown.xyz'), equals('application/octet-stream'));
    });

    test('cacheBytesDirectly, isCached, and getCachedBytes work seamlessly', () async {
      const url = 'https://firebasestorage.googleapis.com/test_image.png';
      final dummyBytes = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);

      // Cache bytes
      await service.cacheBytesDirectly(url, dummyBytes, fileName: 'test_image.png');

      // Check cached
      final isCached = await service.isCached(url);
      expect(isCached, isTrue);

      // Read bytes
      final cachedBytes = await service.getCachedBytes(url);
      expect(cachedBytes, isNotNull);
      expect(cachedBytes, equals(dummyBytes));

      // Remove cached
      await service.removeCached(url);
      expect(await service.isCached(url), isFalse);
    });

    test('clearAll wipes cached files', () async {
      const url = 'https://example.com/test_doc.pdf';
      final dummyBytes = Uint8List.fromList([10, 20, 30]);

      await service.cacheBytesDirectly(url, dummyBytes);
      expect(await service.isCached(url), isTrue);

      await service.clearAll();
      expect(await service.isCached(url), isFalse);
    });
  });
}
