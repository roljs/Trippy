enum ActivityCategory {
  attraction,
  dining,
  transport,
  entertainment,
  flight,
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
      case ActivityCategory.flight:
        return 'Flight';
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
      case 'transport':
        return ActivityCategory.transport;
      case 'entertainment':
        return ActivityCategory.entertainment;
      case 'flight':
        return ActivityCategory.flight;
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
  });

  /// Combines date and startTime for accurate chronological sorting
  DateTime get startDateTime {
    final parts = startTime.split(':');
    final hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return DateTime(date.year, date.month, date.day, hour, minute);
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
    );
  }
}
