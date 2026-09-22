import 'flight.dart';

enum StayType {
  hotel,
  rental,
  overnightFlight,
  nightTrain;

  String get displayName {
    switch (this) {
      case StayType.hotel:
        return 'Hotel';
      case StayType.rental:
        return 'Vacation Rental';
      case StayType.overnightFlight:
        return 'Overnight Flight';
      case StayType.nightTrain:
        return 'Night Train / Sleeper';
    }
  }

  static StayType fromString(String? type) {
    switch (type?.toLowerCase()) {
      case 'rental':
        return StayType.rental;
      case 'overnightflight':
      case 'overnight_flight':
        return StayType.overnightFlight;
      case 'nighttrain':
      case 'night_train':
        return StayType.nightTrain;
      case 'hotel':
      default:
        return StayType.hotel;
    }
  }

  String toJson() => name;
}

class Stay {
  final String id;
  final String tripId;
  final StayType type;
  final String name;
  final String? address;
  final DateTime checkInDate;
  final String? checkInTime; // e.g. "15:00"
  final DateTime checkOutDate;
  final String? checkOutTime; // e.g. "11:00"
  final String? confirmationCode;
  final String? notes;
  final Flight? overnightFlight;

  const Stay({
    required this.id,
    required this.tripId,
    required this.type,
    required this.name,
    this.address,
    required this.checkInDate,
    this.checkInTime,
    required this.checkOutDate,
    this.checkOutTime,
    this.confirmationCode,
    this.notes,
    this.overnightFlight,
  });

  /// Calculates number of nights of this stay
  int get nights {
    final diff = checkOutDate.difference(checkInDate).inDays;
    return diff > 0 ? diff : 1;
  }

  /// Checks if this stay covers the night transition between [day1] and [day2]
  bool coversTransition(DateTime day1, DateTime day2) {
    final d1 = DateTime(day1.year, day1.month, day1.day);
    final inD = DateTime(checkInDate.year, checkInDate.month, checkInDate.day);
    final outD = DateTime(checkOutDate.year, checkOutDate.month, checkOutDate.day);

    // Stay begins on or before day1, and check-out is on or after day2
    return !d1.isBefore(inD) && d1.isBefore(outD);
  }

  Stay copyWith({
    String? id,
    String? tripId,
    StayType? type,
    String? name,
    String? address,
    DateTime? checkInDate,
    String? checkInTime,
    DateTime? checkOutDate,
    String? checkOutTime,
    String? confirmationCode,
    String? notes,
    Flight? overnightFlight,
  }) {
    return Stay(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      type: type ?? this.type,
      name: name ?? this.name,
      address: address ?? this.address,
      checkInDate: checkInDate ?? this.checkInDate,
      checkInTime: checkInTime ?? this.checkInTime,
      checkOutDate: checkOutDate ?? this.checkOutDate,
      checkOutTime: checkOutTime ?? this.checkOutTime,
      confirmationCode: confirmationCode ?? this.confirmationCode,
      notes: notes ?? this.notes,
      overnightFlight: overnightFlight ?? this.overnightFlight,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tripId': tripId,
      'type': type.toJson(),
      'name': name,
      'address': address,
      'checkInDate': checkInDate.toIso8601String(),
      'checkInTime': checkInTime,
      'checkOutDate': checkOutDate.toIso8601String(),
      'checkOutTime': checkOutTime,
      'confirmationCode': confirmationCode,
      'notes': notes,
      'overnightFlight': overnightFlight?.toMap(),
    };
  }

  factory Stay.fromMap(Map<String, dynamic> map) {
    return Stay(
      id: map['id'] as String? ?? '',
      tripId: map['tripId'] as String? ?? '',
      type: StayType.fromString(map['type'] as String?),
      name: map['name'] as String? ?? '',
      address: map['address'] as String?,
      checkInDate: DateTime.parse(map['checkInDate'] as String),
      checkInTime: map['checkInTime'] as String?,
      checkOutDate: DateTime.parse(map['checkOutDate'] as String),
      checkOutTime: map['checkOutTime'] as String?,
      confirmationCode: map['confirmationCode'] as String?,
      notes: map['notes'] as String?,
      overnightFlight: map['overnightFlight'] != null
          ? Flight.fromMap(map['overnightFlight'] as Map<String, dynamic>)
          : null,
    );
  }
}
