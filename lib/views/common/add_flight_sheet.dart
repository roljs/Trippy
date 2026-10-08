import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/airport_timezone_helper.dart';
import '../../core/utils/date_formatters.dart';
import '../../models/models.dart';
import '../../state/trip_providers.dart';
import 'add_activity_sheet.dart';

class AddFlightSheet extends ConsumerStatefulWidget {
  final Flight? flightToEdit;

  const AddFlightSheet({super.key, this.flightToEdit});

  @override
  ConsumerState<AddFlightSheet> createState() => _AddFlightSheetState();
}

class _AddFlightSheetState extends ConsumerState<AddFlightSheet> {
  final _airlineController = TextEditingController();
  final _flightNumController = TextEditingController();
  final _originController = TextEditingController();
  final _destController = TextEditingController();
  final _terminalController = TextEditingController();
  final _gateController = TextEditingController();
  final _seatController = TextEditingController();
  final _bookingRefController = TextEditingController();

  late DateTime _depDateTime;
  late DateTime _arrDateTime;
  bool _createDepartureTransfer = false;
  bool _createArrivalTransfer = false;
  bool? _userSetDepTransfer;
  bool? _userSetArrTransfer;

  @override
  void initState() {
    super.initState();
    final edit = widget.flightToEdit;
    if (edit != null) {
      _airlineController.text = edit.airline;
      _flightNumController.text = edit.flightNumber;
      _originController.text = edit.departureAirport;
      _destController.text = edit.arrivalAirport;
      _terminalController.text = edit.terminal ?? '';
      _gateController.text = edit.gate ?? '';
      _seatController.text = edit.seat ?? '';
      _bookingRefController.text = edit.bookingRef ?? '';
      _depDateTime = edit.departureTime;
      _arrDateTime = edit.arrivalTime;
    } else {
      final trip = ref.read(activeTripProvider);
      final start = trip?.startDate ?? DateTime.now();
      _depDateTime = DateTime(start.year, start.month, start.day, 10, 0);
      _arrDateTime = DateTime(start.year, start.month, start.day, 14, 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeTrip = ref.watch(activeTripProvider);
    final repo = ref.watch(tripRepositoryProvider);
    final isEditing = widget.flightToEdit != null;

    if (activeTrip == null && !isEditing) return const SizedBox.shrink();

    final currentTripId = activeTrip?.id ?? widget.flightToEdit?.tripId ?? '';
    final allActivities = activeTrip != null
        ? (ref.watch(activeTripActivitiesProvider).value ?? [])
        : <Activity>[];
    final linkedTransfers = isEditing
        ? allActivities.where((a) =>
            widget.flightToEdit!.linkedActivityIds.contains(a.id) ||
            a.flightId == widget.flightToEdit!.id).toList()
        : <Activity>[];

    final depXfers = linkedTransfers.where((a) =>
        a.title.toLowerCase().contains('to airport') ||
        a.title.toLowerCase().contains('hotel to') ||
        a.id.contains('dep_xfer')
    ).toList();

    final arrXfers = linkedTransfers.where((a) =>
        a.title.toLowerCase().contains('airport to') ||
        a.title.toLowerCase().contains('to hotel') ||
        a.id.contains('arr_xfer')
    ).toList();

    final hasDepTransfer = depXfers.isNotEmpty;
    final hasArrTransfer = arrXfers.isNotEmpty;

    if (_userSetDepTransfer == null && isEditing) {
      _createDepartureTransfer = hasDepTransfer;
    }
    if (_userSetArrTransfer == null && isEditing) {
      _createArrivalTransfer = hasArrTransfer;
    }

    final duration = AirportTimezoneHelper.calculateDuration(
      departureTime: _depDateTime,
      departureAirport: _originController.text.trim(),
      arrivalTime: _arrDateTime,
      arrivalAirport: _destController.text.trim(),
    );

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isEditing ? 'Edit Flight' : 'Add Flight Booking',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _airlineController,
                    decoration: const InputDecoration(
                      labelText: 'Airline',
                      hintText: 'e.g. United Airlines',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _flightNumController,
                    decoration: const InputDecoration(
                      labelText: 'Flight #',
                      hintText: 'e.g. UA875',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _originController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Departure Airport',
                      hintText: 'e.g. SFO',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _destController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Arrival Airport',
                      hintText: 'e.g. HND',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Departure & Arrival Time Pickers with Visual Duration Plane Graphic
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Departure Time Picker
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Departure',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      OutlinedButton(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _depDateTime,
                            firstDate: DateTime(2025),
                            lastDate: DateTime(2030),
                          );
                          if (date != null && context.mounted) {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.fromDateTime(_depDateTime),
                            );
                            if (time != null) {
                              setState(() {
                                _depDateTime = DateTime(date.year, date.month,
                                    date.day, time.hour, time.minute);
                              });
                            }
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        ),
                        child: Text(
                          '${DateFormatters.shortDate.format(_depDateTime)} ${DateFormatters.time12.format(_depDateTime)}',
                          style: const TextStyle(fontSize: 11),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                // Visual Flight Duration Graphic (Centered between Departure and Arrival)
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 16),
                        Text(
                          '${duration.inHours}h ${duration.inMinutes.remainder(60).abs()}m',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.flight,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 3),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.flight,
                              ),
                            ),
                            Expanded(
                              child: Container(
                                height: 1.5,
                                color: AppColors.flight.withValues(alpha: 0.35),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 2.0),
                              child: Icon(
                                Icons.flight,
                                size: 15,
                                color: AppColors.flight,
                              ),
                            ),
                            Expanded(
                              child: Container(
                                height: 1.5,
                                color: AppColors.flight.withValues(alpha: 0.35),
                              ),
                            ),
                            Container(
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.flight,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Arrival Time Picker
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Arrival',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      OutlinedButton(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _arrDateTime,
                            firstDate: DateTime(2025),
                            lastDate: DateTime(2030),
                          );
                          if (date != null && context.mounted) {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.fromDateTime(_arrDateTime),
                            );
                            if (time != null) {
                              setState(() {
                                _arrDateTime = DateTime(date.year, date.month,
                                    date.day, time.hour, time.minute);
                              });
                            }
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        ),
                        child: Text(
                          '${DateFormatters.shortDate.format(_arrDateTime)} ${DateFormatters.time12.format(_arrDateTime)}',
                          style: const TextStyle(fontSize: 11),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _terminalController,
                    decoration: const InputDecoration(labelText: 'Terminal'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _gateController,
                    decoration: const InputDecoration(labelText: 'Gate'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _seatController,
                    decoration: const InputDecoration(labelText: 'Seat'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _bookingRefController,
              decoration: const InputDecoration(
                labelText: 'Confirmation / Booking Reference',
                hintText: 'e.g. UA-88902',
              ),
            ),


            // Linked Airport Ground Transfers Section (shown when editing or when linked transfers exist)
            // Linked Airport Ground Transfers Section (always shown when editing or when linked transfers exist)
            if (isEditing || linkedTransfers.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.transportContainer.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.transport.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.directions_subway_rounded, size: 16, color: AppColors.transport),
                            const SizedBox(width: 6),
                            Text(
                              'Linked Airport Ground Transfers (${linkedTransfers.length})',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.transport,
                              ),
                            ),
                          ],
                        ),
                        if (widget.flightToEdit != null)
                          InkWell(
                            onTap: () => _showLinkTransferDialog(context, ref, widget.flightToEdit!, allActivities),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
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
                    const SizedBox(height: 8),
                    if (linkedTransfers.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'No transportation activities linked to this flight yet.',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
                        ),
                      )
                    else
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
                                  if (widget.flightToEdit != null) ...[
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: Icon(Icons.link_off_rounded, size: 16, color: Colors.amber.shade800),
                                      tooltip: 'Unlink Transfer',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () async {
                                        final remainingIds = widget.flightToEdit!.linkedActivityIds.where((id) => id != xfer.id).toList();
                                        await repo.updateFlight(widget.flightToEdit!.copyWith(linkedActivityIds: remainingIds));
                                        await repo.updateActivity(xfer.copyWith(flightId: null));
                                      },
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                      tooltip: 'Delete Transfer',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text('Delete Transfer'),
                                            content: Text('Are you sure you want to permanently delete "${xfer.title}"?'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(ctx, false),
                                                child: const Text('Cancel'),
                                              ),
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                                onPressed: () => Navigator.pop(ctx, true),
                                                child: const Text('Delete', style: TextStyle(color: Colors.white)),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          final remainingIds = widget.flightToEdit!.linkedActivityIds.where((id) => id != xfer.id).toList();
                                          await repo.updateFlight(widget.flightToEdit!.copyWith(linkedActivityIds: remainingIds));
                                          await repo.deleteActivity(currentTripId, xfer.id);
                                        }
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
                ),
              ),
            ],

            // Ground transport activities options (only shown when adding a new flight)
            if (!isEditing) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (_createDepartureTransfer || _createArrivalTransfer)
                      ? AppColors.transportContainer.withValues(alpha: 0.3)
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (_createDepartureTransfer || _createArrivalTransfer)
                        ? AppColors.transport.withValues(alpha: 0.4)
                        : Colors.grey.shade300,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.directions_subway_rounded, size: 16, color: AppColors.transport),
                        SizedBox(width: 6),
                        Text(
                          'Airport Ground Transfers',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.transport),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Material(
                      color: Colors.transparent,
                      child: CheckboxListTile(
                        value: _createDepartureTransfer,
                        activeColor: AppColors.transport,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          hasDepTransfer
                              ? 'Transfer: Hotel to ${_originController.text.trim().isEmpty ? 'Departure' : _originController.text.trim()} Airport (Already linked - will sync)'
                              : 'Transfer: Hotel to ${_originController.text.trim().isEmpty ? 'Departure' : _originController.text.trim()} Airport',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          hasDepTransfer
                              ? 'Syncs transfer date/time with departure: ${DateFormatters.shortDate.format(_depDateTime)} (~2 hrs before flight) without duplicates'
                              : 'Creates transport activity on ${DateFormatters.shortDate.format(_depDateTime)} (~2 hrs before flight)',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _userSetDepTransfer = val ?? false;
                            _createDepartureTransfer = val ?? false;
                          });
                        },
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: CheckboxListTile(
                        value: _createArrivalTransfer,
                        activeColor: AppColors.transport,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          hasArrTransfer
                              ? 'Transfer: ${_destController.text.trim().isEmpty ? 'Arrival' : _destController.text.trim()} Airport to Hotel (Already linked - will sync)'
                              : 'Transfer: ${_destController.text.trim().isEmpty ? 'Arrival' : _destController.text.trim()} Airport to Hotel',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          hasArrTransfer
                              ? 'Syncs transfer date/time with arrival: ${DateFormatters.shortDate.format(_arrDateTime)} (~45 min after arrival) without duplicates'
                              : 'Creates transport activity on ${DateFormatters.shortDate.format(_arrDateTime)} (~45 min after arrival)',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _userSetArrTransfer = val ?? false;
                            _createArrivalTransfer = val ?? false;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],

            Row(
              children: [
                if (isEditing) ...[
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: 'Delete Flight',
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete Flight'),
                          content: Text(
                              'Are you sure you want to remove ${_flightNumController.text.trim().isNotEmpty ? _flightNumController.text.trim() : "this flight"}?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Delete',
                                  style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true && context.mounted) {
                        await repo.deleteFlight(
                            currentTripId, widget.flightToEdit!.id);
                        if (context.mounted) Navigator.pop(context);
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      if (_airlineController.text.trim().isEmpty) return;

                      final newFlightId = widget.flightToEdit?.id ??
                          'flt_${DateTime.now().millisecondsSinceEpoch}';



                      final targetTripId = activeTrip?.id ?? widget.flightToEdit?.tripId ?? '';
                      final List<String> currentLinkedIds = [
                        ...(widget.flightToEdit?.linkedActivityIds ?? const <String>[]),
                      ];

                      if (_createDepartureTransfer) {
                        final depTransferTime = _depDateTime.subtract(const Duration(hours: 2));
                        final h = depTransferTime.hour.toString().padLeft(2, '0');
                        final m = depTransferTime.minute.toString().padLeft(2, '0');
                        final depName = _originController.text.trim().isEmpty
                            ? 'Departure'
                            : _originController.text.trim();

                        if (depXfers.isNotEmpty) {
                          // Update existing departure transfer without duplicate
                          final existingDep = depXfers.first;
                          await repo.updateActivity(existingDep.copyWith(
                            flightId: newFlightId,
                            date: DateTime(depTransferTime.year, depTransferTime.month, depTransferTime.day),
                            startTime: '$h:$m',
                            title: 'Transport: Hotel to $depName Airport',
                            location: '$depName Airport',
                            notes: 'Ground transfer to airport for flight ${_airlineController.text.trim()} ${_flightNumController.text.trim()}',
                          ));
                          if (!currentLinkedIds.contains(existingDep.id)) {
                            currentLinkedIds.add(existingDep.id);
                          }
                        } else {
                          final depActId = 'act_${DateTime.now().millisecondsSinceEpoch}_dep_xfer';
                          final act = Activity(
                            id: depActId,
                            tripId: targetTripId,
                            flightId: newFlightId,
                            date: DateTime(depTransferTime.year, depTransferTime.month, depTransferTime.day),
                            startTime: '$h:$m',
                            title: 'Transport: Hotel to $depName Airport',
                            category: ActivityCategory.transport,
                            location: '$depName Airport',
                            notes: 'Ground transfer to airport for flight ${_airlineController.text.trim()} ${_flightNumController.text.trim()}',
                            bookingStatus: BookingStatus.planned,
                          );
                          await repo.addActivity(act);
                          currentLinkedIds.add(depActId);
                        }
                      }

                      if (_createArrivalTransfer) {
                        final arrTransferTime = _arrDateTime.add(const Duration(minutes: 45));
                        final h = arrTransferTime.hour.toString().padLeft(2, '0');
                        final m = arrTransferTime.minute.toString().padLeft(2, '0');
                        final arrName = _destController.text.trim().isEmpty
                            ? 'Arrival'
                            : _destController.text.trim();

                        if (arrXfers.isNotEmpty) {
                          // Update existing arrival transfer without duplicate
                          final existingArr = arrXfers.first;
                          await repo.updateActivity(existingArr.copyWith(
                            flightId: newFlightId,
                            date: DateTime(arrTransferTime.year, arrTransferTime.month, arrTransferTime.day),
                            startTime: '$h:$m',
                            title: 'Transport: $arrName Airport to Hotel',
                            location: '$arrName Airport',
                            notes: 'Ground transfer from airport to hotel after flight ${_airlineController.text.trim()} ${_flightNumController.text.trim()}',
                          ));
                          if (!currentLinkedIds.contains(existingArr.id)) {
                            currentLinkedIds.add(existingArr.id);
                          }
                        } else {
                          final arrActId = 'act_${DateTime.now().millisecondsSinceEpoch + 1}_arr_xfer';
                          final act = Activity(
                            id: arrActId,
                            tripId: targetTripId,
                            flightId: newFlightId,
                            date: DateTime(arrTransferTime.year, arrTransferTime.month, arrTransferTime.day),
                            startTime: '$h:$m',
                            title: 'Transport: $arrName Airport to Hotel',
                            category: ActivityCategory.transport,
                            location: '$arrName Airport',
                            notes: 'Ground transfer from airport to hotel after flight ${_airlineController.text.trim()} ${_flightNumController.text.trim()}',
                            bookingStatus: BookingStatus.planned,
                          );
                          await repo.addActivity(act);
                          currentLinkedIds.add(arrActId);
                        }
                      }

                      final finalLinkedIds = currentLinkedIds.toSet().toList();

                      final flight = Flight(
                        id: newFlightId,
                        tripId: targetTripId,
                        airline: _airlineController.text.trim(),
                        flightNumber: _flightNumController.text.trim(),
                        departureAirport: _originController.text.trim(),
                        arrivalAirport: _destController.text.trim(),
                        departureTime: _depDateTime,
                        arrivalTime: _arrDateTime,
                        isOvernight: _arrDateTime.day != _depDateTime.day,
                        terminal: _terminalController.text.trim().isEmpty
                            ? null
                            : _terminalController.text.trim(),
                        gate: _gateController.text.trim().isEmpty
                            ? null
                            : _gateController.text.trim(),
                        seat: _seatController.text.trim().isEmpty
                            ? null
                            : _seatController.text.trim(),
                        bookingRef: _bookingRefController.text.trim().isEmpty
                            ? null
                            : _bookingRefController.text.trim(),
                        linkedActivityIds: finalLinkedIds,
                      );

                      if (isEditing) {
                        await repo.updateFlight(flight);
                      } else {
                        await repo.addFlight(flight);
                      }

                      if (context.mounted) Navigator.pop(context);
                    },
                    child: Text(isEditing ? 'Save Changes' : 'Add Flight'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showLinkTransferDialog(BuildContext context, WidgetRef ref, Flight flight, List<Activity> activities) {
    // Only show activities in Transportation category that are not already linked
    final availableToLink = activities.where((a) =>
      a.category == ActivityCategory.transport &&
      !flight.linkedActivityIds.contains(a.id) &&
      a.flightId != flight.id
    ).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

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
                    'No available transportation activities to link. Create a transport activity first.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: availableToLink.length,
                  itemBuilder: (c, idx) {
                    final act = availableToLink[idx];
                    return ListTile(
                      dense: true,
                      leading: const Icon(
                        Icons.directions_subway_rounded,
                        color: AppColors.transport,
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
