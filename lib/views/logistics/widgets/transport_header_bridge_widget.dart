import 'package:flutter/material.dart';
import '../../../core/utils/date_formatters.dart';
import '../../../models/models.dart';

enum TransportHeaderMode {
  arrival,
  departure;

  bool get isArrival => this == TransportHeaderMode.arrival;
}

enum TransportType {
  flight,
  train,
  car,
  bus,
  ferry,
  other;

  IconData get icon {
    switch (this) {
      case TransportType.flight:
        return Icons.flight_takeoff_rounded;
      case TransportType.train:
        return Icons.train_rounded;
      case TransportType.car:
        return Icons.directions_car_rounded;
      case TransportType.bus:
        return Icons.directions_bus_rounded;
      case TransportType.ferry:
        return Icons.directions_boat_rounded;
      case TransportType.other:
        return Icons.commute_rounded;
    }
  }

  String get displayName {
    switch (this) {
      case TransportType.flight:
        return 'Flight';
      case TransportType.train:
        return 'Train';
      case TransportType.car:
        return 'Car / Drive';
      case TransportType.bus:
        return 'Bus';
      case TransportType.ferry:
        return 'Ferry';
      case TransportType.other:
        return 'Transport';
    }
  }
}

class TransportHeaderData {
  final String title;
  final String? subtitle;
  final TransportType transportType;
  final String? confirmationRef;
  final DateTime? time;
  final Flight? flight;
  final Activity? activity;

  const TransportHeaderData({
    required this.title,
    this.subtitle,
    this.transportType = TransportType.flight,
    this.confirmationRef,
    this.time,
    this.flight,
    this.activity,
  });

  factory TransportHeaderData.fromFlight(Flight flight, TransportHeaderMode mode) {
    final isArrival = mode.isArrival;
    final timeStr = DateFormatters.time12.format(
        isArrival ? flight.arrivalTime : flight.departureTime);
    final route = '${flight.departureAirport} → ${flight.arrivalAirport}';

    return TransportHeaderData(
      title: '${flight.airline} ${flight.flightNumber}'.trim(),
      subtitle: '$route • ${isArrival ? "Arr" : "Dep"}: $timeStr',
      transportType: TransportType.flight,
      confirmationRef: flight.bookingRef,
      time: isArrival ? flight.arrivalTime : flight.departureTime,
      flight: flight,
    );
  }

  factory TransportHeaderData.fromActivity(Activity activity, TransportHeaderMode mode) {
    final isArrival = mode.isArrival;
    TransportType type = TransportType.other;
    final titleLower = activity.title.toLowerCase();
    if (titleLower.contains('flight')) {
      type = TransportType.flight;
    } else if (titleLower.contains('train') || titleLower.contains('rail') || titleLower.contains('express') || titleLower.contains('frecciarossa') || titleLower.contains('shinkansen')) {
      type = TransportType.train;
    } else if (titleLower.contains('drive') || titleLower.contains('car') || titleLower.contains('taxi') || titleLower.contains('uber')) {
      type = TransportType.car;
    } else if (titleLower.contains('bus')) {
      type = TransportType.bus;
    } else if (titleLower.contains('boat') || titleLower.contains('ferry')) {
      type = TransportType.ferry;
    }

    final timeStr = activity.startTime;
    final loc = activity.location ?? '';

    return TransportHeaderData(
      title: activity.title,
      subtitle: loc.isNotEmpty
          ? '$loc • ${isArrival ? "Arr" : "Dep"}: $timeStr'
          : '${isArrival ? "Arr" : "Dep"}: $timeStr',
      transportType: type,
      confirmationRef: activity.confirmationRef,
      activity: activity,
    );
  }

  factory TransportHeaderData.placeholder({
    required TransportHeaderMode mode,
    required String destination,
    TransportType type = TransportType.flight,
  }) {
    if (mode.isArrival) {
      return TransportHeaderData(
        title: type == TransportType.flight
            ? 'Arrival Flight to $destination'
            : 'Arrival: ${type.displayName} to $destination',
        subtitle: 'Tap to add booking details',
        transportType: type,
      );
    } else {
      return TransportHeaderData(
        title: type == TransportType.flight
            ? 'Return Flight from $destination'
            : 'Departure: ${type.displayName} from $destination',
        subtitle: 'Tap to add booking details',
        transportType: type,
      );
    }
  }
}

class TransportHeaderBridgeWidget extends StatelessWidget {
  final TransportHeaderMode mode;
  final TransportHeaderData data;
  final double width;
  final VoidCallback? onTap;

  const TransportHeaderBridgeWidget({
    super.key,
    required this.mode,
    required this.data,
    this.width = 290.0,
    this.onTap,
  });

  List<Color> get _gradientColors {
    if (mode.isArrival) {
      // Deep Sky Blue to Ocean Cyan for Arrival
      switch (data.transportType) {
        case TransportType.flight:
          return const [Color(0xFF0369A1), Color(0xFF0284C7)];
        case TransportType.train:
          return const [Color(0xFF065F46), Color(0xFF0D9488)];
        case TransportType.car:
          return const [Color(0xFF4338CA), Color(0xFF6366F1)];
        case TransportType.bus:
        case TransportType.ferry:
        case TransportType.other:
          return const [Color(0xFF0F766E), Color(0xFF14B8A6)];
      }
    } else {
      // Sunset Rose to Warm Amber/Coral for Departure
      switch (data.transportType) {
        case TransportType.flight:
          return const [Color(0xFFBE123C), Color(0xFFF43F5E)];
        case TransportType.train:
          return const [Color(0xFF831843), Color(0xFFBE185D)];
        case TransportType.car:
          return const [Color(0xFF9A3412), Color(0xFFEA580C)];
        case TransportType.bus:
        case TransportType.ferry:
        case TransportType.other:
          return const [Color(0xFF7C2D12), Color(0xFFD97706)];
      }
    }
  }

  Color get _shadowColor => _gradientColors.last;

  @override
  Widget build(BuildContext context) {
    final colors = _gradientColors;
    final isArrival = mode.isArrival;

    return SizedBox(
      width: width,
      height: 90,
      child: Column(
        children: [
          const SizedBox(height: 20),
          SizedBox(
            width: width,
            height: 70,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: colors,
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: _shadowColor.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Mode & Type Icon Badge
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        data.transportType.icon,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Title and Details
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  data.title,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              // Badge Tag
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isArrival ? 'ARRIVAL' : 'DEPARTURE',
                                  style: const TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.6,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  data.subtitle ??
                                      (isArrival
                                          ? 'Method of Arrival'
                                          : 'Method of Departure'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white.withValues(alpha: 0.92),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (data.confirmationRef != null &&
                                  data.confirmationRef!.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Text(
                                  '#${data.confirmationRef}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
