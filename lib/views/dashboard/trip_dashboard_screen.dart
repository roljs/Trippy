import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/code_generator.dart';
import '../../core/utils/date_formatters.dart';
import '../../models/models.dart';
import '../../services/export_import/file_upload_helper.dart';
import '../../services/export_import/trip_export_service.dart';
import '../../state/trip_providers.dart';
import '../logistics/widgets/transport_header_bridge_widget.dart';

class TripDashboardScreen extends ConsumerWidget {
  final VoidCallback? onTripSelected;

  const TripDashboardScreen({super.key, this.onTripSelected});

  void _showCreateTripDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => _CreateTripDialog(ref: ref),
    );
  }

  void _showJoinTripDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => _JoinTripDialog(ref: ref),
    );
  }

  void _showShareTripModal(BuildContext context, Trip trip, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ShareTripSheet(trip: trip, ref: ref),
    );
  }

  void _showImportDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => _ImportTripDialog(ref: ref),
    );
  }

  void _exportSingleTrip(BuildContext context, WidgetRef ref, Trip trip) async {
    final repo = ref.read(tripRepositoryProvider);
    final bundle = await TripExportService.exportSingleTrip(repo, trip.id);
    if (bundle != null) {
      TripExportService.downloadSingleTrip(bundle);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported "${trip.title}" JSON file!'),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Copy JSON',
              onPressed: () {
                Clipboard.setData(
                    ClipboardData(text: bundle.toJson(pretty: true)));
              },
            ),
          ),
        );
      }
    }
  }

  void _exportAllTrips(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(tripRepositoryProvider);
    final userId = ref.read(currentUserIdProvider);
    final dbBundle = await TripExportService.exportAllTrips(repo, userId);
    TripExportService.downloadAllTrips(dbBundle);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Exported ${dbBundle.trips.length} trip(s) JSON database file!'),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Copy JSON',
            onPressed: () {
              Clipboard.setData(
                  ClipboardData(text: dbBundle.toJson(pretty: true)));
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(userTripsProvider);
    final activeTrip = ref.watch(activeTripProvider);
    final currentUserId = ref.watch(currentUserIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Trips'),
        actions: [
          IconButton(
            tooltip: 'Import Trip(s) from JSON',
            icon: const Icon(Icons.file_upload_outlined),
            onPressed: () => _showImportDialog(context, ref),
          ),
          PopupMenuButton<String>(
            tooltip: 'Trip Database Options',
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) {
              if (value == 'export_all') {
                _exportAllTrips(context, ref);
              } else if (value == 'import') {
                _showImportDialog(context, ref);
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'export_all',
                child: Row(
                  children: [
                    Icon(Icons.file_download_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Export All Trips (.json)'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'import',
                child: Row(
                  children: [
                    Icon(Icons.file_upload_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Import Trip(s) from JSON'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            tooltip: 'Join with Code',
            icon: const Icon(Icons.group_add_rounded),
            onPressed: () => _showJoinTripDialog(context, ref),
          ),
          IconButton(
            tooltip: 'Create New Trip',
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showCreateTripDialog(context, ref),
          ),
        ],
      ),
      body: tripsAsync.when(
        data: (trips) {
          if (trips.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.luggage_outlined,
                      size: 64, color: AppColors.textMuted),
                  const SizedBox(height: 16),
                  const Text(
                    'No trips yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Create your first trip or join one with an invite code!',
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _showCreateTripDialog(context, ref),
                        icon: const Icon(Icons.add),
                        label: const Text('New Trip'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () => _showJoinTripDialog(context, ref),
                        icon: const Icon(Icons.key_rounded),
                        label: const Text('Join Trip'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: trips.length,
            itemBuilder: (context, index) {
              final trip = trips[index];
              final isActive = trip.id == activeTrip?.id;
              final role = trip.getRole(currentUserId) ?? MemberRole.viewer;

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isActive ? AppColors.primary : AppColors.border,
                    width: isActive ? 2 : 1,
                  ),
                ),
                child: InkWell(
                  onTap: () {
                    ref.read(activeTripIdProvider.notifier).selectTrip(trip.id);
                    onTripSelected?.call();
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? AppColors.primaryContainer
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.flight_takeoff_rounded,
                                color: isActive
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          trip.title,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isActive)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            'ACTIVE',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    trip.destination,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Date range & Days count
                        Row(
                          children: [
                            const Icon(Icons.calendar_month_outlined,
                                size: 14, color: AppColors.textMuted),
                            const SizedBox(width: 6),
                            Text(
                              DateFormatters.formatTripDateRange(
                                  trip.startDate, trip.endDate),
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${trip.daysCount} Days',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),

                        // Bottom Action Row: Role Badge + Invite Code + Share Button
                        Row(
                          children: [
                            // Role Badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: role.isOwner
                                    ? const Color(0xFFFEF3C7)
                                    : const Color(0xFFEDE9FE),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                role.displayName.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: role.isOwner
                                      ? const Color(0xFFD97706)
                                      : AppColors.stay,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Invite Code
                            Text(
                              'Code: ${trip.inviteCode}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.share_rounded, size: 20),
                              tooltip: 'Share & Invite Co-Travelers',
                              onPressed: () =>
                                  _showShareTripModal(context, trip, ref),
                            ),
                            IconButton(
                              icon: const Icon(Icons.file_download_outlined,
                                  size: 20),
                              tooltip: 'Export Trip Details (.json)',
                              onPressed: () =>
                                  _exportSingleTrip(context, ref, trip),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _CreateTripDialog extends StatefulWidget {
  final WidgetRef ref;

  const _CreateTripDialog({required this.ref});

  @override
  State<_CreateTripDialog> createState() => _CreateTripDialogState();
}

class _CreateTripDialogState extends State<_CreateTripDialog> {
  final _titleController = TextEditingController();
  final _destinationController = TextEditingController();
  DateTime _startDate = DateTime.now().add(const Duration(days: 7));
  DateTime _endDate = DateTime.now().add(const Duration(days: 14));
  MemberRole _defaultRole = MemberRole.editor;
  TransportType _arrivalMethod = TransportType.flight;
  TransportType _departureMethod = TransportType.flight;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create New Trip'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Trip Name',
                hintText: 'e.g. Summer in Italy',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _destinationController,
              decoration: const InputDecoration(
                labelText: 'Destination',
                hintText: 'e.g. Rome & Florence, Italy',
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Trip Dates',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: () async {
                final range = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2025),
                  lastDate: DateTime(2030),
                  initialDateRange:
                      DateTimeRange(start: _startDate, end: _endDate),
                );
                if (range != null) {
                  setState(() {
                    _startDate = range.start;
                    _endDate = range.end;
                  });
                }
              },
              icon: const Icon(Icons.date_range_rounded, size: 18),
              label: Text(
                DateFormatters.formatTripDateRange(_startDate, _endDate),
                style: const TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(height: 16),

            // Primary Arrival Method
            const Text(
              'Primary Arrival Method (Day 1)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'How will you get to your initial destination?',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final method in TransportType.values)
                  ChoiceChip(
                    avatar: Icon(
                      method.icon,
                      size: 16,
                      color: _arrivalMethod == method
                          ? Colors.white
                          : AppColors.primary,
                    ),
                    label: Text(
                      method.displayName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: _arrivalMethod == method
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: _arrivalMethod == method
                            ? Colors.white
                            : Colors.grey.shade800,
                      ),
                    ),
                    selected: _arrivalMethod == method,
                    selectedColor: AppColors.primary,
                    backgroundColor: Colors.grey.shade100,
                    showCheckmark: false,
                    onSelected: (selected) {
                      if (selected) setState(() => _arrivalMethod = method);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Return Departure Method
            const Text(
              'Return Departure Method (Final Day)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'How will you depart or return home?',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final method in TransportType.values)
                  ChoiceChip(
                    avatar: Icon(
                      method.icon,
                      size: 16,
                      color: _departureMethod == method
                          ? Colors.white
                          : AppColors.primary,
                    ),
                    label: Text(
                      method.displayName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: _departureMethod == method
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: _departureMethod == method
                            ? Colors.white
                            : Colors.grey.shade800,
                      ),
                    ),
                    selected: _departureMethod == method,
                    selectedColor: const Color(0xFFBE123C),
                    backgroundColor: Colors.grey.shade100,
                    showCheckmark: false,
                    onSelected: (selected) {
                      if (selected) setState(() => _departureMethod = method);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),

            const Text(
              'Default Role for Joining Co-Travelers',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            SegmentedButton<MemberRole>(
              segments: const [
                ButtonSegment(
                  value: MemberRole.editor,
                  label: Text('Editor'),
                  icon: Icon(Icons.edit_rounded, size: 16),
                ),
                ButtonSegment(
                  value: MemberRole.viewer,
                  label: Text('Viewer'),
                  icon: Icon(Icons.visibility_rounded, size: 16),
                ),
              ],
              selected: {_defaultRole},
              onSelectionChanged: (set) {
                setState(() => _defaultRole = set.first);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_titleController.text.trim().isEmpty) return;

            final currentUserId =
                widget.ref.read(currentUserIdProvider);
            final repo = widget.ref.read(tripRepositoryProvider);

            final targetDest = _destinationController.text.trim().isEmpty
                ? _titleController.text.trim()
                : _destinationController.text.trim();

            final newTrip = Trip(
              id: 'trip_${DateTime.now().millisecondsSinceEpoch}',
              title: _titleController.text.trim(),
              destination: targetDest,
              startDate: _startDate,
              endDate: _endDate,
              ownerId: currentUserId,
              inviteCode: CodeGenerator.generateInviteCode(),
              defaultInviteRole: _defaultRole,
              members: {currentUserId: MemberRole.owner},
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

            await repo.createTrip(newTrip);

            // Create Arrival Placeholder Entry
            if (_arrivalMethod == TransportType.flight) {
              final placeholderFlight = Flight(
                id: 'flt_arr_${newTrip.id}',
                tripId: newTrip.id,
                airline: 'Arrival Airline (TBD)',
                flightNumber: 'FLIGHT TBD',
                departureAirport: 'Origin City',
                arrivalAirport: targetDest,
                departureTime: DateTime(
                    _startDate.year, _startDate.month, _startDate.day, 8, 0),
                arrivalTime: DateTime(
                    _startDate.year, _startDate.month, _startDate.day, 11, 30),
                isMainArrival: true,
                bookingRef: 'PENDING',
                notes:
                    'Primary arrival flight placeholder. Tap to update flight numbers and schedule.',
              );
              await repo.addFlight(placeholderFlight);

              final placeholderActivity = Activity(
                id: 'act_arr_${newTrip.id}',
                tripId: newTrip.id,
                date: _startDate,
                startTime: '11:30',
                title: 'Arrival Flight (TBD)',
                category: ActivityCategory.flight,
                location: targetDest,
                bookingStatus: BookingStatus.planned,
                notes: 'Scheduled arrival flight to initial destination.',
              );
              await repo.addActivity(placeholderActivity);
            } else {
              final placeholderActivity = Activity(
                id: 'act_arr_${newTrip.id}',
                tripId: newTrip.id,
                date: _startDate,
                startTime: '11:30',
                title: 'Arrival by ${_arrivalMethod.displayName}',
                category: ActivityCategory.transport,
                location: targetDest,
                bookingStatus: BookingStatus.planned,
                notes:
                    'Primary arrival transport placeholder. Tap to update details.',
              );
              await repo.addActivity(placeholderActivity);
            }

            // Create Departure Placeholder Entry
            if (_departureMethod == TransportType.flight) {
              final placeholderFlight = Flight(
                id: 'flt_dep_${newTrip.id}',
                tripId: newTrip.id,
                airline: 'Return Airline (TBD)',
                flightNumber: 'FLIGHT TBD',
                departureAirport: targetDest,
                arrivalAirport: 'Home City',
                departureTime: DateTime(
                    _endDate.year, _endDate.month, _endDate.day, 18, 0),
                arrivalTime: DateTime(
                    _endDate.year, _endDate.month, _endDate.day, 21, 30),
                isMainDeparture: true,
                bookingRef: 'PENDING',
                notes:
                    'Return departure flight placeholder. Tap to update flight numbers and schedule.',
              );
              await repo.addFlight(placeholderFlight);

              final placeholderActivity = Activity(
                id: 'act_dep_${newTrip.id}',
                tripId: newTrip.id,
                date: _endDate,
                startTime: '18:00',
                title: 'Departure Flight (TBD)',
                category: ActivityCategory.flight,
                location: targetDest,
                bookingStatus: BookingStatus.planned,
                notes: 'Scheduled departure flight returning from trip.',
              );
              await repo.addActivity(placeholderActivity);
            } else {
              final placeholderActivity = Activity(
                id: 'act_dep_${newTrip.id}',
                tripId: newTrip.id,
                date: _endDate,
                startTime: '18:00',
                title: 'Departure by ${_departureMethod.displayName}',
                category: ActivityCategory.transport,
                location: targetDest,
                bookingStatus: BookingStatus.planned,
                notes:
                    'Return departure transport placeholder. Tap to update details.',
              );
              await repo.addActivity(placeholderActivity);
            }

            widget.ref
                .read(activeTripIdProvider.notifier)
                .selectTrip(newTrip.id);

            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Create Trip'),
        ),
      ],
    );
  }
}

class _JoinTripDialog extends StatefulWidget {
  final WidgetRef ref;

  const _JoinTripDialog({required this.ref});

  @override
  State<_JoinTripDialog> createState() => _JoinTripDialogState();
}

class _JoinTripDialogState extends State<_JoinTripDialog> {
  final _codeController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Join a Trip'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enter the 6-character invitation code provided by the trip owner:',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _codeController,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\-]')),
            ],
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              fontFamily: 'monospace',
            ),
            decoration: InputDecoration(
              labelText: 'Invite Code',
              hintText: 'e.g. TYO-8821',
              errorText: _error,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading
              ? null
              : () async {
                  final code = _codeController.text.trim();
                  if (code.isEmpty) return;

                  setState(() {
                    _isLoading = true;
                    _error = null;
                  });

                  final repo = widget.ref.read(tripRepositoryProvider);
                  final userId = widget.ref.read(currentUserIdProvider);

                  final success = await repo.joinTripWithCode(code, userId);

                  if (success) {
                    final joinedTrip = await repo.getTripByInviteCode(code);
                    if (joinedTrip != null) {
                      widget.ref.read(activeTripIdProvider.notifier).selectTrip(joinedTrip.id);
                    }
                    if (context.mounted) Navigator.pop(context);
                  } else {
                    setState(() {
                      _isLoading = false;
                      _error = 'Invalid invite code. Please check and try again.';
                    });
                  }
                },
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Join Trip'),
        ),
      ],
    );
  }
}

class _ShareTripSheet extends StatefulWidget {
  final Trip trip;
  final WidgetRef ref;

  const _ShareTripSheet({required this.trip, required this.ref});

  @override
  State<_ShareTripSheet> createState() => _ShareTripSheetState();
}

class _ShareTripSheetState extends State<_ShareTripSheet> {
  late MemberRole _currentRole;

  @override
  void initState() {
    super.initState();
    _currentRole = widget.trip.defaultInviteRole;
  }

  @override
  Widget build(BuildContext context) {
    final repo = widget.ref.read(tripRepositoryProvider);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Invite Co-Travelers',
                style: TextStyle(
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
          const SizedBox(height: 8),
          Text(
            'Share this code with friends or family traveling on "${widget.trip.title}".',
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),

          // Big Code Display Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TRIP INVITATION CODE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.trip.inviteCode,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                        letterSpacing: 2,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: widget.trip.inviteCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Invite code copied to clipboard!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copy'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Owner Configures the Default Joining Role (Single Code with configurable role!)
          const Text(
            'Configured Role for This Code',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<MemberRole>(
            segments: const [
              ButtonSegment(
                value: MemberRole.editor,
                label: Text('Editor (Can edit itinerary)'),
                icon: Icon(Icons.edit_rounded, size: 16),
              ),
              ButtonSegment(
                value: MemberRole.viewer,
                label: Text('Viewer (Read-only)'),
                icon: Icon(Icons.visibility_rounded, size: 16),
              ),
            ],
            selected: {_currentRole},
            onSelectionChanged: (set) async {
              setState(() => _currentRole = set.first);
              final updated = widget.trip.copyWith(
                defaultInviteRole: _currentRole,
                updatedAt: DateTime.now(),
              );
              await repo.updateTrip(updated);
            },
          ),
          const SizedBox(height: 16),

          // Current Trip Members List
          const Text(
            'Current Trip Collaborators',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          ...widget.trip.members.entries.map((entry) {
            final userId = entry.key;
            final role = entry.value;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.grey.shade200,
                    child: const Icon(Icons.person, size: 16, color: Colors.grey),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    userId == 'user_current' ? 'You (Current User)' : userId,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: role.isOwner
                          ? const Color(0xFFFEF3C7)
                          : const Color(0xFFEDE9FE),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      role.displayName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: role.isOwner ? const Color(0xFFD97706) : AppColors.stay,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _ImportTripDialog extends StatefulWidget {
  final WidgetRef ref;

  const _ImportTripDialog({required this.ref});

  @override
  State<_ImportTripDialog> createState() => _ImportTripDialogState();
}

class _ImportTripDialogState extends State<_ImportTripDialog> {
  final _jsonController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _jsonController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final content = await pickJsonFile();
      if (content != null && content.isNotEmpty) {
        setState(() {
          _jsonController.text = content;
          _error = null;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Could not read selected file: $e';
      });
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      setState(() {
        _jsonController.text = data.text!;
        _error = null;
      });
    }
  }

  Future<void> _performImport() async {
    final text = _jsonController.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Please upload a JSON file or paste JSON text');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repo = widget.ref.read(tripRepositoryProvider);
      final userId = widget.ref.read(currentUserIdProvider);

      final result = await TripExportService.importFromJson(repo, text, userId);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            duration: const Duration(seconds: 4),
            backgroundColor: const Color(0xFF15803D),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Import error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.file_upload_outlined, color: AppColors.primary),
          SizedBox(width: 8),
          Text('Import Trip(s) from JSON'),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Upload a .json file exported from Trippy, or paste JSON content below. Both single trip bundles and full multi-trip exports are supported.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _pickFile,
                    icon: const Icon(Icons.folder_open_rounded, size: 16),
                    label: const Text('Choose .json File'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _pasteFromClipboard,
                    icon: const Icon(Icons.paste_rounded, size: 16),
                    label: const Text('Paste from Clipboard'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _jsonController,
                maxLines: 9,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
                decoration: InputDecoration(
                  hintText: '{\n  "version": 1,\n  "trip": { ... },\n  "stays": [ ... ]\n}',
                  labelText: 'Trip JSON Payload',
                  alignLabelWithHint: true,
                  errorText: _error,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _performImport,
          icon: _isLoading
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.check_rounded, size: 16),
          label: const Text('Import Trips'),
        ),
      ],
    );
  }
}

