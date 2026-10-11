import 'package:flutter_test/flutter_test.dart';
import 'package:trippy/mcp/trippy_mcp_models.dart';
import 'package:trippy/mcp/trippy_mcp_server.dart';
import 'package:trippy/mcp/trippy_mcp_service.dart';

void main() {
  group('Trippy MCP Protocol & Service Tests', () {
    late TrippyMcpService service;
    late TrippyMcpServer server;

    setUp(() {
      service = TrippyMcpService(
        projectId: 'trippy-prod-4524f',
        initialUserId: 'test_user_uid',
      );
      server = TrippyMcpServer(service: service);
    });

    test('initialize returns protocol version and serverInfo', () async {
      final req = JsonRpcRequest(
        id: 1,
        method: 'initialize',
        params: {
          'protocolVersion': '2024-11-05',
          'clientInfo': {'name': 'test-client', 'version': '1.0.0'},
        },
      );

      final resp = await server.handleRequest(req);
      expect(resp, isNotNull);
      expect(resp!.id, 1);
      expect(resp.error, isNull);

      final result = resp.result as Map<String, dynamic>;
      expect(result['protocolVersion'], '2024-11-05');
      expect(result['serverInfo']['name'], 'trippy-mcp-server');
    });

    test('tools/list returns 16 registered tools with valid schema', () async {
      final req = JsonRpcRequest(id: 2, method: 'tools/list');
      final resp = await server.handleRequest(req);

      expect(resp, isNotNull);
      final result = resp!.result as Map<String, dynamic>;
      final tools = result['tools'] as List<dynamic>;

      expect(tools.length, 16);
      final toolNames = tools.map((t) => t['name'] as String).toList();
      expect(toolNames, contains('trippy_list_trips'));
      expect(toolNames, contains('trippy_get_trip_details'));
      expect(toolNames, contains('trippy_create_activity'));
      expect(toolNames, contains('trippy_update_activity'));
      expect(toolNames, contains('trippy_delete_activity'));
      expect(toolNames, contains('trippy_create_stay'));
      expect(toolNames, contains('trippy_create_flight'));
      expect(toolNames, contains('trippy_apply_suggested_itinerary'));
      expect(toolNames, contains('trippy_authenticate'));
    });

    test('trippy_list_trips returns trips available to user', () async {
      final req = JsonRpcRequest(
        id: 3,
        method: 'tools/call',
        params: {
          'name': 'trippy_list_trips',
          'arguments': <String, dynamic>{},
        },
      );

      final resp = await server.handleRequest(req);
      expect(resp, isNotNull);
      final result = resp!.result as Map<String, dynamic>;
      expect(result['data']['count'], greaterThan(0));
    });

    test('trippy_get_trip_details returns trip with activities and stays', () async {
      // First get trip list to find tripId
      final listResult = await service.executeTool('trippy_list_trips', {});
      final trips = listResult['data']['trips'] as List<dynamic>;
      final firstTripId = trips.first['id'] as String;

      final req = JsonRpcRequest(
        id: 4,
        method: 'tools/call',
        params: {
          'name': 'trippy_get_trip_details',
          'arguments': {'tripId': firstTripId},
        },
      );

      final resp = await server.handleRequest(req);
      expect(resp, isNotNull);
      final result = resp!.result as Map<String, dynamic>;
      expect(result['data']['trip']['id'], firstTripId);
      expect(result['data']['activities'], isA<List>());
    });

    test('trippy_create_activity stamps lastModifiedSource as mcp', () async {
      final listResult = await service.executeTool('trippy_list_trips', {});
      final trips = listResult['data']['trips'] as List<dynamic>;
      final tripId = trips.first['id'] as String;

      final req = JsonRpcRequest(
        id: 5,
        method: 'tools/call',
        params: {
          'name': 'trippy_create_activity',
          'arguments': {
            'tripId': tripId,
            'date': '2026-11-15',
            'startTime': '11:00',
            'endTime': '12:30',
            'title': 'Tokyo Skytree Visit',
            'category': 'attraction',
            'location': 'Oshiage, Sumida City, Tokyo',
            'notes': 'Booked via MCP',
          },
        },
      );

      final resp = await server.handleRequest(req);
      expect(resp, isNotNull);
      final result = resp!.result as Map<String, dynamic>;
      final act = result['data']['activity'] as Map<String, dynamic>;

      expect(act['title'], 'Tokyo Skytree Visit');
      expect(act['lastModifiedSource'], 'mcp');
      expect(act['lastModifiedAt'], isNotNull);
    });

    test('trippy_apply_suggested_itinerary translates daily itinerary and stamps objects with mcp', () async {
      final listResult = await service.executeTool('trippy_list_trips', {});
      final trips = listResult['data']['trips'] as List<dynamic>;
      final tripId = trips.first['id'] as String;

      final req = JsonRpcRequest(
        id: 6,
        method: 'tools/call',
        params: {
          'name': 'trippy_apply_suggested_itinerary',
          'arguments': {
            'tripId': tripId,
            'date': '2026-11-16',
            'locations': ['Tokyo', 'Harajuku', 'Shibuya'],
            'clearExistingActivities': true,
            'activities': [
              {
                'title': 'Meiji Jingu Morning Walk',
                'startTime': '09:00',
                'endTime': '10:30',
                'category': 'attraction',
                'location': 'Yoyogikamizonocho, Shibuya',
                'notes': 'Peaceful forested shrine walk',
              },
              {
                'title': 'Takeshita Street Crepes',
                'startTime': '10:45',
                'endTime': '11:30',
                'category': 'dining',
                'mealType': 'breakfast',
                'location': 'Harajuku',
              },
              {
                'title': 'Shibuya Crossing & Hachiko',
                'startTime': '12:00',
                'endTime': '13:30',
                'category': 'attraction',
                'location': 'Shibuya Station',
              },
              {
                'title': 'Omakase Sushi Dinner',
                'startTime': '19:00',
                'endTime': '21:00',
                'category': 'dining',
                'mealType': 'dinner',
                'cost': 12000,
              },
            ],
            'stays': [
              {
                'name': 'Cerulean Tower Tokyu Hotel',
                'type': 'hotel',
                'address': '26-1 Sakuragaokacho, Shibuya',
                'checkInDate': '2026-11-16',
                'checkInTime': '15:00',
                'checkOutDate': '2026-11-18',
                'checkOutTime': '11:00',
              }
            ],
          },
        },
      );

      final resp = await server.handleRequest(req);
      expect(resp, isNotNull);

      final result = resp!.result as Map<String, dynamic>;
      final data = result['data'] as Map<String, dynamic>;
      expect(data['activitiesCount'], 4);
      expect(data['staysCount'], 1);

      final content = result['content'] as List<dynamic>;
      final textContent = content.first['text'] as String;
      expect(textContent, contains('Proposed daily itinerary successfully applied'));
      expect(textContent, contains('Meiji Jingu Morning Walk'));
      expect(textContent, contains('Cerulean Tower Tokyu Hotel'));
      expect(textContent, contains('via MCP'));

      // Check created activities details
      final createdActs = data['activities'] as List<dynamic>;
      for (final a in createdActs) {
        expect(a['lastModifiedSource'], 'mcp');
        expect(a['lastModifiedAt'], isNotNull);
      }

      // Check created stay details
      final createdStays = data['stays'] as List<dynamic>;
      expect(createdStays.first['lastModifiedSource'], 'mcp');

      // Verify that getTripDetails now returns these activities
      final detailsResult = await service.executeTool('trippy_get_trip_details', {
        'tripId': tripId,
        'date': '2026-11-16',
      });
      final dayActs = detailsResult['data']['activities'] as List<dynamic>;
      expect(dayActs.length, 4);
      expect(dayActs.first['title'], 'Meiji Jingu Morning Walk');
    });

    test('trippy_authenticate updates user context', () async {
      final req = JsonRpcRequest(
        id: 7,
        method: 'tools/call',
        params: {
          'name': 'trippy_authenticate',
          'arguments': {
            'userId': 'google_user_999',
            'email': 'traveler@gmail.com',
            'idToken': 'mock_jwt_token_for_trippy_prod',
          },
        },
      );

      final resp = await server.handleRequest(req);
      expect(resp, isNotNull);
      expect(service.currentUserId, 'google_user_999');
      expect(service.currentUserEmail, 'traveler@gmail.com');
      expect(service.authToken, 'mock_jwt_token_for_trippy_prod');
    });
  });
}
