import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_formatters.dart';
import '../../models/models.dart';
import '../../state/trip_providers.dart';
import 'add_flight_sheet.dart';
import 'add_stay_sheet.dart';

class AddActivitySheet extends ConsumerStatefulWidget {
  final Activity? activityToEdit;
  final DateTime? initialDate;
  final String? initialTitle;
  final ActivityCategory? initialCategory;
  final TimeOfDay? initialStartTime;
  final TimeOfDay? initialEndTime;

  const AddActivitySheet({
    super.key,
    this.activityToEdit,
    this.initialDate,
    this.initialTitle,
    this.initialCategory,
    this.initialStartTime,
    this.initialEndTime,
  });

  @override
  ConsumerState<AddActivitySheet> createState() => _AddActivitySheetState();
}

class _AddActivitySheetState extends ConsumerState<AddActivitySheet> {
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _confirmationController = TextEditingController();
  final _notesController = TextEditingController();

  late ActivityCategory _category;
  late BookingStatus _bookingStatus;
  late DateTime _selectedDate;
  TimeOfDay _startTime = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay? _endTime;
  String? _selectedStayId;
  String? _selectedFlightId;

  @override
  void initState() {
    super.initState();
    final edit = widget.activityToEdit;
    if (edit != null) {
      _titleController.text = edit.title;
      _locationController.text = edit.location ?? '';
      _confirmationController.text = edit.confirmationRef ?? '';
      _notesController.text = edit.notes ?? '';
      _category = edit.category;
      _bookingStatus = edit.bookingStatus;
      _selectedDate = edit.date;
      _selectedStayId = edit.stayId;
      _selectedFlightId = edit.flightId;
      final startParts = edit.startTime.split(':');
      if (startParts.length >= 2) {
        _startTime = TimeOfDay(
          hour: int.tryParse(startParts[0]) ?? 10,
          minute: int.tryParse(startParts[1]) ?? 0,
        );
      }
      if (edit.endTime != null) {
        final endParts = edit.endTime!.split(':');
        if (endParts.length >= 2) {
          _endTime = TimeOfDay(
            hour: int.tryParse(endParts[0]) ?? 12,
            minute: int.tryParse(endParts[1]) ?? 0,
          );
        }
      }
    } else {
      _titleController.text = widget.initialTitle ?? '';
      _category = widget.initialCategory ?? ActivityCategory.attraction;
      _bookingStatus = BookingStatus.planned;
      final activeTrip = ref.read(activeTripProvider);
      _selectedDate = widget.initialDate ?? activeTrip?.startDate ?? DateTime.now();
      if (widget.initialStartTime != null) {
        _startTime = widget.initialStartTime!;
      }
      if (widget.initialEndTime != null) {
        _endTime = widget.initialEndTime;
      }
    }
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    final h = tod.hour.toString().padLeft(2, '0');
    final m = tod.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  TimeOfDay _parseTimeOfDay(String? timeStr, {required int defaultHour, int defaultMinute = 0}) {
    if (timeStr == null || timeStr.isEmpty) {
      return TimeOfDay(hour: defaultHour, minute: defaultMinute);
    }
    final parts = timeStr.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? defaultHour,
      minute: parts.length > 1 ? int.tryParse(parts[1]) ?? defaultMinute : defaultMinute,
    );
  }

  void _applyStayCheckIn(Stay stay) {
    setState(() {
      _titleController.text = 'Check-in: ${stay.name}';
      _selectedDate = stay.checkInDate;
      _startTime = _parseTimeOfDay(stay.checkInTime, defaultHour: 15);
      _locationController.text = stay.address ?? stay.name;
      _confirmationController.text = stay.confirmationCode ?? '';
      if (stay.notes != null && stay.notes!.isNotEmpty) {
        _notesController.text = stay.notes!;
      }
      _bookingStatus = BookingStatus.booked;
    });
  }

  void _applyStayCheckOut(Stay stay) {
    setState(() {
      _titleController.text = 'Check-out: ${stay.name}';
      _selectedDate = stay.checkOutDate;
      _startTime = _parseTimeOfDay(stay.checkOutTime, defaultHour: 11);
      _locationController.text = stay.address ?? stay.name;
      _confirmationController.text = stay.confirmationCode ?? '';
      if (stay.notes != null && stay.notes!.isNotEmpty) {
        _notesController.text = stay.notes!;
      }
      _bookingStatus = BookingStatus.booked;
    });
  }

