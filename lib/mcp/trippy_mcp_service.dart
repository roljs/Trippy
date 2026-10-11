import 'dart:convert';
import 'dart:io';
import 'package:uuid/uuid.dart';

import '../models/models.dart';

/// Service implementing the business logic for all Trippy MCP tools.
class TrippyMcpService {
  final String projectId;
  String? _authToken;
  String _currentUserId = 'user_current';
  String? _currentUserEmail;

  // In-memory / local storage backing for trips
  final Map<String, Trip> _trips = {};
  final Map<String, List<Stay>> _stays = {};
  final Map<String, List<Activity>> _activities = {};
  final Map<String, List<Flight>> _flights = {};

  final Uuid _uuid = const Uuid();

  TrippyMcpService({
    this.projectId = 'trippy-prod-4524f',
    String? initialAuthToken,
    String? initialUserId,
  }) {
    _authToken = initialAuthToken ?? Platform.environment['TRIPPY_AUTH_TOKEN'];
    _currentUserId = initialUserId ??
        Platform.environment['TRIPPY_USER_ID'] ??
        'lTlf0l4OceRFyB9DiDiS6JUq7pf2';
    _currentUserEmail = Platform.environment['TRIPPY_USER_EMAIL'];

    _seedData();
  }

  String get currentUserId => _currentUserId;
  String? get currentUserEmail => _currentUserEmail;
  String? get authToken => _authToken;

  void setAuth({String? token, String? userId, String? email}) {
    if (token != null && token.isNotEmpty) _authToken = token;
    if (userId != null && userId.isNotEmpty) _currentUserId = userId;
    if (email != null && email.isNotEmpty) _currentUserEmail = email;
  }

