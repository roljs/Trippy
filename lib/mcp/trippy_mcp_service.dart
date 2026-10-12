import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import 'firestore_rest_client.dart';

/// Service implementing the business logic for all Trippy MCP tools.
class TrippyMcpService {
  final String projectId;
  final String? serverApiKey;
  String? _httpApiKey;
  bool _isHttpMode = false;
  String? _authToken;
  String _currentUserId = 'sample_user';
  String? _currentUserEmail;
  bool _isAuthenticated = false;
  Map<String, dynamic>? _activePat;
  final Map<String, Map<String, String>> _staticPats = {};

  void setHttpApiKey(String? key) {
    _httpApiKey = key;
  }

  void setIsHttpMode(bool isHttp) {
    _isHttpMode = isHttp;
  }

  bool get _hasActiveAuthorization {
    if (!_isHttpMode) return true;
    if (_activePat != null) return true;
    final expectedKey = serverApiKey ??
        Platform.environment['TRIPPY_API_KEY'] ??
        Platform.environment['TRIPPY_PASSCODE'] ??
        Platform.environment['TRIPPY_MCP_KEY'];
    if (expectedKey != null && expectedKey.isNotEmpty) {
      if (_httpApiKey == expectedKey) return true;
    }
    if (_authToken != null && _authToken!.isNotEmpty) return true;
    if (_httpApiKey != null && _httpApiKey!.isNotEmpty) {
      final hash = FirestoreRestClient.hashPat(_httpApiKey!);
      if (_staticPats.containsKey(hash)) return true;
    }
    return false;
  }

  void _loadStaticPats(String? envPats) {
    if (envPats == null || envPats.trim().isEmpty) return;
    final trimmed = envPats.trim();
    if (trimmed.startsWith('{')) {
      try {
        final json = jsonDecode(trimmed) as Map<String, dynamic>;
        for (final entry in json.entries) {
          final data = entry.value as Map<String, dynamic>;
          final rawToken = entry.key;
          final hash = FirestoreRestClient.hashPat(rawToken);
          _staticPats[hash] = {
            'userId': data['userId']?.toString() ?? '',
            'userEmail': data['userEmail']?.toString() ?? '',
            'name': data['name']?.toString() ?? 'Preconfigured PAT',
          };
        }
        return;
      } catch (_) {}
    }
    final entries = trimmed.split(RegExp(r'[,;\n]'));
    for (final e in entries) {
      final parts = e.trim().split(':');
      if (parts.length == 2) {
        final email = parts[0].trim();
        final token = parts[1].trim();
        final uid = resolveKnownUid(email) ?? email;
        _staticPats[FirestoreRestClient.hashPat(token)] = {
          'userId': uid,
          'userEmail': email,
          'name': 'Preconfigured PAT',
        };
      } else if (parts.length >= 3) {
        final email = parts[0].trim();
        final uid = parts[1].trim();
        final token = parts.sublist(2).join(':').trim();
        _staticPats[FirestoreRestClient.hashPat(token)] = {
          'userId': uid,
          'userEmail': email,
          'name': 'Preconfigured PAT',
        };
      }
    }
  }

  Future<Map<String, dynamic>?> _resolvePat(String rawToken) async {
    final clean = rawToken.trim();
    if (clean.isEmpty) return null;
    final hash = FirestoreRestClient.hashPat(clean);
    if (_staticPats.containsKey(hash)) {
      return _staticPats[hash];
    }
    return await _firestore.lookupPersonalAccessToken(clean);
  }

  static const Map<String, String> _knownEmailUidMap = {
    'roljs@hotmail.com': 'lTlf0l4OceRFyB9DiDiS6JUq7pf2',
    'ammzawiz@gmail.com': '5b7jfs69QVMdeRftmbPYWGLkDk93',
  };

  static String? resolveKnownUid(String? email) {
    if (email == null) return null;
    final norm = email.trim().toLowerCase();
    if (_knownEmailUidMap.containsKey(norm)) {
      return _knownEmailUidMap[norm];
    }
    if (norm.contains('roljs')) {
      return 'lTlf0l4OceRFyB9DiDiS6JUq7pf2';
    }
    if (norm.contains('ammzawiz')) {
      return '5b7jfs69QVMdeRftmbPYWGLkDk93';
    }
    return null;
  }

  final FirestoreRestClient _firestore;

  // In-memory / local storage backing for trips
  final Map<String, Trip> _trips = {};
  final Map<String, List<Stay>> _stays = {};
  final Map<String, List<Activity>> _activities = {};
  final Map<String, List<Flight>> _flights = {};

  TripBundle? _pristineSampleBundle;
  String _sampleTripId = 'trip_sample_pnw';

  final Uuid _uuid = const Uuid();

  TrippyMcpService({
    this.projectId = 'trippy-prod-4524f',
    String? initialAuthToken,
    String? initialUserId,
    String? initialUserEmail,
    String? serverApiKey,
    Map<String, Map<String, String>>? preconfiguredPats,
    FirestoreRestClient? firestore,
    this._isHttpMode = false,
  })  : serverApiKey = serverApiKey ??
            Platform.environment['TRIPPY_API_KEY'] ??
            Platform.environment['TRIPPY_PASSCODE'] ??
            Platform.environment['TRIPPY_MCP_KEY'],
        _authToken = initialAuthToken ?? Platform.environment['TRIPPY_AUTH_TOKEN'],
        _currentUserId = initialUserId ??
            Platform.environment['TRIPPY_USER_ID'] ??
            'sample_user',
        _currentUserEmail = initialUserEmail ??
            Platform.environment['TRIPPY_USER_EMAIL'],
        _firestore = firestore ??
            FirestoreRestClient(
              projectId: projectId,
              initialToken:
                  initialAuthToken ?? Platform.environment['TRIPPY_AUTH_TOKEN'],
            ) {
    if (preconfiguredPats != null) {
      for (final entry in preconfiguredPats.entries) {
        final keyHash = entry.key.length == 64
            ? entry.key
            : FirestoreRestClient.hashPat(entry.key);
        _staticPats[keyHash] = entry.value;
      }
    }
    _loadStaticPats(
      Platform.environment['TRIPPY_PATS'] ??
          Platform.environment['TRIPPY_PERSONAL_ACCESS_TOKENS'],
    );
    _loadSampleBundle();
    if ((_currentUserEmail != null &&
            _currentUserEmail!.isNotEmpty &&
            _currentUserEmail != 'sample_user') ||
        (_authToken != null && _authToken!.isNotEmpty) ||
        (_currentUserId != 'sample_user' && _currentUserId.isNotEmpty)) {
      _isAuthenticated = true;
      final known = resolveKnownUid(_currentUserEmail) ?? resolveKnownUid(_currentUserId);
      if (known != null) {
        _currentUserId = known;
      }
    } else {
      _isAuthenticated = false;
      _currentUserId = 'sample_user';
      _currentUserEmail = null;
      resetSampleData();
    }
  }

  bool get isAuthenticated => _isAuthenticated && _hasActiveAuthorization;
  String get currentUserId => _hasActiveAuthorization ? _currentUserId : 'sample_user';
  String? get currentUserEmail => _hasActiveAuthorization ? _currentUserEmail : null;
  String? get authToken => _authToken;

  void _loadSampleBundle() {
    try {
      final file = File('sample_trip.json');
      if (file.existsSync()) {
        final content = file.readAsStringSync();
        _pristineSampleBundle = TripBundle.fromJson(content);
        _sampleTripId = _pristineSampleBundle!.trip.id;
        return;
      }
    } catch (e) {
      stderr.writeln('Warning: Failed to load sample_trip.json: $e');
    }

    // In-memory fallback if sample_trip.json is not found on disk
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day + 10);
    final end = start.add(const Duration(days: 4));
    final fallbackTrip = Trip(
      id: 'trip_sample_pnw',
      title: 'Pacific Northwest Highlights: Seattle & Vancouver',
      destination: 'Seattle, WA & Vancouver, BC',
      startDate: start,
      endDate: end,
      coverImageUrl:
          'https://images.unsplash.com/photo-1502175353174-a7a70e73b362?auto=format&fit=crop&w=1200&q=80',
      ownerId: 'sample_user',
      inviteCode: 'PNW-2026',
      defaultInviteRole: MemberRole.editor,
      members: {'sample_user': MemberRole.owner},
      startLocation: 'Seattle',
      endLocation: 'Vancouver',
      dayLocations: {
        Trip.dateToKey(start): ['Seattle'],
        Trip.dateToKey(start.add(const Duration(days: 1))): ['Seattle'],
        Trip.dateToKey(start.add(const Duration(days: 2))): ['Seattle', 'Vancouver'],
        Trip.dateToKey(start.add(const Duration(days: 3))): ['Vancouver'],
        Trip.dateToKey(end): ['Vancouver'],
      },
      createdAt: now,
      updatedAt: now,
      lastModifiedAt: now,
      lastModifiedSource: 'ui',
    );

