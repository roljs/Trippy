import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatters.dart';
import '../../../models/models.dart';

class FlightDayCardWidget extends StatelessWidget {
  final Flight flight;
  final VoidCallback? onTap;

  const FlightDayCardWidget({
    super.key,
    required this.flight,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final depTimeStr = DateFormatters.time12.format(flight.departureTime);
    final arrTimeStr = DateFormatters.time12.format(flight.arrivalTime);
    final flightTitle = '${flight.airline} ${flight.flightNumber}'.trim();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.flight.withValues(alpha: 0.35),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.flight.withValues(alpha: 0.06),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Flight Time Badge & Flight Pill
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: AppColors.flightContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.flight_takeoff_rounded,
                              size: 12,
                              color: AppColors.flight,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              depTimeStr,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.flight,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          flight.isOvernight
                              ? '– $arrTimeStr (+1d)'
                              : '– $arrTimeStr',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                // Booking status / FLIGHT badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'FLIGHT',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0369A1),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Flight Title: Airline & Number
            Text(
              flightTitle.isEmpty ? 'Flight' : flightTitle,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),

            // Route: Departure -> Arrival
            Row(
              children: [
                const Icon(
                  Icons.flight_land_rounded,
                  size: 13,
                  color: AppColors.flight,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${flight.departureAirport} → ${flight.arrivalAirport}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            // Terminal, Gate & Seat Info
            if ((flight.terminal != null && flight.terminal!.isNotEmpty) ||
                (flight.gate != null && flight.gate!.isNotEmpty) ||
                (flight.seat != null && flight.seat!.isNotEmpty)) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (flight.terminal != null && flight.terminal!.isNotEmpty)
                    _InfoChip(label: 'T${flight.terminal}'),
                  if (flight.gate != null && flight.gate!.isNotEmpty)
                    _InfoChip(label: 'Gate ${flight.gate}'),
                  if (flight.seat != null && flight.seat!.isNotEmpty)
                    _InfoChip(label: 'Seat ${flight.seat}'),
                ],
              ),
            ],

            // Confirmation / Booking Ref
            if (flight.bookingRef != null && flight.bookingRef!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey.shade300, width: 0.8),
                ),
                child: Text(
                  'Ref: ${flight.bookingRef}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],

            // Notes
            if (flight.notes != null && flight.notes!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                flight.notes!,
                style: const TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textMuted,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;

  const _InfoChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade300, width: 0.7),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }
}
