import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_formatters.dart';
import '../../models/models.dart';
import '../../state/trip_providers.dart';
import 'add_activity_sheet.dart';

class AddStaySheet extends ConsumerStatefulWidget {
  final Stay? stayToEdit;
  final DateTime? initialCheckInDate;
  final DateTime? initialCheckOutDate;

  const AddStaySheet({
    super.key,
    this.stayToEdit,
    this.initialCheckInDate,
    this.initialCheckOutDate,
  });

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
  bool _createCheckInOutActivities = true;
  bool? _userSetCheckInOut;

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
      final defaultStart = activeTrip?.startDate ?? DateTime.now();
      _checkInDate = widget.initialCheckInDate ?? defaultStart;
      _checkOutDate = widget.initialCheckOutDate ??
          DateTime(_checkInDate.year, _checkInDate.month, _checkInDate.day + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeTrip = ref.watch(activeTripProvider);
    final repo = ref.watch(tripRepositoryProvider);
    final isEditing = widget.stayToEdit != null;

    if (activeTrip == null) return const SizedBox.shrink();

    final isOvernightFlight = _stayType == StayType.overnightFlight;
    final allActivities = ref.watch(activeTripActivitiesProvider).value ?? [];
    final linkedActivities = isEditing
        ? allActivities.where((a) =>
            widget.stayToEdit!.linkedActivityIds.contains(a.id) ||
            a.stayId == widget.stayToEdit!.id).toList()
        : <Activity>[];

    final checkInActs = linkedActivities.where((a) {
      final title = a.title.toLowerCase();
      return title.contains('check-in') ||
          title.contains('check in') ||
          a.id.endsWith('_in');
    }).toList();

    final checkOutActs = linkedActivities.where((a) {
      final title = a.title.toLowerCase();
      return title.contains('check-out') ||
          title.contains('checkout') ||
          title.contains('check out') ||
          a.id.endsWith('_out');
    }).toList();

    final hasLinkedCheckIn = checkInActs.isNotEmpty;
    final hasLinkedCheckOut = checkOutActs.isNotEmpty;

    if (_userSetCheckInOut == null && isEditing) {
      _createCheckInOutActivities = (hasLinkedCheckIn || hasLinkedCheckOut);
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
                '${DateFormatters.shortDate.format(_checkInDate)} → ${DateFormatters.shortDate.format(_checkOutDate)} (${DateTime.utc(_checkOutDate.year, _checkOutDate.month, _checkOutDate.day).difference(DateTime.utc(_checkInDate.year, _checkInDate.month, _checkInDate.day)).inDays} nights)',
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
            const SizedBox(height: 14),

            // Linked Check-in / Check-out Activities Section (shown when editing or when linked activities exist)
            if (linkedActivities.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.stayContainer.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.stay.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.hotel_rounded, size: 16, color: AppColors.stay),
                            const SizedBox(width: 6),
                            Text(
                              'Linked Check-in / Check-out Activities (${linkedActivities.length})',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.stay,
                              ),
                            ),
                          ],
                        ),
                        if (widget.stayToEdit != null)
                          InkWell(
                            onTap: () => _showLinkActivityDialog(context, ref, widget.stayToEdit!, allActivities),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.stay.withValues(alpha: 0.4)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add_link_rounded, size: 13, color: AppColors.stay),
                                  SizedBox(width: 4),
                                  Text(
                                    'Link Activity',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.stay,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...linkedActivities.map((act) {
                      final isCheckIn = act.title.toLowerCase().contains('check-in') ||
                          act.title.toLowerCase().contains('check in') ||
                          act.id.endsWith('_in');
                      final isCheckOut = act.title.toLowerCase().contains('check-out') ||
                          act.title.toLowerCase().contains('checkout') ||
                          act.id.endsWith('_out');
                      final icon = isCheckIn
                          ? Icons.login_rounded
                          : (isCheckOut ? Icons.logout_rounded : Icons.hotel_rounded);

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
                              builder: (ctx) => AddActivitySheet(activityToEdit: act),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            child: Row(
                              children: [
                                Icon(icon, size: 16, color: AppColors.stay),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        act.title,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        '${DateFormatters.shortDate.format(act.date)}  •  ${DateFormatters.formatTimeString(act.startTime)}${act.location != null ? "  •  ${act.location}" : ""}',
                                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.textMuted),
                                if (widget.stayToEdit != null) ...[
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(Icons.link_off_rounded, size: 16, color: Colors.red),
                                    tooltip: 'Unlink Activity',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () async {
                                      final remainingIds = widget.stayToEdit!.linkedActivityIds.where((id) => id != act.id).toList();
                                      await repo.updateStay(widget.stayToEdit!.copyWith(linkedActivityIds: remainingIds));
                                      await repo.updateActivity(act.copyWith(stayId: null));
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

            // Option to auto-create / sync check-in and check-out activities
            if (!isOvernightFlight) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: _createCheckInOutActivities
                      ? AppColors.stayContainer.withValues(alpha: 0.35)
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _createCheckInOutActivities
                        ? AppColors.stay.withValues(alpha: 0.4)
                        : Colors.grey.shade300,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: CheckboxListTile(
                    value: _createCheckInOutActivities,
                    activeColor: AppColors.stay,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    title: Text(
                      (hasLinkedCheckIn && hasLinkedCheckOut)
                          ? 'Sync linked Check-in & Check-out activities'
                          : (hasLinkedCheckIn || hasLinkedCheckOut)
                              ? 'Update linked activity & create missing check-in/out'
                              : 'Automatically create Check-in & Check-out activities',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      (hasLinkedCheckIn && hasLinkedCheckOut)
                          ? 'Keeps linked activities in sync with Check-in (${DateFormatters.shortDate.format(_checkInDate)} at $_checkInTime) and Check-out (${DateFormatters.shortDate.format(_checkOutDate)} at $_checkOutTime) without duplicates'
                          : 'Schedules Check-in on ${DateFormatters.shortDate.format(_checkInDate)} at $_checkInTime, and Check-out on ${DateFormatters.shortDate.format(_checkOutDate)} at $_checkOutTime',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _userSetCheckInOut = val ?? false;
                        _createCheckInOutActivities = val ?? false;
                      });
                    },
                  ),
                ),
              ),
            ],

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

                      final stayId = widget.stayToEdit?.id ??
                          'stay_${DateTime.now().millisecondsSinceEpoch}';
                      final initialLinkedActivityIds =
                          List<String>.from(widget.stayToEdit?.linkedActivityIds ?? []);

                      if (_createCheckInOutActivities && !isOvernightFlight) {
                        // 1. Check-In: update existing or create new without duplicates
                        if (checkInActs.isNotEmpty) {
                          final existingCheckIn = checkInActs.first;
                          await repo.updateActivity(existingCheckIn.copyWith(
                            stayId: stayId,
                            date: _checkInDate,
                            startTime: _checkInTime,
                            title: 'Check-in: $name',
                            location: _addressController.text.trim().isEmpty
                                ? name
                                : _addressController.text.trim(),
                            bookingStatus: BookingStatus.booked,
                            confirmationRef: _confirmationController.text.trim().isEmpty
                                ? null
                                : _confirmationController.text.trim(),
                            notes: _notesController.text.trim().isEmpty
                                ? null
                                : _notesController.text.trim(),
                          ));
                          if (!initialLinkedActivityIds.contains(existingCheckIn.id)) {
                            initialLinkedActivityIds.add(existingCheckIn.id);
                          }
                        } else {
                          final inActId = 'act_${DateTime.now().millisecondsSinceEpoch}_in';
                          final checkInAct = Activity(
                            id: inActId,
                            tripId: activeTrip.id,
                            date: _checkInDate,
                            startTime: _checkInTime,
                            title: 'Check-in: $name',
                            category: ActivityCategory.stay,
                            location: _addressController.text.trim().isEmpty
                                ? name
                                : _addressController.text.trim(),
                            bookingStatus: BookingStatus.booked,
                            confirmationRef: _confirmationController.text.trim().isEmpty
                                ? null
                                : _confirmationController.text.trim(),
                            notes: _notesController.text.trim().isEmpty
                                ? null
                                : _notesController.text.trim(),
                            stayId: stayId,
                          );
                          await repo.addActivity(checkInAct);
                          if (!initialLinkedActivityIds.contains(inActId)) {
                            initialLinkedActivityIds.add(inActId);
                          }
                        }

                        // 2. Check-Out: update existing or create new without duplicates
                        if (checkOutActs.isNotEmpty) {
                          final existingCheckOut = checkOutActs.first;
                          await repo.updateActivity(existingCheckOut.copyWith(
                            stayId: stayId,
                            date: _checkOutDate,
                            startTime: _checkOutTime,
                            title: 'Check-out: $name',
                            location: _addressController.text.trim().isEmpty
                                ? name
                                : _addressController.text.trim(),
                            bookingStatus: BookingStatus.booked,
                            confirmationRef: _confirmationController.text.trim().isEmpty
                                ? null
                                : _confirmationController.text.trim(),
                            notes: _notesController.text.trim().isEmpty
                                ? null
                                : _notesController.text.trim(),
                          ));
                          if (!initialLinkedActivityIds.contains(existingCheckOut.id)) {
                            initialLinkedActivityIds.add(existingCheckOut.id);
                          }
                        } else {
                          final outActId = 'act_${DateTime.now().millisecondsSinceEpoch + 1}_out';
                          final checkOutAct = Activity(
                            id: outActId,
                            tripId: activeTrip.id,
                            date: _checkOutDate,
                            startTime: _checkOutTime,
                            title: 'Check-out: $name',
                            category: ActivityCategory.stay,
                            location: _addressController.text.trim().isEmpty
                                ? name
                                : _addressController.text.trim(),
                            bookingStatus: BookingStatus.booked,
                            confirmationRef: _confirmationController.text.trim().isEmpty
                                ? null
                                : _confirmationController.text.trim(),
                            notes: _notesController.text.trim().isEmpty
                                ? null
                                : _notesController.text.trim(),
                            stayId: stayId,
                          );
                          await repo.addActivity(checkOutAct);
                          if (!initialLinkedActivityIds.contains(outActId)) {
                            initialLinkedActivityIds.add(outActId);
                          }
                        }
                      }

                      final finalLinkedIds = initialLinkedActivityIds.toSet().toList();

                      final stay = Stay(
                        id: stayId,
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
                        linkedActivityIds: finalLinkedIds,
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

  void _showLinkActivityDialog(BuildContext context, WidgetRef ref, Stay stay, List<Activity> activities) {
    final availableToLink = activities.where((a) =>
      !stay.linkedActivityIds.contains(a.id) && a.stayId != stay.id
    ).toList()
      ..sort((a, b) {
        if (a.category == ActivityCategory.stay && b.category != ActivityCategory.stay) return -1;
        if (a.category != ActivityCategory.stay && b.category == ActivityCategory.stay) return 1;
        return a.date.compareTo(b.date);
      });

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.add_link_rounded, color: AppColors.stay, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Link Activity to ${stay.name}',
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
                    'No available activities to link. Create a stay or other activity first.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: availableToLink.length,
                  itemBuilder: (context, idx) {
                    final act = availableToLink[idx];
                    final isCheckIn = act.title.toLowerCase().contains('check-in') || act.title.toLowerCase().contains('check in');
                    final isCheckOut = act.title.toLowerCase().contains('check-out') || act.title.toLowerCase().contains('checkout');
                    final icon = isCheckIn
                        ? Icons.login_rounded
                        : (isCheckOut ? Icons.logout_rounded : Icons.hotel_rounded);

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      leading: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.stayContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(icon, size: 16, color: AppColors.stay),
                      ),
                      title: Text(
                        act.title,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${DateFormatters.shortDate.format(act.date)}  •  ${DateFormatters.formatTimeString(act.startTime)}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: const Icon(Icons.add_circle_outline_rounded, color: AppColors.stay, size: 20),
                      onTap: () async {
                        final repo = ref.read(tripRepositoryProvider);
                        final updatedLinks = {...stay.linkedActivityIds, act.id}.toList();
                        await repo.updateStay(stay.copyWith(linkedActivityIds: updatedLinks));
                        await repo.updateActivity(act.copyWith(stayId: stay.id));
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
