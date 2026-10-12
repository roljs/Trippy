import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../models/models.dart';

/// Lightweight Firestore REST API client for Cloud Run & MCP server.
/// Uses dart:io HttpClient (no heavy SDK dependencies).
class FirestoreRestClient {
  final String projectId;
  String? _explicitToken;

  String? _cachedMetadataToken;
  DateTime? _tokenExpiry;

  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 4);

  FirestoreRestClient({
    this.projectId = 'trippy-prod-4524f',
    String? initialToken,
  }) : _explicitToken = initialToken;

  void setToken(String? token) {
    if (token != null && token.isNotEmpty) {
      if (token.startsWith('trippy_pat_')) {
        // PATs are application-layer secrets for MCP clients, not Google Cloud OAuth/ID tokens
        return;
      }
      _explicitToken = token;
    } else {
      _explicitToken = null;
    }
  }

  String get _baseUrl =>
      'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents';

  /// Resolves an OAuth2 access token via explicit token, env var, or GCP metadata server.
  Future<String?> _resolveToken() async {
    if (_explicitToken != null &&
        _explicitToken!.isNotEmpty &&
        !_explicitToken!.startsWith('trippy_pat_')) {
      return _explicitToken;
    }

    final envToken = Platform.environment['TRIPPY_AUTH_TOKEN'];
    if (envToken != null && envToken.isNotEmpty) {
      return envToken;
    }

    // Check cached metadata token
    if (_cachedMetadataToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return _cachedMetadataToken;
    }

    // Try Google Cloud metadata server (available in Cloud Run)
    try {
      final uri = Uri.parse(
        'http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token',
      );
      final req = await _client.getUrl(uri).timeout(const Duration(seconds: 2));
      req.headers.set('Metadata-Flavor', 'Google');
      final resp = await req.close().timeout(const Duration(seconds: 2));
      if (resp.statusCode == HttpStatus.ok) {
        final body = await resp.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final token = json['access_token'] as String?;
        final expiresIn = json['expires_in'] as int? ?? 3600;
        if (token != null) {
          _cachedMetadataToken = token;
          _tokenExpiry =
              DateTime.now().add(Duration(seconds: (expiresIn - 60).clamp(60, 3600)));
          return token;
        }
      }
    } catch (_) {
      // Not running on GCP or metadata server unreachable
    }

    return null;
  }

  /// Convert Dart map to Firestore REST fields map
  static Map<String, dynamic> encodeFields(Map<String, dynamic> data) {
    final fields = <String, dynamic>{};
    for (final entry in data.entries) {
      final encoded = _encodeValue(entry.value);
      if (encoded != null) {
        fields[entry.key] = encoded;
      }
    }
    return fields;
  }

  static dynamic _encodeValue(dynamic value) {
    if (value == null) return {'nullValue': null};
    if (value is bool) return {'booleanValue': value};
    if (value is int) return {'integerValue': value.toString()};
    if (value is double) return {'doubleValue': value};
    if (value is String) return {'stringValue': value};
    if (value is DateTime) return {'stringValue': value.toIso8601String()};
    if (value is List) {
      return {
        'arrayValue': {
          'values': value.map(_encodeValue).where((v) => v != null).toList(),
        },
      };
    }
    if (value is Map) {
      final mapFields = <String, dynamic>{};
      for (final k in value.keys) {
        final enc = _encodeValue(value[k]);
        if (enc != null) mapFields[k.toString()] = enc;
      }
      return {
        'mapValue': {'fields': mapFields},
      };
    }
    return {'stringValue': value.toString()};
  }

  /// Decode Firestore REST fields into normal Dart map
  static Map<String, dynamic> decodeFields(Map<String, dynamic>? fields) {
    if (fields == null) return {};
    final result = <String, dynamic>{};
    for (final entry in fields.entries) {
      result[entry.key] = _decodeValue(entry.value);
    }
    return result;
  }

  static dynamic _decodeValue(dynamic raw) {
    if (raw is! Map) return raw;
    if (raw.containsKey('nullValue')) return null;
    if (raw.containsKey('stringValue')) return raw['stringValue'];
    if (raw.containsKey('booleanValue')) return raw['booleanValue'];
    if (raw.containsKey('integerValue')) {
      return int.tryParse(raw['integerValue'].toString()) ?? 0;
    }
    if (raw.containsKey('doubleValue')) {
      final v = raw['doubleValue'];
      return v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0;
    }
    if (raw.containsKey('timestampValue')) return raw['timestampValue'];
    if (raw.containsKey('arrayValue')) {
      final list = raw['arrayValue']?['values'] as List<dynamic>?;
      return list?.map(_decodeValue).toList() ?? [];
    }
    if (raw.containsKey('mapValue')) {
      final f = raw['mapValue']?['fields'] as Map<String, dynamic>?;
      return decodeFields(f);
    }
    return raw;
  }

  /// Fetch all trips in the Firestore database
  Future<List<Trip>?> getTrips() async {
    final token = await _resolveToken();
    if (token == null) return null;

    try {
      final uri = Uri.parse('$_baseUrl/trips');
      final req = await _client.getUrl(uri);
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      final resp = await req.close();
      if (resp.statusCode != HttpStatus.ok) return null;

      final body = await resp.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final docs = json['documents'] as List<dynamic>? ?? [];

      final trips = <Trip>[];
      for (final doc in docs) {
        final docMap = doc as Map<String, dynamic>;
        final fields = docMap['fields'] as Map<String, dynamic>?;
        if (fields != null) {
          final decoded = decodeFields(fields);
          // Set ID from document path if missing
          final name = docMap['name'] as String? ?? '';
          final docId = name.split('/').last;
          if (decoded['id'] == null || (decoded['id'] as String).isEmpty) {
            decoded['id'] = docId;
          }
          trips.add(Trip.fromMap(decoded));
        }
      }
      return trips;
    } catch (e) {
      stderr.writeln('FirestoreRestClient: Error fetching trips: $e');
      return null;
    }
  }

  /// Fetch activities for a trip
  Future<List<Activity>?> getActivities(String tripId) async {
    final token = await _resolveToken();
    if (token == null) return null;

    try {
      final uri = Uri.parse('$_baseUrl/trips/$tripId/activities?pageSize=300');
      final req = await _client.getUrl(uri);
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      final resp = await req.close();
      if (resp.statusCode != HttpStatus.ok) return null;

      final body = await resp.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final docs = json['documents'] as List<dynamic>? ?? [];

      final activities = <Activity>[];
      for (final doc in docs) {
        final docMap = doc as Map<String, dynamic>;
        final fields = docMap['fields'] as Map<String, dynamic>?;
        if (fields != null) {
          final decoded = decodeFields(fields);
          final name = docMap['name'] as String? ?? '';
          final docId = name.split('/').last;
          if (decoded['id'] == null || (decoded['id'] as String).isEmpty) {
            decoded['id'] = docId;
          }
          decoded['tripId'] = tripId;
          activities.add(Activity.fromMap(decoded));
        }
      }
      return activities;
    } catch (e) {
      stderr.writeln('FirestoreRestClient: Error fetching activities for $tripId: $e');
      return null;
    }
  }

  /// Fetch stays for a trip
  Future<List<Stay>?> getStays(String tripId) async {
    final token = await _resolveToken();
    if (token == null) return null;

    try {
      final uri = Uri.parse('$_baseUrl/trips/$tripId/stays?pageSize=100');
      final req = await _client.getUrl(uri);
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      final resp = await req.close();
      if (resp.statusCode != HttpStatus.ok) return null;

      final body = await resp.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final docs = json['documents'] as List<dynamic>? ?? [];

      final stays = <Stay>[];
      for (final doc in docs) {
        final docMap = doc as Map<String, dynamic>;
        final fields = docMap['fields'] as Map<String, dynamic>?;
        if (fields != null) {
          final decoded = decodeFields(fields);
          final name = docMap['name'] as String? ?? '';
          final docId = name.split('/').last;
          if (decoded['id'] == null || (decoded['id'] as String).isEmpty) {
            decoded['id'] = docId;
          }
          decoded['tripId'] = tripId;
          stays.add(Stay.fromMap(decoded));
        }
      }
      return stays;
    } catch (e) {
      stderr.writeln('FirestoreRestClient: Error fetching stays for $tripId: $e');
      return null;
    }
  }

  /// Fetch flights for a trip
  Future<List<Flight>?> getFlights(String tripId) async {
    final token = await _resolveToken();
    if (token == null) return null;

    try {
      final uri = Uri.parse('$_baseUrl/trips/$tripId/flights?pageSize=100');
      final req = await _client.getUrl(uri);
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      final resp = await req.close();
      if (resp.statusCode != HttpStatus.ok) return null;

      final body = await resp.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final docs = json['documents'] as List<dynamic>? ?? [];

      final flights = <Flight>[];
      for (final doc in docs) {
        final docMap = doc as Map<String, dynamic>;
        final fields = docMap['fields'] as Map<String, dynamic>?;
        if (fields != null) {
          final decoded = decodeFields(fields);
          final name = docMap['name'] as String? ?? '';
          final docId = name.split('/').last;
          if (decoded['id'] == null || (decoded['id'] as String).isEmpty) {
            decoded['id'] = docId;
          }
          decoded['tripId'] = tripId;
          flights.add(Flight.fromMap(decoded));
        }
      }
      return flights;
    } catch (e) {
      stderr.writeln('FirestoreRestClient: Error fetching flights for $tripId: $e');
      return null;
    }
  }

  /// Save or update an activity directly in Firestore
  Future<bool> saveActivity(Activity act) async {
    final token = await _resolveToken();
    if (token == null) return false;

    try {
      final uri = Uri.parse('$_baseUrl/trips/${act.tripId}/activities/${act.id}');
      final req = await _client.patchUrl(uri);
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      req.headers.contentType = ContentType.json;

      final map = act.toMap();
      final payload = jsonEncode({'fields': encodeFields(map)});
      req.write(payload);

      final resp = await req.close();
      if (resp.statusCode != HttpStatus.ok) {
        final body = await utf8.decodeStream(resp);
        stderr.writeln('FirestoreRestClient: Error saving activity ${act.id} (${resp.statusCode}): $body');
        return false;
      }
      return true;
    } catch (e) {
      stderr.writeln('FirestoreRestClient: Error saving activity ${act.id}: $e');
      return false;
    }
  }

  /// Delete an activity in Firestore
  Future<bool> deleteActivity(String tripId, String activityId) async {
    final token = await _resolveToken();
    if (token == null) return false;

    try {
      final uri = Uri.parse('$_baseUrl/trips/$tripId/activities/$activityId');
      final req = await _client.deleteUrl(uri);
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      final resp = await req.close();
      return resp.statusCode == HttpStatus.ok;
    } catch (e) {
      stderr.writeln('FirestoreRestClient: Error deleting activity $activityId: $e');
      return false;
    }
  }

  /// Save or update a stay in Firestore
  Future<bool> saveStay(Stay stay) async {
    final token = await _resolveToken();
    if (token == null) return false;

    try {
      final uri = Uri.parse('$_baseUrl/trips/${stay.tripId}/stays/${stay.id}');
      final req = await _client.patchUrl(uri);
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      req.headers.contentType = ContentType.json;

      final map = stay.toMap();
      final payload = jsonEncode({'fields': encodeFields(map)});
      req.write(payload);

      final resp = await req.close();
      if (resp.statusCode != HttpStatus.ok) {
        final body = await utf8.decodeStream(resp);
        stderr.writeln('FirestoreRestClient: Error saving stay ${stay.id} (${resp.statusCode}): $body');
        return false;
      }
      return true;
    } catch (e) {
      stderr.writeln('FirestoreRestClient: Error saving stay ${stay.id}: $e');
      return false;
    }
  }

  /// Delete a stay in Firestore
  Future<bool> deleteStay(String tripId, String stayId) async {
    final token = await _resolveToken();
    if (token == null) return false;

    try {
      final uri = Uri.parse('$_baseUrl/trips/$tripId/stays/$stayId');
      final req = await _client.deleteUrl(uri);
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      final resp = await req.close();
      return resp.statusCode == HttpStatus.ok;
    } catch (e) {
      stderr.writeln('FirestoreRestClient: Error deleting stay $stayId: $e');
      return false;
    }
  }

  /// Save or update a flight in Firestore
  Future<bool> saveFlight(Flight flight) async {
    final token = await _resolveToken();
    if (token == null) return false;

    try {
      final uri = Uri.parse('$_baseUrl/trips/${flight.tripId}/flights/${flight.id}');
      final req = await _client.patchUrl(uri);
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      req.headers.contentType = ContentType.json;

      final map = flight.toMap();
      final payload = jsonEncode({'fields': encodeFields(map)});
      req.write(payload);

      final resp = await req.close();
      if (resp.statusCode != HttpStatus.ok) {
        final body = await utf8.decodeStream(resp);
        stderr.writeln('FirestoreRestClient: Error saving flight ${flight.id} (${resp.statusCode}): $body');
        return false;
      }
      return true;
    } catch (e) {
      stderr.writeln('FirestoreRestClient: Error saving flight ${flight.id}: $e');
      return false;
    }
  }

  /// Delete a flight in Firestore
  Future<bool> deleteFlight(String tripId, String flightId) async {
    final token = await _resolveToken();
    if (token == null) return false;

    try {
      final uri = Uri.parse('$_baseUrl/trips/$tripId/flights/$flightId');
      final req = await _client.deleteUrl(uri);
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      final resp = await req.close();
      return resp.statusCode == HttpStatus.ok;
    } catch (e) {
      stderr.writeln('FirestoreRestClient: Error deleting flight $flightId: $e');
      return false;
    }
  }

  /// Update trip in Firestore (e.g. dayLocations, metadata)
  Future<bool> saveTrip(Trip trip) async {
    final token = await _resolveToken();
    if (token == null) return false;

    try {
      final uri = Uri.parse('$_baseUrl/trips/${trip.id}');
      final req = await _client.patchUrl(uri);
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      req.headers.contentType = ContentType.json;

      final map = trip.toMap();
      map['memberIds'] = <String>{trip.ownerId, ...trip.members.keys}.toList();
      final payload = jsonEncode({'fields': encodeFields(map)});
      req.write(payload);

      final resp = await req.close();
      if (resp.statusCode != HttpStatus.ok) {
        final body = await utf8.decodeStream(resp);
        stderr.writeln('FirestoreRestClient: Error saving trip ${trip.id} (${resp.statusCode}): $body');
        return false;
      }
      return true;
    } catch (e) {
      stderr.writeln('FirestoreRestClient: Error saving trip ${trip.id}: $e');
      return false;
    }
  }

  /// Look up a user's Firebase UID by their email using Google Identity Toolkit API.
  Future<String?> lookupUidByEmail(String email) async {
    final token = await _resolveToken();
    if (token == null) return null;

    try {
      final uri = Uri.parse(
        'https://identitytoolkit.googleapis.com/v1/projects/$projectId/accounts:lookup',
      );
      final req = await _client.postUrl(uri);
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      req.headers.set('X-Goog-User-Project', projectId);
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({
        'email': [email.trim().toLowerCase()]
      }));

      final resp = await req.close();
      if (resp.statusCode == HttpStatus.ok) {
        final body = await resp.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final users = json['users'] as List<dynamic>?;
        if (users != null && users.isNotEmpty) {
          final localId = users.first['localId'] as String?;
          if (localId != null && localId.isNotEmpty) {
            return localId;
          }
        }
      }
    } catch (e) {
      stderr.writeln('FirestoreRestClient: Error looking up UID for $email: $e');
    }
    return null;
  }

  /// Cryptographically verify a Firebase Auth ID Token using Google Identity Toolkit.
  /// Returns a Map with 'uid' and 'email' if valid, or null if invalid or expired.
  Future<Map<String, String>?> verifyIdToken(String idToken) async {
    final token = await _resolveToken();
    if (token == null) return null;

    try {
      final uri = Uri.parse(
        'https://identitytoolkit.googleapis.com/v1/projects/$projectId/accounts:lookup',
      );
      final req = await _client.postUrl(uri);
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      req.headers.set('X-Goog-User-Project', projectId);
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({
        'idToken': idToken.trim(),
      }));

      final resp = await req.close();
      if (resp.statusCode == HttpStatus.ok) {
        final body = await resp.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final users = json['users'] as List<dynamic>?;
        if (users != null && users.isNotEmpty) {
          final first = users.first as Map<String, dynamic>;
          final localId = first['localId'] as String?;
          final email = first['email'] as String?;
          if (localId != null && localId.isNotEmpty) {
            return {
              'uid': localId,
              'email': ?email,
            };
          }
        }
      }
    } catch (e) {
      stderr.writeln('FirestoreRestClient: Error verifying ID token: $e');
    }
    return null;
  }

  /// Compute SHA-256 hash of a Personal Access Token.
  static String hashPat(String token) {
    return sha256.convert(utf8.encode(token.trim())).toString();
  }

  /// Looks up a Personal Access Token from Firestore `mcp_api_keys/{tokenHash}`.
  /// Returns a map with `userId`, `userEmail`, `name` if valid and enabled, else null.
  Future<Map<String, dynamic>?> lookupPersonalAccessToken(String rawToken) async {
    final clean = rawToken.trim();
    if (clean.isEmpty) return null;
    final tokenHash = hashPat(clean);
    final token = await _resolveToken();
    if (token == null) return null;

    try {
      final uri = Uri.parse('$_baseUrl/mcp_api_keys/$tokenHash');
      final req = await _client.getUrl(uri);
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      final resp = await req.close();
      if (resp.statusCode != HttpStatus.ok) return null;

      final body = await resp.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final fields = json['fields'] as Map<String, dynamic>?;
      if (fields == null) return null;

      final decoded = decodeFields(fields);
      final isEnabled = decoded['enabled'] != false;
      if (!isEnabled) return null;

      final userId = decoded['userId'] as String?;
      final userEmail = decoded['userEmail'] as String?;
      if (userId == null || userId.isEmpty) return null;

      // Asynchronously update lastUsedAt timestamp without blocking
      _touchPatLastUsed(tokenHash, token).ignore();

      return {
        'userId': userId,
        'userEmail': userEmail ?? '',
        'name': decoded['name'] as String? ?? 'Personal Access Token',
        'createdAt': decoded['createdAt'],
      };
    } catch (e) {
      stderr.writeln('FirestoreRestClient: Error looking up PAT: $e');
      return null;
    }
  }

  Future<void> _touchPatLastUsed(String tokenHash, String authToken) async {
    try {
      final uri = Uri.parse('$_baseUrl/mcp_api_keys/$tokenHash?updateMask.fieldPaths=lastUsedAt');
      final req = await _client.patchUrl(uri);
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $authToken');
      req.headers.contentType = ContentType.json;
      final payload = {
        'fields': {
          'lastUsedAt': {'stringValue': DateTime.now().toUtc().toIso8601String()},
        },
      };
      req.write(jsonEncode(payload));
      final resp = await req.close();
      await resp.drain();
    } catch (_) {}
  }

  /// Store or register a Personal Access Token in Firestore `mcp_api_keys/{tokenHash}`.
  Future<bool> registerPersonalAccessToken({
    required String rawToken,
    required String userId,
    required String userEmail,
    String name = 'MCP Access Token',
  }) async {
    final tokenHash = hashPat(rawToken);
    final token = await _resolveToken();
    if (token == null) return false;

    try {
      final uri = Uri.parse('$_baseUrl/mcp_api_keys/$tokenHash');
      final req = await _client.patchUrl(uri);
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      req.headers.contentType = ContentType.json;
      final prefix = rawToken.length > 15 ? '${rawToken.substring(0, 14)}...' : rawToken;
      final payload = {
        'fields': encodeFields({
          'userId': userId,
          'userEmail': userEmail,
          'name': name,
          'tokenPrefix': prefix,
          'createdAt': DateTime.now().toUtc().toIso8601String(),
          'lastUsedAt': DateTime.now().toUtc().toIso8601String(),
          'enabled': true,
        }),
      };
      req.write(jsonEncode(payload));
      final resp = await req.close();
      if (resp.statusCode == HttpStatus.ok) return true;
      final body = await resp.transform(utf8.decoder).join();
      stderr.writeln('Failed to register PAT (${resp.statusCode}): $body');
      return false;
    } catch (e) {
      stderr.writeln('FirestoreRestClient: Error registering PAT: $e');
      return false;
    }
  }

  /// Revoke a Personal Access Token in Firestore
  Future<bool> revokePersonalAccessToken(String rawToken) async {
    final tokenHash = hashPat(rawToken);
    final token = await _resolveToken();
    if (token == null) return false;

    try {
      final uri = Uri.parse('$_baseUrl/mcp_api_keys/$tokenHash');
      final req = await _client.deleteUrl(uri);
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      final resp = await req.close();
      return resp.statusCode == HttpStatus.ok;
    } catch (e) {
      stderr.writeln('FirestoreRestClient: Error revoking PAT: $e');
      return false;
    }
  }
}

