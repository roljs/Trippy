import 'dart:io';
import 'dart:math';

import 'package:trippy/mcp/firestore_rest_client.dart';
import 'package:trippy/mcp/trippy_mcp_service.dart';

void main(List<String> args) async {
  String? email;
  String? name = 'MCP AI Client';
  String? uid;
  String projectId = Platform.environment['TRIPPY_PROJECT_ID'] ?? 'trippy-prod-4524f';

  for (int i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--email' && i + 1 < args.length) {
      email = args[++i];
    } else if (arg == '--name' && i + 1 < args.length) {
      name = args[++i];
    } else if (arg == '--uid' && i + 1 < args.length) {
      uid = args[++i];
    } else if (arg == '--project' && i + 1 < args.length) {
      projectId = args[++i];
    } else if (arg == '--help' || arg == '-h') {
      stdout.writeln('''
Create Trippy Personal Access Token (PAT)
=========================================
Generates a cryptographically secure token tied strictly to one user account.
Prevents identity impersonation across AI clients (Grok Bot, Gemini, Claude, Cursor).

Usage:
  dart run bin/create_pat.dart --email <email> [--name <label>] [--uid <uid>]

Options:
  --email <email>   User email address (e.g. roljs@hotmail.com).
  --name <label>    Friendly label for token (e.g. "Grok Bot", "Laptop Cursor").
  --uid <uid>       User UID (auto-resolved if omitted).
  --project <id>    Google Cloud / Firebase project ID.
''');
      exit(0);
    }
  }

  if (email == null || email.trim().isEmpty) {
    stderr.writeln('❌ Error: --email is required. Run with --help for usage.');
    exit(1);
  }

  email = email.trim();
  uid ??= TrippyMcpService.resolveKnownUid(email);

  // If UID is still unknown, try resolving with gcloud access token via Identity Toolkit
  String? gcloudToken;
  for (final cmd in [
    'gcloud',
    r'C:\Users\roljs\AppData\Local\Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd',
  ]) {
    try {
      final proc = await Process.run(
        cmd,
        ['auth', 'print-access-token'],
        runInShell: true,
      );
      if (proc.exitCode == 0 && (proc.stdout as String).trim().isNotEmpty) {
        gcloudToken = (proc.stdout as String).trim();
        break;
      }
    } catch (_) {}
  }

  final firestore = FirestoreRestClient(
    projectId: projectId,
    initialToken: gcloudToken,
  );

  if (uid == null || uid.isEmpty) {
    stdout.writeln('🔍 Looking up Firebase UID for $email...');
    uid = await firestore.lookupUidByEmail(email);
  }

  if (uid == null || uid.isEmpty) {
    stderr.writeln('❌ Error: Could not resolve Firebase UID for email "$email".');
    stderr.writeln('Please specify --uid <user_uid> explicitly.');
    exit(1);
  }

  // Generate secure random 192-bit token
  final randomBytes = List<int>.generate(24, (_) => Random.secure().nextInt(256));
  final tokenHex = randomBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  final rawToken = 'trippy_pat_$tokenHex';

  stdout.writeln('🔐 Registering Personal Access Token in Cloud Firestore...');
  final success = await firestore.registerPersonalAccessToken(
    rawToken: rawToken,
    userId: uid,
    userEmail: email,
    name: name ?? 'MCP Access Token',
  );

  if (!success) {
    stderr.writeln('⚠️ Note: Could not write directly to Firestore (check your gcloud auth).');
    stderr.writeln('However, you can configure this token statically on Cloud Run via TRIPPY_PATS:');
    stderr.writeln('  --set-env-vars TRIPPY_PATS="$email:$uid:$rawToken"');
  } else {
    stdout.writeln('✅ Personal Access Token successfully saved in Firestore collection mcp_api_keys!');
  }

  final mcpUrl = 'https://trippy-mcp-server-392329008088.us-central1.run.app/mcp?key=$rawToken';
  final sseUrl = 'https://trippy-mcp-server-392329008088.us-central1.run.app/sse?key=$rawToken';

  stdout.writeln('''
================================================================================
🎉 PERSONAL ACCESS TOKEN GENERATED SUCCESSFULLY
================================================================================
• User Email: $email
• User UID:   $uid
• Token Name: $name
• Raw Token:  $rawToken

================================================================================
🤖 READY-TO-USE MCP URLS FOR AI BOTS (Grok Bot, Gemini, ChatGPT):
================================================================================
Streamable HTTP POST (Grok Bot, ChatGPT Actions, Gemini):
  $mcpUrl

Server-Sent Events (SSE) (Claude Desktop, Cursor):
  $sseUrl

================================================================================
🔒 IMPERSONATION PROTECTION IS ACTIVE:
This token is cryptographically bound to $email.
No other user or email can be accessed using this token.
================================================================================
''');
}
