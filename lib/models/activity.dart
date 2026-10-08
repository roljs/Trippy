enum ActivityCategory {
  attraction,
  dining,
  transport,
  entertainment,
  stay,
  custom;

  String get displayName {
    switch (this) {
      case ActivityCategory.attraction:
        return 'Attraction';
      case ActivityCategory.dining:
        return 'Food & Dining';
      case ActivityCategory.transport:
        return 'Transport';
      case ActivityCategory.entertainment:
        return 'Entertainment';
      case ActivityCategory.stay:
        return 'Hotel & Stay';
      case ActivityCategory.custom:
        return 'Other';
    }
  }

  static ActivityCategory fromString(String? cat) {
    switch (cat?.toLowerCase()) {
      case 'dining':
        return ActivityCategory.dining;
      case 'flight':
      case 'transport':
        return ActivityCategory.transport;
      case 'entertainment':
        return ActivityCategory.entertainment;
      case 'stay':
      case 'hotel':
      case 'lodging':
        return ActivityCategory.stay;
      case 'custom':
        return ActivityCategory.custom;
      case 'attraction':
      default:
        return ActivityCategory.attraction;
    }
  }

  String toJson() => name;
}

enum BookingStatus {
  planned,
  booked,
  ticketed;

  String get displayName {
    switch (this) {
      case BookingStatus.planned:
        return 'Planned';
      case BookingStatus.booked:
        return 'Booked';
      case BookingStatus.ticketed:
        return 'Ticketed';
    }
  }

  static BookingStatus fromString(String? status) {
    switch (status?.toLowerCase()) {
      case 'booked':
        return BookingStatus.booked;
      case 'ticketed':
        return BookingStatus.ticketed;
      case 'planned':
      default:
        return BookingStatus.planned;
    }
  }

  String toJson() => name;
}

class Activity {
  final String id;
  final String tripId;
  final DateTime date;
  final String startTime; // "HH:mm" (24-hour format)
  final String? endTime; // "HH:mm"
  final String title;
  final ActivityCategory category;
  final String? location;
  final BookingStatus bookingStatus;
  final String? confirmationRef;
  final String? ticketUrl;
  final String? notes;
  final double? cost;
  final bool isCompleted;
  final String? stayId; // Optional link to a Stay
  final String? flightId; // Optional link to a Flight
  final String? mealType; // Optional tag: 'breakfast', 'lunch', 'dinner'
  final String? fromLocation; // For transport: departure place/address
  final String? toLocation; // For transport: destination place/address
  final String? transportDirection; // 'to_airport' or 'from_airport'
  final String? fromStayId; // If from is a linked stay
  final String? toStayId; // If to is a linked stay

  const Activity({
    required this.id,
    required this.tripId,
    required this.date,
    required this.startTime,
    this.endTime,
    required this.title,
    this.category = ActivityCategory.attraction,
    this.location,
    this.bookingStatus = BookingStatus.planned,
    this.confirmationRef,
    this.ticketUrl,
    this.notes,
    this.cost,
    this.isCompleted = false,
    this.stayId,
    this.flightId,
    this.mealType,
    this.fromLocation,
    this.toLocation,
    this.transportDirection,
    this.fromStayId,
    this.toStayId,
  });

