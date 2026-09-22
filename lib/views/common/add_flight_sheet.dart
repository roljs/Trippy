import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_formatters.dart';
import '../../models/models.dart';
import '../../state/trip_providers.dart';

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
  bool _isNightStay = false;
  bool _isMainArrival = false;
  bool _isMainDeparture = false;

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
      _isNightStay = edit.isNightStay;
      _isMainArrival = edit.isMainArrival;
      _isMainDeparture = edit.isMainDeparture;
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

    if (activeTrip == null) return const SizedBox.shrink();

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
                    decoration: const InputDecoration(
                      labelText: 'Arrival Airport',
                      hintText: 'e.g. HND',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Departure Time Picker
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                        child: Text(
                          '${DateFormatters.shortDate.format(_depDateTime)} ${DateFormatters.time12.format(_depDateTime)}',
                          style: const TextStyle(fontSize: 12),
                        ),
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
                        child: Text(
                          '${DateFormatters.shortDate.format(_arrDateTime)} ${DateFormatters.time12.format(_arrDateTime)}',
                          style: const TextStyle(fontSize: 12),
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
            const SizedBox(height: 18),
            const Divider(height: 1),
            const SizedBox(height: 16),

            const Text(
              'Itinerary Role & Special Characteristics',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),

            // 1. Night / Stay Flight Switch
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: _isNightStay ? const Color(0xFFEFF6FF) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isNightStay ? const Color(0xFF0284C7) : Colors.grey.shade200,
                ),
              ),
              child: SwitchListTile(
                value: _isNightStay,
                onChanged: (val) => setState(() {
                  _isNightStay = val;
                  if (val) {
                    _isMainArrival = false;
                    _isMainDeparture = false;
                  }
                }),
                title: const Row(
                  children: [
                    Text('🌙  ', style: TextStyle(fontSize: 14)),
                    Text(
                      'Night / Stay Flight',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                subtitle: const Text(
                  'Shows as an overnight lodging stay header in the Itinerary view.',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                dense: true,
              ),
            ),

            // 2. Main Arrival Flight Switch
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: _isMainArrival ? const Color(0xFFEFF6FF) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isMainArrival ? const Color(0xFF0284C7) : Colors.grey.shade200,
                ),
              ),
              child: SwitchListTile(
                value: _isMainArrival,
                onChanged: (val) => setState(() {
                  _isMainArrival = val;
                  if (val) {
                    _isNightStay = false;
                    _isMainDeparture = false;
                  }
                }),
                title: const Row(
                  children: [
                    Text('✈️  ', style: TextStyle(fontSize: 14)),
                    Text(
                      'Main Arrival Flight',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                subtitle: const Text(
                  'Shows as the primary Arrival header on Day 1 in the Itinerary view.',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                dense: true,
              ),
            ),

            // 3. Main Departure Flight Switch
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: _isMainDeparture ? const Color(0xFFFFF1F2) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isMainDeparture ? const Color(0xFFF43F5E) : Colors.grey.shade200,
                ),
              ),
              child: SwitchListTile(
                value: _isMainDeparture,
                onChanged: (val) => setState(() {
                  _isMainDeparture = val;
                  if (val) {
                    _isNightStay = false;
                    _isMainArrival = false;
                  }
                }),
                title: const Row(
                  children: [
                    Text('🛫  ', style: TextStyle(fontSize: 14)),
                    Text(
                      'Main Departure Flight',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                subtitle: const Text(
                  'Shows as the primary Departure header on the final day in the Itinerary view.',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                dense: true,
              ),
            ),

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
                            activeTrip.id, widget.flightToEdit!.id);
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

                      // If marking as main arrival or main departure, clear previous flags on other flights
                      if (_isMainArrival || _isMainDeparture) {
                        final currentFlights =
                            await repo.getFlights(activeTrip.id);
                        for (final f in currentFlights) {
                          if (f.id != newFlightId) {
                            bool changed = false;
                            bool arr = f.isMainArrival;
                            bool dep = f.isMainDeparture;
                            if (_isMainArrival && arr) {
                              arr = false;
                              changed = true;
                            }
                            if (_isMainDeparture && dep) {
                              dep = false;
                              changed = true;
                            }
                            if (changed) {
                              await repo.updateFlight(f.copyWith(
                                isMainArrival: arr,
                                isMainDeparture: dep,
                              ));
                            }
                          }
                        }
                      }

                      final flight = Flight(
                        id: newFlightId,
                        tripId: activeTrip.id,
                        airline: _airlineController.text.trim(),
                        flightNumber: _flightNumController.text.trim(),
                        departureAirport: _originController.text.trim(),
                        arrivalAirport: _destController.text.trim(),
                        departureTime: _depDateTime,
                        arrivalTime: _arrDateTime,
                        isOvernight: _arrDateTime.day != _depDateTime.day,
                        isNightStay: _isNightStay,
                        isMainArrival: _isMainArrival,
                        isMainDeparture: _isMainDeparture,
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
}
