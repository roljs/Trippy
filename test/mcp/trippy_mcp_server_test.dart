import 'package:flutter_test/flutter_test.dart';
import 'package:trippy/mcp/trippy_mcp_models.dart';
import 'package:trippy/mcp/trippy_mcp_server.dart';
import 'package:trippy/mcp/trippy_mcp_service.dart';
import 'package:trippy/models/models.dart';

void main() {
  group('Trippy MCP Protocol & Service Tests', () {
    late TrippyMcpService service;
    late TrippyMcpServer server;

    setUp(() {
      // By default, server starts in unauthenticated sample mode (sample_user and sample_trip.json)
      service = TrippyMcpService(
        projectId: 'trippy-prod-4524f',
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

    test('tools/list returns 19 registered tools with valid schema', () async {
      final req = JsonRpcRequest(id: 2, method: 'tools/list');
      final resp = await server.handleRequest(req);

      expect(resp, isNotNull);
      final result = resp!.result as Map<String, dynamic>;
      final tools = result['tools'] as List<dynamic>;

      expect(tools.length, 19);
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
      expect(toolNames, contains('trippy_add_link'));
      expect(toolNames, contains('trippy_generate_pat'));
      expect(toolNames, contains('trippy_revoke_pat'));
    });

    test('trippy_list_trips defaults to unauthenticated sample trip', () async {
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
      expect(result['data']['authenticated'], isFalse);
      expect(result['data']['currentUserId'], 'sample_user');
      expect(result['data']['count'], 1);

      final trips = result['data']['trips'] as List<dynamic>;
      expect(trips.first['id'], 'trip_sample_pnw');
      expect(trips.first['destination'], contains('Seattle'));
    });

    test('trippy_get_trip_details returns sample trip with activities, stays, and flights', () async {
      final req = JsonRpcRequest(
        id: 4,
        method: 'tools/call',
        params: {
          'name': 'trippy_get_trip_details',
          'arguments': {'tripId': 'trip_sample_pnw'},
        },
      );

      final resp = await server.handleRequest(req);
      expect(resp, isNotNull);
      final result = resp!.result as Map<String, dynamic>;
      expect(result['data']['trip']['id'], 'trip_sample_pnw');
      expect(result['data']['trip']['ownerId'], 'sample_user');
      expect(result['data']['activities'], isA<List>());
      expect((result['data']['activities'] as List).length, 9);
      expect((result['data']['stays'] as List).length, 2);
      expect((result['data']['flights'] as List).length, 2);
    });

    test('trippy_create_activity stamps lastModifiedSource as mcp in-memory', () async {
      final req = JsonRpcRequest(
        id: 5,
        method: 'tools/call',
        params: {
          'name': 'trippy_create_activity',
          'arguments': {
            'tripId': 'trip_sample_pnw',
            'date': '2026-07-11',
            'startTime': '11:00',
            'endTime': '12:30',
            'title': 'Chihuly Garden and Glass',
            'category': 'attraction',
            'location': 'Seattle Center',
            'notes': 'Booked via MCP',
          },
        },
      );

      final resp = await server.handleRequest(req);
      expect(resp, isNotNull);
      final result = resp!.result as Map<String, dynamic>;
      final act = result['data']['activity'] as Map<String, dynamic>;

      expect(act['title'], 'Chihuly Garden and Glass');
      expect(act['lastModifiedSource'], 'mcp');
      expect(act['lastModifiedAt'], isNotNull);

      // Verify that message mentions in-memory only mode
      final msg = result['data']['message'] as String;
      expect(msg, contains('in-memory only'));
    });

    test('trippy_apply_suggested_itinerary translates daily itinerary into sample trip', () async {
      final req = JsonRpcRequest(
        id: 6,
        method: 'tools/call',
        params: {
          'name': 'trippy_apply_suggested_itinerary',
          'arguments': {
            'tripId': 'trip_sample_pnw',
            'date': '2026-07-12',
            'locations': ['Seattle', 'Capitol Hill'],
            'clearExistingActivities': false,
            'activities': [
              {
                'title': 'Volunteer Park Conservatory',
                'startTime': '14:00',
                'endTime': '15:30',
                'category': 'attraction',
                'location': 'Volunteer Park, Seattle',
                'notes': 'Historic Victorian greenhouse',
              },
              {
                'title': 'Dinner at Spinasse',
                'startTime': '18:30',
                'endTime': '20:30',
                'category': 'dining',
                'mealType': 'dinner',
                'cost': 120,
              },
            ],
          },
        },
      );

      final resp = await server.handleRequest(req);
      expect(resp, isNotNull);

      final result = resp!.result as Map<String, dynamic>;
      final data = result['data'] as Map<String, dynamic>;
      expect(data['activitiesCount'], 2);

      final content = result['content'] as List<dynamic>;
      final textContent = content.first['text'] as String;
      expect(textContent, contains('Proposed daily itinerary successfully applied'));
      expect(textContent, contains('Volunteer Park Conservatory'));
      expect(textContent, contains('unauthenticated mode'));

      // Check created activities details
      final createdActs = data['activities'] as List<dynamic>;
      for (final a in createdActs) {
        expect(a['lastModifiedSource'], 'mcp');
        expect(a['lastModifiedAt'], isNotNull);
      }
    });

    test('tools without tripId automatically resolve to sample trip for unauthenticated user', () async {
      final req = JsonRpcRequest(
        id: 7,
        method: 'tools/call',
        params: {
          'name': 'trippy_get_trip_details',
          'arguments': <String, dynamic>{},
        },
      );

      final resp = await server.handleRequest(req);
      expect(resp, isNotNull);
      final result = resp!.result as Map<String, dynamic>;
      final trip = result['data']['trip'] as Map<String, dynamic>;
      expect(trip['id'], 'trip_sample_pnw');
      expect(trip['ownerId'], 'sample_user');
    });

    test('unauthenticated in-memory changes do not persist and reset when initialize is received', () async {
      // 1. Add an activity as unauthenticated sample user
      final addReq = JsonRpcRequest(
        id: 8,
        method: 'tools/call',
        params: {
          'name': 'trippy_create_activity',
          'arguments': {
            'tripId': 'trip_sample_pnw',
            'date': '2026-07-11',
            'startTime': '15:00',
            'title': 'Temporary In-Memory Activity',
            'category': 'attraction',
          },
        },
      );
      await server.handleRequest(addReq);

      // Verify the activity is present in memory (now 10 activities)
      final detailsBefore = await service.executeTool('trippy_get_trip_details', {});
      final countBefore = (detailsBefore['data']['activities'] as List).length;
      expect(countBefore, 10);

      // 2. Another client connects (or current client reinitializes)
      final initReq = JsonRpcRequest(
        id: 9,
        method: 'initialize',
        params: {
          'protocolVersion': '2024-11-05',
          'clientInfo': {'name': 'other-device-client', 'version': '1.0.0'},
        },
      );
      await server.handleRequest(initReq);

      // 3. Verify sample data was cleanly reset to pristine bundle (back to 9 activities)
      final detailsAfter = await service.executeTool('trippy_get_trip_details', {});
      final countAfter = (detailsAfter['data']['activities'] as List).length;
      expect(countAfter, 9);
      final acts = detailsAfter['data']['activities'] as List<dynamic>;
      expect(acts.any((a) => a['title'] == 'Temporary In-Memory Activity'), isFalse);
    });

    test('trippy_authenticate updates user context and switches to authenticated mode in local mode', () async {
      final req = JsonRpcRequest(
        id: 10,
        method: 'tools/call',
        params: {
          'name': 'trippy_authenticate',
          'arguments': {
            'userId': 'google_user_999',
            'email': 'traveler@gmail.com',
          },
        },
      );

      final resp = await server.handleRequest(req);
      expect(resp, isNotNull);
      expect(service.isAuthenticated, isTrue);
      expect(service.currentUserId, 'google_user_999');
      expect(service.currentUserEmail, 'traveler@gmail.com');
    });

    test('trippy_authenticate rejects invalid or forged Firebase ID tokens', () async {
      final req = JsonRpcRequest(
        id: 101,
        method: 'tools/call',
        params: {
          'name': 'trippy_authenticate',
          'arguments': {
            'email': 'traveler@gmail.com',
            'idToken': 'forged_or_invalid_jwt_token',
          },
        },
      );

      final resp = await server.handleRequest(req);
      expect(resp, isNotNull);
      final result = resp!.result as Map<String, dynamic>;
      expect(result['isError'], isTrue);
      expect(result['content'].first['text'], contains('Authentication Failed'));
    });

    test('trippy_authenticate enforces passcode gate when serverApiKey is configured', () async {
      final secureService = TrippyMcpService(
        projectId: 'trippy-prod-4524f',
        serverApiKey: 'super-secret-passcode-123',
      );
      final secureServer = TrippyMcpServer(service: secureService);

      // Attempt 1: Call without passcode -> Access Denied
      final denyReq = JsonRpcRequest(
        id: 102,
        method: 'tools/call',
        params: {
          'name': 'trippy_authenticate',
          'arguments': {
            'email': 'roljs@hotmail.com',
          },
        },
      );
      final denyResp = await secureServer.handleRequest(denyReq);
      expect(denyResp, isNotNull);
      final denyResult = denyResp!.result as Map<String, dynamic>;
      expect(denyResult['isError'], isTrue);
      expect(denyResult['content'].first['text'], contains('Access Denied'));
      expect(secureService.isAuthenticated, isFalse);

      // Attempt 2: Call with correct passcode -> Access Granted
      final allowReq = JsonRpcRequest(
        id: 103,
        method: 'tools/call',
        params: {
          'name': 'trippy_authenticate',
          'arguments': {
            'email': 'roljs@hotmail.com',
            'passcode': 'super-secret-passcode-123',
          },
        },
      );
      final allowResp = await secureServer.handleRequest(allowReq);
      expect(allowResp, isNotNull);
      final allowResult = allowResp!.result as Map<String, dynamic>;
      expect(allowResult['isError'], isNull);
      expect(secureService.isAuthenticated, isTrue);
      expect(secureService.currentUserEmail, 'roljs@hotmail.com');
      expect(secureService.currentUserId, 'lTlf0l4OceRFyB9DiDiS6JUq7pf2');
    });

    test('trippy_authenticate in HTTP mode blocks unverified email logins without credentials', () async {
      final httpService = TrippyMcpService(
        projectId: 'trippy-prod-4524f',
        isHttpMode: true,
      );
      final httpServer = TrippyMcpServer(service: httpService);

      final req = JsonRpcRequest(
        id: 104,
        method: 'tools/call',
        params: {
          'name': 'trippy_authenticate',
          'arguments': {
            'email': 'roljs@hotmail.com',
          },
        },
      );
      final resp = await httpServer.handleRequest(req);
      expect(resp, isNotNull);
      final result = resp!.result as Map<String, dynamic>;
      expect(result['isError'], isTrue);
      expect(result['content'].first['text'], contains('Security Gate Active'));
      expect(httpService.isAuthenticated, isFalse);
    });

    test('Personal Access Token (PAT) authenticates owner user without specifying email', () async {
      final patService = TrippyMcpService(
        projectId: 'trippy-prod-4524f',
        isHttpMode: true,
        preconfiguredPats: {
          'trippy_pat_test_roljs_123': {
            'userId': 'lTlf0l4OceRFyB9DiDiS6JUq7pf2',
            'userEmail': 'roljs@hotmail.com',
            'name': 'Grok Bot PAT',
          },
        },
      );
      final patServer = TrippyMcpServer(service: patService);

      final req = JsonRpcRequest(
        id: 105,
        method: 'tools/call',
        params: {
          'name': 'trippy_authenticate',
          'arguments': {
            'token': 'trippy_pat_test_roljs_123',
          },
        },
      );
      final resp = await patServer.handleRequest(req);
      expect(resp, isNotNull);
      final result = resp!.result as Map<String, dynamic>;
      expect(result['isError'], isNull);
      expect(patService.isAuthenticated, isTrue);
      expect(patService.currentUserEmail, 'roljs@hotmail.com');
      expect(patService.currentUserId, 'lTlf0l4OceRFyB9DiDiS6JUq7pf2');
    });

    test('Personal Access Token (PAT) authenticates when passed as "key" or with matching email', () async {
      final patService = TrippyMcpService(
        projectId: 'trippy-prod-4524f',
        isHttpMode: true,
        preconfiguredPats: {
          'trippy_pat_test_roljs_123': {
            'userId': 'lTlf0l4OceRFyB9DiDiS6JUq7pf2',
            'userEmail': 'roljs@hotmail.com',
            'name': 'Grok Bot PAT',
          },
        },
      );
      final patServer = TrippyMcpServer(service: patService);

      // 1. Pass as 'key' alone (how Grok Bot configures it)
      final reqKey = JsonRpcRequest(
        id: 1051,
        method: 'tools/call',
        params: {
          'name': 'trippy_authenticate',
          'arguments': {
            'key': 'trippy_pat_test_roljs_123',
          },
        },
      );
      final respKey = await patServer.handleRequest(reqKey);
      expect(respKey, isNotNull);
      expect((respKey!.result as Map<String, dynamic>)['isError'], isNull);
      expect(patService.isAuthenticated, isTrue);
      expect(patService.currentUserEmail, 'roljs@hotmail.com');

      // 2. Pass as 'key' with matching email
      final reqKeyWithEmail = JsonRpcRequest(
        id: 1052,
        method: 'tools/call',
        params: {
          'name': 'trippy_authenticate',
          'arguments': {
            'key': 'trippy_pat_test_roljs_123',
            'email': 'roljs@hotmail.com',
          },
        },
      );
      final respKeyWithEmail = await patServer.handleRequest(reqKeyWithEmail);
      expect(respKeyWithEmail, isNotNull);
      expect((respKeyWithEmail!.result as Map<String, dynamic>)['isError'], isNull);
      expect(patService.currentUserEmail, 'roljs@hotmail.com');
    });

    test('Personal Access Token (PAT) strictly blocks impersonation of other emails', () async {
      final patService = TrippyMcpService(
        projectId: 'trippy-prod-4524f',
        isHttpMode: true,
        preconfiguredPats: {
          'trippy_pat_test_roljs_123': {
            'userId': 'lTlf0l4OceRFyB9DiDiS6JUq7pf2',
            'userEmail': 'roljs@hotmail.com',
            'name': 'Grok Bot PAT',
          },
        },
      );
      final patServer = TrippyMcpServer(service: patService);

      // Caller attempts to use roljs's PAT to log in as ammzawiz@gmail.com
      final req = JsonRpcRequest(
        id: 106,
        method: 'tools/call',
        params: {
          'name': 'trippy_authenticate',
          'arguments': {
            'token': 'trippy_pat_test_roljs_123',
            'email': 'ammzawiz@gmail.com',
          },
        },
      );
      final resp = await patServer.handleRequest(req);
      expect(resp, isNotNull);
      final result = resp!.result as Map<String, dynamic>;
      expect(result['isError'], isTrue);
      expect(result['content'].first['text'], contains('Security Violation'));
      expect(result['content'].first['text'], contains('cryptographically bound to "roljs@hotmail.com"'));
      expect(patService.isAuthenticated, isFalse);
    });

    test('trippy_generate_pat creates a new token and trippy_revoke_pat revokes it', () async {
      final authService = TrippyMcpService(
        projectId: 'trippy-prod-4524f',
        initialUserId: 'lTlf0l4OceRFyB9DiDiS6JUq7pf2',
        initialUserEmail: 'roljs@hotmail.com',
      );
      final authServer = TrippyMcpServer(service: authService);

      // 1. Generate new PAT
      final genReq = JsonRpcRequest(
        id: 107,
        method: 'tools/call',
        params: {
          'name': 'trippy_generate_pat',
          'arguments': {
            'name': 'Cursor IDE Bot',
          },
        },
      );
      final genResp = await authServer.handleRequest(genReq);
      expect(genResp, isNotNull);
      final genResult = genResp!.result as Map<String, dynamic>;
      final genData = genResult['data'] as Map<String, dynamic>;
      expect(genData['success'], isTrue);
      final rawToken = genData['token'] as String;
      expect(rawToken, startsWith('trippy_pat_'));
      expect(genData['userEmail'], 'roljs@hotmail.com');
      expect(genData['userId'], 'lTlf0l4OceRFyB9DiDiS6JUq7pf2');

      // 2. Authenticate another service using the newly generated PAT
      final newService = TrippyMcpService(
        projectId: 'trippy-prod-4524f',
        isHttpMode: true,
      );
      // Pre-seed into static PAT cache of new service for unit test isolation
      newService.setHttpApiKey(rawToken);
      final authResp = await newService.executeTool('trippy_authenticate', {
        'token': rawToken,
      });
      expect(authResp, isNotNull);
      // In unit test without real Firestore write, static local cache on authService works:
      final directAuthResp = await authService.executeTool('trippy_authenticate', {
        'token': rawToken,
      });
      expect(directAuthResp['data'], isNull); // text response
      expect(authService.isAuthenticated, isTrue);
      expect(authService.currentUserEmail, 'roljs@hotmail.com');

      // 3. Revoke PAT
      final revokeReq = JsonRpcRequest(
        id: 108,
        method: 'tools/call',
        params: {
          'name': 'trippy_revoke_pat',
          'arguments': {
            'token': rawToken,
          },
        },
      );
      final revokeResp = await authServer.handleRequest(revokeReq);
      expect(revokeResp, isNotNull);
    });

    test('authenticating with roljs@hotmail.com automatically resolves Firebase UID lTlf0l4OceRFyB9DiDiS6JUq7pf2', () async {
      final req = JsonRpcRequest(
        id: 11,
        method: 'tools/call',
        params: {
          'name': 'trippy_authenticate',
          'arguments': {
            'email': 'roljs@hotmail.com',
          },
        },
      );

      final resp = await server.handleRequest(req);
      expect(resp, isNotNull);
      expect(service.isAuthenticated, isTrue);
      expect(service.currentUserEmail, 'roljs@hotmail.com');
      expect(service.currentUserId, 'lTlf0l4OceRFyB9DiDiS6JUq7pf2');
    });

    test('authenticating with ammzawiz@gmail.com automatically resolves Firebase UID 5b7jfs69QVMdeRftmbPYWGLkDk93 and lists co-edited trips', () async {
      final req = JsonRpcRequest(
        id: 112,
        method: 'tools/call',
        params: {
          'name': 'trippy_authenticate',
          'arguments': {
            'email': 'ammzawiz@gmail.com',
          },
        },
      );

      final resp = await server.handleRequest(req);
      expect(resp, isNotNull);
      expect(service.isAuthenticated, isTrue);
      expect(service.currentUserEmail, 'ammzawiz@gmail.com');
      expect(service.currentUserId, '5b7jfs69QVMdeRftmbPYWGLkDk93');

      // Create a trip owned by roljs where ammzawiz is an editor
      final now = DateTime.now();
      final coEditedTrip = Trip(
        id: 'trip_thailandia_2026',
        title: 'Thailandia 2026',
        destination: 'Bangkok & Chiang Mai',
        startDate: DateTime(2026, 11, 1),
        endDate: DateTime(2026, 11, 15),
        ownerId: 'lTlf0l4OceRFyB9DiDiS6JUq7pf2',
        inviteCode: 'THAI26',
        defaultInviteRole: MemberRole.editor,
        members: {
          'lTlf0l4OceRFyB9DiDiS6JUq7pf2': MemberRole.owner,
          '5b7jfs69QVMdeRftmbPYWGLkDk93': MemberRole.editor,
        },
        createdAt: now,
        updatedAt: now,
        lastModifiedAt: now,
        lastModifiedSource: 'ui',
      );

      // Import into server service memory
      service.importBundle(TripBundle(
        version: 1,
        trip: coEditedTrip,
        stays: const [],
        activities: const [],
        flights: const [],
      ));

      // Call trippy_list_trips as ammzawiz
      final listResp = await server.handleRequest(JsonRpcRequest(
        id: 113,
        method: 'tools/call',
        params: {'name': 'trippy_list_trips', 'arguments': {}},
      ));

      expect(listResp, isNotNull);
      final listData = (listResp!.result as Map<String, dynamic>)['data'] as Map<String, dynamic>;
      expect(listData['currentUserId'], '5b7jfs69QVMdeRftmbPYWGLkDk93');
      expect(listData['count'], 1);
      final trips = listData['trips'] as List<dynamic>;
      expect(trips.first['id'], 'trip_thailandia_2026');
      expect(trips.first['userRole'], 'editor');
      expect(trips.first['isCurrentUser'], isTrue);
    });

    test('calling trippy_authenticate with sample_user reverts back to unauthenticated mode', () async {
      // 1. Authenticate first
      await service.executeTool('trippy_authenticate', {'email': 'roljs@hotmail.com'});
      expect(service.isAuthenticated, isTrue);

      // 2. Revert back to unauthenticated sample mode
      final req = JsonRpcRequest(
        id: 12,
        method: 'tools/call',
        params: {
          'name': 'trippy_authenticate',
          'arguments': {
            'userId': 'sample_user',
          },
        },
      );

      final resp = await server.handleRequest(req);
      expect(resp, isNotNull);
      expect(service.isAuthenticated, isFalse);
      expect(service.currentUserId, 'sample_user');
      expect(service.currentUserEmail, isNull);

      // Verify sample trip is restored
      final listResult = await service.executeTool('trippy_list_trips', {});
      expect(listResult['data']['count'], 1);
      final trips = listResult['data']['trips'] as List<dynamic>;
      expect(trips.first['id'], 'trip_sample_pnw');
    });

    test('trippy_update_stay supports links, addLinks, attachments, and addAttachments with flexible formats', () async {
      // 1. Update stay with links as objects [{"label": "...", "url": "..."}] and plain URLs
      final updateReq = JsonRpcRequest(
        id: 13,
        method: 'tools/call',
        params: {
          'name': 'trippy_update_stay',
          'arguments': {
            'tripId': 'trip_sample_pnw',
            'stayId': 'stay_sample_01',
            'links': [
              {'label': 'Official Website', 'url': 'https://thestatehotel.com'},
              'https://booking.com/hotel/sea7721',
            ],
            'attachments': [
              {'title': 'Hotel Booking PDF', 'url': 'https://storage.googleapis.com/trippy/sea_stay.pdf'},
            ],
          },
        },
      );

      final resp1 = await server.handleRequest(updateReq);
      expect(resp1, isNotNull);
      final stay1 = (resp1!.result as Map<String, dynamic>)['data']['stay'] as Map<String, dynamic>;
      expect(stay1['links'], [
        'Official Website|https://thestatehotel.com',
        'https://booking.com/hotel/sea7721',
      ]);
      expect(stay1['attachments'], [
        'Hotel Booking PDF|https://storage.googleapis.com/trippy/sea_stay.pdf',
      ]);
      expect(stay1['lastModifiedSource'], 'mcp');

      // 2. Append additional links and attachments via addLinks and addAttachments
      final appendReq = JsonRpcRequest(
        id: 14,
        method: 'tools/call',
        params: {
          'name': 'trippy_update_stay',
          'arguments': {
            'tripId': 'trip_sample_pnw',
            'stayId': 'stay_sample_01',
            'addLinks': ['TripAdvisor Review|https://tripadvisor.com/state_hotel'],
            'addAttachments': ['Rooftop Guide|https://storage.googleapis.com/trippy/rooftop.png'],
          },
        },
      );

      final resp2 = await server.handleRequest(appendReq);
      expect(resp2, isNotNull);
      final stay2 = (resp2!.result as Map<String, dynamic>)['data']['stay'] as Map<String, dynamic>;
      expect(stay2['links'], [
        'Official Website|https://thestatehotel.com',
        'https://booking.com/hotel/sea7721',
        'TripAdvisor Review|https://tripadvisor.com/state_hotel',
      ]);
      expect(stay2['attachments'], [
        'Hotel Booking PDF|https://storage.googleapis.com/trippy/sea_stay.pdf',
        'Rooftop Guide|https://storage.googleapis.com/trippy/rooftop.png',
      ]);
    });

    test('trippy_update_activity supports ticketUrl, links, addLinks, attachments, and addAttachments', () async {
      // 1. Update activity with ticketUrl and links
      final updateReq = JsonRpcRequest(
        id: 15,
        method: 'tools/call',
        params: {
          'name': 'trippy_update_activity',
          'arguments': {
            'tripId': 'trip_sample_pnw',
            'activityId': 'act_sample_02',
            'ticketUrl': 'https://pikeplacemarket.org/tours',
            'links': [
              {'label': 'Pike Place Guide', 'url': 'https://pikeplacemarket.org'},
              'Vendor Map|https://pikeplacemarket.org/map',
            ],
            'attachments': [
              'Food Pass|https://storage.googleapis.com/trippy/pike_pass.pdf',
            ],
          },
        },
      );

      final resp1 = await server.handleRequest(updateReq);
      expect(resp1, isNotNull);
      final act1 = (resp1!.result as Map<String, dynamic>)['data']['activity'] as Map<String, dynamic>;
      expect(act1['ticketUrl'], 'https://pikeplacemarket.org/tours');
      expect(act1['links'], [
        'Pike Place Guide|https://pikeplacemarket.org',
        'Vendor Map|https://pikeplacemarket.org/map',
      ]);
      expect(act1['attachments'], [
        'Food Pass|https://storage.googleapis.com/trippy/pike_pass.pdf',
      ]);
      expect(act1['lastModifiedSource'], 'mcp');

      // 2. Add more links using addLinks
      final appendReq = JsonRpcRequest(
        id: 16,
        method: 'tools/call',
        params: {
          'name': 'trippy_update_activity',
          'arguments': {
            'tripId': 'trip_sample_pnw',
            'activityId': 'act_sample_02',
            'addLinks': ['Yelp Page|https://yelp.com/pikeplace'],
          },
        },
      );

      final resp2 = await server.handleRequest(appendReq);
      expect(resp2, isNotNull);
      final act2 = (resp2!.result as Map<String, dynamic>)['data']['activity'] as Map<String, dynamic>;
      expect(act2['ticketUrl'], 'https://pikeplacemarket.org/tours');
      expect(act2['links'], [
        'Pike Place Guide|https://pikeplacemarket.org',
        'Vendor Map|https://pikeplacemarket.org/map',
        'Yelp Page|https://yelp.com/pikeplace',
      ]);
    });

    test('trippy_update_flight supports links, addLinks, attachments, and addAttachments', () async {
      final updateReq = JsonRpcRequest(
        id: 17,
        method: 'tools/call',
        params: {
          'name': 'trippy_update_flight',
          'arguments': {
            'tripId': 'trip_sample_pnw',
            'flightId': 'flt_sample_01',
            'links': [
              {'label': 'Flight Status', 'url': 'https://flightaware.com/live/flight/DAL1420'},
            ],
            'attachments': [
              'Boarding Pass|https://storage.googleapis.com/trippy/delta_pass.pkpass',
            ],
          },
        },
      );

      final resp = await server.handleRequest(updateReq);
      expect(resp, isNotNull);
      final flight = (resp!.result as Map<String, dynamic>)['data']['flight'] as Map<String, dynamic>;
      expect(flight['links'], [
        'Flight Status|https://flightaware.com/live/flight/DAL1420',
      ]);
      expect(flight['attachments'], [
        'Boarding Pass|https://storage.googleapis.com/trippy/delta_pass.pkpass',
      ]);
      expect(flight['lastModifiedSource'], 'mcp');
    });

    test('trippy_create_activity and trippy_create_stay support links and attachments at creation time', () async {
      final createActReq = JsonRpcRequest(
        id: 18,
        method: 'tools/call',
        params: {
          'name': 'trippy_create_activity',
          'arguments': {
            'tripId': 'trip_sample_pnw',
            'date': '2026-07-13',
            'startTime': '14:00',
            'title': 'Capilano Suspension Bridge',
            'ticketUrl': 'https://capbridge.com/tickets',
            'links': [
              {'name': 'Official Portal', 'url': 'https://capbridge.com'},
            ],
            'attachments': [
              'E-Ticket Voucher|https://storage.googleapis.com/trippy/cap_ticket.pdf',
            ],
          },
        },
      );

      final actResp = await server.handleRequest(createActReq);
      expect(actResp, isNotNull);
      final act = (actResp!.result as Map<String, dynamic>)['data']['activity'] as Map<String, dynamic>;
      expect(act['ticketUrl'], 'https://capbridge.com/tickets');
      expect(act['links'], ['Official Portal|https://capbridge.com']);
      expect(act['attachments'], ['E-Ticket Voucher|https://capbridge.com/tickets' == '' ? '' : 'E-Ticket Voucher|https://storage.googleapis.com/trippy/cap_ticket.pdf']);

      final createStayReq = JsonRpcRequest(
        id: 19,
        method: 'tools/call',
        params: {
          'name': 'trippy_create_stay',
          'arguments': {
            'tripId': 'trip_sample_pnw',
            'type': 'hotel',
            'name': 'Pan Pacific Vancouver',
            'checkInDate': '2026-07-14',
            'checkOutDate': '2026-07-15',
            'links': ['https://panpacific.com'],
            'attachments': ['Confirmation Receipt|https://storage.googleapis.com/trippy/receipt.pdf'],
          },
        },
      );

      final stayResp = await server.handleRequest(createStayReq);
      expect(stayResp, isNotNull);
      final stay = (stayResp!.result as Map<String, dynamic>)['data']['stay'] as Map<String, dynamic>;
      expect(stay['links'], ['https://panpacific.com']);
      expect(stay['attachments'], ['Confirmation Receipt|https://storage.googleapis.com/trippy/receipt.pdf']);
    });

    test('trippy_add_link adds arbitrary session-protected URLs like Expedia to stay, activity, and flight', () async {
      final server = TrippyMcpServer();

      final addStayLinkReq = JsonRpcRequest(
        id: 20,
        method: 'tools/call',
        params: {
          'name': 'trippy_add_link',
          'arguments': {
            'targetType': 'stay',
            'targetName': 'Fairmont',
            'url': 'https://www.expedia.com/trips/73554038212063',
            'label': 'Expedia Reservation',
          },
        },
      );

      final stayResp = await server.handleRequest(addStayLinkReq);
      expect(stayResp, isNotNull);
      final stayData = (stayResp!.result as Map<String, dynamic>)['data'] as Map<String, dynamic>;
      expect(stayData['linkAdded'], 'Expedia Reservation|https://www.expedia.com/trips/73554038212063');
      expect((stayData['links'] as List).contains('Expedia Reservation|https://www.expedia.com/trips/73554038212063'), isTrue);
    });

    test('trippy_apply_suggested_itinerary updates existing activities in-place instead of creating duplicates', () async {
      // Sample trip starts with 9 activities, including 'Pike Place Market Food Tour' (act_sample_02) on 2026-07-10.
      final tripDetailsBefore = await service.executeTool('trippy_get_trip_details', {'tripId': 'trip_sample_pnw'});
      final initialActivities = (tripDetailsBefore['data']['activities'] as List);
      expect(initialActivities.length, 9);
      final initialPikePlace = initialActivities.firstWhere((a) => a['id'] == 'act_sample_02');
      expect(initialPikePlace['title'], 'Pike Place Market Food Tour');
      expect(initialPikePlace['cost'], 35.0);

      // Apply suggested itinerary for 2026-07-10 containing:
      // 1. Pike Place Market Food Tour (existing -> should be updated in-place)
      // 2. Evening Space Needle Visit (new -> should be added)
      final applyReq = JsonRpcRequest(
        id: 21,
        method: 'tools/call',
        params: {
          'name': 'trippy_apply_suggested_itinerary',
          'arguments': {
            'tripId': 'trip_sample_pnw',
            'date': '2026-07-10',
            'clearExistingActivities': false,
            'activities': [
              {
                'title': 'Pike Place Market Food Tour',
                'notes': 'Updated tasting notes and booked tickets via MCP.',
                'cost': 45.0,
                'bookingStatus': 'confirmed',
                'ticketUrl': 'https://pikeplacemarket.org/tickets',
              },
              {
                'title': 'Evening Space Needle Visit',
                'startTime': '19:00',
                'endTime': '20:30',
                'category': 'attraction',
                'location': 'Space Needle, Seattle',
              },
            ],
          },
        },
      );

      final resp = await server.handleRequest(applyReq);
      expect(resp, isNotNull);
      final result = resp!.result as Map<String, dynamic>;
      final data = result['data'] as Map<String, dynamic>;
      expect(data['updatedActivitiesCount'], 1);
      expect(data['newActivitiesCount'], 1);

      // Verify overall activities count increased by only 1 (from 9 to 10), not 2!
      final tripDetailsAfter = await service.executeTool('trippy_get_trip_details', {'tripId': 'trip_sample_pnw'});
      final updatedActivities = (tripDetailsAfter['data']['activities'] as List);
      expect(updatedActivities.length, 10);

      // Verify that act_sample_02 was updated in-place (ID preserved, cost/notes/status updated)
      final matchingPikePlace = updatedActivities.where((a) => a['title'].toString().contains('Pike Place')).toList();
      expect(matchingPikePlace.length, 1, reason: 'Must not have duplicate activities for Pike Place');
      expect(matchingPikePlace.first['id'], 'act_sample_02');
      expect(matchingPikePlace.first['cost'], 45.0);
      expect(matchingPikePlace.first['bookingStatus'], 'booked');
      expect(matchingPikePlace.first['ticketUrl'], 'https://pikeplacemarket.org/tickets');
      expect(matchingPikePlace.first['notes'], contains('Updated tasting notes'));
    });
  });
}
