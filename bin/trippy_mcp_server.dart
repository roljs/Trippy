import 'dart:io';
import 'package:trippy/mcp/trippy_mcp_server.dart';
import 'package:trippy/mcp/trippy_mcp_service.dart';

void main(List<String> args) async {
  int? port;
  bool useStdio = false;
  String? userId;
  String? token;
  String? email;
  String? apiKey;

  for (int i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--help' || arg == '-h') {
      stderr.writeln('''
Trippy MCP Server
=================
Model Context Protocol (MCP) server for Trippy Travel Planner.
Usable from Claude Desktop, Antigravity IDE, ChatGPT Actions, Gemini, Cursor, mobile & web.

Usage:
  dart run bin/trippy_mcp_server.dart [options]

Options:
  --port, -p <port>     Start HTTP / SSE server on specified port (e.g. 8080).
  --stdio               Run standard I/O JSON-RPC loop (default if no --port).
  --api-key <key>       Set security passcode / API key for MCP authentication.
  --user <userId>       Set default user ID.
  --email <email>       Set default user email.
  --token <token>       Set default Google/Firebase Auth Bearer token.
  --help, -h            Show this help message.

Environment Variables:
  PORT                  HTTP port if set.
  TRIPPY_API_KEY        Security passcode / API key for authenticating AI clients.
  TRIPPY_AUTH_TOKEN     Google/Firebase ID token.
  TRIPPY_USER_ID        User UID.
  TRIPPY_USER_EMAIL     User email address.
  TRIPPY_PROJECT_ID     GCP / Firebase project ID.
''');
      exit(0);
    } else if (arg == '--port' || arg == '-p') {
      if (i + 1 < args.length) {
        port = int.tryParse(args[++i]);
      }
    } else if (arg.startsWith('--port=')) {
      port = int.tryParse(arg.substring('--port='.length));
    } else if (arg == '--stdio') {
      useStdio = true;
    } else if ((arg == '--api-key' || arg == '--passcode') && i + 1 < args.length) {
      apiKey = args[++i];
    } else if (arg == '--user' && i + 1 < args.length) {
      userId = args[++i];
    } else if (arg == '--email' && i + 1 < args.length) {
      email = args[++i];
    } else if (arg == '--token' && i + 1 < args.length) {
      token = args[++i];
    }
  }

  // Check PORT env var
  if (port == null && Platform.environment.containsKey('PORT')) {
    port = int.tryParse(Platform.environment['PORT']!);
  }

  // Default to stdio if port is not specified
  if (port == null && !useStdio) {
    useStdio = true;
  }

  final isHttp = port != null;
  final service = TrippyMcpService(
    projectId: Platform.environment['TRIPPY_PROJECT_ID'] ?? 'trippy-prod-4524f',
    initialAuthToken: token,
    initialUserId: userId,
    initialUserEmail: email,
    serverApiKey: apiKey,
    isHttpMode: isHttp,
  );
  final server = TrippyMcpServer(service: service);

  if (port != null) {
    final http = await server.startHttpServer(port: port);
    stderr.writeln(
      '🚀 Trippy MCP Server HTTP/SSE listening on http://localhost:${http.port}',
    );
    if (service.serverApiKey != null && service.serverApiKey!.isNotEmpty) {
      stderr.writeln('🔐 Security Gate: ACTIVE (TRIPPY_API_KEY configured)');
    } else {
      stderr.writeln('⚠️ Security Warning: TRIPPY_API_KEY not set. Passcode gate will require configuration.');
    }
    stderr.writeln('   • MCP JSON-RPC: POST http://localhost:${http.port}/mcp');
    stderr.writeln('   • SSE endpoint: GET  http://localhost:${http.port}/sse');
    stderr.writeln('   • Health check: GET  http://localhost:${http.port}/health');
  }

  if (useStdio) {
    stderr.writeln('🔌 Trippy MCP Server stdio transport active.');
    await server.runStdio();
  }
}
