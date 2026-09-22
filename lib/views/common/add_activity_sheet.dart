import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_formatters.dart';
import '../../models/models.dart';
import '../../state/trip_providers.dart';

class AddActivitySheet extends ConsumerStatefulWidget {
  final Activity? activityToEdit;

  const AddActivitySheet({super.key, this.activityToEdit});

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
      _category = ActivityCategory.attraction;
      _bookingStatus = BookingStatus.planned;
      final activeTrip = ref.read(activeTripProvider);
      _selectedDate = activeTrip?.startDate ?? DateTime.now();
    }
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    final h = tod.hour.toString().padLeft(2, '0');
    final m = tod.minute.toString().padLeft(2, '0');
    return '$h:$m';
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
                    if (val) setState(() => _category = cat);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // Date selector
            const Text(
              'Day in Itinerary',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<DateTime>(
              initialValue: tripDays.contains(_selectedDate)
                  ? _selectedDate
                  : tripDays.first,
              decoration: const InputDecoration(
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                      );

                      if (isEditing) {
                        await repo.updateActivity(activity);
                      } else {
                        await repo.addActivity(activity);
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
