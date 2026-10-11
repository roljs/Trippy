import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'trippy_mcp_models.dart';
import 'trippy_mcp_service.dart';

/// The Trippy Model Context Protocol (MCP) Server.
/// Supports both stdio (for desktop clients like Claude, Antigravity, Cursor)
/// and HTTP/SSE (for ChatGPT Actions, Gemini Extensions, Web & Mobile apps).
class TrippyMcpServer {
  final TrippyMcpService service;
  HttpServer? _httpServer;
  final List<HttpResponse> _sseClients = [];

  TrippyMcpServer({TrippyMcpService? service})
      : service = service ?? TrippyMcpService();

  /// Process an incoming JSON-RPC 2.0 request and return the response.
  Future<JsonRpcResponse?> handleRequest(JsonRpcRequest request) async {
    final id = request.id;
    final method = request.method;
    final params = request.params ?? const <String, dynamic>{};

    switch (method) {
      case 'initialize':
        return JsonRpcResponse.success(id, {
          'protocolVersion': '2024-11-05',
          'capabilities': {
            'tools': {'listChanged': false},
          },
          'serverInfo': {
            'name': 'trippy-mcp-server',
            'version': '1.0.0',
            'description':
                'Trippy Travel Itinerary MCP Server. Create, read, and modify trips, '
                'activities, stays, flights, and directly translate AI daily itineraries.',
          },
        });

      case 'notifications/initialized':
        // Acknowledge notification; notifications do not expect a response in JSON-RPC
        return null;

      case 'ping':
        return JsonRpcResponse.success(id, {});

      case 'tools/list':
        return JsonRpcResponse.success(id, {
          'tools': TrippyMcpToolDefinitions.tools.map((t) => t.toMap()).toList(),
        });

      case 'tools/call':
        final toolName = params['name'] as String?;
        final arguments = params['arguments'] is Map
            ? Map<String, dynamic>.from(params['arguments'])
            : <String, dynamic>{};

        if (toolName == null || toolName.isEmpty) {
          return JsonRpcResponse.error(id, -32602, 'Tool name is required.');
        }

        final toolResult = await service.executeTool(toolName, arguments);
        return JsonRpcResponse.success(id, toolResult);

      default:
        return JsonRpcResponse.error(id, -32601, 'Method not found: $method');
    }
  }

  /// Start the stdio JSON-RPC loop (stdin -> handle -> stdout).
  Future<void> runStdio() async {
    final lines = stdin
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final req = JsonRpcRequest.tryParse(trimmed);
      if (req == null) {
        stdout.writeln(
          JsonRpcResponse.error(null, -32700, 'Parse error: invalid JSON')
              .toJson(),
        );
        continue;
      }

      final resp = await handleRequest(req);
      if (resp != null) {
        stdout.writeln(resp.toJson());
      }
    }
  }

  /// Start an HTTP and SSE server on the specified port.
  Future<HttpServer> startHttpServer({int port = 8080}) async {
    final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    _httpServer = server;

    server.listen((HttpRequest request) async {
      _applyCors(request.response);

      if (request.method == 'OPTIONS') {
        request.response.statusCode = HttpStatus.ok;
        await request.response.close();
        return;
      }

      final path = request.uri.path;

      // Extract Authorization header if present
      final authHeader = request.headers.value(HttpHeaders.authorizationHeader);
      if (authHeader != null && authHeader.startsWith('Bearer ')) {
        final token = authHeader.substring('Bearer '.length).trim();
        service.setAuth(token: token);
      }

      if (path == '/' || path == '/health') {
        _handleHealth(request);
      } else if (path == '/mcp' || path == '/api/mcp') {
        await _handleHttpMcp(request);
      } else if (path == '/sse') {
        _handleSse(request);
      } else if (path == '/messages') {
        await _handleSseMessage(request);
      } else if (path == '/api/trips') {
        await _handleRestListTrips(request);
      } else if (path.startsWith('/api/trips/') && path.endsWith('/suggested-itinerary')) {
        await _handleRestSuggestedItinerary(request);
      } else {
        request.response.statusCode = HttpStatus.notFound;
        request.response.write(jsonEncode({'error': 'Not found', 'path': path}));
        await request.response.close();
      }
    });

    return server;
  }

  void _applyCors(HttpResponse response) {
    response.headers.set('Access-Control-Allow-Origin', '*');
    response.headers.set(
        'Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
    response.headers.set('Access-Control-Allow-Headers',
        'Origin, Content-Type, Authorization, Accept, X-Requested-With');
  }

  void _handleHealth(HttpRequest request) {
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({
      'status': 'online',
      'server': 'Trippy MCP Server',
      'version': '1.0.0',
      'project': service.projectId,
      'currentUser': service.currentUserId,
      'authenticated': service.authToken != null && service.authToken!.isNotEmpty,
      'toolsCount': TrippyMcpToolDefinitions.tools.length,
    }));
    request.response.close();
  }

  Future<void> _handleHttpMcp(HttpRequest request) async {
    if (request.method != 'POST') {
      request.response.statusCode = HttpStatus.methodNotAllowed;
      await request.response.close();
      return;
    }

    final body = await utf8.decoder.bind(request).join();
    final jsonReq = JsonRpcRequest.tryParse(body);

    request.response.headers.contentType = ContentType.json;
    if (jsonReq == null) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.write(
        JsonRpcResponse.error(null, -32700, 'Invalid JSON-RPC request').toJson(),
      );
      await request.response.close();
      return;
    }

    final resp = await handleRequest(jsonReq);
    if (resp != null) {
      request.response.write(resp.toJson());
    } else {
      request.response.statusCode = HttpStatus.noContent;
    }
    await request.response.close();
  }

  void _handleSse(HttpRequest request) {
    request.response.headers.contentType = ContentType('text', 'event-stream');
    request.response.headers.set('Cache-Control', 'no-cache');
    request.response.headers.set('Connection', 'keep-alive');

    _sseClients.add(request.response);
    request.response.write('event: endpoint\ndata: /messages\n\n');

    request.response.done.then((_) {
      _sseClients.remove(request.response);
    });
  }

  Future<void> _handleSseMessage(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    final jsonReq = JsonRpcRequest.tryParse(body);
    if (jsonReq != null) {
      final resp = await handleRequest(jsonReq);
      if (resp != null) {
        for (final client in _sseClients) {
          client.write('event: message\ndata: ${resp.toJson()}\n\n');
        }
      }
    }
    request.response.statusCode = HttpStatus.accepted;
    await request.response.close();
  }

  // REST endpoints
  Future<void> _handleRestListTrips(HttpRequest request) async {
    final result = await service.executeTool('trippy_list_trips', {});
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(result['data'] ?? result));
    await request.response.close();
  }

  Future<void> _handleRestSuggestedItinerary(HttpRequest request) async {
    final segments = request.uri.pathSegments;
    final tripId = segments[2];
    final body = await utf8.decoder.bind(request).join();
    Map<String, dynamic> params = {};
    try {
      params = jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {}
    params['tripId'] = tripId;

    final result = await service.executeTool('trippy_apply_suggested_itinerary', params);
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(result));
    await request.response.close();
  }

  Future<void> stop() async {
    for (final client in _sseClients) {
      await client.close();
    }
    _sseClients.clear();
    await _httpServer?.close(force: true);
    _httpServer = null;
  }
}