  /// Combines date and startTime for accurate chronological sorting
  DateTime get startDateTime {
    final parts = startTime.split(':');
    final hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  /// True if this transport activity is directed to the airport
  bool get isToAirport =>
      transportDirection == 'to_airport' ||
      (transportDirection == null &&
          flightId != null &&
          (id.contains('dep_xfer') ||
              title.toLowerCase().contains('to airport') ||
              (notes?.toLowerCase().contains('to airport') ?? false)));

  /// True if this transport activity is directed from the airport
  bool get isFromAirport =>
      transportDirection == 'from_airport' ||
      (transportDirection == null &&
          flightId != null &&
          (id.contains('arr_xfer') ||
              title.toLowerCase().contains('from airport') ||
              (notes?.toLowerCase().contains('from airport') ?? false)));

  /// Effective from location with fallback if stored in location
  String? get effectiveFromLocation {
    if (fromLocation != null && fromLocation!.isNotEmpty) return fromLocation;
    if (category == ActivityCategory.transport && location != null && location!.contains(' → ')) {
      return location!.split(' → ').first.trim();
    }
    return fromLocation;
  }

  /// Effective to location with fallback if stored in location
  String? get effectiveToLocation {
    if (toLocation != null && toLocation!.isNotEmpty) return toLocation;
    if (category == ActivityCategory.transport && location != null && location!.contains(' → ')) {
      return location!.split(' → ').last.trim();
    }
    return toLocation;
  }

  Activity copyWith({
    String? id,
    String? tripId,
    DateTime? date,
    String? startTime,
    String? endTime,
    String? title,
    ActivityCategory? category,
    String? location,
    BookingStatus? bookingStatus,
    String? confirmationRef,
    String? ticketUrl,
    String? notes,
    double? cost,
    bool? isCompleted,
    String? stayId,
    String? flightId,
    String? mealType,
    String? fromLocation,
    String? toLocation,
    String? transportDirection,
    String? fromStayId,
    String? toStayId,
  }) {
    return Activity(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      title: title ?? this.title,
      category: category ?? this.category,
      location: location ?? this.location,
      bookingStatus: bookingStatus ?? this.bookingStatus,
      confirmationRef: confirmationRef ?? this.confirmationRef,
      ticketUrl: ticketUrl ?? this.ticketUrl,
      notes: notes ?? this.notes,
      cost: cost ?? this.cost,
      isCompleted: isCompleted ?? this.isCompleted,
      stayId: stayId ?? this.stayId,
      flightId: flightId ?? this.flightId,
      mealType: mealType ?? this.mealType,
      fromLocation: fromLocation ?? this.fromLocation,
      toLocation: toLocation ?? this.toLocation,
      transportDirection: transportDirection ?? this.transportDirection,
      fromStayId: fromStayId ?? this.fromStayId,
      toStayId: toStayId ?? this.toStayId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tripId': tripId,
      'date': date.toIso8601String(),
      'startTime': startTime,
      'endTime': endTime,
      'title': title,
      'category': category.toJson(),
      'location': location,
      'bookingStatus': bookingStatus.toJson(),
      'confirmationRef': confirmationRef,
      'ticketUrl': ticketUrl,
      'notes': notes,
      'cost': cost,
      'isCompleted': isCompleted,
      if (stayId != null) 'stayId': stayId,
      if (flightId != null) 'flightId': flightId,
      if (mealType != null) 'mealType': mealType,
      if (fromLocation != null) 'fromLocation': fromLocation,
      if (toLocation != null) 'toLocation': toLocation,
      if (transportDirection != null) 'transportDirection': transportDirection,
      if (fromStayId != null) 'fromStayId': fromStayId,
      if (toStayId != null) 'toStayId': toStayId,
    };
  }

  factory Activity.fromMap(Map<String, dynamic> map) {
    return Activity(
      id: map['id'] as String? ?? '',
      tripId: map['tripId'] as String? ?? '',
      date: DateTime.parse(map['date'] as String),
      startTime: map['startTime'] as String? ?? '09:00',
      endTime: map['endTime'] as String?,
      title: map['title'] as String? ?? '',
      category: ActivityCategory.fromString(map['category'] as String?),
      location: map['location'] as String?,
      bookingStatus: BookingStatus.fromString(map['bookingStatus'] as String?),
      confirmationRef: map['confirmationRef'] as String?,
      ticketUrl: map['ticketUrl'] as String?,
      notes: map['notes'] as String?,
      cost: (map['cost'] as num?)?.toDouble(),
      isCompleted: map['isCompleted'] as bool? ?? false,
      stayId: map['stayId'] as String?,
      flightId: map['flightId'] as String?,
      mealType: map['mealType'] as String?,
      fromLocation: map['fromLocation'] as String?,
      toLocation: map['toLocation'] as String?,
      transportDirection: map['transportDirection'] as String?,
      fromStayId: map['fromStayId'] as String?,
      toStayId: map['toStayId'] as String?,
    );
  }
}

