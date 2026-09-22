import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_formatters.dart';
import '../../models/models.dart';
import '../../state/trip_providers.dart';
import '../common/add_flight_sheet.dart';

class FlightsView extends ConsumerWidget {
  final VoidCallback? onAddFlight;
  final void Function(Flight flight)? onFlightTap;

  const FlightsView({
    super.key,
    this.onAddFlight,
    this.onFlightTap,
  });

  void _openFlightSheet(BuildContext context, [Flight? flight]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddFlightSheet(flightToEdit: flight),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flightsAsync = ref.watch(activeTripFlightsProvider);
    final canEdit = ref.watch(canEditActiveTripProvider);
    final repo = ref.watch(tripRepositoryProvider);
    final activeTrip = ref.watch(activeTripProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              onPressed: onAddFlight ?? () => _openFlightSheet(context),
              icon: const Icon(Icons.add),
              label: const Text('Add Flight'),
            )
          : null,
      body: flightsAsync.when(
        data: (flights) {
          if (flights.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.flight_takeoff_rounded,
                      size: 56, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  const Text(
                    'No flights added yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Track departures, terminals, gates, and layovers',
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                  if (canEdit) ...[
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: onAddFlight ?? () => _openFlightSheet(context),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Flight'),
                    ),
                  ],
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: flights.length,
            itemBuilder: (context, index) {
              final flight = flights[index];
              return _FlightCard(
                flight: flight,
                canEdit: canEdit,
                onTap: () {
                  if (onFlightTap != null) {
                    onFlightTap!(flight);
                  } else {
                    _openFlightSheet(context, flight);
                  }
                },
                onDelete: () async {
                  if (activeTrip == null) return;
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete Flight'),
                      content: Text(
                          'Are you sure you want to remove flight ${flight.flightNumber} (${flight.airline})?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Delete',
                              style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await repo.deleteFlight(activeTrip.id, flight.id);
                  }
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading flights: $e')),
      ),
    );
  }
}

class _FlightCard extends StatelessWidget {
  final Flight flight;
  final bool canEdit;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const _FlightCard({
    required this.flight,
    this.canEdit = true,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: canEdit ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Airline & Flight Number & Badges Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.flightContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.flight_takeoff_rounded,
                      color: AppColors.flight,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          flight.airline,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          flight.flightNumber,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.flight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (flight.isNightStay)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: const Color(0xFF0284C7), width: 0.8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('🌙', style: TextStyle(fontSize: 10)),
                              SizedBox(width: 4),
                              Text(
                                'NIGHT STAY',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0369A1),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (flight.isMainArrival)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: const Color(0xFF0284C7), width: 0.8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.flight_land_rounded,
                                  size: 12, color: Color(0xFF0284C7)),
                              SizedBox(width: 4),
                              Text(
                                'MAIN ARRIVAL',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0369A1),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (flight.isMainDeparture)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFE4E6),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: const Color(0xFFF43F5E), width: 0.8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.flight_takeoff_rounded,
                                  size: 12, color: Color(0xFFE11D48)),
                              SizedBox(width: 4),
                              Text(
                                'MAIN DEPARTURE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFBE123C),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (flight.spansAcrossDays && !flight.isNightStay)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.bedtime_outlined,
                                  size: 12, color: Color(0xFFD97706)),
                              SizedBox(width: 4),
                              Text(
                                'OVERNIGHT',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFD97706),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (canEdit) ...[
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert,
                              size: 18, color: AppColors.textSecondary),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onSelected: (val) {
                            if (val == 'edit') onTap?.call();
                            if (val == 'delete') onDelete?.call();
                          },
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined, size: 16),
                                  SizedBox(width: 8),
                                  Text('Edit Flight'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline,
                                      size: 16, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Delete Flight',
                                      style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

            // Route & Times Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Origin
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      flight.departureAirport,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormatters.dayHeader.format(flight.departureTime),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      DateFormatters.time12.format(flight.departureTime),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.flight,
                      ),
                    ),
                  ],
                ),

                // Airplane Flight Graphic
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      children: [
                        Text(
                          '${flight.duration.inHours}h ${flight.duration.inMinutes.remainder(60)}m',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.flight,
                              ),
                            ),
                            Expanded(
                              child: Container(
                                height: 2,
                                color: AppColors.flight.withValues(alpha: 0.3),
                              ),
                            ),
                            const Icon(
                              Icons.flight,
                              size: 16,
                              color: AppColors.flight,
                            ),
                            Expanded(
                              child: Container(
                                height: 2,
                                color: AppColors.flight.withValues(alpha: 0.3),
                              ),
                            ),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.flight,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Non-stop',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Destination
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      flight.arrivalAirport,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormatters.dayHeader.format(flight.arrivalTime),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      DateFormatters.time12.format(flight.arrivalTime),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.flight,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 28),

            // Bottom Badges: Terminal, Gate, Seat, Booking Ref
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                if (flight.terminal != null)
                  _FlightDetailBadge(
                    label: 'Terminal',
                    value: flight.terminal!,
                  ),
                if (flight.gate != null)
                  _FlightDetailBadge(
                    label: 'Gate',
                    value: flight.gate!,
                  ),
                if (flight.seat != null)
                  _FlightDetailBadge(
                    label: 'Seat',
                    value: flight.seat!,
                  ),
                if (flight.bookingRef != null)
                  _FlightDetailBadge(
                    label: 'Booking Ref',
                    value: flight.bookingRef!,
                    isMonospace: true,
                  ),
              ],
            ),

            if (flight.notes != null && flight.notes!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                flight.notes!,
                style: const TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
}

class _FlightDetailBadge extends StatelessWidget {
  final String label;
  final String value;
  final bool isMonospace;

  const _FlightDetailBadge({
    required this.label,
    required this.value,
    this.isMonospace = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              fontFamily: isMonospace ? 'monospace' : null,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
