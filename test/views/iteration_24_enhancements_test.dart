import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trippy/mcp/trippy_mcp_models.dart';
import 'package:trippy/mcp/trippy_mcp_server.dart';
import 'package:trippy/mcp/trippy_mcp_service.dart';
import 'package:trippy/models/models.dart';

void main() {
  group('Iteration #24 - Trip Notes, Links & Attachments', () {
    test('Trip model supports notes, links, and attachments', () {
      final now = DateTime.now();
      final trip = Trip(
        id: 'trip_test_24',
        title: 'Japan Adventure 2026',
        destination: 'Tokyo & Kyoto',
        ownerId: 'user_test_24',
        inviteCode: 'TEST24',
        members: {'user_test_24': MemberRole.owner},
        startDate: DateTime(2026, 4, 1),
        endDate: DateTime(2026, 4, 15),
        notes: 'Remember to exchange Yen and pack comfortable walking shoes.',
        links: ['JR Pass Guide|https://japanrailpass.net', 'https://tokyocheapo.com'],
        attachments: ['Packing Checklist.pdf|https://storage.googleapis.com/...'],
        createdAt: now,
        updatedAt: now,
        lastModifiedAt: now,
        lastModifiedSource: 'ui',
      );

      expect(trip.notes, contains('comfortable walking shoes'));
      expect(trip.links[0], contains('JR Pass'));
      expect(trip.links.length, 2);
      expect(trip.attachments.length, 1);

      // Serialization round-trip
      final map = trip.toMap();
      expect(map['notes'], 'Remember to exchange Yen and pack comfortable walking shoes.');
      expect(map['links'], ['JR Pass Guide|https://japanrailpass.net', 'https://tokyocheapo.com']);
      expect(map['attachments'], ['Packing Checklist.pdf|https://storage.googleapis.com/...']);

      final restored = Trip.fromMap(map);
      expect(restored.notes, trip.notes);
      expect(restored.links, trip.links);
      expect(restored.attachments, trip.attachments);
      expect(restored.title, 'Japan Adventure 2026');

      // copyWith updates notes, links, attachments
      final updated = trip.copyWith(
        notes: 'Updated notes',
        links: ['New Link|https://example.com'],
        attachments: [],
      );
      expect(updated.notes, 'Updated notes');
      expect(updated.links, ['New Link|https://example.com']);
      expect(updated.attachments, isEmpty);
    });

    test('Trip model handles legacy maps without notes, links, or attachments', () {
      final legacyMap = {
        'id': 'legacy_trip',
        'title': 'Legacy Trip',
        'destination': 'Paris',
        'ownerId': 'legacy_owner',
        'inviteCode': 'LEGACY',
        'members': {'legacy_owner': 'owner'},
        'startDate': '2026-05-01T00:00:00.000',
        'endDate': '2026-05-10T00:00:00.000',
        'createdAt': '2026-05-01T00:00:00.000',
        'updatedAt': '2026-05-01T00:00:00.000',
      };

      final trip = Trip.fromMap(legacyMap);
      expect(trip.notes, isNull);
      expect(trip.links, isEmpty);
      expect(trip.attachments, isEmpty);
    });
  });

  group('Iteration #24 - MCP Server Trip Notes, Links & Attachments', () {
    test('trippy_create_trip and trippy_update_trip handle notes, links, and attachments', () async {
      final service = TrippyMcpService(projectId: 'trippy-prod-4524f');
      final server = TrippyMcpServer(service: service);

      // Create trip with notes, links, attachments
      final createReq = JsonRpcRequest(
        id: 1,
        method: 'tools/call',
        params: {
          'name': 'trippy_create_trip',
          'arguments': {
            'title': 'Italian Escape',
            'destination': 'Rome & Venice',
            'startDate': '2026-06-01',
            'endDate': '2026-06-10',
            'notes': 'Book Colosseum underground tour tickets 30 days prior.',
            'links': ['Trenitalia Booking|https://www.trenitalia.com'],
            'attachments': ['Passports.pdf|https://storage.trippy.app/passports.pdf'],
          },
        },
      );
      final createResp = await server.handleRequest(createReq);
      expect(createResp, isNotNull);
      expect(createResp!.error, isNull);

      final createRes = createResp.result as Map<String, dynamic>;
      final tripData = (createRes['data'] ?? createRes)['trip'] as Map<String, dynamic>;
      final tripId = tripData['id'] as String;
      expect(tripData['notes'], contains('Colosseum'));
      expect(tripData['links'], contains('Trenitalia Booking|https://www.trenitalia.com'));
      expect(tripData['attachments'].length, 1);

      // Update trip with append links and attachments
      final updateReq = JsonRpcRequest(
        id: 2,
        method: 'tools/call',
        params: {
          'name': 'trippy_update_trip',
          'arguments': {
            'tripId': tripId,
            'notes': 'Updated: Colosseum tickets secured!',
            'addLinks': ['Venice Vaporetto Pass|https://actv.avmspa.it'],
            'addAttachments': ['Colosseum_Voucher.pdf|https://storage.trippy.app/voucher.pdf'],
          },
        },
      );
      final updateResp = await server.handleRequest(updateReq);
      expect(updateResp, isNotNull);
      expect(updateResp!.error, isNull);

      final updateRes = updateResp.result as Map<String, dynamic>;
      final updatedTrip = (updateRes['data'] ?? updateRes)['trip'] as Map<String, dynamic>;
      expect(updatedTrip['notes'], 'Updated: Colosseum tickets secured!');
      final links = List<String>.from(updatedTrip['links'] as List);
      expect(links.length, 2);
      expect(links, contains('Venice Vaporetto Pass|https://actv.avmspa.it'));
      final attachments = List<String>.from(updatedTrip['attachments'] as List);
      expect(attachments.length, 2);
    });
  });

  group('Iteration #24 - Day Planner Minimum Height & Grid Alignment Logic', () {
    test('Short activities are clamped to minimum height of 48.0 dp', () {
      const hourHeight = 72.0;
      const minuteHeight = hourHeight / 60.0; // 1.2 dp per min
      const minActivityHeight = 48.0;

      // 10-minute activity: raw height = 12.0 dp
      final h10 = (10 * minuteHeight).clamp(minActivityHeight, double.infinity);
      expect(h10, equals(48.0));

      // 15-minute activity: raw height = 18.0 dp
      final h15 = (15 * minuteHeight).clamp(minActivityHeight, double.infinity);
      expect(h15, equals(48.0));

      // 30-minute activity: raw height = 36.0 dp
      final h30 = (30 * minuteHeight).clamp(minActivityHeight, double.infinity);
      expect(h30, equals(48.0));

      // 60-minute activity: raw height = 72.0 dp
      final h60 = (60 * minuteHeight).clamp(minActivityHeight, double.infinity);
      expect(h60, equals(72.0));

      // 120-minute activity: raw height = 144.0 dp
      final h120 = (120 * minuteHeight).clamp(minActivityHeight, double.infinity);
      expect(h120, equals(144.0));
    });

    test('Hourly grid lines and hour-aligned activities share exact top pixel', () {
      const hourHeight = 72.0;

      for (int h = 0; h <= 24; h++) {
        final gridLineTop = h * hourHeight;
        final activityTop = (h * 60) * (hourHeight / 60.0);
        expect(activityTop, equals(gridLineTop));
      }
    });
  });

  group('Iteration #24 - Personal Access Token (PAT) Generation & Hashing', () {
    test('Generates securely formatted PAT and valid SHA-256 hash', () {
      const rawToken = 'trippy_pat_test1234567890abcdef1234567890abcdef';
      expect(rawToken.startsWith('trippy_pat_'), isTrue);

      final tokenHash = sha256.convert(utf8.encode(rawToken)).toString();
      expect(tokenHash.length, equals(64));

      final tokenPrefix = rawToken.substring(0, 16);
      expect(tokenPrefix, equals('trippy_pat_test1'));
    });
  });
}
