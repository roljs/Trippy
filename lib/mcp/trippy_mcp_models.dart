import 'dart:convert';

/// Represents a tool exposed by the Trippy MCP Server.
class McpTool {
  final String name;
  final String description;
  final Map<String, dynamic> inputSchema;

  const McpTool({
    required this.name,
    required this.description,
    required this.inputSchema,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'description': description,
        'inputSchema': inputSchema,
      };
}

/// JSON-RPC 2.0 Request
class JsonRpcRequest {
  final String jsonrpc;
  final dynamic id;
  final String method;
  final Map<String, dynamic>? params;

  JsonRpcRequest({
    this.jsonrpc = '2.0',
    required this.id,
    required this.method,
    this.params,
  });

  factory JsonRpcRequest.fromMap(Map<String, dynamic> map) {
    return JsonRpcRequest(
      jsonrpc: map['jsonrpc'] as String? ?? '2.0',
      id: map['id'],
      method: map['method'] as String? ?? '',
      params: map['params'] is Map ? Map<String, dynamic>.from(map['params']) : null,
    );
  }

  static JsonRpcRequest? tryParse(String line) {
    try {
      final decoded = jsonDecode(line);
      if (decoded is Map<String, dynamic>) {
        return JsonRpcRequest.fromMap(decoded);
      }
    } catch (_) {}
    return null;
  }
}

/// JSON-RPC 2.0 Response
class JsonRpcResponse {
  final String jsonrpc;
  final dynamic id;
  final dynamic result;
  final Map<String, dynamic>? error;

  JsonRpcResponse({
    this.jsonrpc = '2.0',
    required this.id,
    this.result,
    this.error,
  });

  factory JsonRpcResponse.success(dynamic id, dynamic result) =>
      JsonRpcResponse(id: id, result: result);

  factory JsonRpcResponse.error(dynamic id, int code, String message, [dynamic data]) =>
      JsonRpcResponse(
        id: id,
        error: {
          'code': code,
          'message': message,
          'data': ?data,
        },
      );

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'jsonrpc': jsonrpc,
      'id': id,
    };
    if (error != null) {
      map['error'] = error;
    } else {
      map['result'] = result;
    }
    return map;
  }

  String toJson() => jsonEncode(toMap());
}