  void _seedData() {
    // 1. Try to load thailandia_2026_trip.json if present
    try {
      final file = File('thailandia_2026_trip.json');
      if (file.existsSync()) {
        final content = file.readAsStringSync();
        final bundle = TripBundle.fromJson(content);
        _importBundle(bundle);
        return;
      }
    } catch (_) {}

    // 2. Fallback to basic Tokyo trip
    final now = DateTime.now();
    final day1 = DateTime(now.year, now.month, now.day + 15);
    final day5 = day1.add(const Duration(days: 4));

    final trip = Trip(
      id: 'trip_japan_2026',
      title: 'Japan Odyssey: Tokyo & Kyoto',
      destination: 'Tokyo & Kyoto, Japan',
      startDate: day1,
      endDate: day5,
      coverImageUrl:
          'https://images.unsplash.com/photo-1503899036084-c55cdd92da26?auto=format&fit=crop&w=1200&q=80',
      ownerId: _currentUserId,
      inviteCode: 'TYO-8821',
      defaultInviteRole: MemberRole.editor,
      members: {_currentUserId: MemberRole.owner},
      dayLocations: {
        Trip.dateToKey(day1): ['Japan', 'Tokyo'],
        Trip.dateToKey(day1.add(const Duration(days: 1))): ['Japan', 'Tokyo'],
        Trip.dateToKey(day1.add(const Duration(days: 2))): ['Japan', 'Kyoto'],
        Trip.dateToKey(day1.add(const Duration(days: 3))): ['Japan', 'Kyoto'],
        Trip.dateToKey(day5): ['Japan', 'Osaka'],
      },
      createdAt: now.subtract(const Duration(days: 10)),
      updatedAt: now,
      lastModifiedAt: now,
      lastModifiedSource: 'ui',
    );
    _trips[trip.id] = trip;
    _stays[trip.id] = [];
    _activities[trip.id] = [];
    _flights[trip.id] = [];
  }

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
          return _handleAuthenticate(args);
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
        default:
          return _error('Unknown tool: $name');
      }
    } catch (e, st) {
      return _error('Tool execution failed ($name): $e\n$st');
    }
  }

  // ---------------------------------------------------------------------------
  // Handlers
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _handleAuthenticate(Map<String, dynamic> args) {
    final idToken = args['idToken'] as String?;
    final userId = args['userId'] as String?;
    final email = args['email'] as String?;

    setAuth(token: idToken, userId: userId, email: email);

    return _text(
      'Authenticated successfully with Trippy MCP Server!\n'
      'Project: $projectId\n'
      'User ID: $_currentUserId\n'
      'Email: ${_currentUserEmail ?? "Not provided"}\n'
      'Token status: ${_authToken != null && _authToken!.isNotEmpty ? "Valid Bearer Token set" : "Using local user session"}',
    );
  }

  Future<Map<String, dynamic>> _handleListTrips(Map<String, dynamic> args) async {
    final tripsList = _trips.values.toList();

    final result = tripsList.map((t) {
      final actCount = _activities[t.id]?.length ?? 0;
      final stayCount = _stays[t.id]?.length ?? 0;
      final flightCount = _flights[t.id]?.length ?? 0;

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
        'lastModifiedSource': t.lastModifiedSource ?? 'ui',
        'lastModifiedAt': t.lastModifiedAt?.toIso8601String(),
      };
    }).toList();

    return _json({
      'count': result.length,
      'trips': result,
    });
  }

  Future<Map<String, dynamic>> _handleGetTripDetails(Map<String, dynamic> args) async {
    final tripId = args['tripId'] as String?;
    if (tripId == null || tripId.isEmpty) {
      return _error('tripId is required.');
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
    final now = DateTime.now();
    final tripId = 'trip_${_uuid.v4().substring(0, 8)}';
    final startDate = DateTime.parse(args['startDate'] as String);
    final endDate = DateTime.parse(args['endDate'] as String);

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
      createdAt: now,
      updatedAt: now,
      lastModifiedAt: now,
      lastModifiedSource: 'mcp',
    );

    _trips[trip.id] = trip;
    _stays[trip.id] = [];
    _activities[trip.id] = [];
    _flights[trip.id] = [];

    return _json({
      'message': 'Trip created successfully via MCP.',
      'trip': trip.toMap(),
    });
  }

  Future<Map<String, dynamic>> _handleUpdateTrip(Map<String, dynamic> args) async {
    final tripId = args['tripId'] as String;
    final existing = _trips[tripId];
    if (existing == null) return _error('Trip "$tripId" not found.');

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
      updatedAt: DateTime.now(),
      lastModifiedAt: DateTime.now(),
      lastModifiedSource: 'mcp',
    );

    _trips[tripId] = updated;
    return _json({
      'message': 'Trip updated successfully via MCP.',
      'trip': updated.toMap(),
    });
  }

  Future<Map<String, dynamic>> _handleSetDayLocations(Map<String, dynamic> args) async {
    final tripId = args['tripId'] as String;
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

    return _json({
      'message': 'Day locations updated via MCP for $dateStr.',
      'date': dateStr,
      'locations': locations,
    });
  }

  Future<Map<String, dynamic>> _handleCreateActivity(Map<String, dynamic> args) async {
    final tripId = args['tripId'] as String;
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
      mealType: args['mealType'] as String?,
      stayId: args['stayId'] as String?,
      flightId: args['flightId'] as String?,
      lastModifiedAt: DateTime.now(),
      lastModifiedSource: 'mcp',
    );

    final list = _activities.putIfAbsent(tripId, () => []);
    list.add(activity);

    return _json({
      'message': 'Activity created successfully via MCP.',
      'activity': activity.toMap(),
    });
  }

  Future<Map<String, dynamic>> _handleUpdateActivity(Map<String, dynamic> args) async {
    final tripId = args['tripId'] as String;
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
      mealType: args['mealType'] as String?,
      isCompleted: args['isCompleted'] as bool?,
      lastModifiedAt: DateTime.now(),
      lastModifiedSource: 'mcp',
    );

    list[idx] = updated;

    return _json({
      'message': 'Activity updated successfully via MCP.',
      'activity': updated.toMap(),
    });
  }

  Future<Map<String, dynamic>> _handleDeleteActivity(Map<String, dynamic> args) async {
    final tripId = args['tripId'] as String;
    final activityId = args['activityId'] as String;
    final list = _activities[tripId];
    if (list == null) return _error('No activities found for trip "$tripId".');

    final before = list.length;
    list.removeWhere((a) => a.id == activityId);
    if (list.length == before) return _error('Activity "$activityId" not found.');

    return _json({
      'message': 'Activity "$activityId" deleted via MCP.',
    });
  }

  Future<Map<String, dynamic>> _handleCreateStay(Map<String, dynamic> args) async {
    final tripId = args['tripId'] as String;
    if (!_trips.containsKey(tripId)) return _error('Trip "$tripId" not found.');

    final stayId = 'stay_${_uuid.v4().substring(0, 8)}';
    final typeStr = (args['type'] as String?)?.toLowerCase() ?? 'hotel';
    final stayType = StayType.values.firstWhere(
      (t) => t.name.toLowerCase() == typeStr,
      orElse: () => StayType.hotel,
    );

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
      lastModifiedAt: DateTime.now(),
      lastModifiedSource: 'mcp',
    );

    final list = _stays.putIfAbsent(tripId, () => []);
    list.add(stay);

    return _json({
      'message': 'Stay created successfully via MCP.',
      'stay': stay.toMap(),
    });
  }

  Future<Map<String, dynamic>> _handleUpdateStay(Map<String, dynamic> args) async {
    final tripId = args['tripId'] as String;
    final stayId = args['stayId'] as String;
    final list = _stays[tripId];
    if (list == null) return _error('No stays found for trip "$tripId".');

    final idx = list.indexWhere((s) => s.id == stayId);
    if (idx == -1) return _error('Stay "$stayId" not found.');

    final existing = list[idx];
    final updated = existing.copyWith(
      name: args['name'] as String?,
      address: args['address'] as String?,
      checkInDate: args['checkInDate'] != null ? DateTime.parse(args['checkInDate']) : null,
      checkInTime: args['checkInTime'] as String?,
      checkOutDate: args['checkOutDate'] != null ? DateTime.parse(args['checkOutDate']) : null,
      checkOutTime: args['checkOutTime'] as String?,
      confirmationCode: args['confirmationCode'] as String?,
      notes: args['notes'] as String?,
      lastModifiedAt: DateTime.now(),
      lastModifiedSource: 'mcp',
    );

    list[idx] = updated;

    return _json({
      'message': 'Stay updated successfully via MCP.',
      'stay': updated.toMap(),
    });
  }

  Future<Map<String, dynamic>> _handleDeleteStay(Map<String, dynamic> args) async {
    final tripId = args['tripId'] as String;
    final stayId = args['stayId'] as String;
    final list = _stays[tripId];
    if (list == null) return _error('No stays found for trip "$tripId".');

    final before = list.length;
    list.removeWhere((s) => s.id == stayId);
    if (list.length == before) return _error('Stay "$stayId" not found.');

    return _json({'message': 'Stay "$stayId" deleted via MCP.'});
  }

  Future<Map<String, dynamic>> _handleCreateFlight(Map<String, dynamic> args) async {
    final tripId = args['tripId'] as String;
    if (!_trips.containsKey(tripId)) return _error('Trip "$tripId" not found.');

    final flightId = 'fl_${_uuid.v4().substring(0, 8)}';
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
      isOvernight: args['isOvernight'] as bool? ?? false,
      isNightStay: args['isNightStay'] as bool? ?? false,
      lastModifiedAt: DateTime.now(),
      lastModifiedSource: 'mcp',
    );

    final list = _flights.putIfAbsent(tripId, () => []);
    list.add(flight);

    return _json({
      'message': 'Flight created successfully via MCP.',
      'flight': flight.toMap(),
    });
  }

  Future<Map<String, dynamic>> _handleUpdateFlight(Map<String, dynamic> args) async {
    final tripId = args['tripId'] as String;
    final flightId = args['flightId'] as String;
    final list = _flights[tripId];
    if (list == null) return _error('No flights found for trip "$tripId".');

    final idx = list.indexWhere((f) => f.id == flightId);
    if (idx == -1) return _error('Flight "$flightId" not found.');

    final existing = list[idx];
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
      lastModifiedAt: DateTime.now(),
      lastModifiedSource: 'mcp',
    );

    list[idx] = updated;

    return _json({
      'message': 'Flight updated successfully via MCP.',
      'flight': updated.toMap(),
    });
  }

  Future<Map<String, dynamic>> _handleDeleteFlight(Map<String, dynamic> args) async {
    final tripId = args['tripId'] as String;
    final flightId = args['flightId'] as String;
    final list = _flights[tripId];
    if (list == null) return _error('No flights found for trip "$tripId".');

    final before = list.length;
    list.removeWhere((f) => f.id == flightId);
    if (list.length == before) return _error('Flight "$flightId" not found.');

    return _json({'message': 'Flight "$flightId" deleted via MCP.'});
  }

  // ---------------------------------------------------------------------------
  // PRIMARY USE CASE: Apply Proposed Daily Itinerary
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> _handleApplySuggestedItinerary(Map<String, dynamic> args) async {
    final tripId = args['tripId'] as String?;
    if (tripId == null || tripId.isEmpty) return _error('tripId is required.');

    final trip = _trips[tripId];
    if (trip == null) return _error('Trip "$tripId" not found.');

    final dateStr = args['date'] as String?;
    if (dateStr == null || dateStr.isEmpty) return _error('date (YYYY-MM-DD) is required.');

    final targetDate = DateTime.parse(dateStr);
    final bool clearExisting = args['clearExistingActivities'] as bool? ?? false;
    final now = DateTime.now();

    // 1. Clear existing activities for this date if requested
    final actList = _activities.putIfAbsent(tripId, () => []);
    if (clearExisting) {
      actList.removeWhere((a) =>
          a.date.year == targetDate.year &&
          a.date.month == targetDate.month &&
          a.date.day == targetDate.day);
    }

    // 2. Add proposed activities
    final rawActivities = (args['activities'] as List<dynamic>?) ?? [];
    final createdActivities = <Activity>[];

    for (final raw in rawActivities) {
      final item = raw as Map<String, dynamic>;
      final title = item['title'] as String? ?? 'Planned Activity';
      final startTime = item['startTime'] as String? ?? '10:00';
      final endTime = item['endTime'] as String?;
      final location = item['location'] as String?;
      final notes = item['notes'] as String?;
      final cost = (item['cost'] as num?)?.toDouble();
      final mealType = item['mealType'] as String?;

      final catStr = (item['category'] as String?)?.toLowerCase() ?? 'attraction';
      final category = ActivityCategory.values.firstWhere(
        (c) => c.name.toLowerCase() == catStr,
        orElse: () => ActivityCategory.attraction,
      );

      final statusStr = (item['bookingStatus'] as String?)?.toLowerCase() ?? 'planned';
      final bookingStatus = BookingStatus.values.firstWhere(
        (b) => b.name.toLowerCase() == statusStr,
        orElse: () => BookingStatus.planned,
      );

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
        mealType: mealType,
        lastModifiedAt: now,
        lastModifiedSource: 'mcp',
      );

      actList.add(act);
      createdActivities.add(act);
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
      _trips[tripId] = trip.copyWith(
        dayLocations: newLocationsMap,
        updatedAt: now,
        lastModifiedAt: now,
        lastModifiedSource: 'mcp',
      );
    }

    // 4. Stays (if included)
    final rawStays = args['stays'] as List<dynamic>?;
    final createdStays = <Stay>[];
    if (rawStays != null && rawStays.isNotEmpty) {
      final stayList = _stays.putIfAbsent(tripId, () => []);
      for (final raw in rawStays) {
        final item = raw as Map<String, dynamic>;
        final stay = Stay(
          id: 'stay_${_uuid.v4().substring(0, 8)}',
          tripId: tripId,
          type: StayType.fromString(item['type'] as String?),
          name: item['name'] as String,
          address: item['address'] as String?,
          checkInDate: DateTime.parse(item['checkInDate'] as String),
          checkInTime: item['checkInTime'] as String? ?? '15:00',
          checkOutDate: DateTime.parse(item['checkOutDate'] as String),
          checkOutTime: item['checkOutTime'] as String? ?? '11:00',
          confirmationCode: item['confirmationCode'] as String?,
          notes: item['notes'] as String?,
          lastModifiedAt: now,
          lastModifiedSource: 'mcp',
        );
        stayList.add(stay);
        createdStays.add(stay);
      }
    }

    // 5. Flights (if included)
    final rawFlights = args['flights'] as List<dynamic>?;
    final createdFlights = <Flight>[];
    if (rawFlights != null && rawFlights.isNotEmpty) {
      final flightList = _flights.putIfAbsent(tripId, () => []);
      for (final raw in rawFlights) {
        final item = raw as Map<String, dynamic>;
        final flt = Flight(
          id: 'fl_${_uuid.v4().substring(0, 8)}',
          tripId: tripId,
          airline: item['airline'] as String,
          flightNumber: item['flightNumber'] as String,
          departureAirport: item['departureAirport'] as String,
          arrivalAirport: item['arrivalAirport'] as String,
          departureTime: DateTime.parse(item['departureTime'] as String),
          arrivalTime: DateTime.parse(item['arrivalTime'] as String),
          terminal: item['terminal'] as String?,
          gate: item['gate'] as String?,
          seat: item['seat'] as String?,
          bookingRef: item['bookingRef'] as String?,
          notes: item['notes'] as String?,
          lastModifiedAt: now,
          lastModifiedSource: 'mcp',
        );
        flightList.add(flt);
        createdFlights.add(flt);
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
    buffer.writeln('\nScheduled Activities (${createdActivities.length}):');
    for (final a in createdActivities) {
      final time = a.endTime != null ? '${a.startTime} – ${a.endTime}' : a.startTime;
      final loc = a.location != null ? ' @ ${a.location}' : '';
      buffer.writeln('  • $time: ${a.title} [${a.category.displayName}]$loc (via MCP)');
    }
    if (createdStays.isNotEmpty) {
      buffer.writeln('\nStays (${createdStays.length}):');
      for (final s in createdStays) {
        buffer.writeln('  • ${s.name} (${s.checkInTime} check-in) (via MCP)');
      }
    }
    if (createdFlights.isNotEmpty) {
      buffer.writeln('\nFlights (${createdFlights.length}):');
      for (final f in createdFlights) {
        buffer.writeln('  • ${f.airline} ${f.flightNumber}: ${f.departureAirport} → ${f.arrivalAirport} (via MCP)');
      }
    }
    buffer.writeln('\nAll objects stamped with lastModifiedSource="mcp" and timestamp.');

    return {
      'content': [
        {'type': 'text', 'text': buffer.toString()}
      ],
      'data': {
        'tripId': tripId,
        'date': dateStr,
        'activitiesCount': createdActivities.length,
        'staysCount': createdStays.length,
        'flightsCount': createdFlights.length,
        'activities': createdActivities.map((a) => a.toMap()).toList(),
        'stays': createdStays.map((s) => s.toMap()).toList(),
        'flights': createdFlights.map((f) => f.toMap()).toList(),
      },
    };
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

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

  Map<String, dynamic> _error(String errorMsg) => {
        'isError': true,
        'content': [
          {'type': 'text', 'text': 'Error: $errorMsg'}
        ],
      };
}
