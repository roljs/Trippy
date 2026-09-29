import 'package:flutter/material.dart';
import '../../../core/utils/date_formatters.dart';
import '../../../models/models.dart';

class StayGradientPalette {
  final List<Color> gradient;
  final Color shadow;

  const StayGradientPalette({required this.gradient, required this.shadow});
}

const List<StayGradientPalette> stayPalettes = [
  // 0. Imperial Purple
  StayGradientPalette(
    gradient: [Color(0xFF5B21B6), Color(0xFF7C3AED)],
    shadow: Color(0xFF7C3AED),
  ),
  // 1. Emerald Teal
  StayGradientPalette(
    gradient: [Color(0xFF065F46), Color(0xFF059669)],
    shadow: Color(0xFF059669),
  ),
  // 2. Ocean Cyan
  StayGradientPalette(
    gradient: [Color(0xFF0F766E), Color(0xFF0D9488)],
    shadow: Color(0xFF0D9488),
  ),
  // 3. Sunset Rose
  StayGradientPalette(
    gradient: [Color(0xFF9F1239), Color(0xFFE11D48)],
    shadow: Color(0xFFE11D48),
  ),
  // 4. Amber Rust
  StayGradientPalette(
    gradient: [Color(0xFF9A3412), Color(0xFFEA580C)],
    shadow: Color(0xFFEA580C),
  ),
  // 5. Deep Cobalt Blue
  StayGradientPalette(
    gradient: [Color(0xFF1E40AF), Color(0xFF2563EB)],
    shadow: Color(0xFF2563EB),
  ),
];

const StayGradientPalette overnightFlightPalette = StayGradientPalette(
  gradient: [Color(0xFF0369A1), Color(0xFF0284C7)],
  shadow: Color(0xFF0284C7),
);

class StayHeaderBridgeWidget extends StatelessWidget {
  final Stay? stay;
  final String? cityName;
  final double width;
  final int spanDays;
  final int startNightNumber;
  final StayGradientPalette? palette;
  final VoidCallback? onTap;

  const StayHeaderBridgeWidget({
    super.key,
    required this.stay,
    this.cityName,
    this.width = 600.0,
    this.spanDays = 2,
    this.startNightNumber = 1,
    this.palette,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (stay == null) {
      // Empty bridge slot for days with no lodging
      final content = Container(
        height: 64,
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        decoration: BoxDecoration(
          color: onTap != null
              ? Colors.white.withValues(alpha: 0.8)
              : Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: onTap != null ? Colors.grey.shade400 : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bed_outlined, size: 16, color: Colors.grey.shade500),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'No lodging recorded for this night',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 6),
              Icon(Icons.add_circle_outline_rounded,
                  size: 15, color: Colors.blueGrey.shade600),
            ],
          ],
        ),
      );

      final emptyCityText = (cityName != null && cityName!.isNotEmpty) ? ' • $cityName' : '';
      return SizedBox(
        width: width,
        height: 90,
        child: Column(
          children: [
            SizedBox(
              width: width,
              height: 18,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade600.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.45),
                      width: 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.10),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    'Night $startNightNumber$emptyCityText',
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            if (onTap != null)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(12),
                  child: Tooltip(
                    message: 'Tap to add lodging for this night',
                    child: content,
                  ),
                ),
              )
            else
              content,
          ],
        ),
      );
    }

    final isOvernightFlight = stay!.type == StayType.overnightFlight;
    final activePalette = palette ??
        (isOvernightFlight ? overnightFlightPalette : stayPalettes[0]);
    final numNights = stay!.nights > 0 ? stay!.nights : spanDays;
    final stayCityText = (cityName != null && cityName!.isNotEmpty) ? ' • $cityName' : '';

    return SizedBox(
      width: width,
      height: 90,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Outside Top Night Labels (centered between dividers/edges)
          SizedBox(
            width: width,
            height: 18,
            child: Row(
              children: [
                for (int s = 0; s < numNights; s++)
                  Expanded(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: activePalette.gradient.first
                              .withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.45),
                            width: 0.8,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Text(
                          'Night ${startNightNumber + s}$stayCityText',
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 2),

          // 2. Main Horizontal Stay Rectangle
          SizedBox(
            width: width,
            height: 70,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: activePalette.gradient,
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: activePalette.shadow.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    children: [
                      // Subtle Multi-Night Segment Background & Dividers inside rectangle
                      if (numNights > 1) ...[
                        Row(
                          children: [
                            for (int s = 0; s < numNights; s++)
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: s % 2 == 1
                                        ? Colors.black.withValues(alpha: 0.06)
                                        : Colors.transparent,
                                  ),
                                ),
                              ),
                          ],
                        ),

                        // Discrete vertical dividers positioned at the center of each intermediate day
                        for (int k = 1; k < numNights; k++)
                          Positioned(
                            left: (k * (width / numNights)) - 4.0,
                            top: 8,
                            bottom: 8,
                            child: Center(
                              child: Container(
                                width: 1.5,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(1),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.15),
                                      blurRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],

                // 2. Primary Stay Header Content
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      // Left Icon Badge
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isOvernightFlight
                              ? Icons.flight_takeoff_rounded
                              : (stay!.type == StayType.rental
                                  ? Icons.holiday_village_rounded
                                  : (stay!.type == StayType.nightTrain
                                      ? Icons.train_rounded
                                      : Icons.hotel_rounded)),
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),

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
                                    stay!.name,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Type & Nights Compact Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    isOvernightFlight
                                        ? 'OVERNIGHT FLIGHT'
                                        : '${stay!.type.displayName.toUpperCase()} • ${stay!.nights}N',
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            // Subtitle Details
                            if (isOvernightFlight && stay!.overnightFlight != null)
                              Text(
                                '${stay!.overnightFlight!.departureAirport} → ${stay!.overnightFlight!.arrivalAirport} (${DateFormatters.time12.format(stay!.overnightFlight!.departureTime)} – ${DateFormatters.time12.format(stay!.overnightFlight!.arrivalTime)} next day)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.92),
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )
                            else
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    Text(
                                      '${stay!.nights} ${stay!.nights == 1 ? 'night' : 'nights'}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.white.withValues(alpha: 0.95),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (stay!.checkInTime != null) ...[
                                      Text(
                                        '  •  In: ${DateFormatters.formatTimeString(stay!.checkInTime!)}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.white.withValues(alpha: 0.9),
                                        ),
                                      ),
                                    ],
                                    if (stay!.checkOutTime != null) ...[
                                      Text(
                                        '  •  Out: ${DateFormatters.formatTimeString(stay!.checkOutTime!)}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.white.withValues(alpha: 0.9),
                                        ),
                                      ),
                                    ],
                                    if (stay!.confirmationCode != null &&
                                        stay!.confirmationCode!.isNotEmpty) ...[
                                      Text(
                                        '  •  Conf: ${stay!.confirmationCode}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontFamily: 'monospace',
                                          color: Colors.white.withValues(alpha: 0.95),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Right Arrow indicator
                      Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white.withValues(alpha: 0.7),
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ],
),
);
  }
}