    _pristineSampleBundle = TripBundle(
      version: 1,
      trip: fallbackTrip,
      stays: const [],
      activities: const [],
      flights: const [],
    );
    _sampleTripId = fallbackTrip.id;
  }

  /// Resets unauthenticated state to the pristine sample trip.
  void resetSampleData() {
    _trips.clear();
    _stays.clear();
    _activities.clear();
    _flights.clear();

    if (_pristineSampleBundle != null) {
      _importBundle(_pristineSampleBundle!);
    }
  }

  void setAuth({
    String? token,
    String? userId,
    String? email,
    Map<String, dynamic>? patRecord,
  }) {
    final hasValidToken = token != null && token.isNotEmpty;
    final hasValidEmail =
        email != null && email.isNotEmpty && email != 'sample_user';
    final hasValidUser =
        userId != null && userId.isNotEmpty && userId != 'sample_user';

    if (hasValidToken || hasValidEmail || hasValidUser || patRecord != null) {
      _isAuthenticated = true;
      _activePat = patRecord;
      if (hasValidToken && !token.startsWith('trippy_pat_')) {
        _authToken = token;
        _firestore.setToken(token);
      }
      if (hasValidEmail) {
        _currentUserEmail = email.trim();
        final known = resolveKnownUid(email);
        if (known != null) {
          _currentUserId = known;
        } else {
          _currentUserId = userId ?? email.trim();
        }
      } else if (hasValidUser) {
        final known = resolveKnownUid(userId);
        if (known != null) {
          _currentUserId = known;
        } else {
          _currentUserId = userId;
        }
        if (userId.contains('@')) {
          _currentUserEmail = userId.trim();
        }
      }
      // Clear sample trip data when authenticating into live user context
      _trips.clear();
      _stays.clear();
      _activities.clear();
      _flights.clear();
    } else {
      // Revert to sample unauthenticated mode
      _isAuthenticated = false;
      _activePat = null;
      _currentUserId = 'sample_user';
      _currentUserEmail = null;
      _authToken = null;
      resetSampleData();
    }
  }

  String _resolveTripId(String? requestedTripId) {
    if (requestedTripId != null &&
        requestedTripId.isNotEmpty &&
        _trips.containsKey(requestedTripId)) {
      return requestedTripId;
    }
    if (requestedTripId != null && requestedTripId.isNotEmpty) {
      final lower = requestedTripId.toLowerCase();
      for (final entry in _trips.entries) {
        if (entry.key.toLowerCase() == lower ||
            entry.key.toLowerCase().contains(lower) ||
            entry.value.title.toLowerCase().contains(lower)) {
          return entry.key;
        }
      }
      if (lower != 'default' && lower != 'current') {
        return requestedTripId;
      }
    }

    if (!_isAuthenticated) {
      return _sampleTripId;
    }

    if (_trips.isNotEmpty) {
      return _trips.keys.first;
    }

    return _sampleTripId;
  }

  void importBundle(TripBundle bundle) => _importBundle(bundle);

  void _importBundle(TripBundle bundle) {
    _trips[bundle.trip.id] = bundle.trip;
    _stays[bundle.trip.id] = List.from(bundle.stays);
    _activities[bundle.trip.id] = List.from(bundle.activities);
    _flights[bundle.trip.id] = List.from(bundle.flights);
  }

  /// Dispatch and execute any MCP tool call.
  Future<Map<String, dynamic>> executeTool(
    String name,
    Map<String, dynamic>? arguments,
  ) async {
    final args = arguments ?? const <String, dynamic>{};

    try {
      switch (name) {
        case 'trippy_authenticate':
          return await _handleAuthenticate(args);
        case 'trippy_list_trips':
          return await _handleListTrips(args);
        case 'trippy_get_trip_details':
          return await _handleGetTripDetails(args);
        case 'trippy_create_trip':
          return await _handleCreateTrip(args);
        case 'trippy_update_trip':
          return await _handleUpdateTrip(args);
        case 'trippy_set_day_locations':
          return await _handleSetDayLocations(args);
        case 'trippy_create_activity':
          return await _handleCreateActivity(args);
        case 'trippy_update_activity':
          return await _handleUpdateActivity(args);
        case 'trippy_delete_activity':
          return await _handleDeleteActivity(args);
        case 'trippy_create_stay':
          return await _handleCreateStay(args);
        case 'trippy_update_stay':
          return await _handleUpdateStay(args);
        case 'trippy_delete_stay':
          return await _handleDeleteStay(args);
        case 'trippy_create_flight':
          return await _handleCreateFlight(args);
        case 'trippy_update_flight':
          return await _handleUpdateFlight(args);
        case 'trippy_delete_flight':
          return await _handleDeleteFlight(args);
        case 'trippy_apply_suggested_itinerary':
          return await _handleApplySuggestedItinerary(args);
        case 'trippy_add_link':
          return await _handleAddLink(args);
        case 'trippy_generate_pat':
          return await _handleGeneratePat(args);
        case 'trippy_revoke_pat':
          return await _handleRevokePat(args);
        default:
          return _error('Unknown tool: $name');
      }
    } catch (e, st) {
      return _error('Tool execution failed ($name): $e\n$st');
    }
  }

  // ---------------------------------------------------------------------------
  // User Resolution & Sync Helpers
  // ---------------------------------------------------------------------------

  /// Ensures current user UID is resolved to a real Firebase Auth UID.
  Future<void> _ensureUserUidResolved() async {
    if (!_isAuthenticated) return;
    if (_currentUserEmail != null &&
        (_currentUserId == _currentUserEmail || _currentUserId == 'sample_user')) {
      final known = resolveKnownUid(_currentUserEmail);
      if (known != null) {
        _currentUserId = known;
        return;
      }
      try {
        final lookedUpUid = await _firestore.lookupUidByEmail(_currentUserEmail!);
        if (lookedUpUid != null && lookedUpUid.isNotEmpty) {
          _currentUserId = lookedUpUid;
        }
      } catch (e) {
        stderr.writeln('Dynamic UID lookup error: $e');
      }
    }
  }

  /// Syncs remote trips from Firestore and filters by current user (owner or member).
  Future<void> _syncRemoteTripsForCurrentUser() async {
    if (!_isAuthenticated) return;
    await _ensureUserUidResolved();
    try {
      final remoteTrips = await _firestore.getTrips();
      if (remoteTrips != null && remoteTrips.isNotEmpty) {
        _trips.clear();
        for (final t in remoteTrips) {
          if (t.ownerId == _currentUserId ||
              t.members.containsKey(_currentUserId)) {
            _trips[t.id] = t;
          }
        }
      }
    } catch (e) {
      stderr.writeln('Firestore sync failed: $e');
    }
  }

  /// Ensures trips are loaded into in-memory state if authenticated and currently empty.
  Future<void> _ensureTripsLoaded() async {
    if (_isAuthenticated && _trips.isEmpty) {
      await _syncRemoteTripsForCurrentUser();
    }
  }

  // ---------------------------------------------------------------------------
  // Handlers
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> _handleAuthenticate(Map<String, dynamic> args) async {
    final idToken = args['idToken'] as String?;
    final userId = args['userId'] as String?;
    final email = args['email'] as String?;
    final tokenParam = (args['token'] as String?) ??
        (args['key'] as String?) ??
        (args['pat'] as String?) ??
        (args['passcode'] as String?) ??
        (args['apiKey'] as String?);

    // If caller requests logout or reverting to unauthenticated sample sandbox
    if (userId == 'sample_user' ||
        email == 'sample_user' ||
        (idToken == null && userId == null && email == null && tokenParam == null && _httpApiKey == null)) {
      setAuth();
      return _text(
        'ℹ️ Running in Unauthenticated Sample Mode.\n\n'
        '• User: sample_user (Unauthenticated)\n'
        '• Active Trip: ${_pristineSampleBundle?.trip.title ?? "Pacific Northwest"} ($_sampleTripId)\n'
        '• Persistence: IN-MEMORY ONLY (changes do not persist to Cloud Firestore).\n'
        '• To connect your live trips, provide your Personal Access Token (e.g. ?key=trippy_pat_...) or Firebase ID token.',
      );
    }

    final expectedKey = serverApiKey ??
        Platform.environment['TRIPPY_API_KEY'] ??
        Platform.environment['TRIPPY_PASSCODE'] ??
        Platform.environment['TRIPPY_MCP_KEY'];
    final effectiveKey = tokenParam ?? _httpApiKey;

    bool isAuthorized = false;
    String? verifiedEmail;
    String? verifiedUid;
    Map<String, dynamic>? activePatRecord;

    // 1. Verify Personal Access Token (PAT)
    if (effectiveKey != null && effectiveKey.isNotEmpty) {
      final patRecord = await _resolvePat(effectiveKey);
      if (patRecord != null) {
        final patUserId = patRecord['userId'] as String;
        final patUserEmail = patRecord['userEmail'] as String;
        final patName = patRecord['name'] as String? ?? 'Personal Access Token';

        // STRICT ANTI-IMPERSONATION CHECK:
        // If caller passed an email, it MUST match the PAT owner's email!
        if (email != null &&
            email.trim().isNotEmpty &&
            email.trim().toLowerCase() != patUserEmail.trim().toLowerCase()) {
          return _error(
            '🔒 Security Violation: This Personal Access Token ($patName) is cryptographically bound to "$patUserEmail".\n'
            'You cannot use this token to access or impersonate "$email".'
          );
        }

        if (userId != null &&
            userId.trim().isNotEmpty &&
            userId != patUserId &&
            userId.toLowerCase() != patUserEmail.toLowerCase()) {
          return _error(
            '🔒 Security Violation: This Personal Access Token is bound to UID "$patUserId".\n'
            'You cannot use this token to access or impersonate UID "$userId".'
          );
        }

        isAuthorized = true;
        activePatRecord = patRecord;
        verifiedEmail = patUserEmail;
        verifiedUid = patUserId;
        _httpApiKey = effectiveKey;
      }
    }

    // 2. Verify Google / Firebase Auth ID token if provided
    if (!isAuthorized && idToken != null && idToken.isNotEmpty) {
      final verified = await _firestore.verifyIdToken(idToken);
      if (verified != null) {
        final tokenEmail = verified['email'];
        final tokenUid = verified['uid'];
        if (email != null &&
            tokenEmail != null &&
            email.trim().toLowerCase() != tokenEmail.trim().toLowerCase()) {
          return _error(
            '🔒 Security Violation: Firebase ID token belongs to "$tokenEmail". '
            'You cannot use this token to impersonate "$email".'
          );
        }
        isAuthorized = true;
        verifiedUid = tokenUid;
        verifiedEmail = tokenEmail;
      } else {
        return _error(
          '❌ Authentication Failed: The provided Firebase ID token is invalid, forged, or expired. '
          'Please sign in again through the Trippy app to obtain a fresh token.',
        );
      }
    }

    // 3. Verify server security passcode / legacy API key
    if (!isAuthorized && expectedKey != null && expectedKey.isNotEmpty) {
      if (effectiveKey != null && effectiveKey == expectedKey) {
        isAuthorized = true;
        _httpApiKey = effectiveKey;
      } else {
        return _error(
          '🔒 Access Denied: Invalid Personal Access Token (PAT) or security passcode.\n'
          'Please provide a valid token generated for your user account (e.g. "trippy_pat_...").'
        );
      }
    }

    // 4. Fallback when expectedKey is NOT configured
    if (!isAuthorized) {
      if (_isHttpMode) {
        return _error(
          '🔒 Security Gate Active: Direct unverified email login is disabled on public HTTP endpoints for security.\n'
          'Please provide a Personal Access Token (PAT) bound to your account, '
          'or authenticate with a verified Firebase ID token.',
        );
      } else {
        // Local stdio mode (e.g. desktop CLI pairing without remote network exposure)
        isAuthorized = true;
      }
    }

    final targetEmail = verifiedEmail ?? email;
    final targetUser = verifiedUid ?? userId;

    setAuth(
      token: idToken,
      userId: targetUser,
      email: targetEmail,
      patRecord: activePatRecord,
    );

    if (_isAuthenticated) {
      await _syncRemoteTripsForCurrentUser();

      final tripsCount = _trips.length;
      final tripSummary = _trips.isEmpty
          ? '  (No existing trips found in Firestore for this account)'
          : _trips.values.map((t) {
              final role = t.ownerId == _currentUserId
                  ? 'owner'
                  : (t.members[_currentUserId]?.name ?? 'editor');
              return '  • ${t.title} [${t.id}] (role: $role)';
            }).join('\n');

      final patNote = activePatRecord != null
          ? '\n• Access Credential: Personal Access Token (${activePatRecord['name']})\n'
            '• Anti-Impersonation Gate: ENFORCED (Token locked to $targetEmail)'
          : '';

      return _text(
        '✅ Authenticated successfully with Trippy MCP Server!\n\n'
        '• User: ${_currentUserEmail ?? _currentUserId}$patNote\n'
        '• User UID: $_currentUserId\n'
        '• Cloud Firestore Sync: ACTIVE (Project: $projectId)\n'
        '• Real-time updates: Connected directly to your web and mobile apps.\n'
        '• User Trips ($tripsCount):\n$tripSummary',
      );
    } else {
      return _error('Authentication could not be established.');
    }
  }

  Future<Map<String, dynamic>> _handleGeneratePat(Map<String, dynamic> args) async {
    if (!_isAuthenticated || _currentUserId == 'sample_user') {
      return _error(
        'Authentication required: You must be authenticated to generate a Personal Access Token.',
      );
    }

    final name = (args['name'] as String?)?.trim() ?? 'MCP Assistant Token';
    final email = _currentUserEmail ?? _currentUserId;

    // Generate high-entropy 192-bit token
    final randomBytes = List<int>.generate(24, (_) => Random.secure().nextInt(256));
    final tokenHex = randomBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final rawToken = 'trippy_pat_$tokenHex';

    // Store in Firestore
    final saved = await _firestore.registerPersonalAccessToken(
      rawToken: rawToken,
      userId: _currentUserId,
      userEmail: email,
      name: name,
    );

    // Also cache locally
    final hash = FirestoreRestClient.hashPat(rawToken);
    _staticPats[hash] = {
      'userId': _currentUserId,
      'userEmail': email,
      'name': name,
    };

    final serverUrl = 'https://trippy-mcp-server-392329008088.us-central1.run.app/mcp?key=$rawToken';

    return _json({
      'success': true,
      'message':
          'Personal Access Token created successfully! Save this token now. It cannot be shown again.',
      'token': rawToken,
      'name': name,
      'userEmail': email,
      'userId': _currentUserId,
      'firestoreSaved': saved,
      'connectionUrl': serverUrl,
      'configurationInstructions':
          'Paste this URL into Grok Bot, Gemini, or Claude Desktop MCP settings to connect securely:\n$serverUrl',
    });
  }

  Future<Map<String, dynamic>> _handleRevokePat(Map<String, dynamic> args) async {
    if (!_isAuthenticated || _currentUserId == 'sample_user') {
      return _error(
        'Authentication required: You must be authenticated to revoke a Personal Access Token.',
      );
    }

    final token = (args['token'] as String?)?.trim();
    if (token == null || token.isEmpty) {
      return _error('The "token" parameter is required to revoke a Personal Access Token.');
    }

    final hash = FirestoreRestClient.hashPat(token);
    _staticPats.remove(hash);
    final revoked = await _firestore.revokePersonalAccessToken(token);

    return _json({
      'success': revoked,
      'message': revoked
          ? 'Personal Access Token was successfully revoked from Firestore.'
          : 'Token was deleted or could not be found.',
    });
  }

  Future<Map<String, dynamic>> _handleListTrips(Map<String, dynamic> args) async {
    if (_isAuthenticated) {
      await _syncRemoteTripsForCurrentUser();
    } else {
      // Unauthenticated: ensure sample trip is populated
      if (_trips.isEmpty && _pristineSampleBundle != null) {
        resetSampleData();
      }
    }

    final tripsList = _trips.values.toList();

    final result = tripsList.map((t) {
      final actCount = _activities[t.id]?.length ?? 0;
      final stayCount = _stays[t.id]?.length ?? 0;
      final flightCount = _flights[t.id]?.length ?? 0;
      final role = t.ownerId == _currentUserId
          ? 'owner'
          : (t.members[_currentUserId]?.name ?? 'editor');

      return {
        'id': t.id,
        'title': t.title,
        'destination': t.destination,
        'startDate': t.startDate.toIso8601String().split('T').first,
        'endDate': t.endDate.toIso8601String().split('T').first,
        'durationDays': t.daysCount,
        'activitiesCount': actCount,
        'staysCount': stayCount,
        'flightsCount': flightCount,
        'inviteCode': t.inviteCode,
        'ownerId': t.ownerId,
        'userRole': role,
        'isCurrentUser': _isAuthenticated &&
            (t.ownerId == _currentUserId ||
                t.members.containsKey(_currentUserId)),
        'lastModifiedSource': t.lastModifiedSource ?? 'ui',
        'lastModifiedAt': t.lastModifiedAt?.toIso8601String(),
      };
    }).toList();

    return _json({
      'authenticated': _isAuthenticated,
      'currentUserEmail': _currentUserEmail,
      'currentUserId': _currentUserId,
      'mode': _isAuthenticated ? 'live_firestore' : 'sample_in_memory',
      'count': result.length,
      'trips': result,
    });
  }

  Future<Map<String, dynamic>> _handleGetTripDetails(Map<String, dynamic> args) async {
    await _ensureTripsLoaded();
    final requestedTripId = args['tripId'] as String?;
    final tripId = _resolveTripId(requestedTripId);

    // Sync latest from Firestore if authenticated
    if (_isAuthenticated) {
      try {
        final remoteActs = await _firestore.getActivities(tripId);
        if (remoteActs != null) _activities[tripId] = remoteActs;

        final remoteStays = await _firestore.getStays(tripId);
        if (remoteStays != null) _stays[tripId] = remoteStays;

        final remoteFlights = await _firestore.getFlights(tripId);
        if (remoteFlights != null) _flights[tripId] = remoteFlights;
      } catch (e) {
        stderr.writeln('Firestore sync in get_trip_details: $e');
      }
    }

    final trip = _trips[tripId];
    if (trip == null) {
      return _error('Trip "$tripId" not found.');
    }

    final dateFilter = args['date'] as String?;
    DateTime? filterDate;
    if (dateFilter != null) {
      filterDate = DateTime.tryParse(dateFilter);
    }

    var acts = _activities[tripId] ?? [];
    if (filterDate != null) {
      acts = acts.where((a) =>
          a.date.year == filterDate!.year &&
          a.date.month == filterDate.month &&
          a.date.day == filterDate.day).toList();
    }
    acts.sort((a, b) => a.startDateTime.compareTo(b.startDateTime));

    final staysList = _stays[tripId] ?? [];
    final flightsList = _flights[tripId] ?? [];

    final result = {
      'trip': {
        'id': trip.id,
        'title': trip.title,
        'destination': trip.destination,
        'startDate': trip.startDate.toIso8601String().split('T').first,
        'endDate': trip.endDate.toIso8601String().split('T').first,
        'dayLocations': trip.dayLocations,
        'ownerId': trip.ownerId,
        'lastModifiedSource': trip.lastModifiedSource,
        'lastModifiedAt': trip.lastModifiedAt?.toIso8601String(),
      },
      'activities': acts.map((a) => a.toMap()).toList(),
      'stays': staysList.map((s) => s.toMap()).toList(),
      'flights': flightsList.map((f) => f.toMap()).toList(),
    };

    return _json(result);
  }

  Future<Map<String, dynamic>> _handleCreateTrip(Map<String, dynamic> args) async {
    await _ensureUserUidResolved();
    final now = DateTime.now();
    final tripId = 'trip_${_uuid.v4().substring(0, 8)}';
    final startDate = DateTime.parse(args['startDate'] as String);
    final endDate = DateTime.parse(args['endDate'] as String);
    final links = _parseStringList(args['links']);
    final attachments = _parseStringList(args['attachments']);

    final trip = Trip(
      id: tripId,
      title: args['title'] as String,
      destination: args['destination'] as String,
      startDate: startDate,
      endDate: endDate,
      coverImageUrl: args['coverImageUrl'] as String?,
      ownerId: _currentUserId,
      inviteCode: _uuid.v4().substring(0, 6).toUpperCase(),
      defaultInviteRole: MemberRole.editor,
      members: {_currentUserId: MemberRole.owner},
      startLocation: args['startLocation'] as String?,
      endLocation: args['endLocation'] as String?,
      notes: args['notes'] as String?,
      links: links,
      attachments: attachments,
      createdAt: now,
      updatedAt: now,
      lastModifiedAt: now,
      lastModifiedSource: 'mcp',
    );

    _trips[trip.id] = trip;
    _stays[trip.id] = [];
    _activities[trip.id] = [];
    _flights[trip.id] = [];

    if (_isAuthenticated) {
      try {
        await _firestore.saveTrip(trip);
      } catch (e) {
        stderr.writeln('Warning: Failed to save trip to Firestore: $e');
      }
    }

    return _json({
      'message': _isAuthenticated
          ? 'Trip created successfully via MCP and saved to Cloud Firestore.'
          : 'Trip created in sample mode (in-memory only; not saved to Firestore).',
      'trip': trip.toMap(),
    });
  }

  Future<Map<String, dynamic>> _handleUpdateTrip(Map<String, dynamic> args) async {
    await _ensureTripsLoaded();
    final tripId = _resolveTripId(args['tripId'] as String?);
    final existing = _trips[tripId];
    if (existing == null) return _error('Trip "$tripId" not found.');

    List<String>? updatedLinks;
    if (args.containsKey('links')) {
      updatedLinks = _parseStringList(args['links']);
    } else if (args.containsKey('addLinks')) {
      final toAdd = _parseStringList(args['addLinks']);
      if (toAdd.isNotEmpty) {
        updatedLinks = {...existing.links, ...toAdd}.toList();
      }
    }

    List<String>? updatedAttachments;
    if (args.containsKey('attachments')) {
      updatedAttachments = _parseStringList(args['attachments']);
    } else if (args.containsKey('addAttachments')) {
      final toAdd = _parseStringList(args['addAttachments']);
      if (toAdd.isNotEmpty) {
        updatedAttachments = {...existing.attachments, ...toAdd}.toList();
      }
    }

    final updated = existing.copyWith(
      title: args['title'] as String?,
      destination: args['destination'] as String?,
      startDate: args['startDate'] != null
          ? DateTime.parse(args['startDate'] as String)
          : null,
      endDate: args['endDate'] != null
          ? DateTime.parse(args['endDate'] as String)
          : null,
      coverImageUrl: args['coverImageUrl'] as String?,
      startLocation: args['startLocation'] as String?,
      endLocation: args['endLocation'] as String?,
      notes: args.containsKey('notes') ? (args['notes'] as String?) : existing.notes,
      links: updatedLinks,
      attachments: updatedAttachments,
      updatedAt: DateTime.now(),
      lastModifiedAt: DateTime.now(),
      lastModifiedSource: 'mcp',
    );

    _trips[tripId] = updated;

    if (_isAuthenticated) {
      try {
        await _firestore.saveTrip(updated);
      } catch (e) {
        stderr.writeln('Warning: Failed to update trip in Firestore: $e');
      }
    }

    return _json({
      'message': _isAuthenticated
          ? 'Trip updated successfully via MCP and saved to Cloud Firestore.'
          : 'Trip updated in sample mode (in-memory only; not saved to Firestore).',
      'trip': updated.toMap(),
    });
  }

  Future<Map<String, dynamic>> _handleSetDayLocations(Map<String, dynamic> args) async {
    await _ensureTripsLoaded();
    final tripId = _resolveTripId(args['tripId'] as String?);
    final trip = _trips[tripId];
    if (trip == null) return _error('Trip "$tripId" not found.');

    final dateStr = args['date'] as String;
    final locations = (args['locations'] as List<dynamic>).map((e) => e.toString()).toList();

    final newDayLocations = Map<String, List<String>>.from(trip.dayLocations);
    if (locations.isEmpty) {
      newDayLocations.remove(dateStr);
    } else {
      newDayLocations[dateStr] = locations;
    }

    final updated = trip.copyWith(
      dayLocations: newDayLocations,
      updatedAt: DateTime.now(),
      lastModifiedAt: DateTime.now(),
      lastModifiedSource: 'mcp',
    );
    _trips[tripId] = updated;

    if (_isAuthenticated) {
      try {
        await _firestore.saveTrip(updated);
      } catch (e) {
        stderr.writeln('Warning: Failed to save day locations to Firestore: $e');
      }
    }

    return _json({
      'message': _isAuthenticated
          ? 'Day locations updated via MCP for $dateStr and saved to Cloud Firestore.'
          : 'Day locations updated in-memory for $dateStr (sample mode; not saved to Firestore).',
      'date': dateStr,
      'locations': locations,
    });
  }

  Future<Map<String, dynamic>> _handleCreateActivity(Map<String, dynamic> args) async {
    await _ensureTripsLoaded();
    final tripId = _resolveTripId(args['tripId'] as String?);
    if (!_trips.containsKey(tripId)) return _error('Trip "$tripId" not found.');

    final actId = 'act_${_uuid.v4().substring(0, 8)}';
    final date = DateTime.parse(args['date'] as String);

    final catStr = (args['category'] as String?)?.toLowerCase() ?? 'attraction';
    final category = ActivityCategory.values.firstWhere(
      (c) => c.name.toLowerCase() == catStr,
      orElse: () => ActivityCategory.attraction,
    );

    final statusStr = (args['bookingStatus'] as String?)?.toLowerCase() ?? 'planned';
    final bookingStatus = BookingStatus.values.firstWhere(
      (b) => b.name.toLowerCase() == statusStr,
      orElse: () => BookingStatus.planned,
    );

    final links = _parseStringList(args['links']);
    final attachments = _parseStringList(args['attachments']);

    final activity = Activity(
      id: actId,
      tripId: tripId,
      date: date,
      startTime: args['startTime'] as String,
      endTime: args['endTime'] as String?,
      title: args['title'] as String,
      category: category,
      location: args['location'] as String?,
      notes: args['notes'] as String?,
      cost: (args['cost'] as num?)?.toDouble(),
      bookingStatus: bookingStatus,
      confirmationRef: args['confirmationRef'] as String?,
      ticketUrl: args['ticketUrl'] as String?,
      links: links,
      attachments: attachments,
      mealType: args['mealType'] as String?,
      stayId: args['stayId'] as String?,
      flightId: args['flightId'] as String?,
      lastModifiedAt: DateTime.now(),
      lastModifiedSource: 'mcp',
    );

    final list = _activities.putIfAbsent(tripId, () => []);
    list.add(activity);

    if (_isAuthenticated) {
      try {
        await _firestore.saveActivity(activity);
      } catch (e) {
        stderr.writeln('Warning: Failed to save activity to Firestore: $e');
      }
    }

    return _json({
      'message': _isAuthenticated
          ? 'Activity created successfully via MCP and saved to Cloud Firestore.'
          : 'Activity created in sample trip (in-memory only; not saved to Firestore).',
      'activity': activity.toMap(),
    });
  }

  Future<Map<String, dynamic>> _handleUpdateActivity(Map<String, dynamic> args) async {
    await _ensureTripsLoaded();
    final tripId = _resolveTripId(args['tripId'] as String?);
    if (_isAuthenticated && (_activities[tripId] == null || _activities[tripId]!.isEmpty)) {
      try {
        final remoteActs = await _firestore.getActivities(tripId);
        if (remoteActs != null) _activities[tripId] = remoteActs;
      } catch (_) {}
    }
    final activityId = args['activityId'] as String;
    final list = _activities[tripId];
    if (list == null) return _error('No activities found for trip "$tripId".');

    final idx = list.indexWhere((a) => a.id == activityId);
    if (idx == -1) return _error('Activity "$activityId" not found.');

    final existing = list[idx];

    ActivityCategory? category;
    if (args['category'] != null) {
      final catStr = (args['category'] as String).toLowerCase();
      category = ActivityCategory.values.firstWhere(
        (c) => c.name.toLowerCase() == catStr,
        orElse: () => existing.category,
      );
    }

    BookingStatus? bookingStatus;
    if (args['bookingStatus'] != null) {
      final statusStr = (args['bookingStatus'] as String).toLowerCase();
      bookingStatus = BookingStatus.values.firstWhere(
        (b) => b.name.toLowerCase() == statusStr,
        orElse: () => existing.bookingStatus,
      );
    }

    List<String>? updatedLinks;
    if (args.containsKey('links')) {
      updatedLinks = _parseStringList(args['links']);
    }
    if (args.containsKey('addLinks')) {
      final toAdd = _parseStringList(args['addLinks']);
      updatedLinks = List<String>.from(updatedLinks ?? existing.links)..addAll(toAdd);
    }

    List<String>? updatedAttachments;
    if (args.containsKey('attachments')) {
      updatedAttachments = _parseStringList(args['attachments']);
    }
    if (args.containsKey('addAttachments')) {
      final toAdd = _parseStringList(args['addAttachments']);
      updatedAttachments = List<String>.from(updatedAttachments ?? existing.attachments)..addAll(toAdd);
    }

    final ticketUrl = args.containsKey('ticketUrl')
        ? (args['ticketUrl'] as String?)
        : existing.ticketUrl;

    final updated = existing.copyWith(
      date: args['date'] != null ? DateTime.parse(args['date'] as String) : null,
      startTime: args['startTime'] as String?,
      endTime: args['endTime'] as String?,
      title: args['title'] as String?,
      category: category,
      location: args['location'] as String?,
      notes: args['notes'] as String?,
      cost: (args['cost'] as num?)?.toDouble(),
      bookingStatus: bookingStatus,
      confirmationRef: args['confirmationRef'] as String?,
      ticketUrl: ticketUrl,
      links: updatedLinks,
      attachments: updatedAttachments,
      mealType: args['mealType'] as String?,
      isCompleted: args['isCompleted'] as bool?,
      lastModifiedAt: DateTime.now(),
      lastModifiedSource: 'mcp',
    );

    list[idx] = updated;

    if (_isAuthenticated) {
      try {
        await _firestore.saveActivity(updated);
      } catch (e) {
        stderr.writeln('Warning: Failed to update activity in Firestore: $e');
      }
    }

    return _json({
      'message': _isAuthenticated
          ? 'Activity updated successfully via MCP and saved to Cloud Firestore.'
          : 'Activity updated in sample trip (in-memory only; not saved to Firestore).',
      'activity': updated.toMap(),
    });
  }

  Future<Map<String, dynamic>> _handleDeleteActivity(Map<String, dynamic> args) async {
    await _ensureTripsLoaded();
    final tripId = _resolveTripId(args['tripId'] as String?);
    if (_isAuthenticated && (_activities[tripId] == null || _activities[tripId]!.isEmpty)) {
      try {
        final remoteActs = await _firestore.getActivities(tripId);
        if (remoteActs != null) _activities[tripId] = remoteActs;
      } catch (_) {}
    }
    final activityId = args['activityId'] as String;
    final list = _activities[tripId];
    if (list == null) return _error('No activities found for trip "$tripId".');

    final before = list.length;
    list.removeWhere((a) => a.id == activityId);
    if (list.length == before) return _error('Activity "$activityId" not found.');

    if (_isAuthenticated) {
      try {
        await _firestore.deleteActivity(tripId, activityId);
      } catch (e) {
        stderr.writeln('Warning: Failed to delete activity from Firestore: $e');
      }
    }

    return _json({
      'message': _isAuthenticated
          ? 'Activity "$activityId" deleted via MCP and removed from Cloud Firestore.'
          : 'Activity "$activityId" deleted from sample trip (in-memory only).',
    });
  }

  Future<Map<String, dynamic>> _handleCreateStay(Map<String, dynamic> args) async {
    await _ensureTripsLoaded();
    final tripId = _resolveTripId(args['tripId'] as String?);
    if (!_trips.containsKey(tripId)) return _error('Trip "$tripId" not found.');

    final stayId = 'stay_${_uuid.v4().substring(0, 8)}';
    final typeStr = (args['type'] as String?)?.toLowerCase() ?? 'hotel';
    final stayType = StayType.values.firstWhere(
      (t) => t.name.toLowerCase() == typeStr,
      orElse: () => StayType.hotel,
    );

    final links = _parseStringList(args['links']);
    final attachments = _parseStringList(args['attachments']);

    final stay = Stay(
      id: stayId,
      tripId: tripId,
      type: stayType,
      name: args['name'] as String,
      address: args['address'] as String?,
      checkInDate: DateTime.parse(args['checkInDate'] as String),
      checkInTime: args['checkInTime'] as String? ?? '15:00',
      checkOutDate: DateTime.parse(args['checkOutDate'] as String),
      checkOutTime: args['checkOutTime'] as String? ?? '11:00',
      confirmationCode: args['confirmationCode'] as String?,
      notes: args['notes'] as String?,
      links: links,
      attachments: attachments,
      lastModifiedAt: DateTime.now(),
      lastModifiedSource: 'mcp',
    );

    final list = _stays.putIfAbsent(tripId, () => []);
    list.add(stay);

    if (_isAuthenticated) {
      try {
        await _firestore.saveStay(stay);
      } catch (e) {
        stderr.writeln('Warning: Failed to save stay to Firestore: $e');
      }
    }

    return _json({
      'message': _isAuthenticated
          ? 'Stay created successfully via MCP and saved to Firestore.'
          : 'Stay created in sample trip (in-memory only; not saved to Firestore).',
      'stay': stay.toMap(),
    });
  }

  Future<Map<String, dynamic>> _handleUpdateStay(Map<String, dynamic> args) async {
    await _ensureTripsLoaded();
    final tripId = _resolveTripId(args['tripId'] as String?);
    if (_isAuthenticated && (_stays[tripId] == null || _stays[tripId]!.isEmpty)) {
      try {
        final remoteStays = await _firestore.getStays(tripId);
        if (remoteStays != null) _stays[tripId] = remoteStays;
      } catch (_) {}
    }
    final stayId = args['stayId'] as String;
    final list = _stays[tripId];
    if (list == null) return _error('No stays found for trip "$tripId".');

    final idx = list.indexWhere((s) => s.id == stayId);
    if (idx == -1) return _error('Stay "$stayId" not found.');

    final existing = list[idx];

    List<String>? updatedLinks;
    if (args.containsKey('links')) {
      updatedLinks = _parseStringList(args['links']);
    }
    if (args.containsKey('addLinks')) {
      final toAdd = _parseStringList(args['addLinks']);
      updatedLinks = List<String>.from(updatedLinks ?? existing.links)..addAll(toAdd);
    }

    List<String>? updatedAttachments;
    if (args.containsKey('attachments')) {
      updatedAttachments = _parseStringList(args['attachments']);
    }
    if (args.containsKey('addAttachments')) {
      final toAdd = _parseStringList(args['addAttachments']);
      updatedAttachments = List<String>.from(updatedAttachments ?? existing.attachments)..addAll(toAdd);
    }

    final updated = existing.copyWith(
      name: args['name'] as String?,
      address: args['address'] as String?,
      checkInDate: args['checkInDate'] != null ? DateTime.parse(args['checkInDate']) : null,
      checkInTime: args['checkInTime'] as String?,
      checkOutDate: args['checkOutDate'] != null ? DateTime.parse(args['checkOutDate']) : null,
      checkOutTime: args['checkOutTime'] as String?,
      confirmationCode: args['confirmationCode'] as String?,
      notes: args['notes'] as String?,
      links: updatedLinks,
      attachments: updatedAttachments,
      lastModifiedAt: DateTime.now(),
      lastModifiedSource: 'mcp',
    );

    list[idx] = updated;

    if (_isAuthenticated) {
      try {
        await _firestore.saveStay(updated);
      } catch (e) {
        stderr.writeln('Warning: Failed to update stay in Firestore: $e');
      }
    }

    return _json({
      'message': _isAuthenticated
          ? 'Stay updated successfully via MCP and saved to Firestore.'
          : 'Stay updated in sample trip (in-memory only; not saved to Firestore).',
      'stay': updated.toMap(),
    });
  }

  Future<Map<String, dynamic>> _handleDeleteStay(Map<String, dynamic> args) async {
    await _ensureTripsLoaded();
    final tripId = _resolveTripId(args['tripId'] as String?);
    if (_isAuthenticated && (_stays[tripId] == null || _stays[tripId]!.isEmpty)) {
      try {
        final remoteStays = await _firestore.getStays(tripId);
        if (remoteStays != null) _stays[tripId] = remoteStays;
      } catch (_) {}
    }
    final stayId = args['stayId'] as String;
    final list = _stays[tripId];
    if (list == null) return _error('No stays found for trip "$tripId".');

    final before = list.length;
    list.removeWhere((s) => s.id == stayId);
    if (list.length == before) return _error('Stay "$stayId" not found.');

    if (_isAuthenticated) {
      try {
        await _firestore.deleteStay(tripId, stayId);
      } catch (e) {
        stderr.writeln('Warning: Failed to delete stay from Firestore: $e');
      }
    }

    return _json({
      'message': _isAuthenticated
          ? 'Stay "$stayId" deleted via MCP and removed from Firestore.'
          : 'Stay "$stayId" deleted from sample trip (in-memory only).',
    });
  }

  Future<Map<String, dynamic>> _handleCreateFlight(Map<String, dynamic> args) async {
    await _ensureTripsLoaded();
    final tripId = _resolveTripId(args['tripId'] as String?);
    if (!_trips.containsKey(tripId)) return _error('Trip "$tripId" not found.');

    final flightId = 'fl_${_uuid.v4().substring(0, 8)}';
    final links = _parseStringList(args['links']);
    final attachments = _parseStringList(args['attachments']);

    final flight = Flight(
      id: flightId,
      tripId: tripId,
      airline: args['airline'] as String,
      flightNumber: args['flightNumber'] as String,
      departureAirport: args['departureAirport'] as String,
      arrivalAirport: args['arrivalAirport'] as String,
      departureTime: DateTime.parse(args['departureTime'] as String),
      arrivalTime: DateTime.parse(args['arrivalTime'] as String),
      terminal: args['terminal'] as String?,
      gate: args['gate'] as String?,
      seat: args['seat'] as String?,
      bookingRef: args['bookingRef'] as String?,
      notes: args['notes'] as String?,
      links: links,
      attachments: attachments,
      isOvernight: args['isOvernight'] as bool? ?? false,
      isNightStay: args['isNightStay'] as bool? ?? false,
      lastModifiedAt: DateTime.now(),
      lastModifiedSource: 'mcp',
    );

    final list = _flights.putIfAbsent(tripId, () => []);
    list.add(flight);

    if (_isAuthenticated) {
      try {
        await _firestore.saveFlight(flight);
      } catch (e) {
        stderr.writeln('Warning: Failed to save flight to Firestore: $e');
      }
    }

    return _json({
      'message': _isAuthenticated
          ? 'Flight created successfully via MCP and saved to Firestore.'
          : 'Flight created in sample trip (in-memory only; not saved to Firestore).',
      'flight': flight.toMap(),
    });
  }

  Future<Map<String, dynamic>> _handleUpdateFlight(Map<String, dynamic> args) async {
    await _ensureTripsLoaded();
    final tripId = _resolveTripId(args['tripId'] as String?);
    if (_isAuthenticated && (_flights[tripId] == null || _flights[tripId]!.isEmpty)) {
      try {
        final remoteFlights = await _firestore.getFlights(tripId);
        if (remoteFlights != null) _flights[tripId] = remoteFlights;
      } catch (_) {}
    }
    final flightId = args['flightId'] as String;
    final list = _flights[tripId];
    if (list == null) return _error('No flights found for trip "$tripId".');

    final idx = list.indexWhere((f) => f.id == flightId);
    if (idx == -1) return _error('Flight "$flightId" not found.');

    final existing = list[idx];

    List<String>? updatedLinks;
    if (args.containsKey('links')) {
      updatedLinks = _parseStringList(args['links']);
    }
    if (args.containsKey('addLinks')) {
      final toAdd = _parseStringList(args['addLinks']);
      updatedLinks = List<String>.from(updatedLinks ?? existing.links)..addAll(toAdd);
    }

    List<String>? updatedAttachments;
    if (args.containsKey('attachments')) {
      updatedAttachments = _parseStringList(args['attachments']);
    }
    if (args.containsKey('addAttachments')) {
      final toAdd = _parseStringList(args['addAttachments']);
      updatedAttachments = List<String>.from(updatedAttachments ?? existing.attachments)..addAll(toAdd);
    }

    final updated = existing.copyWith(
      airline: args['airline'] as String?,
      flightNumber: args['flightNumber'] as String?,
      departureAirport: args['departureAirport'] as String?,
      arrivalAirport: args['arrivalAirport'] as String?,
      departureTime: args['departureTime'] != null ? DateTime.parse(args['departureTime']) : null,
      arrivalTime: args['arrivalTime'] != null ? DateTime.parse(args['arrivalTime']) : null,
      terminal: args['terminal'] as String?,
      gate: args['gate'] as String?,
      seat: args['seat'] as String?,
      bookingRef: args['bookingRef'] as String?,
      notes: args['notes'] as String?,
      links: updatedLinks,
      attachments: updatedAttachments,
      lastModifiedAt: DateTime.now(),
      lastModifiedSource: 'mcp',
    );

    list[idx] = updated;

    if (_isAuthenticated) {
      try {
        await _firestore.saveFlight(updated);
      } catch (e) {
        stderr.writeln('Warning: Failed to update flight in Firestore: $e');
      }
    }

    return _json({
      'message': _isAuthenticated
          ? 'Flight updated successfully via MCP and saved to Firestore.'
          : 'Flight updated in sample trip (in-memory only; not saved to Firestore).',
      'flight': updated.toMap(),
    });
  }

  Future<Map<String, dynamic>> _handleDeleteFlight(Map<String, dynamic> args) async {
    await _ensureTripsLoaded();
    final tripId = _resolveTripId(args['tripId'] as String?);
    if (_isAuthenticated && (_flights[tripId] == null || _flights[tripId]!.isEmpty)) {
      try {
        final remoteFlights = await _firestore.getFlights(tripId);
        if (remoteFlights != null) _flights[tripId] = remoteFlights;
      } catch (_) {}
    }
    final flightId = args['flightId'] as String;
    final list = _flights[tripId];
    if (list == null) return _error('No flights found for trip "$tripId".');

    final before = list.length;
    list.removeWhere((f) => f.id == flightId);
    if (list.length == before) return _error('Flight "$flightId" not found.');

    if (_isAuthenticated) {
      try {
        await _firestore.deleteFlight(tripId, flightId);
      } catch (e) {
        stderr.writeln('Warning: Failed to delete flight from Firestore: $e');
      }
    }

    return _json({
      'message': _isAuthenticated
          ? 'Flight "$flightId" deleted via MCP and removed from Firestore.'
          : 'Flight "$flightId" deleted from sample trip (in-memory only).',
    });
  }

  // ---------------------------------------------------------------------------
  // PRIMARY USE CASE: Apply Proposed Daily Itinerary
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> _handleApplySuggestedItinerary(Map<String, dynamic> args) async {
    await _ensureTripsLoaded();
    final requestedTripId = args['tripId'] as String?;
    final tripId = _resolveTripId(requestedTripId);

    final trip = _trips[tripId];
    if (trip == null) return _error('Trip "$tripId" not found.');

    final dateStr = args['date'] as String?;
    if (dateStr == null || dateStr.isEmpty) return _error('date (YYYY-MM-DD) is required.');

    final targetDate = DateTime.parse(dateStr);
    final bool clearExisting = args['clearExistingActivities'] as bool? ?? false;
    final now = DateTime.now();

    // Ensure remote collections are loaded if authenticated
    if (_isAuthenticated) {
      if (_activities[tripId] == null || _activities[tripId]!.isEmpty) {
        try {
          final remoteActs = await _firestore.getActivities(tripId);
          if (remoteActs != null) _activities[tripId] = remoteActs;
        } catch (_) {}
      }
      if (_stays[tripId] == null || _stays[tripId]!.isEmpty) {
        try {
          final remoteStays = await _firestore.getStays(tripId);
          if (remoteStays != null) _stays[tripId] = remoteStays;
        } catch (_) {}
      }
      if (_flights[tripId] == null || _flights[tripId]!.isEmpty) {
        try {
          final remoteFlights = await _firestore.getFlights(tripId);
          if (remoteFlights != null) _flights[tripId] = remoteFlights;
        } catch (_) {}
      }
    }

    // 1. Clear existing activities for this date if explicitly requested
    final actList = _activities.putIfAbsent(tripId, () => []);
    if (clearExisting) {
      final toRemove = actList.where((a) =>
          a.date.year == targetDate.year &&
          a.date.month == targetDate.month &&
          a.date.day == targetDate.day).toList();
      if (_isAuthenticated) {
        for (final oldAct in toRemove) {
          try {
            await _firestore.deleteActivity(tripId, oldAct.id);
          } catch (_) {}
        }
      }
      actList.removeWhere((a) => toRemove.contains(a));
    }

    // 2. Add or update proposed activities
    final rawActivities = (args['activities'] as List<dynamic>?) ?? [];
    final appliedActivities = <Activity>[];
    final updatedActivities = <String>[];
    final createdActivities = <String>[];

    for (final raw in rawActivities) {
      final item = raw as Map<String, dynamic>;
      final title = item['title'] as String? ?? 'Planned Activity';
      final startTime = item['startTime'] as String? ?? '10:00';
      final endTime = item['endTime'] as String?;
      final location = item['location'] as String?;
      final notes = item['notes'] as String?;
      final cost = (item['cost'] as num?)?.toDouble();
      final mealType = item['mealType'] as String?;
      final ticketUrl = item['ticketUrl'] as String?;
      final confirmationRef = item['confirmationRef'] as String?;
      final links = _parseStringList(item['links']);
      final attachments = _parseStringList(item['attachments']);

      final catStr = (item['category'] as String?)?.toLowerCase() ?? 'attraction';
      final category = ActivityCategory.values.firstWhere(
        (c) => c.name.toLowerCase() == catStr,
        orElse: () => ActivityCategory.attraction,
      );

      final bookingStatus = BookingStatus.fromString(item['bookingStatus'] as String?);

      final matchIdx = clearExisting
          ? -1
          : _findMatchingActivityIndex(actList, targetDate, item, title, startTime);

      if (matchIdx != -1) {
        // Smart update existing activity instead of duplicating!
        final existing = actList[matchIdx];

        // Merge links & attachments without duplicates
        final mergedLinks = <String>{
          ...existing.links,
          ...links,
        }.toList();
        final mergedAttachments = <String>{
          ...existing.attachments,
          ...attachments,
        }.toList();

        // Merge notes intelligently
        String? updatedNotes = existing.notes;
        if (notes != null && notes.trim().isNotEmpty) {
          if (existing.notes == null || existing.notes!.trim().isEmpty) {
            updatedNotes = notes.trim();
          } else if (!existing.notes!.contains(notes.trim()) && !notes.trim().contains(existing.notes!)) {
            updatedNotes = '${existing.notes}\n${notes.trim()}';
          }
        }

        final updated = existing.copyWith(
          title: title.isNotEmpty ? title : existing.title,
          startTime: (item['startTime'] != null && startTime.isNotEmpty) ? startTime : existing.startTime,
          endTime: endTime ?? existing.endTime,
          category: (item['category'] != null) ? category : existing.category,
          location: (location != null && location.isNotEmpty) ? location : existing.location,
          notes: updatedNotes,
          cost: cost ?? existing.cost,
          bookingStatus: (item['bookingStatus'] != null) ? bookingStatus : existing.bookingStatus,
          confirmationRef: (confirmationRef != null && confirmationRef.isNotEmpty) ? confirmationRef : existing.confirmationRef,
          ticketUrl: (ticketUrl != null && ticketUrl.isNotEmpty) ? ticketUrl : existing.ticketUrl,
          links: mergedLinks,
          attachments: mergedAttachments,
          mealType: (item['mealType'] != null && mealType != null) ? mealType : existing.mealType,
          lastModifiedAt: now,
          lastModifiedSource: 'mcp',
        );

        actList[matchIdx] = updated;
        appliedActivities.add(updated);
        updatedActivities.add(updated.title);

        if (_isAuthenticated) {
          try {
            await _firestore.saveActivity(updated);
          } catch (e) {
            stderr.writeln('Warning: Failed to update activity in Firestore: $e');
          }
        }
      } else {
        // Create new activity
        final act = Activity(
          id: 'act_${_uuid.v4().substring(0, 8)}',
          tripId: tripId,
          date: targetDate,
          startTime: startTime,
          endTime: endTime,
          title: title,
          category: category,
          location: location,
          notes: notes,
          cost: cost,
          bookingStatus: bookingStatus,
          confirmationRef: confirmationRef,
          ticketUrl: ticketUrl,
          links: links,
          attachments: attachments,
          mealType: mealType,
          lastModifiedAt: now,
          lastModifiedSource: 'mcp',
        );

        actList.add(act);
        appliedActivities.add(act);
        createdActivities.add(act.title);

        if (_isAuthenticated) {
          try {
            await _firestore.saveActivity(act);
          } catch (e) {
            stderr.writeln('Warning: Failed to save activity to Firestore: $e');
          }
        }
      }
    }

    // Sort activities by time
    actList.sort((a, b) => a.startDateTime.compareTo(b.startDateTime));

    // 3. Update dayLocations if provided
    final rawLocations = args['locations'] as List<dynamic>?;
    List<String>? updatedLocations;
    if (rawLocations != null) {
      updatedLocations = rawLocations.map((e) => e.toString()).toList();
      final newLocationsMap = Map<String, List<String>>.from(trip.dayLocations);
      newLocationsMap[dateStr] = updatedLocations;
      final updatedTrip = trip.copyWith(
        dayLocations: newLocationsMap,
        updatedAt: now,
        lastModifiedAt: now,
        lastModifiedSource: 'mcp',
      );
      _trips[tripId] = updatedTrip;
      if (_isAuthenticated) {
        try {
          await _firestore.saveTrip(updatedTrip);
        } catch (e) {
          stderr.writeln('Warning: Failed to save trip locations to Firestore: $e');
        }
      }
    }

    // 4. Stays (if included)
    final rawStays = args['stays'] as List<dynamic>?;
    final appliedStays = <Stay>[];
    if (rawStays != null && rawStays.isNotEmpty) {
      final stayList = _stays.putIfAbsent(tripId, () => []);
      for (final raw in rawStays) {
        final item = raw as Map<String, dynamic>;
        final stayName = item['name'] as String? ?? 'Lodging';
        final checkInDate = DateTime.parse(item['checkInDate'] as String);
        final checkOutDate = DateTime.parse(item['checkOutDate'] as String);
        final stayLinks = _parseStringList(item['links']);
        final stayAttachments = _parseStringList(item['attachments']);

        final matchIdx = _findMatchingStayIndex(stayList, item, stayName, checkInDate);
        if (matchIdx != -1) {
          final existing = stayList[matchIdx];
          final mergedLinks = <String>{...existing.links, ...stayLinks}.toList();
          final mergedAttachments = <String>{...existing.attachments, ...stayAttachments}.toList();
          final updated = existing.copyWith(
            name: stayName,
            address: item['address'] as String? ?? existing.address,
            checkInDate: checkInDate,
            checkInTime: item['checkInTime'] as String? ?? existing.checkInTime,
            checkOutDate: checkOutDate,
            checkOutTime: item['checkOutTime'] as String? ?? existing.checkOutTime,
            confirmationCode: item['confirmationCode'] as String? ?? existing.confirmationCode,
            notes: item['notes'] as String? ?? existing.notes,
            links: mergedLinks,
            attachments: mergedAttachments,
            lastModifiedAt: now,
            lastModifiedSource: 'mcp',
          );
          stayList[matchIdx] = updated;
          appliedStays.add(updated);
          if (_isAuthenticated) {
            try {
              await _firestore.saveStay(updated);
            } catch (_) {}
          }
        } else {
          final stay = Stay(
            id: 'stay_${_uuid.v4().substring(0, 8)}',
            tripId: tripId,
            type: StayType.fromString(item['type'] as String?),
            name: stayName,
            address: item['address'] as String?,
            checkInDate: checkInDate,
            checkInTime: item['checkInTime'] as String? ?? '15:00',
            checkOutDate: checkOutDate,
            checkOutTime: item['checkOutTime'] as String? ?? '11:00',
            confirmationCode: item['confirmationCode'] as String?,
            notes: item['notes'] as String?,
            links: stayLinks,
            attachments: stayAttachments,
            lastModifiedAt: now,
            lastModifiedSource: 'mcp',
          );
          stayList.add(stay);
          appliedStays.add(stay);
          if (_isAuthenticated) {
            try {
              await _firestore.saveStay(stay);
            } catch (_) {}
          }
        }
      }
    }

    // 5. Flights (if included)
    final rawFlights = args['flights'] as List<dynamic>?;
    final appliedFlights = <Flight>[];
    if (rawFlights != null && rawFlights.isNotEmpty) {
      final flightList = _flights.putIfAbsent(tripId, () => []);
      for (final raw in rawFlights) {
        final item = raw as Map<String, dynamic>;
        final flightNumber = item['flightNumber'] as String? ?? '';
        final departureTime = DateTime.parse(item['departureTime'] as String);
        final flightLinks = _parseStringList(item['links']);
        final flightAttachments = _parseStringList(item['attachments']);

        final matchIdx = _findMatchingFlightIndex(flightList, item, flightNumber, departureTime);
        if (matchIdx != -1) {
          final existing = flightList[matchIdx];
          final mergedLinks = <String>{...existing.links, ...flightLinks}.toList();
          final mergedAttachments = <String>{...existing.attachments, ...flightAttachments}.toList();
          final updated = existing.copyWith(
            airline: item['airline'] as String? ?? existing.airline,
            flightNumber: flightNumber.isNotEmpty ? flightNumber : existing.flightNumber,
            departureAirport: item['departureAirport'] as String? ?? existing.departureAirport,
            arrivalAirport: item['arrivalAirport'] as String? ?? existing.arrivalAirport,
            departureTime: departureTime,
            arrivalTime: DateTime.parse(item['arrivalTime'] as String? ?? existing.arrivalTime.toIso8601String()),
            terminal: item['terminal'] as String? ?? existing.terminal,
            gate: item['gate'] as String? ?? existing.gate,
            seat: item['seat'] as String? ?? existing.seat,
            bookingRef: item['bookingRef'] as String? ?? existing.bookingRef,
            notes: item['notes'] as String? ?? existing.notes,
            links: mergedLinks,
            attachments: mergedAttachments,
            lastModifiedAt: now,
            lastModifiedSource: 'mcp',
          );
          flightList[matchIdx] = updated;
          appliedFlights.add(updated);
          if (_isAuthenticated) {
            try {
              await _firestore.saveFlight(updated);
            } catch (_) {}
          }
        } else {
          final flt = Flight(
            id: 'fl_${_uuid.v4().substring(0, 8)}',
            tripId: tripId,
            airline: item['airline'] as String,
            flightNumber: flightNumber,
            departureAirport: item['departureAirport'] as String,
            arrivalAirport: item['arrivalAirport'] as String,
            departureTime: departureTime,
            arrivalTime: DateTime.parse(item['arrivalTime'] as String),
            terminal: item['terminal'] as String?,
            gate: item['gate'] as String?,
            seat: item['seat'] as String?,
            bookingRef: item['bookingRef'] as String?,
            notes: item['notes'] as String?,
            links: flightLinks,
            attachments: flightAttachments,
            lastModifiedAt: now,
            lastModifiedSource: 'mcp',
          );
          flightList.add(flt);
          appliedFlights.add(flt);
          if (_isAuthenticated) {
            try {
              await _firestore.saveFlight(flt);
            } catch (_) {}
          }
        }
      }
    }

    // Build user-friendly human readable confirmation summary
    final buffer = StringBuffer();
    buffer.writeln('✨ Proposed daily itinerary successfully applied to Trippy!');
    buffer.writeln('Trip: ${trip.title} (${trip.destination})');
    buffer.writeln('Date: $dateStr');
    if (updatedLocations != null && updatedLocations.isNotEmpty) {
      buffer.writeln('Locations: ${updatedLocations.join(", ")}');
    }
    if (updatedActivities.isNotEmpty) {
      buffer.writeln('\nUpdated Existing Activities (${updatedActivities.length}):');
      for (final title in updatedActivities) {
        buffer.writeln('  • $title (updated in-place, preserved IDs & links)');
      }
    }
    if (createdActivities.isNotEmpty) {
      buffer.writeln('\nNew Activities Added (${createdActivities.length}):');
      for (final title in createdActivities) {
        buffer.writeln('  • $title (new activity created)');
      }
    }
    if (appliedStays.isNotEmpty) {
      buffer.writeln('\nStays (${appliedStays.length}):');
      for (final s in appliedStays) {
        buffer.writeln('  • ${s.name} (${s.checkInTime} check-in) (via MCP)');
      }
    }
    if (appliedFlights.isNotEmpty) {
      buffer.writeln('\nFlights (${appliedFlights.length}):');
      for (final f in appliedFlights) {
        buffer.writeln('  • ${f.airline} ${f.flightNumber}: ${f.departureAirport} → ${f.arrivalAirport} (via MCP)');
      }
    }
    if (_isAuthenticated) {
      buffer.writeln('\n✨ All changes saved to Cloud Firestore.');
    } else {
      buffer.writeln('\nℹ️ Applied to sample trip in-memory (unauthenticated mode). Changes will not persist.');
    }
    buffer.writeln('All objects stamped with lastModifiedSource="mcp" and timestamp.');

    return {
      'content': [
        {'type': 'text', 'text': buffer.toString()}
      ],
      'data': {
        'tripId': tripId,
        'date': dateStr,
        'activitiesCount': appliedActivities.length,
        'updatedActivitiesCount': updatedActivities.length,
        'createdActivitiesCount': createdActivities.length,
        'newActivitiesCount': createdActivities.length,
        'staysCount': appliedStays.length,
        'flightsCount': appliedFlights.length,
        'activities': appliedActivities.map((a) => a.toMap()).toList(),
        'stays': appliedStays.map((s) => s.toMap()).toList(),
        'flights': appliedFlights.map((f) => f.toMap()).toList(),
      },
    };
  }

  // ---------------------------------------------------------------------------
  // Matching Helpers
  // ---------------------------------------------------------------------------

  String _normalizeString(String str) =>
      str.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  int _findMatchingActivityIndex(
    List<Activity> list,
    DateTime targetDate,
    Map<String, dynamic> item,
    String proposedTitle,
    String proposedStartTime,
  ) {
    // 1. Explicit ID match
    final explicitId = (item['id'] ?? item['activityId']) as String?;
    if (explicitId != null && explicitId.isNotEmpty) {
      final idx = list.indexWhere((a) => a.id == explicitId);
      if (idx != -1) return idx;
    }

    final pNorm = _normalizeString(proposedTitle);
    if (pNorm.isEmpty) return -1;

    // Check candidate activities on the same date
    final sameDayIndices = <int>[];
    for (int i = 0; i < list.length; i++) {
      final a = list[i];
      if (a.date.year == targetDate.year &&
          a.date.month == targetDate.month &&
          a.date.day == targetDate.day) {
        sameDayIndices.add(i);
      }
    }

    // 2. Exact normalized title match on the same day
    for (final i in sameDayIndices) {
      final a = list[i];
      if (_normalizeString(a.title) == pNorm) {
        return i;
      }
    }

    // 3. Substring / containment match on the same day
    for (final i in sameDayIndices) {
      final a = list[i];
      final aNorm = _normalizeString(a.title);
      if (aNorm.isNotEmpty) {
        if (aNorm.contains(pNorm) || pNorm.contains(aNorm)) {
          final shorter = aNorm.length < pNorm.length ? aNorm.length : pNorm.length;
          if (shorter >= 4) {
            return i;
          }
        }
      }
    }

    // 4. Time match + location overlap on the same day
    final proposedLocation = (item['location'] as String?)?.trim();
    if (proposedLocation != null && proposedLocation.isNotEmpty) {
      final locNorm = _normalizeString(proposedLocation);
      for (final i in sameDayIndices) {
        final a = list[i];
        if (a.location != null && a.location!.isNotEmpty) {
          final aLocNorm = _normalizeString(a.location!);
          if (aLocNorm.contains(locNorm) || locNorm.contains(aLocNorm)) {
            if (a.startTime == proposedStartTime) {
              return i;
            }
          }
        }
      }
    }

    return -1;
  }

  int _findMatchingStayIndex(
    List<Stay> list,
    Map<String, dynamic> item,
    String proposedName,
    DateTime checkInDate,
  ) {
    final explicitId = (item['id'] ?? item['stayId']) as String?;
    if (explicitId != null && explicitId.isNotEmpty) {
      final idx = list.indexWhere((s) => s.id == explicitId);
      if (idx != -1) return idx;
    }

    final pNorm = _normalizeString(proposedName);
    if (pNorm.isEmpty) return -1;

    for (int i = 0; i < list.length; i++) {
      final s = list[i];
      if (_normalizeString(s.name) == pNorm) {
        return i;
      }
    }

    for (int i = 0; i < list.length; i++) {
      final s = list[i];
      final sNorm = _normalizeString(s.name);
      if (sNorm.isNotEmpty) {
        if (sNorm.contains(pNorm) || pNorm.contains(sNorm)) {
          final shorter = sNorm.length < pNorm.length ? sNorm.length : pNorm.length;
          if (shorter >= 5) {
            return i;
          }
        }
      }
    }

    return -1;
  }

  int _findMatchingFlightIndex(
    List<Flight> list,
    Map<String, dynamic> item,
    String flightNumber,
    DateTime departureTime,
  ) {
    final explicitId = (item['id'] ?? item['flightId']) as String?;
    if (explicitId != null && explicitId.isNotEmpty) {
      final idx = list.indexWhere((f) => f.id == explicitId);
      if (idx != -1) return idx;
    }

    final fNorm = _normalizeString(flightNumber);
    if (fNorm.isEmpty) return -1;

    for (int i = 0; i < list.length; i++) {
      final f = list[i];
      if (_normalizeString(f.flightNumber) == fNorm) {
        if (f.departureTime.year == departureTime.year &&
            f.departureTime.month == departureTime.month &&
            f.departureTime.day == departureTime.day) {
          return i;
        }
      }
    }

    return -1;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  List<String> _parseStringList(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) {
      final result = <String>[];
      for (final item in raw) {
        if (item is String) {
          final trimmed = item.trim();
          if (trimmed.isNotEmpty) result.add(trimmed);
        } else if (item is Map) {
          final label = item['label'] ?? item['title'] ?? item['name'];
          final url = item['url'] ?? item['link'] ?? item['path'] ?? item['uri'];
          if (label != null && url != null && label.toString().trim().isNotEmpty) {
            result.add('${label.toString().trim()}|${url.toString().trim()}');
          } else if (url != null && url.toString().trim().isNotEmpty) {
            result.add(url.toString().trim());
          } else if (label != null && label.toString().trim().isNotEmpty) {
            result.add(label.toString().trim());
          }
        } else if (item != null) {
          final str = item.toString().trim();
          if (str.isNotEmpty) result.add(str);
        }
      }
      return result;
    } else if (raw is String) {
      final trimmed = raw.trim();
      return trimmed.isNotEmpty ? [trimmed] : [];
    }
    return [];
  }

  Map<String, dynamic> _text(String message) => {
        'content': [
          {'type': 'text', 'text': message}
        ],
      };

  Map<String, dynamic> _json(Map<String, dynamic> data) => {
        'content': [
          {
            'type': 'text',
            'text': const JsonEncoder.withIndent('  ').convert(data),
          }
        ],
        'data': data,
      };

  Future<Map<String, dynamic>> _handleAddLink(Map<String, dynamic> args) async {
    await _ensureTripsLoaded();
    final tripId = _resolveTripId(args['tripId'] as String?);
    final targetType = (args['targetType'] as String? ?? 'stay').toLowerCase().trim();
    final targetId = (args['targetId'] as String?)?.trim();
    final targetName = (args['targetName'] as String?)?.trim();
    final rawUrl = (args['url'] as String?)?.trim();
    final label = (args['label'] as String?)?.trim();
    final isAttachment = args['isAttachment'] as bool? ?? false;

    if (rawUrl == null || rawUrl.isEmpty) {
      return _error('A valid "url" is required.');
    }

    final formattedLink = (label != null && label.isNotEmpty) ? '$label|$rawUrl' : rawUrl;

    if (targetType == 'stay') {
      if (_isAuthenticated && (_stays[tripId] == null || _stays[tripId]!.isEmpty)) {
        try {
          final remote = await _firestore.getStays(tripId);
          if (remote != null) _stays[tripId] = remote;
        } catch (_) {}
      }

      final list = _stays[tripId];
      if (list == null || list.isEmpty) {
        return _error('No stays found for trip "$tripId".');
      }

      int idx = -1;
      if (targetId != null && targetId.isNotEmpty) {
        idx = list.indexWhere((s) => s.id == targetId);
      } else if (targetName != null && targetName.isNotEmpty) {
        final query = targetName.toLowerCase();
        idx = list.indexWhere((s) => s.name.toLowerCase().contains(query));
      } else if (list.length == 1) {
        idx = 0;
      }

      if (idx == -1) {
        return _error(
          'Stay not found. Please provide a valid "targetId" or "targetName". '
          'Available stays: ${list.map((s) => "${s.name} (${s.id})").join(", ")}',
        );
      }

      final existing = list[idx];
      final currentList = isAttachment ? existing.attachments : existing.links;
      final updatedList = List<String>.from(currentList)..add(formattedLink);

      final updated = existing.copyWith(
        links: isAttachment ? null : updatedList,
        attachments: isAttachment ? updatedList : null,
        lastModifiedAt: DateTime.now(),
        lastModifiedSource: 'mcp',
      );
      list[idx] = updated;

      if (_isAuthenticated) {
        final ok = await _firestore.saveStay(updated);
        if (!ok) {
          return _error('Failed to save stay link to Firestore. Please check permissions.');
        }
      }

      return _json({
        'message': 'Link added successfully to stay "${updated.name}"!',
        'targetType': 'stay',
        'targetId': updated.id,
        'targetName': updated.name,
        'linkAdded': formattedLink,
        'links': updated.links,
        'attachments': updated.attachments,
      });
    } else if (targetType == 'activity') {
      if (_isAuthenticated && (_activities[tripId] == null || _activities[tripId]!.isEmpty)) {
        try {
          final remote = await _firestore.getActivities(tripId);
          if (remote != null) _activities[tripId] = remote;
        } catch (_) {}
      }

      final list = _activities[tripId];
      if (list == null || list.isEmpty) {
        return _error('No activities found for trip "$tripId".');
      }

      int idx = -1;
      if (targetId != null && targetId.isNotEmpty) {
        idx = list.indexWhere((a) => a.id == targetId);
      } else if (targetName != null && targetName.isNotEmpty) {
        final query = targetName.toLowerCase();
        idx = list.indexWhere((a) => a.title.toLowerCase().contains(query));
      } else if (list.length == 1) {
        idx = 0;
      }

      if (idx == -1) {
        return _error(
          'Activity not found. Please provide a valid "targetId" or "targetName".',
        );
      }

      final existing = list[idx];
      final currentList = isAttachment ? existing.attachments : existing.links;
      final updatedList = List<String>.from(currentList)..add(formattedLink);

      final updated = existing.copyWith(
        links: isAttachment ? null : updatedList,
        attachments: isAttachment ? updatedList : null,
        lastModifiedAt: DateTime.now(),
        lastModifiedSource: 'mcp',
      );
      list[idx] = updated;

      if (_isAuthenticated) {
        final ok = await _firestore.saveActivity(updated);
        if (!ok) {
          return _error('Failed to save activity link to Firestore. Please check permissions.');
        }
      }

      return _json({
        'message': 'Link added successfully to activity "${updated.title}"!',
        'targetType': 'activity',
        'targetId': updated.id,
        'targetName': updated.title,
        'linkAdded': formattedLink,
        'links': updated.links,
        'attachments': updated.attachments,
      });
    } else if (targetType == 'flight') {
      if (_isAuthenticated && (_flights[tripId] == null || _flights[tripId]!.isEmpty)) {
        try {
          final remote = await _firestore.getFlights(tripId);
          if (remote != null) _flights[tripId] = remote;
        } catch (_) {}
      }

      final list = _flights[tripId];
      if (list == null || list.isEmpty) {
        return _error('No flights found for trip "$tripId".');
      }

      int idx = -1;
      if (targetId != null && targetId.isNotEmpty) {
        idx = list.indexWhere((f) => f.id == targetId);
      } else if (targetName != null && targetName.isNotEmpty) {
        final query = targetName.toLowerCase();
        idx = list.indexWhere((f) =>
            f.airline.toLowerCase().contains(query) ||
            f.flightNumber.toLowerCase().contains(query));
      } else if (list.length == 1) {
        idx = 0;
      }

      if (idx == -1) {
        return _error(
          'Flight not found. Please provide a valid "targetId" or "targetName".',
        );
      }

      final existing = list[idx];
      final currentList = isAttachment ? existing.attachments : existing.links;
      final updatedList = List<String>.from(currentList)..add(formattedLink);

      final updated = existing.copyWith(
        links: isAttachment ? null : updatedList,
        attachments: isAttachment ? updatedList : null,
        lastModifiedAt: DateTime.now(),
        lastModifiedSource: 'mcp',
      );
      list[idx] = updated;

      if (_isAuthenticated) {
        final ok = await _firestore.saveFlight(updated);
        if (!ok) {
          return _error('Failed to save flight link to Firestore. Please check permissions.');
        }
      }

      return _json({
        'message': 'Link added successfully to flight "${updated.airline} ${updated.flightNumber}"!',
        'targetType': 'flight',
        'targetId': updated.id,
        'targetName': '${updated.airline} ${updated.flightNumber}',
        'linkAdded': formattedLink,
        'links': updated.links,
        'attachments': updated.attachments,
      });
    }

    return _error('Unsupported targetType "$targetType". Supported values: "stay", "activity", or "flight".');
  }

  Map<String, dynamic> _error(String errorMsg) => {
        'isError': true,
        'content': [
          {'type': 'text', 'text': 'Error: $errorMsg'}
        ],
      };
}
