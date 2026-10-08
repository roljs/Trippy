import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_formatters.dart';
import '../../models/models.dart';
import '../../state/trip_providers.dart';
import '../common/add_activity_sheet.dart';
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

class _FlightCard extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
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
                      if (flight.spansAcrossDays)
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

            // Airport Ground Transfers Section
            Builder(
              builder: (context) {
                final activities = ref.watch(activeTripActivitiesProvider).value ?? [];
                final linkedTransfers = activities.where((a) =>
                    flight.linkedActivityIds.contains(a.id) || a.flightId == flight.id
                ).toList();

                if (linkedTransfers.isEmpty && !canEdit) {
                  return const SizedBox.shrink();
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 14),
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.directions_subway_rounded, size: 16, color: AppColors.transport),
                            const SizedBox(width: 6),
                            Text(
                              'Airport Ground Transfers (${linkedTransfers.length})',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.transport,
                              ),
                            ),
                          ],
                        ),
                        if (canEdit)
                          InkWell(
                            onTap: () => _showLinkTransferDialog(context, ref, flight, activities),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.transportContainer.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.transport.withValues(alpha: 0.4)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add_link_rounded, size: 13, color: AppColors.transport),
                                  SizedBox(width: 4),
                                  Text(
                                    'Link Transfer',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.transport,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (linkedTransfers.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ...linkedTransfers.map((xfer) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (ctx) => AddActivitySheet(activityToEdit: xfer),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              child: Row(
                                children: [
                                  const Icon(Icons.directions_car_rounded, size: 16, color: AppColors.transport),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                xfer.title,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.textPrimary,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (xfer.isToAirport) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFEFF6FF),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: const Color(0xFF93C5FD), width: 0.8),
                                                ),
                                                child: const Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.flight_takeoff_rounded, size: 10, color: Color(0xFF2563EB)),
                                                    SizedBox(width: 3),
                                                    Text(
                                                      'TO AIRPORT',
                                                      style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: Color(0xFF1D4ED8)),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ] else if (xfer.isFromAirport) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFF0FDF4),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: const Color(0xFF86EFAC), width: 0.8),
                                                ),
                                                child: const Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.flight_land_rounded, size: 10, color: Color(0xFF16A34A)),
                                                    SizedBox(width: 3),
                                                    Text(
                                                      'FROM AIRPORT',
                                                      style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: Color(0xFF15803D)),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        Text(
                                          '${DateFormatters.shortDate.format(xfer.date)}  •  ${DateFormatters.formatTimeString(xfer.startTime)}${xfer.location != null ? "  •  ${xfer.location}" : ""}',
                                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.textMuted),
                                  if (canEdit) ...[
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(Icons.link_off_rounded, size: 16, color: Colors.red),
                                      tooltip: 'Unlink Transfer',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () async {
                                        final repo = ref.read(tripRepositoryProvider);
                                        final remainingIds = flight.linkedActivityIds.where((id) => id != xfer.id).toList();
                                        await repo.updateFlight(flight.copyWith(linkedActivityIds: remainingIds));
                                        await repo.updateActivity(xfer.copyWith(flightId: null));
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}

  void _showLinkTransferDialog(BuildContext context, WidgetRef ref, Flight flight, List<Activity> activities) {
    final availableToLink = activities.where((a) =>
      !flight.linkedActivityIds.contains(a.id) && a.flightId != flight.id
    ).toList()
      ..sort((a, b) {
        if (a.category == ActivityCategory.transport && b.category != ActivityCategory.transport) return -1;
        if (a.category != ActivityCategory.transport && b.category == ActivityCategory.transport) return 1;
        return a.date.compareTo(b.date);
      });

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.add_link_rounded, color: AppColors.transport, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Link Transfer to ${flight.flightNumber}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: availableToLink.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'No available activities to link. Create a transport activity first.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: availableToLink.length,
                  itemBuilder: (c, idx) {
                    final act = availableToLink[idx];
                    final isTransport = act.category == ActivityCategory.transport;
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        isTransport ? Icons.directions_subway_rounded : Icons.local_activity_rounded,
                        color: isTransport ? AppColors.transport : AppColors.primary,
                        size: 20,
                      ),
                      title: Text(act.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        '${DateFormatters.shortDate.format(act.date)}  •  ${DateFormatters.formatTimeString(act.startTime)}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      onTap: () async {
                        final repo = ref.read(tripRepositoryProvider);
                        final updatedLinked = {...flight.linkedActivityIds, act.id}.toList();
                        await repo.updateFlight(flight.copyWith(linkedActivityIds: updatedLinked));
                        await repo.updateActivity(act.copyWith(flightId: flight.id));
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Linked "${act.title}" to ${flight.flightNumber}')),
                          );
                        }
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
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