  void _applyFlightDepartureTransfer(Flight flight) {
    setState(() {
      final depAirport = flight.departureAirport;
      final depName = depAirport.contains('(')
          ? depAirport.substring(depAirport.indexOf('(') + 1, depAirport.indexOf(')'))
          : depAirport.split(' ').first;
      _titleController.text = 'Transport: Hotel to $depName Airport';
      final depTransferTime = flight.departureTime.subtract(const Duration(hours: 2));
      _selectedDate = DateTime(depTransferTime.year, depTransferTime.month, depTransferTime.day);
      _startTime = TimeOfDay(hour: depTransferTime.hour, minute: depTransferTime.minute);
      _locationController.text = '$depAirport Airport';
      _notesController.text = 'Ground transfer to airport for flight ${flight.airline} ${flight.flightNumber}';
      _bookingStatus = BookingStatus.planned;
    });
  }

  void _applyFlightArrivalTransfer(Flight flight) {
    setState(() {
      final arrAirport = flight.arrivalAirport;
      final arrName = arrAirport.contains('(')
          ? arrAirport.substring(arrAirport.indexOf('(') + 1, arrAirport.indexOf(')'))
          : arrAirport.split(' ').first;
      _titleController.text = 'Transport: $arrName Airport to Hotel';
      final arrTransferTime = flight.arrivalTime.add(const Duration(minutes: 45));
      _selectedDate = DateTime(arrTransferTime.year, arrTransferTime.month, arrTransferTime.day);
      _startTime = TimeOfDay(hour: arrTransferTime.hour, minute: arrTransferTime.minute);
      _locationController.text = '$arrAirport Airport';
      _notesController.text = 'Ground transfer from airport to hotel after flight ${flight.airline} ${flight.flightNumber}';
      _bookingStatus = BookingStatus.planned;
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeTrip = ref.watch(activeTripProvider);
    final repo = ref.watch(tripRepositoryProvider);
    final isEditing = widget.activityToEdit != null;

    if (activeTrip == null) {
      return const SizedBox.shrink();
    }

    final tripDays = activeTrip.daysList;
    final staysAsync = ref.watch(activeTripStaysProvider);
    final availableStays = staysAsync.value?.where((s) => s.type != StayType.overnightFlight).toList() ?? [];

    final flightsAsync = ref.watch(activeTripFlightsProvider);
    final availableFlights = flightsAsync.value ?? [];

    Stay? currentSelectedStay;
    if (_selectedStayId != null) {
      currentSelectedStay = availableStays.where((s) => s.id == _selectedStayId).firstOrNull;
    }

    Flight? currentSelectedFlight;
    if (_selectedFlightId != null) {
      currentSelectedFlight = availableFlights.where((f) => f.id == _selectedFlightId).firstOrNull;
    }

    // Normalized date check for trip day dropdown
    DateTime matchedDay = tripDays.first;
    for (final d in tripDays) {
      if (d.year == _selectedDate.year && d.month == _selectedDate.month && d.day == _selectedDate.day) {
        matchedDay = d;
        break;
      }
    }

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
                  isEditing ? 'Edit Activity' : 'Add Activity',
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

            // Title
            TextField(
              controller: _titleController,
              autofocus: !isEditing,
              decoration: const InputDecoration(
                labelText: 'Activity Title',
                hintText: 'e.g. Senso-ji Temple Tour or Ramen Lunch',
              ),
            ),
            const SizedBox(height: 14),

            // Category Chips
            const Text(
              'Category',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ActivityCategory.values.map((cat) {
                return ChoiceChip(
                  label: Text(cat.displayName),
                  selected: _category == cat,
                  onSelected: (val) {
                    if (val) {
                      setState(() {
                        _category = cat;
                        if (cat == ActivityCategory.stay && _selectedStayId == null && availableStays.isNotEmpty) {
                          _selectedStayId = availableStays.first.id;
                          _applyStayCheckIn(availableStays.first);
                        }
                      });
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // Stay linking section if category is Stay
            if (_category == ActivityCategory.stay) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.stayContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.stay.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.hotel_rounded, size: 18, color: AppColors.stay),
                        const SizedBox(width: 8),
                        const Text(
                          'Link to Hotel / Stay',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.stay,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (availableStays.isEmpty)
                      const Text(
                        'No stays created yet. You can still enter hotel details below.',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      )
                    else ...[
                      DropdownButtonFormField<String?>(
                        key: ValueKey(_selectedStayId),
                        initialValue: _selectedStayId,
                        decoration: const InputDecoration(
                          labelText: 'Select Stay',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('None (Unlinked)', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                          ),
                          ...availableStays.map((s) {
                            return DropdownMenuItem<String?>(
                              value: s.id,
                              child: Text(
                                '${s.name} (${DateFormatters.shortDate.format(s.checkInDate)} - ${DateFormatters.shortDate.format(s.checkOutDate)})',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13),
                              ),
                            );
                          }),
                        ],
                        onChanged: (stayId) {
                          setState(() {
                            _selectedStayId = stayId;
                            if (stayId != null) {
                              final stay = availableStays.firstWhere((s) => s.id == stayId);
                              _applyStayCheckIn(stay);
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      if (currentSelectedStay != null) ...[
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _applyStayCheckIn(currentSelectedStay!),
                                icon: const Icon(Icons.login_rounded, size: 14),
                                label: const Text('Quick: Check-in', style: TextStyle(fontSize: 12)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _applyStayCheckOut(currentSelectedStay!),
                                icon: const Icon(Icons.logout_rounded, size: 14),
                                label: const Text('Quick: Check-out', style: TextStyle(fontSize: 12)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              Navigator.pop(context);
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (ctx) => AddStaySheet(stayToEdit: currentSelectedStay),
                              );
                            },
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              currentSelectedStay.name,
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                                            ),
                                          ),
                                          const Text(
                                            'View Stay',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.stay,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: AppColors.stay),
                                        ],
                                      ),
                                      if (currentSelectedStay.address != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          currentSelectedStay.address!,
                                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                        ),
                                      ],
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text(
                                            'Check-in: ${DateFormatters.shortDate.format(currentSelectedStay.checkInDate)} at ${currentSelectedStay.checkInTime ?? "15:00"}',
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '•  Out: ${DateFormatters.shortDate.format(currentSelectedStay.checkOutDate)} at ${currentSelectedStay.checkOutTime ?? "11:00"}',
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // 2. Flight Linking Card (Available when Transport category is selected or linking to a flight)
            if (_category == ActivityCategory.transport && availableFlights.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.transportContainer.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.transport.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.flight_takeoff_rounded, size: 16, color: AppColors.transport),
                        SizedBox(width: 6),
                        Text(
                          'Link to Flight (Airport Ground Transfer)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.transport,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String?>(
                      key: ValueKey(_selectedFlightId),
                      initialValue: _selectedFlightId,
                      decoration: const InputDecoration(
                        labelText: 'Select Flight',
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('None (Unlinked)', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                        ),
                        ...availableFlights.map((f) {
                          return DropdownMenuItem<String?>(
                            value: f.id,
                            child: Text(
                              '${f.flightNumber} (${f.airline}) • ${f.departureAirport.split(' ').first} -> ${f.arrivalAirport.split(' ').first}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                          );
                        }),
                      ],
                      onChanged: (flightId) {
                        setState(() {
                          _selectedFlightId = flightId;
                          if (flightId != null) {
                            final f = availableFlights.firstWhere((x) => x.id == flightId);
                            _applyFlightDepartureTransfer(f);
                          }
                        });
                      },
                    ),
                    if (currentSelectedFlight != null) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _applyFlightDepartureTransfer(currentSelectedFlight!),
                              icon: const Icon(Icons.flight_takeoff_rounded, size: 14),
                              label: const Text('Quick: To Airport', style: TextStyle(fontSize: 12)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _applyFlightArrivalTransfer(currentSelectedFlight!),
                              icon: const Icon(Icons.flight_land_rounded, size: 14),
                              label: const Text('Quick: From Airport', style: TextStyle(fontSize: 12)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              Navigator.pop(context);
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (ctx) => AddFlightSheet(flightToEdit: currentSelectedFlight),
                              );
                            },
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '${currentSelectedFlight.flightNumber} (${currentSelectedFlight.airline})',
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                                            ),
                                          ),
                                          const Text(
                                            'View Flight',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.flight,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: AppColors.flight),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${currentSelectedFlight.departureAirport} → ${currentSelectedFlight.arrivalAirport}',
                                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Departs: ${DateFormatters.shortDate.format(currentSelectedFlight.departureTime)} ${DateFormatters.time12.format(currentSelectedFlight.departureTime)}',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

            // Date selector
            const Text(
              'Day in Itinerary',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<DateTime>(
              key: ValueKey(matchedDay),
              initialValue: matchedDay,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              items: tripDays.map((d) {
                final dayIdx = tripDays.indexOf(d) + 1;
                return DropdownMenuItem(
                  value: d,
                  child: Text('Day $dayIdx: ${DateFormatters.dayHeader.format(d)}'),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedDate = val);
              },
            ),
            const SizedBox(height: 14),

            // Time Selectors
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Start Time',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: _startTime,
                          );
                          if (picked != null) {
                            setState(() => _startTime = picked);
                          }
                        },
                        icon: const Icon(Icons.access_time_rounded, size: 16),
                        label: Text(_formatTimeOfDay(_startTime)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'End Time (Optional)',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: _endTime ??
                                TimeOfDay(
                                    hour: (_startTime.hour + 2) % 24,
                                    minute: _startTime.minute),
                          );
                          if (picked != null) {
                            setState(() => _endTime = picked);
                          }
                        },
                        icon: const Icon(Icons.access_time_rounded, size: 16),
                        label: Text(
                          _endTime != null
                              ? _formatTimeOfDay(_endTime!)
                              : 'None',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Location
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Location / Address',
                hintText: 'e.g. Asakusa, Taito City',
                prefixIcon: Icon(Icons.location_on_outlined, size: 18),
              ),
            ),
            const SizedBox(height: 14),

            // Booking Status
            const Text(
              'Booking Status',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            SegmentedButton<BookingStatus>(
              segments: const [
                ButtonSegment(
                    value: BookingStatus.planned, label: Text('Planned')),
                ButtonSegment(
                    value: BookingStatus.booked, label: Text('Booked')),
                ButtonSegment(
                    value: BookingStatus.ticketed, label: Text('Ticketed')),
              ],
              selected: {_bookingStatus},
              onSelectionChanged: (set) {
                setState(() => _bookingStatus = set.first);
              },
            ),
            const SizedBox(height: 14),

            // Confirmation Ref
            TextField(
              controller: _confirmationController,
              decoration: const InputDecoration(
                labelText: 'Confirmation / Booking Reference',
                hintText: 'e.g. RES-99812',
                prefixIcon: Icon(Icons.confirmation_number_outlined, size: 18),
              ),
            ),
            const SizedBox(height: 14),

            // Notes
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notes & Tips',
                hintText: 'e.g. Bring comfortable shoes, camera allowed',
              ),
            ),
            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                if (isEditing) ...[
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () async {
                      await repo.deleteActivity(
                          activeTrip.id, widget.activityToEdit!.id);
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final title = _titleController.text.trim();
                      if (title.isEmpty) return;

                      final activity = Activity(
                        id: widget.activityToEdit?.id ??
                            'act_${DateTime.now().millisecondsSinceEpoch}',
                        tripId: activeTrip.id,
                        date: _selectedDate,
                        startTime: _formatTimeOfDay(_startTime),
                        endTime: _endTime != null
                            ? _formatTimeOfDay(_endTime!)
                            : null,
                        title: title,
                        category: _category,
                        location: _locationController.text.trim().isEmpty
                            ? null
                            : _locationController.text.trim(),
                        bookingStatus: _bookingStatus,
                        confirmationRef:
                            _confirmationController.text.trim().isEmpty
                                ? null
                                : _confirmationController.text.trim(),
                        notes: _notesController.text.trim().isEmpty
                            ? null
                            : _notesController.text.trim(),
                        stayId: _category == ActivityCategory.stay ? _selectedStayId : null,
                        flightId: _category == ActivityCategory.transport ? _selectedFlightId : null,
                      );

                      if (isEditing) {
                        await repo.updateActivity(activity);
                      } else {
                        await repo.addActivity(activity);
                      }

                      // Manage reciprocal link on Flight side
                      final targetFlightId = _category == ActivityCategory.transport ? _selectedFlightId : null;
                      final prevFlightId = widget.activityToEdit?.flightId;

                      if (targetFlightId != null) {
                        final flt = availableFlights.where((f) => f.id == targetFlightId).firstOrNull;
                        if (flt != null && !flt.linkedActivityIds.contains(activity.id)) {
                          await repo.updateFlight(flt.copyWith(
                            linkedActivityIds: [...flt.linkedActivityIds, activity.id],
                          ));
                        }
                      }

                      if (prevFlightId != null && prevFlightId != targetFlightId) {
                        final oldFlt = availableFlights.where((f) => f.id == prevFlightId).firstOrNull;
                        if (oldFlt != null && oldFlt.linkedActivityIds.contains(activity.id)) {
                          await repo.updateFlight(oldFlt.copyWith(
                            linkedActivityIds: oldFlt.linkedActivityIds.where((id) => id != activity.id).toList(),
                          ));
                        }
                      }

                      // Manage reciprocal link on Stay side
                      final targetStayId = _category == ActivityCategory.stay ? _selectedStayId : null;
                      final prevStayId = widget.activityToEdit?.stayId;

                      if (targetStayId != null) {
                        final sty = availableStays.where((s) => s.id == targetStayId).firstOrNull;
                        if (sty != null && !sty.linkedActivityIds.contains(activity.id)) {
                          await repo.updateStay(sty.copyWith(
                            linkedActivityIds: [...sty.linkedActivityIds, activity.id],
                          ));
                        }
                      }

                      if (prevStayId != null && prevStayId != targetStayId) {
                        final oldSty = availableStays.where((s) => s.id == prevStayId).firstOrNull;
                        if (oldSty != null && oldSty.linkedActivityIds.contains(activity.id)) {
                          await repo.updateStay(oldSty.copyWith(
                            linkedActivityIds: oldSty.linkedActivityIds.where((id) => id != activity.id).toList(),
                          ));
                        }
                      }

                      if (context.mounted) Navigator.pop(context);
                    },
                    child: Text(isEditing ? 'Save Changes' : 'Add to Day'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
