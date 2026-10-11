import '../core/utils/airport_timezone_helper.dart';

class Flight {
  final String id;
  final String tripId;
  final String airline;
  final String flightNumber;
  final String departureAirport;
  final String arrivalAirport;
  final DateTime departureTime;
  final DateTime arrivalTime;
  final bool isOvernight;
  final bool isNightStay;
  final bool isMainArrival;
  final bool isMainDeparture;
  final String? terminal;
  final String? gate;
  final String? seat;
  final String? bookingRef;
  final String? notes;
  final List<String> links;
  final List<String> attachments;
  final List<String> linkedActivityIds;
  final DateTime? lastModifiedAt;
  final String? lastModifiedSource; // 'ui' or 'mcp'

  const Flight({
    required this.id,
    required this.tripId,
    required this.airline,
    required this.flightNumber,
    required this.departureAirport,
    required this.arrivalAirport,
    required this.departureTime,
    required this.arrivalTime,
    this.isOvernight = false,
    bool isNightStay = false,
    this.isMainArrival = false,
    this.isMainDeparture = false,
    this.terminal,
    this.gate,
    this.seat,
    this.bookingRef,
    this.notes,
    this.links = const [],
    this.attachments = const [],
    this.linkedActivityIds = const [],
    this.lastModifiedAt,
    this.lastModifiedSource,
  }) : isNightStay = (isMainArrival || isMainDeparture) ? false : isNightStay;

  bool get isModifiedByMcp => lastModifiedSource?.toLowerCase() == 'mcp';
  bool get isModifiedByUi => lastModifiedSource == null || lastModifiedSource?.toLowerCase() == 'ui';

  /// True if the flight spans into the next calendar day
  bool get spansAcrossDays {
    return isOvernight ||
        isNightStay ||
        arrivalTime.year != departureTime.year ||
        arrivalTime.month != departureTime.month ||
        arrivalTime.day != departureTime.day;
  }

  Duration get duration => AirportTimezoneHelper.calculateDuration(
        departureTime: departureTime,
        departureAirport: departureAirport,
        arrivalTime: arrivalTime,
        arrivalAirport: arrivalAirport,
      );

  Flight copyWith({
    String? id,
    String? tripId,
    String? airline,
    String? flightNumber,
    String? departureAirport,
    String? arrivalAirport,
    DateTime? departureTime,
    DateTime? arrivalTime,
    bool? isOvernight,
    bool? isNightStay,
    bool? isMainArrival,
    bool? isMainDeparture,
    String? terminal,
    String? gate,
    String? seat,
    String? bookingRef,
    String? notes,
    List<String>? links,
    List<String>? attachments,
    List<String>? linkedActivityIds,
    DateTime? lastModifiedAt,
    String? lastModifiedSource,
  }) {
    final bool explicitNightStay = isNightStay == true;
    final bool newArrival = explicitNightStay ? false : (isMainArrival ?? this.isMainArrival);
    final bool newDeparture = explicitNightStay ? false : (isMainDeparture ?? this.isMainDeparture);
    final bool newNightStay = (newArrival || newDeparture) ? false : (isNightStay ?? this.isNightStay);

    return Flight(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      airline: airline ?? this.airline,
      flightNumber: flightNumber ?? this.flightNumber,
      departureAirport: departureAirport ?? this.departureAirport,
      arrivalAirport: arrivalAirport ?? this.arrivalAirport,
      departureTime: departureTime ?? this.departureTime,
      arrivalTime: arrivalTime ?? this.arrivalTime,
      isOvernight: isOvernight ?? this.isOvernight,
      isNightStay: newNightStay,
      isMainArrival: newArrival,
      isMainDeparture: newDeparture,
      terminal: terminal ?? this.terminal,
      gate: gate ?? this.gate,
      seat: seat ?? this.seat,
      bookingRef: bookingRef ?? this.bookingRef,
      notes: notes ?? this.notes,
      links: links ?? this.links,
      attachments: attachments ?? this.attachments,
      linkedActivityIds: linkedActivityIds ?? this.linkedActivityIds,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      lastModifiedSource: lastModifiedSource ?? this.lastModifiedSource,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tripId': tripId,
      'airline': airline,
      'flightNumber': flightNumber,
      'departureAirport': departureAirport,
      'arrivalAirport': arrivalAirport,
      'departureTime': departureTime.toIso8601String(),
      'arrivalTime': arrivalTime.toIso8601String(),
      'isOvernight': isOvernight,
      'isNightStay': isNightStay,
      'isMainArrival': isMainArrival,
      'isMainDeparture': isMainDeparture,
      'terminal': terminal,
      'gate': gate,
      'seat': seat,
      'bookingRef': bookingRef,
      'notes': notes,
      'links': links,
      'attachments': attachments,
      'linkedActivityIds': linkedActivityIds,
      if (lastModifiedAt != null) 'lastModifiedAt': lastModifiedAt!.toIso8601String(),
      if (lastModifiedSource != null) 'lastModifiedSource': lastModifiedSource,
    };
  }

  factory Flight.fromMap(Map<String, dynamic> map) {
    return Flight(
      id: map['id'] as String? ?? '',
      tripId: map['tripId'] as String? ?? '',
      airline: map['airline'] as String? ?? '',
      flightNumber: map['flightNumber'] as String? ?? '',
      departureAirport: map['departureAirport'] as String? ?? '',
      arrivalAirport: map['arrivalAirport'] as String? ?? '',
      departureTime: DateTime.parse(map['departureTime'] as String),
      arrivalTime: DateTime.parse(map['arrivalTime'] as String),
      isOvernight: map['isOvernight'] as bool? ?? false,
      isNightStay: map['isNightStay'] as bool? ?? false,
      isMainArrival: map['isMainArrival'] as bool? ?? false,
      isMainDeparture: map['isMainDeparture'] as bool? ?? false,
      terminal: map['terminal'] as String?,
      gate: map['gate'] as String?,
      seat: map['seat'] as String?,
      bookingRef: map['bookingRef'] as String?,
      notes: map['notes'] as String?,
      links: (map['links'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      attachments: (map['attachments'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      linkedActivityIds: (map['linkedActivityIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      lastModifiedAt: map['lastModifiedAt'] != null
          ? DateTime.tryParse(map['lastModifiedAt'].toString())
          : null,
      lastModifiedSource: map['lastModifiedSource'] as String?,
    );
  }
}
