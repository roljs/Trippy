import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_formatters.dart';
import '../../models/models.dart';
import '../../state/trip_providers.dart';

class AddStaySheet extends ConsumerStatefulWidget {
  final Stay? stayToEdit;

  const AddStaySheet({super.key, this.stayToEdit});

  @override
  ConsumerState<AddStaySheet> createState() => _AddStaySheetState();
}

class _AddStaySheetState extends ConsumerState<AddStaySheet> {
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _confirmationController = TextEditingController();
  final _notesController = TextEditingController();

  // Overnight Flight fields
  final _flightAirlineController = TextEditingController();
  final _flightNumController = TextEditingController();
  final _flightOriginController = TextEditingController();
  final _flightDestController = TextEditingController();

  late StayType _stayType;
  late DateTime _checkInDate;
  late DateTime _checkOutDate;
  String _checkInTime = '15:00';
  String _checkOutTime = '11:00';

  @override
  void initState() {
    super.initState();
    final edit = widget.stayToEdit;
    if (edit != null) {
      _stayType = edit.type;
      _nameController.text = edit.name;
      _addressController.text = edit.address ?? '';
      _confirmationController.text = edit.confirmationCode ?? '';
      _notesController.text = edit.notes ?? '';
      _checkInDate = edit.checkInDate;
      _checkOutDate = edit.checkOutDate;
      _checkInTime = edit.checkInTime ?? '15:00';
      _checkOutTime = edit.checkOutTime ?? '11:00';

      if (edit.overnightFlight != null) {
        _flightAirlineController.text = edit.overnightFlight!.airline;
        _flightNumController.text = edit.overnightFlight!.flightNumber;
        _flightOriginController.text = edit.overnightFlight!.departureAirport;
        _flightDestController.text = edit.overnightFlight!.arrivalAirport;
      }
    } else {
      _stayType = StayType.hotel;
      final activeTrip = ref.read(activeTripProvider);
      _checkInDate = activeTrip?.startDate ?? DateTime.now();
      _checkOutDate = _checkInDate.add(const Duration(days: 2));
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeTrip = ref.watch(activeTripProvider);
    final repo = ref.watch(tripRepositoryProvider);
    final isEditing = widget.stayToEdit != null;

    if (activeTrip == null) return const SizedBox.shrink();

    final isOvernightFlight = _stayType == StayType.overnightFlight;

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
                  isEditing ? 'Edit Stay / Transition' : 'Add Stay / Transition',
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

            // Stay Type Segmented Button
            const Text(
              'Stay / Transition Type',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            SegmentedButton<StayType>(
              segments: const [
                ButtonSegment(
                  value: StayType.hotel,
                  label: Text('Hotel'),
                  icon: Icon(Icons.hotel_rounded, size: 16),
                ),
                ButtonSegment(
                  value: StayType.rental,
                  label: Text('Rental'),
                  icon: Icon(Icons.holiday_village_rounded, size: 16),
                ),
                ButtonSegment(
                  value: StayType.overnightFlight,
                  label: Text('Night Flight'),
                  icon: Icon(Icons.flight_takeoff_rounded, size: 16),
                ),
              ],
              selected: {_stayType},
              onSelectionChanged: (set) {
                setState(() => _stayType = set.first);
              },
            ),
            const SizedBox(height: 16),

            // Dates Spanned
            const Text(
              'Dates of Transition / Stay',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: () async {
                final range = await showDateRangePicker(
                  context: context,
                  firstDate: activeTrip.startDate.subtract(const Duration(days: 2)),
                  lastDate: activeTrip.endDate.add(const Duration(days: 2)),
                  initialDateRange:
                      DateTimeRange(start: _checkInDate, end: _checkOutDate),
                );
                if (range != null) {
                  setState(() {
                    _checkInDate = range.start;
                    _checkOutDate = range.end;
                  });
                }
              },
              icon: const Icon(Icons.calendar_month_rounded, size: 18),
              label: Text(
                '${DateFormatters.shortDate.format(_checkInDate)} → ${DateFormatters.shortDate.format(_checkOutDate)} (${_checkOutDate.difference(_checkInDate).inDays} nights)',
                style: const TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(height: 16),

            if (!isOvernightFlight) ...[
              // Hotel / Rental Fields
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Lodging Name',
                  hintText: 'e.g. Grand Hyatt Tokyo',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  hintText: 'e.g. 6-10-3 Roppongi, Minato City',
                  prefixIcon: Icon(Icons.location_on_outlined, size: 18),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Check-in Time',
                        hintText: '15:00',
                      ),
                      onChanged: (val) => _checkInTime = val,
                      controller: TextEditingController(text: _checkInTime),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Check-out Time',
                        hintText: '11:00',
                      ),
                      onChanged: (val) => _checkOutTime = val,
                      controller: TextEditingController(text: _checkOutTime),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirmationController,
                decoration: const InputDecoration(
                  labelText: 'Confirmation Code',
                  hintText: 'e.g. GH-82910',
                ),
              ),
            ] else ...[
              // Overnight Flight Fields
              TextField(
                controller: _flightAirlineController,
                decoration: const InputDecoration(
                  labelText: 'Airline',
                  hintText: 'e.g. Japan Airlines',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _flightNumController,
                decoration: const InputDecoration(
                  labelText: 'Flight Number',
                  hintText: 'e.g. JL060',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _flightOriginController,
                      decoration: const InputDecoration(
                        labelText: 'Origin Airport',
                        hintText: 'e.g. KIX',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _flightDestController,
                      decoration: const InputDecoration(
                        labelText: 'Destination Airport',
                        hintText: 'e.g. SFO',
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),

            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notes',
                hintText: 'e.g. Late arrival confirmed with front desk',
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
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete Stay'),
                          content: Text(
                              'Are you sure you want to remove "${widget.stayToEdit!.name}"?'),
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
                        await repo.deleteStay(
                            activeTrip.id, widget.stayToEdit!.id);
                        if (context.mounted) Navigator.pop(context);
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final name = isOvernightFlight
                          ? 'Flight ${_flightNumController.text.trim()} (Overnight)'
                          : _nameController.text.trim();

                      if (name.isEmpty) return;

                      Flight? overnightFlightObj;
                      if (isOvernightFlight) {
                        overnightFlightObj = Flight(
                          id: 'flt_${DateTime.now().millisecondsSinceEpoch}',
                          tripId: activeTrip.id,
                          airline: _flightAirlineController.text.trim().isEmpty
                              ? 'Airline'
                              : _flightAirlineController.text.trim(),
                          flightNumber: _flightNumController.text.trim(),
                          departureAirport: _flightOriginController.text.trim(),
                          arrivalAirport: _flightDestController.text.trim(),
                          departureTime: DateTime(
                            _checkInDate.year,
                            _checkInDate.month,
                            _checkInDate.day,
                            21,
                            0,
                          ),
                          arrivalTime: DateTime(
                            _checkOutDate.year,
                            _checkOutDate.month,
                            _checkOutDate.day,
                            14,
                            0,
                          ),
                          isOvernight: true,
                        );
                      }

                      final stay = Stay(
                        id: widget.stayToEdit?.id ??
                            'stay_${DateTime.now().millisecondsSinceEpoch}',
                        tripId: activeTrip.id,
                        type: _stayType,
                        name: name,
                        address: _addressController.text.trim().isEmpty
                            ? null
                            : _addressController.text.trim(),
                        checkInDate: _checkInDate,
                        checkInTime: _checkInTime,
                        checkOutDate: _checkOutDate,
                        checkOutTime: _checkOutTime,
                        confirmationCode:
                            _confirmationController.text.trim().isEmpty
                                ? null
                                : _confirmationController.text.trim(),
                        notes: _notesController.text.trim().isEmpty
                            ? null
                            : _notesController.text.trim(),
                        overnightFlight: overnightFlightObj,
                      );

                      if (isEditing) {
                        await repo.updateStay(stay);
                      } else {
                        await repo.addStay(stay);
                      }

                      if (context.mounted) Navigator.pop(context);
                    },
                    child: Text(isEditing ? 'Save Changes' : 'Add Stay Bridge'),
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