/// Definitions of all Trippy MCP tools.
class TrippyMcpToolDefinitions {
  static final List<McpTool> tools = [
    // 1. Authentication
    const McpTool(
      name: 'trippy_authenticate',
      description:
          'Authenticate the Trippy MCP session to access Cloud Firestore trips. '
          'Requires either a Personal Access Token (PAT) (token/apiKey), '
          'a pre-configured server key, or a verified Google/Firebase Auth ID token (idToken). '
          'To log out or revert to the unauthenticated in-memory sample sandbox, '
          'pass userId: "sample_user" or call with empty arguments.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'token': {
            'type': 'string',
            'description': 'Personal Access Token (e.g. "trippy_pat_...") or verified Firebase ID token.',
          },
          'key': {
            'type': 'string',
            'description': 'Personal Access Token (e.g. "trippy_pat_...") or API key.',
          },
          'pat': {
            'type': 'string',
            'description': 'Personal Access Token (e.g. "trippy_pat_...").',
          },
          'apiKey': {
            'type': 'string',
            'description': 'Alias for token or Personal Access Token.',
          },
          'passcode': {
            'type': 'string',
            'description': 'Alias for apiKey / token.',
          },
          'email': {
            'type': 'string',
            'description': 'User email address to verify against the Personal Access Token.',
          },
          'idToken': {
            'type': 'string',
            'description': 'Verified Google or Firebase Auth Bearer ID token.',
          },
          'userId': {
            'type': 'string',
            'description': 'User UID, or "sample_user" to revert to unauthenticated mode.',
          },
        },
      },
    ),

    // 2. List Trips
    const McpTool(
      name: 'trippy_list_trips',
      description:
          'List all trips available to the authenticated user with summaries, '
          'destinations, dates, and member access.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'userId': {
            'type': 'string',
            'description': 'Optional user ID filter. Defaults to current authenticated user.',
          },
        },
      },
    ),

    // 3. Get Trip Details
    const McpTool(
      name: 'trippy_get_trip_details',
      description:
          'Get complete details for a specific trip, including all scheduled activities, '
          'lodgings/stays, flights, day-by-day locations, and metadata.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'tripId': {
            'type': 'string',
            'description': 'Unique identifier of the trip.',
          },
          'date': {
            'type': 'string',
            'description': 'Optional filter by date (YYYY-MM-DD).',
          },
        },
        'required': ['tripId'],
      },
    ),

    // 4. Create Trip
    const McpTool(
      name: 'trippy_create_trip',
      description: 'Create a new trip in Trippy.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'title': {'type': 'string', 'description': 'Title of the trip.'},
          'destination': {'type': 'string', 'description': 'Primary destination(s).'},
          'startDate': {'type': 'string', 'description': 'Start date (YYYY-MM-DD).'},
          'endDate': {'type': 'string', 'description': 'End date (YYYY-MM-DD).'},
          'coverImageUrl': {'type': 'string', 'description': 'Optional cover banner URL.'},
          'startLocation': {'type': 'string', 'description': 'Origin city/airport.'},
          'endLocation': {'type': 'string', 'description': 'Return city/airport.'},
          'notes': {'type': 'string', 'description': 'Optional overall trip notes or itinerary summary.'},
          'links': {
            'type': 'array',
            'description': 'Optional list of URLs, "Label|URL" strings, or {"label", "url"} objects.',
            'items': {'type': 'string'},
          },
          'attachments': {
            'type': 'array',
            'description': 'Optional list of document URLs or attachment strings.',
            'items': {'type': 'string'},
          },
        },
        'required': ['title', 'destination', 'startDate', 'endDate'],
      },
    ),

    // 5. Update Trip
    const McpTool(
      name: 'trippy_update_trip',
      description: 'Update metadata of an existing trip.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'tripId': {'type': 'string', 'description': 'Trip ID to update.'},
          'title': {'type': 'string', 'description': 'Updated title.'},
          'destination': {'type': 'string', 'description': 'Updated destination.'},
          'startDate': {'type': 'string', 'description': 'Updated start date (YYYY-MM-DD).'},
          'endDate': {'type': 'string', 'description': 'Updated end date (YYYY-MM-DD).'},
          'coverImageUrl': {'type': 'string', 'description': 'Updated cover banner URL.'},
          'startLocation': {'type': 'string', 'description': 'Updated start location.'},
          'endLocation': {'type': 'string', 'description': 'Updated end location.'},
          'notes': {'type': 'string', 'description': 'Updated trip notes.'},
          'links': {
            'type': 'array',
            'description': 'Replace all trip links.',
            'items': {'type': 'string'},
          },
          'addLinks': {
            'type': 'array',
            'description': 'Append links to existing trip links without replacing.',
            'items': {'type': 'string'},
          },
          'attachments': {
            'type': 'array',
            'description': 'Replace all trip attachments.',
            'items': {'type': 'string'},
          },
          'addAttachments': {
            'type': 'array',
            'description': 'Append attachments to existing trip attachments without replacing.',
            'items': {'type': 'string'},
          },
        },
        'required': ['tripId'],
      },
    ),

    // 6. Set Day Locations
    const McpTool(
      name: 'trippy_set_day_locations',
      description: 'Update the list of locations/cities planned for a specific day of the trip.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'tripId': {'type': 'string', 'description': 'Trip ID.'},
          'date': {'type': 'string', 'description': 'Date in YYYY-MM-DD format.'},
          'locations': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'List of locations (e.g. ["Tokyo", "Shibuya"]).',
          },
        },
        'required': ['tripId', 'date', 'locations'],
      },
    ),

    // 7. Create Activity
    const McpTool(
      name: 'trippy_create_activity',
      description:
          'Create a new scheduled activity in Trippy. Automatically stamps '
          'lastModifiedSource: "mcp" and current lastModifiedAt timestamp.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'tripId': {'type': 'string', 'description': 'Trip ID.'},
          'date': {'type': 'string', 'description': 'Date of the activity (YYYY-MM-DD).'},
          'startTime': {'type': 'string', 'description': 'Start time in HH:mm 24h format (e.g. 09:30).'},
          'endTime': {'type': 'string', 'description': 'Optional end time in HH:mm 24h format (e.g. 11:00).'},
          'title': {'type': 'string', 'description': 'Activity title.'},
          'category': {
            'type': 'string',
            'enum': ['attraction', 'dining', 'transport', 'entertainment', 'stay', 'custom'],
            'description': 'Category of activity.',
          },
          'location': {'type': 'string', 'description': 'Address or place name.'},
          'notes': {'type': 'string', 'description': 'Optional notes or tips.'},
          'cost': {'type': 'number', 'description': 'Optional estimated or actual cost.'},
          'bookingStatus': {
            'type': 'string',
            'enum': ['planned', 'booked', 'ticketed'],
            'description': 'Booking status (defaults to planned).',
          },
          'confirmationRef': {'type': 'string', 'description': 'Reservation confirmation code.'},
          'ticketUrl': {'type': 'string', 'description': 'Link to tickets or website.'},
          'mealType': {
            'type': 'string',
            'enum': ['breakfast', 'lunch', 'dinner'],
            'description': 'Meal type for dining category.',
          },
          'stayId': {'type': 'string', 'description': 'Optional linked stay ID.'},
          'flightId': {'type': 'string', 'description': 'Optional linked flight ID.'},
          'links': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'List of reference URLs or "Label|URL" strings (e.g. ["Official Guide|https://..."]). Accepts ALL web URLs unconditionally (including Expedia, Booking, Airbnb, airline reservations, or session-protected links). Trippy stores URLs directly as bookmarks without fetching or validating them.',
          },
          'attachments': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'List of attachment URLs or "Label|URL" strings.',
          },
        },
        'required': ['tripId', 'date', 'startTime', 'title'],
      },
    ),

    // 8. Update Activity
    const McpTool(
      name: 'trippy_update_activity',
      description:
          'Update an existing activity in Trippy. Automatically stamps '
          'lastModifiedSource: "mcp" and current lastModifiedAt timestamp.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'tripId': {'type': 'string', 'description': 'Trip ID.'},
          'activityId': {'type': 'string', 'description': 'Activity ID.'},
          'date': {'type': 'string', 'description': 'Updated date (YYYY-MM-DD).'},
          'startTime': {'type': 'string', 'description': 'Updated start time (HH:mm).'},
          'endTime': {'type': 'string', 'description': 'Updated end time (HH:mm).'},
          'title': {'type': 'string', 'description': 'Updated title.'},
          'category': {'type': 'string', 'description': 'Updated category.'},
          'location': {'type': 'string', 'description': 'Updated location.'},
          'notes': {'type': 'string', 'description': 'Updated notes.'},
          'cost': {'type': 'number', 'description': 'Updated cost.'},
          'bookingStatus': {'type': 'string', 'description': 'Updated booking status.'},
          'confirmationRef': {'type': 'string', 'description': 'Updated confirmation ref.'},
          'ticketUrl': {'type': 'string', 'description': 'Updated ticket, reservation, or official website URL. Pass raw URL directly without pre-fetching.'},
          'links': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'Replace all links with this list of URLs or "Label|URL" strings (e.g. ["Official Website|https://..."]). Accepts ALL web URLs unconditionally. Do NOT pre-fetch or validate URLs with web browsing tools (which trigger bot PERMISSION_DENIED). Pass raw URL strings directly.',
          },
          'addLinks': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'Append new links to the existing links array without overwriting existing links. Accepts ALL web URLs unconditionally. Do NOT pre-fetch or crawl URLs.',
          },
          'attachments': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'Replace all attachments with this list of URLs or "Label|URL" strings.',
          },
          'addAttachments': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'Append new attachments to existing attachments array.',
          },
          'mealType': {'type': 'string', 'description': 'Updated meal type.'},
          'isCompleted': {'type': 'boolean', 'description': 'Whether the activity was completed.'},
        },
        'required': ['tripId', 'activityId'],
      },
    ),

    // 9. Delete Activity
    const McpTool(
      name: 'trippy_delete_activity',
      description: 'Delete an activity from a trip.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'tripId': {'type': 'string', 'description': 'Trip ID.'},
          'activityId': {'type': 'string', 'description': 'Activity ID to delete.'},
        },
        'required': ['tripId', 'activityId'],
      },
    ),

    // 10. Create Stay
    const McpTool(
      name: 'trippy_create_stay',
      description:
          'Create a stay/lodging (hotel, rental, overnight flight) in Trippy. '
          'Automatically stamps lastModifiedSource: "mcp".',
      inputSchema: {
        'type': 'object',
        'properties': {
          'tripId': {'type': 'string', 'description': 'Trip ID.'},
          'type': {
            'type': 'string',
            'enum': ['hotel', 'rental', 'overnightFlight', 'nightTrain'],
            'description': 'Stay type.',
          },
          'name': {'type': 'string', 'description': 'Hotel or lodging name.'},
          'address': {'type': 'string', 'description': 'Street address.'},
          'checkInDate': {'type': 'string', 'description': 'Check-in date (YYYY-MM-DD).'},
          'checkInTime': {'type': 'string', 'description': 'Check-in time (HH:mm). Defaults to 15:00.'},
          'checkOutDate': {'type': 'string', 'description': 'Check-out date (YYYY-MM-DD).'},
          'checkOutTime': {'type': 'string', 'description': 'Check-out time (HH:mm). Defaults to 11:00.'},
          'confirmationCode': {'type': 'string', 'description': 'Reservation confirmation code.'},
          'notes': {'type': 'string', 'description': 'Notes or booking details.'},
          'links': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'List of booking, hotel, or guide URLs or "Label|URL" strings (e.g. ["Hotel Website|https://..."]). Accepts ALL web URLs unconditionally (including Expedia, Booking, Airbnb, private reservation links, session-protected URLs). The server stores URLs directly as bookmarks without crawling or validating external site accessibility.',
          },
          'attachments': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'List of attachment URLs or "Label|URL" strings.',
          },
        },
        'required': ['tripId', 'name', 'checkInDate', 'checkOutDate'],
      },
    ),

    // 11. Update Stay
    const McpTool(
      name: 'trippy_update_stay',
      description:
          'Update an existing stay in Trippy. Automatically stamps '
          'lastModifiedSource: "mcp".',
      inputSchema: {
        'type': 'object',
        'properties': {
          'tripId': {'type': 'string', 'description': 'Trip ID.'},
          'stayId': {'type': 'string', 'description': 'Stay ID.'},
          'name': {'type': 'string', 'description': 'Updated name.'},
          'type': {'type': 'string', 'description': 'Updated type.'},
          'address': {'type': 'string', 'description': 'Updated address.'},
          'checkInDate': {'type': 'string', 'description': 'Updated check-in date.'},
          'checkInTime': {'type': 'string', 'description': 'Updated check-in time.'},
          'checkOutDate': {'type': 'string', 'description': 'Updated check-out date.'},
          'checkOutTime': {'type': 'string', 'description': 'Updated check-out time.'},
          'confirmationCode': {'type': 'string', 'description': 'Updated confirmation code.'},
          'notes': {'type': 'string', 'description': 'Updated notes.'},
          'links': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'Replace all links with this list of URLs or "Label|URL" strings (e.g. ["Booking.com Reservation|https://..."]). Accepts ANY web URL unconditionally. Do NOT pre-fetch or validate URLs with web browsing tools (which trigger bot PERMISSION_DENIED). Pass raw URL strings directly.',
          },
          'addLinks': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'Append new links to existing links array without overwriting existing links. Accepts ANY web URL unconditionally. Do NOT pre-fetch or crawl URLs.',
          },
          'attachments': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'Replace all attachments with this list of URLs or "Label|URL" strings.',
          },
          'addAttachments': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'Append new attachments to existing attachments array.',
          },
        },
        'required': ['tripId', 'stayId'],
      },
    ),

    // 12. Delete Stay
    const McpTool(
      name: 'trippy_delete_stay',
      description: 'Delete a stay from a trip.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'tripId': {'type': 'string', 'description': 'Trip ID.'},
          'stayId': {'type': 'string', 'description': 'Stay ID to delete.'},
        },
        'required': ['tripId', 'stayId'],
      },
    ),

    // 13. Create Flight
    const McpTool(
      name: 'trippy_create_flight',
      description:
          'Create a flight booking in Trippy. Automatically stamps '
          'lastModifiedSource: "mcp".',
      inputSchema: {
        'type': 'object',
        'properties': {
          'tripId': {'type': 'string', 'description': 'Trip ID.'},
          'airline': {'type': 'string', 'description': 'Airline name (e.g. United Airlines).'},
          'flightNumber': {'type': 'string', 'description': 'Flight number (e.g. UA875).'},
          'departureAirport': {'type': 'string', 'description': 'Departure airport code/name (e.g. SFO).'},
          'arrivalAirport': {'type': 'string', 'description': 'Arrival airport code/name (e.g. HND).'},
          'departureTime': {'type': 'string', 'description': 'Departure ISO-8601 datetime.'},
          'arrivalTime': {'type': 'string', 'description': 'Arrival ISO-8601 datetime.'},
          'terminal': {'type': 'string', 'description': 'Terminal.'},
          'gate': {'type': 'string', 'description': 'Gate.'},
          'seat': {'type': 'string', 'description': 'Seat.'},
          'bookingRef': {'type': 'string', 'description': 'Booking reference / PNR.'},
          'isOvernight': {'type': 'boolean', 'description': 'Whether flight spans overnight.'},
          'isNightStay': {'type': 'boolean', 'description': 'Whether flight counts as night accommodation.'},
          'notes': {'type': 'string', 'description': 'Flight notes.'},
          'links': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'List of flight/airline URLs or "Label|URL" strings.',
          },
          'attachments': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'List of attachment URLs or "Label|URL" strings.',
          },
        },
        'required': [
          'tripId',
          'airline',
          'flightNumber',
          'departureAirport',
          'arrivalAirport',
          'departureTime',
          'arrivalTime',
        ],
      },
    ),

    // 14. Update Flight
    const McpTool(
      name: 'trippy_update_flight',
      description:
          'Update an existing flight in Trippy. Automatically stamps '
          'lastModifiedSource: "mcp".',
      inputSchema: {
        'type': 'object',
        'properties': {
          'tripId': {'type': 'string', 'description': 'Trip ID.'},
          'flightId': {'type': 'string', 'description': 'Flight ID.'},
          'airline': {'type': 'string', 'description': 'Updated airline.'},
          'flightNumber': {'type': 'string', 'description': 'Updated flight number.'},
          'departureAirport': {'type': 'string', 'description': 'Updated departure airport.'},
          'arrivalAirport': {'type': 'string', 'description': 'Updated arrival airport.'},
          'departureTime': {'type': 'string', 'description': 'Updated departure time.'},
          'arrivalTime': {'type': 'string', 'description': 'Updated arrival time.'},
          'terminal': {'type': 'string', 'description': 'Updated terminal.'},
          'gate': {'type': 'string', 'description': 'Updated gate.'},
          'seat': {'type': 'string', 'description': 'Updated seat.'},
          'bookingRef': {'type': 'string', 'description': 'Updated booking ref.'},
          'notes': {'type': 'string', 'description': 'Updated notes.'},
          'links': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'Replace all links with this list of URLs or "Label|URL" strings. Accepts ANY web URL unconditionally (including airline confirmation or boarding pass links).',
          },
          'addLinks': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'Append new links to existing links array without overwriting existing links. Accepts ANY web URL unconditionally.',
          },
          'attachments': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'Replace all attachments with this list of URLs or "Label|URL" strings.',
          },
          'addAttachments': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'Append new attachments to existing attachments array.',
          },
        },
        'required': ['tripId', 'flightId'],
      },
    ),

    // 15. Delete Flight
    const McpTool(
      name: 'trippy_delete_flight',
      description: 'Delete a flight from a trip.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'tripId': {'type': 'string', 'description': 'Trip ID.'},
          'flightId': {'type': 'string', 'description': 'Flight ID to delete.'},
        },
        'required': ['tripId', 'flightId'],
      },
    ),

    // 16. PRIMARY USE CASE: Apply Proposed Daily Itinerary
    const McpTool(
      name: 'trippy_apply_suggested_itinerary',
      description:
          'Directly translates and saves an approved AI-proposed daily itinerary into Trippy. '
          'Smart deduplication: If activities, stays, or flights already exist representing the planned items, '
          'they are automatically updated in-place (preserving existing IDs, ticket links, and attachments) '
          'instead of creating duplicates. New activities are seamlessly appended. '
          'All created and modified objects are automatically stamped with '
          'lastModifiedSource: "mcp" and current lastModifiedAt timestamp.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'tripId': {
            'type': 'string',
            'description': 'Unique identifier of the trip.',
          },
          'date': {
            'type': 'string',
            'description': 'Target date for daily itinerary (YYYY-MM-DD).',
          },
          'locations': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'Optional list of cities/neighborhoods for this day (e.g. ["Tokyo", "Asakusa"]).',
          },
          'clearExistingActivities': {
            'type': 'boolean',
            'description': 'If true, clears existing activities scheduled on this day before adding new ones.',
          },
          'activities': {
            'type': 'array',
            'description': 'List of proposed activities to add for the day.',
            'items': {
              'type': 'object',
              'properties': {
                'title': {'type': 'string', 'description': 'Activity title.'},
                'startTime': {'type': 'string', 'description': 'Start time in HH:mm 24h format (e.g. 09:30).'},
                'endTime': {'type': 'string', 'description': 'Optional end time in HH:mm 24h format (e.g. 11:00).'},
                'category': {
                  'type': 'string',
                  'enum': ['attraction', 'dining', 'transport', 'entertainment', 'stay', 'custom'],
                  'description': 'Category of activity.',
                },
                'location': {'type': 'string', 'description': 'Location name or address.'},
                'notes': {'type': 'string', 'description': 'Notes, descriptions, or visitor tips.'},
                'cost': {'type': 'number', 'description': 'Estimated cost in local currency.'},
                'mealType': {
                  'type': 'string',
                  'enum': ['breakfast', 'lunch', 'dinner'],
                  'description': 'Meal type for dining category.',
                },
                'bookingStatus': {
                  'type': 'string',
                  'enum': ['planned', 'booked', 'ticketed'],
                  'description': 'Booking status (defaults to planned).',
                },
                'confirmationRef': {'type': 'string', 'description': 'Confirmation / reservation code.'},
                'ticketUrl': {'type': 'string', 'description': 'Link to tickets or official website.'},
                'links': {
                  'type': 'array',
                  'items': {'type': 'string'},
                  'description': 'List of reference URLs or "Label|URL" strings or {"label", "url"} objects.',
                },
                'attachments': {
                  'type': 'array',
                  'items': {'type': 'string'},
                  'description': 'List of attachment URLs or "Label|URL" strings.',
                },
              },
              'required': ['title', 'startTime'],
            },
          },
          'stays': {
            'type': 'array',
            'description': 'Optional stays/lodgings to add or update.',
            'items': {
              'type': 'object',
              'properties': {
                'name': {'type': 'string'},
                'type': {'type': 'string', 'enum': ['hotel', 'rental', 'overnightFlight', 'nightTrain']},
                'address': {'type': 'string'},
                'checkInDate': {'type': 'string'},
                'checkInTime': {'type': 'string'},
                'checkOutDate': {'type': 'string'},
                'checkOutTime': {'type': 'string'},
                'confirmationCode': {'type': 'string'},
                'notes': {'type': 'string'},
                'links': {
                  'type': 'array',
                  'items': {'type': 'string'},
                  'description': 'List of lodging URLs or "Label|URL" strings (e.g. ["Hotel Website|https://..."]).',
                },
                'attachments': {
                  'type': 'array',
                  'items': {'type': 'string'},
                  'description': 'List of attachment URLs or "Label|URL" strings.',
                },
              },
              'required': ['name', 'checkInDate', 'checkOutDate'],
            },
          },
          'flights': {
            'type': 'array',
            'description': 'Optional flights to add or update.',
            'items': {
              'type': 'object',
              'properties': {
                'airline': {'type': 'string'},
                'flightNumber': {'type': 'string'},
                'departureAirport': {'type': 'string'},
                'arrivalAirport': {'type': 'string'},
                'departureTime': {'type': 'string'},
                'arrivalTime': {'type': 'string'},
                'terminal': {'type': 'string'},
                'gate': {'type': 'string'},
                'seat': {'type': 'string'},
                'bookingRef': {'type': 'string'},
                'notes': {'type': 'string'},
                'links': {
                  'type': 'array',
                  'items': {'type': 'string'},
                  'description': 'List of flight URLs or "Label|URL" strings.',
                },
                'attachments': {
                  'type': 'array',
                  'items': {'type': 'string'},
                  'description': 'List of attachment URLs or "Label|URL" strings.',
                },
              },
              'required': ['airline', 'flightNumber', 'departureAirport', 'arrivalAirport', 'departureTime', 'arrivalTime'],
            },
          },
        },
        'required': ['tripId', 'date', 'activities'],
      },
    ),

    // 17. Add Link or Attachment
    const McpTool(
      name: 'trippy_add_link',
      description:
          'Add a reference link or attachment URL to any existing Stay, Activity, Flight, or Trip. '
          'Accepts ANY valid web URL format unconditionally (including Booking.com, Expedia, Airbnb, '
          'airline bookings, or private reservation confirmation URLs). '
          'CRITICAL FOR AI ASSISTANTS: Do NOT use web search or internal browser tools to fetch, crawl, '
          'or test this URL before calling this tool. Commercial booking portals block automated AI scrapers '
          'with "PERMISSION_DENIED: This website is inaccessible". The Trippy server stores URLs purely as '
          'database bookmarks and performs ZERO network reachability checks. Call this tool immediately '
          'with the raw URL string.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'tripId': {
            'type': 'string',
            'description': 'Trip ID. If omitted, uses active/current trip.',
          },
          'targetType': {
            'type': 'string',
            'enum': ['stay', 'activity', 'flight'],
            'description': 'Type of entity to attach the link to ("stay", "activity", or "flight").',
          },
          'targetId': {
            'type': 'string',
            'description': 'ID of the stay, activity, or flight. If omitted, targetName can be used.',
          },
          'targetName': {
            'type': 'string',
            'description': 'Name or title of the hotel/stay, activity, or airline to find and attach to.',
          },
          'url': {
            'type': 'string',
            'description':
                'The exact URL to store (e.g. "https://secure.booking.com/..."). '
                'Pass the raw URL directly without pre-fetching or validating via web search.',
          },
          'label': {
            'type': 'string',
            'description': 'Optional human-readable label (e.g. "Expedia Itinerary", "Hotel Reservation").',
          },
          'isAttachment': {
            'type': 'boolean',
            'description': 'True if this should be added to attachments instead of links. Defaults to false.',
          },
        },
        'required': ['targetType', 'url'],
      },
    ),

    // 18. Generate Personal Access Token
    const McpTool(
      name: 'trippy_generate_pat',
      description:
          'Generate a new Personal Access Token (PAT) for the current user. '
          'The token is cryptographically bound to your specific account UID/email and prevents any impersonation. '
          'Use this token in Grok Bot, Gemini, ChatGPT Actions, or IDEs (e.g. ?key=trippy_pat_...).',
      inputSchema: {
        'type': 'object',
        'properties': {
          'name': {
            'type': 'string',
            'description': 'Friendly label for the token (e.g. "Grok Bot", "Cursor IDE", "Phone Assistant").',
          },
        },
      },
    ),

    // 19. Revoke Personal Access Token
    const McpTool(
      name: 'trippy_revoke_pat',
      description:
          'Revoke an existing Personal Access Token (PAT) so it can no longer be used.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'token': {
            'type': 'string',
            'description': 'The token string (e.g. "trippy_pat_...") to revoke.',
          },
        },
        'required': ['token'],
      },
    ),
  ];
}
