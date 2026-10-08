import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/city_color_helper.dart';
import '../../core/utils/date_formatters.dart';
import '../../core/utils/location_inference_helper.dart';
import '../../models/models.dart';
import '../../state/trip_providers.dart';
import '../common/add_activity_sheet.dart';
import '../common/add_flight_sheet.dart';
import '../common/add_stay_sheet.dart';
import '../logistics/widgets/manage_day_locations_dialog.dart';
import 'widgets/day_planner_map_panel.dart';

class DayPlannerView extends ConsumerStatefulWidget {
  final void Function([DateTime? initialDate, Activity? activityToEdit])?
      onOpenAddActivity;
  final ValueChanged<Activity>? onActivityTap;
  final ValueChanged<Stay>? onStayTap;
  final ValueChanged<Flight>? onFlightTap;
  final void Function(DateTime checkIn, DateTime checkOut)? onAddStayForDates;

  const DayPlannerView({
    super.key,
    this.onOpenAddActivity,
    this.onActivityTap,
    this.onStayTap,
    this.onFlightTap,
    this.onAddStayForDates,
  });

  @override
  ConsumerState<DayPlannerView> createState() => _DayPlannerViewState();
}

class _DayPlannerViewState extends ConsumerState<DayPlannerView> {
  DateTime? _selectedDate;
  final ScrollController _timelineScrollController = ScrollController();
  bool _hasInitialScrolled = false;
  bool _isDesktopSuggestionsVisible = true;
  bool _isDesktopMapVisible = false;
  Activity? _selectedMapActivity;
  DateTime? _lastSyncedFocusedDate;

  void _changeSelectedDate(DateTime newDate) {
    setState(() {
      _selectedDate = newDate;
      _lastSyncedFocusedDate = newDate;
      _hasInitialScrolled = false;
      _selectedMapActivity = null;
    });
    ref.read(focusedTripDateProvider.notifier).setDate(newDate);
  }

  @override
  void dispose() {
    _timelineScrollController.dispose();
    super.dispose();
  }

  DateTime _computeInitialDate(Trip trip) {
    final days = trip.daysList;
    if (days.isEmpty) return trip.startDate;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start =
        DateTime(trip.startDate.year, trip.startDate.month, trip.startDate.day);
    final end =
        DateTime(trip.endDate.year, trip.endDate.month, trip.endDate.day);

    // If current date is beyond the trip dates it should open on the first day of the trip,
    // otherwise it should open on the day of the trip that corresponds to the current date.
    if (today.isBefore(start) || today.isAfter(end)) {
      return days.first;
    }

    return days.firstWhere(
      (d) => d.year == today.year && d.month == today.month && d.day == today.day,
      orElse: () => days.first,
    );
  }

  void _scrollToEarliestActivity(
      List<Activity> activities, List<Flight> flights) {
    if (!_timelineScrollController.hasClients) return;

    const double hourHeight = 60.0;
    final allMinutes = <int>[];

    for (final a in activities) {
      final parts = a.startTime.split(':');
      if (parts.length >= 2) {
        final h = int.tryParse(parts[0]) ?? 10;
        final m = int.tryParse(parts[1]) ?? 0;
        allMinutes.add(h * 60 + m);
      }
    }

    if (_selectedDate != null) {
      for (final f in flights) {
        final depDate = DateTime(
            f.departureTime.year, f.departureTime.month, f.departureTime.day);
        if (_isSameDay(depDate, _selectedDate!)) {
          allMinutes.add(f.departureTime.hour * 60 + f.departureTime.minute);
        } else {
          // Arriving or continuing overnight flight starts at 00:00 midnight
          allMinutes.add(0);
        }
      }
    } else {
      for (final f in flights) {
        allMinutes.add(f.departureTime.hour * 60 + f.departureTime.minute);
      }
    }

    final int targetMinute =
        allMinutes.isNotEmpty ? allMinutes.reduce(min) : 8 * 60;
    final double targetOffset =
        max(0.0, (targetMinute - 30) * (hourHeight / 60.0));

    _timelineScrollController.animateTo(
      targetOffset.clamp(
          0.0, _timelineScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  void _openAddActivitySheet({
    required DateTime date,
    String? initialTitle,
    ActivityCategory? initialCategory,
    TimeOfDay? initialStartTime,
    TimeOfDay? initialEndTime,
    Activity? activityToEdit,
    String? initialMealType,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddActivitySheet(
        activityToEdit: activityToEdit,
        initialDate: date,
        initialTitle: initialTitle,
        initialCategory: initialCategory,
        initialStartTime: initialStartTime,
        initialEndTime: initialEndTime,
        initialMealType: initialMealType,
      ),
    );
  }

  void _openAddStayModal(DateTime checkIn, DateTime checkOut, [Stay? stayToEdit]) {
    if (stayToEdit != null && widget.onStayTap != null) {
      widget.onStayTap!(stayToEdit);
      return;
    }
    if (widget.onAddStayForDates != null && stayToEdit == null) {
      widget.onAddStayForDates!(checkIn, checkOut);
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddStaySheet(
        stayToEdit: stayToEdit,
        initialCheckInDate: checkIn,
        initialCheckOutDate: checkOut,
      ),
    );
  }

  void _openEditFlightModal(Flight flight) {
    if (widget.onFlightTap != null) {
      widget.onFlightTap!(flight);
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => AddFlightSheet(flightToEdit: flight),
      );
    }
  }

  static int _getActivityStartMinutes(Activity activity) {
    return _parseMinutes(activity.startTime);
  }

  static int _getActivityEndMinutes(Activity activity) {
    final start = _getActivityStartMinutes(activity);
    if (activity.endTime != null && activity.endTime!.isNotEmpty) {
      final end = _parseMinutes(activity.endTime!);
      if (end > start) return end;
    }
    return start + 60;
  }

  static String _formatMinutesToHHmm(int minutes) {
    final h = (minutes ~/ 60) % 24;
    final m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  List<_OverlapGroup> _detectOverlapGroups(List<Activity> activities) {
    if (activities.length < 2) return [];

    final n = activities.length;
    final adj = List.generate(n, (_) => <int>[]);

    for (int i = 0; i < n; i++) {
      final startI = _getActivityStartMinutes(activities[i]);
      final endI = _getActivityEndMinutes(activities[i]);

      for (int j = i + 1; j < n; j++) {
        final startJ = _getActivityStartMinutes(activities[j]);
        final endJ = _getActivityEndMinutes(activities[j]);

        // Activities overlap if max(startI, startJ) < min(endI, endJ)
        if (max(startI, startJ) < min(endI, endJ)) {
          adj[i].add(j);
          adj[j].add(i);
        }
      }
    }

    final visited = List<bool>.filled(n, false);
    final groups = <_OverlapGroup>[];
    int groupId = 1;

    for (int i = 0; i < n; i++) {
      if (visited[i] || adj[i].isEmpty) continue;

      final component = <Activity>[];
      final queue = <int>[i];
      visited[i] = true;

      while (queue.isNotEmpty) {
        final curr = queue.removeAt(0);
        component.add(activities[curr]);

        for (final neighbor in adj[curr]) {
          if (!visited[neighbor]) {
            visited[neighbor] = true;
            queue.add(neighbor);
          }
        }
      }

      if (component.length >= 2) {
        component.sort((a, b) => _getActivityStartMinutes(a)
            .compareTo(_getActivityStartMinutes(b)));

        final groupStart = component.map(_getActivityStartMinutes).reduce(min);
        final groupEnd = component.map(_getActivityEndMinutes).reduce(max);

        groups.add(_OverlapGroup(
          id: groupId++,
          activities: component,
          startMinutes: groupStart,
          endMinutes: groupEnd,
        ));
      }
    }

    groups.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    return groups;
  }

  void _openMobileSuggestionsSheet({
    required Trip trip,
    required DateTime currentDate,
    required int dayNumber,
    required int dayIndex,
    required bool canEdit,
    required _LocationInfo wakeUpInfo,
    required _LocationInfo sleepAtInfo,
    required List<String> effectiveLocations,
    required String defaultCountry,
    required dynamic repo,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Consumer(
          builder: (context, ref, _) {
            final activitiesByDay = ref.watch(activitiesByDayProvider);
            final currentDayActivities = activitiesByDay[currentDate] ?? [];
            final currentTrip = ref.watch(activeTripProvider) ?? trip;
            final stays = ref.watch(sortedActiveTripStaysProvider).value ?? [];
            final allFlights = ref.watch(activeTripFlightsProvider).value ?? [];
            final dateStr = Trip.dateToKey(currentDate);
            final customLocations = currentTrip.dayLocations[dateStr];
            final currentEffectiveLocations = customLocations ?? [defaultCountry];
            final currentRepo = ref.read(tripRepositoryProvider);
            final currentSuggestions = _generateSuggestions(
              trip: currentTrip,
              currentDate: currentDate,
              dayNumber: dayNumber,
              dayIndex: dayIndex,
              dayActivities: currentDayActivities,
              wakeUpInfo: wakeUpInfo,
              sleepAtInfo: sleepAtInfo,
              effectiveLocations: currentEffectiveLocations,
              defaultCountry: defaultCountry,
              stays: stays,
              allFlights: allFlights,
              repo: currentRepo,
            );
            final currentOverlapGroups =
                _detectOverlapGroups(currentDayActivities);

            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              minChildSize: 0.4,
              maxChildSize: 0.95,
              builder: (ctx, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 16,
                        offset: Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Drag handle
                      Container(
                        margin: const EdgeInsets.only(top: 10, bottom: 6),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Expanded(
                        child: _buildSuggestionsPane(
                          suggestions: currentSuggestions,
                          overlapGroups: currentOverlapGroups,
                          dayNumber: dayNumber,
                          canEdit: canEdit,
                          dayActivities: currentDayActivities,
                          currentDate: currentDate,
                          onClose: () => Navigator.pop(sheetCtx),
                          isModal: true,
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildFloatingSuggestionsBulb({
    required int suggestionsCount,
    required int overlapsCount,
    required VoidCallback onTap,
  }) {
    final hasOverlaps = overlapsCount > 0;
    final totalCount = suggestionsCount + overlapsCount;

    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: hasOverlaps
            ? '$overlapsCount conflict${overlapsCount == 1 ? '' : 's'} detected'
            : 'Suggestions ($totalCount)',
        child: InkWell(
          key: const ValueKey('floating_suggestions_bulb'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: hasOverlaps
                  ? const Color(0xFFFEF2F2)
                  : const Color(0xFFFFFBEB),
              shape: BoxShape.circle,
              border: Border.all(
                color: hasOverlaps
                    ? const Color(0xFFFCA5A5)
                    : const Color(0xFFFCD34D),
                width: 1.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: (hasOverlaps ? Colors.red : Colors.amber)
                      .withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  hasOverlaps
                      ? Icons.warning_amber_rounded
                      : Icons.lightbulb_rounded,
                  size: 26,
                  color: hasOverlaps
                      ? const Color(0xFFDC2626)
                      : const Color(0xFFD97706),
                ),
                if (totalCount > 0)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: hasOverlaps
                            ? const Color(0xFFDC2626)
                            : const Color(0xFFD97706),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      constraints:
                          const BoxConstraints(minWidth: 18, minHeight: 18),
                      child: Center(
                        child: Text(
                          '$totalCount',
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openMobileMapSheet({
    required Trip trip,
    required DateTime currentDate,
    required int dayNumber,
    required List<Activity> dayActivities,
    required List<Flight> dayFlights,
    required List<Stay> stays,
    required String defaultCountry,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Consumer(
          builder: (context, ref, _) {
            final activitiesByDay = ref.watch(activitiesByDayProvider);
            final currentDayActivities = activitiesByDay[currentDate] ?? dayActivities;
            final currentTrip = ref.watch(activeTripProvider) ?? trip;
            final currentStays = ref.watch(sortedActiveTripStaysProvider).value ?? stays;
            final currentFlights = ref.watch(activeTripFlightsProvider).value ?? dayFlights;

            return StatefulBuilder(
              builder: (ctx, setModalState) {
                return DraggableScrollableSheet(
                  initialChildSize: 0.85,
                  minChildSize: 0.45,
                  maxChildSize: 0.96,
                  builder: (sheetContentCtx, scrollController) {
                    return Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(20)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 16,
                            offset: Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Drag handle
                          Container(
                            margin: const EdgeInsets.only(top: 10, bottom: 6),
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          Expanded(
                            child: DayPlannerMapPanel(
                              trip: currentTrip,
                              date: currentDate,
                              dayNumber: dayNumber,
                              dayActivities: currentDayActivities,
                              dayFlights: currentFlights,
                              stays: currentStays,
                              defaultCountry:
                                  (currentTrip.getCustomLocationsForDate(currentDate)?.firstOrNull) ??
                                      defaultCountry,
                              selectedActivity: _selectedMapActivity,
                              onSelectActivity: (act) {
                                setModalState(() {
                                  _selectedMapActivity = act;
                                });
                                setState(() {
                                  _selectedMapActivity = act;
                                });
                              },
                              onClose: () => Navigator.pop(sheetCtx),
                              isModal: true,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildFloatingMapButton({
    required int pinCount,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: 'Day Map ($pinCount locations)',
        child: InkWell(
          key: const ValueKey('floating_map_button'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary,
                width: 1.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(
                  Icons.map_rounded,
                  size: 26,
                  color: AppColors.primary,
                ),
                if (pinCount > 0)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      constraints:
                          const BoxConstraints(minWidth: 18, minHeight: 18),
                      child: Center(
                        child: Text(
                          '$pinCount',
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openEditTripLocations(BuildContext context, Trip trip) {
    final startController =
        TextEditingController(text: trip.startLocation ?? '');
    final endController = TextEditingController(text: trip.endLocation ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Trip Start & Finish Locations'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Specify the starting and finishing locations for this trip.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: startController,
                decoration: const InputDecoration(
                  labelText: 'Starting Location (Origin)',
                  hintText: 'e.g. San Francisco or Origin City',
                  helperText: 'Displayed as Wake-Up location on Day 1',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: endController,
                decoration: const InputDecoration(
                  labelText: 'Finishing Location (Return)',
                  hintText: 'e.g. San Francisco or Return City',
                  helperText: 'Displayed at the end of the trip',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newStart = startController.text.trim();
              final newEnd = endController.text.trim();
              final updated = trip.copyWith(
                startLocation: newStart.isNotEmpty ? newStart : null,
                endLocation: newEnd.isNotEmpty ? newEnd : null,
                updatedAt: DateTime.now(),
              );
              await ref.read(tripRepositoryProvider).updateTrip(updated);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trip = ref.watch(activeTripProvider);
    final canEdit = ref.watch(canEditActiveTripProvider);
    final activitiesByDay = ref.watch(activitiesByDayProvider);
    final staysAsync = ref.watch(sortedActiveTripStaysProvider);
    final flightsAsync = ref.watch(activeTripFlightsProvider);
    final activitiesAsync = ref.watch(activeTripActivitiesProvider);
    final repo = ref.watch(tripRepositoryProvider);

    if (trip == null) {
      return const Center(
        child: Text('No trip selected. Select or create a trip to start.'),
      );
    }

    final days = trip.daysList;
    if (days.isEmpty) {
      return const Center(
        child: Text('This trip has no days configured.'),
      );
    }

    // Initialize or reconcile selected date
    final focusedDate = ref.watch(focusedTripDateProvider);
    if (focusedDate != null && (_lastSyncedFocusedDate == null || !_isSameDay(_lastSyncedFocusedDate!, focusedDate))) {
      _lastSyncedFocusedDate = focusedDate;
      if (days.any((d) => _isSameDay(d, focusedDate))) {
        _selectedDate = focusedDate;
        _hasInitialScrolled = false;
      }
    } else if (_selectedDate == null || !days.any((d) => _isSameDay(d, _selectedDate!))) {
      _selectedDate = _computeInitialDate(trip);
      _hasInitialScrolled = false;
    }

    final currentDate = _selectedDate!;
    final currentDayIndex = days.indexWhere((d) => _isSameDay(d, currentDate));
    final dayNumber = currentDayIndex != -1 ? currentDayIndex + 1 : 1;

    final stays = staysAsync.value ?? [];
    final allFlights = flightsAsync.value ?? [];
    final allActivities = activitiesAsync.value ?? [];
    final dayActivities = activitiesByDay[currentDate] ?? [];
    final dayFlights = allFlights.where((f) {
      final dep = DateTime(
          f.departureTime.year, f.departureTime.month, f.departureTime.day);
      final arr = DateTime(
          f.arrivalTime.year, f.arrivalTime.month, f.arrivalTime.day);
      final effectiveArr = arr.isAfter(dep)
          ? arr
          : (f.spansAcrossDays ? dep.add(const Duration(days: 1)) : dep);

      final cur = DateTime(currentDate.year, currentDate.month, currentDate.day);
      return !cur.isBefore(dep) && !cur.isAfter(effectiveArr);
    }).toList();

    // Trigger auto-scroll on initial load or date change
    if (!_hasInitialScrolled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToEarliestActivity(dayActivities, dayFlights);
        _hasInitialScrolled = true;
      });
    }

    // Resolve Wake-up location & Stay
    final wakeUpInfo = _resolveWakeUpLocation(
      trip: trip,
      currentDate: currentDate,
      dayIndex: currentDayIndex,
      stays: stays,
      allFlights: allFlights,
    );

    // Resolve Sleep At location & Stay
    final sleepAtInfo = _resolveSleepAtLocation(
      trip: trip,
      currentDate: currentDate,
      dayIndex: currentDayIndex,
      stays: stays,
      allFlights: allFlights,
    );

    final isToday = _isSameDay(currentDate, DateTime.now());
    final customLocations = trip.getCustomLocationsForDate(currentDate);
    final defaultCountry = LocationInferenceHelper.inferTargetCountryForDay(
      date: currentDate,
      flights: allFlights,
      activities: allActivities,
      tripDestination: trip.destination,
    );
    final effectiveLocations = customLocations ?? [defaultCountry];

    // Compute Suggestions
    final suggestions = _generateSuggestions(
      trip: trip,
      currentDate: currentDate,
      dayNumber: dayNumber,
      dayIndex: currentDayIndex,
      dayActivities: dayActivities,
      wakeUpInfo: wakeUpInfo,
      sleepAtInfo: sleepAtInfo,
      effectiveLocations: effectiveLocations,
      defaultCountry: defaultCountry,
      stays: stays,
      allFlights: allFlights,
      repo: repo,
    );
    final overlapGroups = _detectOverlapGroups(dayActivities);

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWide = constraints.maxWidth >= 900;
        final bool showFullHeaderInfo = constraints.maxWidth >= 600;

        return Column(
          children: [
            // Top Navigation & Information Bar (matches Itinerary view)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border, width: 0.8)),
                color: Colors.white,
              ),
              child: Row(
                children: [
                  if (constraints.maxWidth >= 500) ...[
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.view_agenda_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'DAY PLANNER  •  ${days.length} DAYS',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (showFullHeaderInfo) ...[
                      const SizedBox(width: 12),
                      Text(
                        DateFormatters.formatTripDateRange(
                            trip.startDate, trip.endDate),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                  // Centered Day Navigation Controls (Prev, Dropdown Selector, Next)
                  Expanded(
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left_rounded, size: 22),
                            tooltip: 'Previous Day',
                            visualDensity: VisualDensity.compact,
                            onPressed: currentDayIndex > 0
                                ? () => _changeSelectedDate(days[currentDayIndex - 1])
                                : null,
                          ),

                          // Jump to Day Dropdown Picker
                          PopupMenuButton<int>(
                            tooltip: 'Jump to specific day',
                            initialValue: currentDayIndex,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.calendar_today_rounded,
                                      size: 13, color: Colors.grey.shade700),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Day $dayNumber of ${days.length}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.arrow_drop_down_rounded, size: 18),
                                ],
                              ),
                            ),
                            itemBuilder: (ctx) {
                              return [
                                for (int k = 0; k < days.length; k++)
                                  PopupMenuItem<int>(
                                    value: k,
                                    child: Row(
                                      children: [
                                        Text(
                                          'Day ${k + 1}',
                                          style: TextStyle(
                                            fontWeight: k == currentDayIndex
                                                ? FontWeight.w800
                                                : FontWeight.w600,
                                            color: k == currentDayIndex
                                                ? AppColors.primary
                                                : AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          DateFormatters.dayHeader.format(days[k]),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ];
                            },
                            onSelected: (idx) => _changeSelectedDate(days[idx]),
                          ),

                          IconButton(
                            icon: const Icon(Icons.chevron_right_rounded, size: 22),
                            tooltip: 'Next Day',
                            visualDensity: VisualDensity.compact,
                            onPressed: currentDayIndex < days.length - 1
                                ? () => _changeSelectedDate(days[currentDayIndex + 1])
                                : null,
                          ),

                          if (!isToday &&
                              days.any((d) => _isSameDay(d, DateTime.now()))) ...[
                            const SizedBox(width: 4),
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                              ),
                              icon: const Icon(Icons.today_rounded, size: 15),
                              label: const Text('Today', style: TextStyle(fontSize: 12)),
                              onPressed: () => _changeSelectedDate(days.firstWhere(
                                  (d) => _isSameDay(d, DateTime.now()))),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  if (isWide) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(
                        _isDesktopMapVisible
                            ? Icons.map_rounded
                            : Icons.map_outlined,
                        color: _isDesktopMapVisible
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        size: 20,
                      ),
                      tooltip: _isDesktopMapVisible
                          ? 'Hide Day Map'
                          : 'Show Day Map',
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        setState(() {
                          _isDesktopMapVisible = !_isDesktopMapVisible;
                          if (!_isDesktopMapVisible) {
                            _selectedMapActivity = null;
                          }
                        });
                      },
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(
                        _isDesktopSuggestionsVisible
                            ? Icons.lightbulb_rounded
                            : Icons.lightbulb_outline_rounded,
                        color: _isDesktopSuggestionsVisible
                            ? const Color(0xFFD97706)
                            : AppColors.textSecondary,
                        size: 20,
                      ),
                      tooltip: _isDesktopSuggestionsVisible
                          ? 'Hide Suggestions'
                          : 'Show Suggestions',
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        setState(() {
                          _isDesktopSuggestionsVisible =
                              !_isDesktopSuggestionsVisible;
                        });
                      },
                    ),
                  ] else ...[
                    IconButton(
                      icon: const Icon(Icons.map_outlined,
                          size: 20, color: AppColors.textSecondary),
                      tooltip: 'Show Day Map',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _openMobileMapSheet(
                        trip: trip,
                        currentDate: currentDate,
                        dayNumber: dayNumber,
                        dayActivities: dayActivities,
                        dayFlights: dayFlights,
                        stays: stays,
                        defaultCountry:
                            effectiveLocations.firstOrNull ?? defaultCountry,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Main Content Area: Single-Day Pane + Right Suggestions Pane + Map Panel
            Expanded(
              child: Container(
                color: const Color(0xFFF8FAFC),
                child: isWide
                    ? Stack(
                        children: [
                          Center(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // 1. Single Day Pane (expanded, ~420dp or 540dp if suggestions and map hidden)
                                  SizedBox(
                                    width: _isDesktopMapVisible
                                        ? 420
                                        : (_isDesktopSuggestionsVisible
                                            ? 450
                                            : 540),
                                    height: constraints.maxHeight - 75,
                                    child: _buildSingleDayPane(
                                      trip: trip,
                                      date: currentDate,
                                      dayNumber: dayNumber,
                                      isToday: isToday,
                                      canEdit: canEdit,
                                      effectiveLocations: effectiveLocations,
                                      defaultCountry: defaultCountry,
                                      dayActivities: dayActivities,
                                      dayFlights: dayFlights,
                                      wakeUpInfo: wakeUpInfo,
                                      sleepAtInfo: sleepAtInfo,
                                      repo: repo,
                                    ),
                                  ),
                                  if (_isDesktopSuggestionsVisible) ...[
                                    const SizedBox(width: 20),
                                    // 2. Right Suggestions Pane (~340dp or 380dp)
                                    SizedBox(
                                      width: _isDesktopMapVisible ? 340 : 380,
                                      height: constraints.maxHeight - 75,
                                      child: _buildSuggestionsPane(
                                        suggestions: suggestions,
                                        overlapGroups: overlapGroups,
                                        dayNumber: dayNumber,
                                        canEdit: canEdit,
                                        dayActivities: dayActivities,
                                        currentDate: currentDate,
                                        onClose: () => setState(() =>
                                            _isDesktopSuggestionsVisible =
                                                false),
                                      ),
                                    ),
                                  ],
                                  if (_isDesktopMapVisible) ...[
                                    const SizedBox(width: 20),
                                    // 3. Map Panel (takes advantage of remaining desktop real estate)
                                    SizedBox(
                                      width: max(
                                        460.0,
                                        constraints.maxWidth -
                                            40.0 -
                                            420.0 -
                                            (_isDesktopSuggestionsVisible
                                                ? (340.0 + 20.0)
                                                : 0.0) -
                                            20.0,
                                      ),
                                      height: constraints.maxHeight - 75,
                                      child: DayPlannerMapPanel(
                                        trip: trip,
                                        date: currentDate,
                                        dayNumber: dayNumber,
                                        dayActivities: dayActivities,
                                        dayFlights: dayFlights,
                                        stays: stays,
                                        defaultCountry:
                                            effectiveLocations.firstOrNull ??
                                                defaultCountry,
                                        selectedActivity: _selectedMapActivity,
                                        onSelectActivity: (act) {
                                          setState(() {
                                            _selectedMapActivity = act;
                                          });
                                        },
                                        onClose: () {
                                          setState(() {
                                            _isDesktopMapVisible = false;
                                            _selectedMapActivity = null;
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          if (!_isDesktopSuggestionsVisible)
                            Positioned(
                              right: 24,
                              bottom: 24,
                              child: _buildFloatingSuggestionsBulb(
                                suggestionsCount: suggestions.length,
                                overlapsCount: overlapGroups.length,
                                onTap: () => setState(() =>
                                    _isDesktopSuggestionsVisible = true),
                              ),
                            ),
                          if (!_isDesktopMapVisible)
                            Positioned(
                              right: 24,
                              bottom: !_isDesktopSuggestionsVisible ? 90 : 24,
                              child: _buildFloatingMapButton(
                                pinCount: dayActivities
                                    .where((a) =>
                                        (a.location != null &&
                                            a.location!.trim().isNotEmpty) ||
                                        (a.effectiveFromLocation != null &&
                                            a.effectiveFromLocation!
                                                .trim()
                                                .isNotEmpty) ||
                                        (a.effectiveToLocation != null &&
                                            a.effectiveToLocation!
                                                .trim()
                                                .isNotEmpty))
                                    .length,
                                onTap: () => setState(
                                    () => _isDesktopMapVisible = true),
                              ),
                            ),
                        ],
                      )
                    : Stack(
                        children: [
                          // Mobile layout: Single Day Pane fills the entire screen
                          Positioned.fill(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                              child: _buildSingleDayPane(
                                trip: trip,
                                date: currentDate,
                                dayNumber: dayNumber,
                                isToday: isToday,
                                canEdit: canEdit,
                                effectiveLocations: effectiveLocations,
                                defaultCountry: defaultCountry,
                                dayActivities: dayActivities,
                                dayFlights: dayFlights,
                                wakeUpInfo: wakeUpInfo,
                                sleepAtInfo: sleepAtInfo,
                                repo: repo,
                              ),
                            ),
                          ),
                          // Floating Map icon on the side
                          Positioned(
                            right: 20,
                            bottom: 90,
                            child: _buildFloatingMapButton(
                              pinCount: dayActivities
                                  .where((a) =>
                                      (a.location != null &&
                                          a.location!.trim().isNotEmpty) ||
                                      (a.effectiveFromLocation != null &&
                                          a.effectiveFromLocation!
                                              .trim()
                                              .isNotEmpty) ||
                                      (a.effectiveToLocation != null &&
                                          a.effectiveToLocation!
                                              .trim()
                                              .isNotEmpty))
                                  .length,
                              onTap: () => _openMobileMapSheet(
                                trip: trip,
                                currentDate: currentDate,
                                dayNumber: dayNumber,
                                dayActivities: dayActivities,
                                dayFlights: dayFlights,
                                stays: stays,
                                defaultCountry: defaultCountry,
                              ),
                            ),
                          ),
                          // Floating Bulb icon on the side
                          Positioned(
                            right: 20,
                            bottom: 24,
                            child: _buildFloatingSuggestionsBulb(
                              suggestionsCount: suggestions.length,
                              overlapsCount: overlapGroups.length,
                              onTap: () => _openMobileSuggestionsSheet(
                                trip: trip,
                                currentDate: currentDate,
                                dayNumber: dayNumber,
                                dayIndex: currentDayIndex,
                                canEdit: canEdit,
                                wakeUpInfo: wakeUpInfo,
                                sleepAtInfo: sleepAtInfo,
                                effectiveLocations: effectiveLocations,
                                defaultCountry: defaultCountry,
                                repo: repo,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Single Day Pane Builder
  // ---------------------------------------------------------------------------
  Widget _buildSingleDayPane({
    required Trip trip,
    required DateTime date,
    required int dayNumber,
    required bool isToday,
    required bool canEdit,
    required List<String> effectiveLocations,
    required String defaultCountry,
    required List<Activity> dayActivities,
    required List<Flight> dayFlights,
    required _LocationInfo wakeUpInfo,
    required _LocationInfo sleepAtInfo,
    required dynamic repo,
  }) {
    String? startStr;
    String? endStr;
    if (dayActivities.isNotEmpty) {
      final firstAct = dayActivities.reduce((a, b) =>
          _getActivityStartMinutes(a) <= _getActivityStartMinutes(b) ? a : b);
      startStr = DateFormatters.formatTimeString(firstAct.startTime);

      final lastAct = dayActivities.reduce((a, b) =>
          _getActivityEndMinutes(a) >= _getActivityEndMinutes(b) ? a : b);
      final lastEndMin = _getActivityEndMinutes(lastAct);
      endStr = DateFormatters.formatTimeString(
          lastAct.endTime ?? _formatMinutesToHHmm(lastEndMin));
    }

    return Container(
      decoration: BoxDecoration(
        color: isToday
            ? Colors.blue.shade50.withValues(alpha: 0.3)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isToday ? AppColors.primary : AppColors.border,
          width: isToday ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. MAIN HEADER: Date, Day Number, Location Tags
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isToday ? AppColors.primary : const Color(0xFFF8FAFC),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(15)),
              border: Border(
                bottom: BorderSide(
                  color: isToday ? AppColors.primary : AppColors.border,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        children: [
                          Text(
                            'DAY $dayNumber',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: isToday
                                  ? Colors.white70
                                  : AppColors.primary,
                            ),
                          ),
                          if (isToday)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'TODAY',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormatters.dayHeader.format(date),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isToday ? Colors.white : AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 11,
                            color: isToday ? Colors.white70 : AppColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              (startStr != null && endStr != null)
                                  ? 'Start: $startStr • End: $endStr'
                                  : 'No activities scheduled',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isToday ? Colors.white70 : AppColors.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Location tags
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          for (final loc in effectiveLocations)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isToday
                                    ? Colors.white.withValues(alpha: 0.25)
                                    : AppColors.primaryContainer
                                        .withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.place_rounded,
                                    size: 10,
                                    color: isToday
                                        ? Colors.white
                                        : AppColors.primary,
                                  ),
                                  const SizedBox(width: 2),
                                  Flexible(
                                    child: Text(
                                      loc,
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        color: isToday
                                            ? Colors.white
                                            : AppColors.primary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (canEdit)
                            InkWell(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => ManageDayLocationsDialog(
                                    dayNumber: dayNumber,
                                    date: date,
                                    currentLocations: effectiveLocations,
                                    defaultCountry: defaultCountry,
                                    onSave: (newLocations) {
                                      repo.updateDayLocations(
                                        trip.id,
                                        date,
                                        newLocations,
                                      );
                                    },
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isToday
                                      ? Colors.white.withValues(alpha: 0.15)
                                      : Colors.grey.shade100,
                                  border: Border.all(
                                    color: isToday
                                        ? Colors.white.withValues(alpha: 0.6)
                                        : Colors.grey.shade300,
                                    width: 0.8,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  effectiveLocations.isEmpty ? '+ Loc' : 'Edit',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: isToday
                                        ? Colors.white
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Total Activities & Flights pill
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isToday
                        ? Colors.white.withValues(alpha: 0.2)
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${dayActivities.length + dayFlights.length} ${(dayActivities.length + dayFlights.length) == 1 ? 'item' : 'items'}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isToday ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    ref.read(focusedTripDateProvider.notifier).setDate(date);
                    ref.read(itineraryViewModeProvider.notifier).setMode(ItineraryViewMode.full);
                    ref.read(navTabIndexProvider.notifier).setTab(1);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isToday
                          ? Colors.white.withValues(alpha: 0.25)
                          : AppColors.primaryContainer.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isToday
                            ? Colors.white.withValues(alpha: 0.5)
                            : AppColors.primary.withValues(alpha: 0.3),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_view_week_rounded,
                          size: 12,
                          color: isToday ? Colors.white : AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Itinerary',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isToday ? Colors.white : AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. DISTINCTIVE SUB-HEADER: Wake-Up Location
          _buildWakeUpSubHeader(wakeUpInfo, trip, date),

          // 3. 24-HOUR PROPORTIONAL TIMELINE (Scrollable)
          Expanded(
            child: _build24HourTimeline(
              activities: dayActivities,
              flights: dayFlights,
              date: date,
              canEdit: canEdit,
            ),
          ),

          // 4. DISTINCTIVE FOOTER: Sleep At Location
          _buildSleepAtFooter(sleepAtInfo, trip, date),

          // 5. BOTTOM ADD ACTIVITY BUTTON
          if (canEdit)
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: OutlinedButton.icon(
                onPressed: () => _openAddActivitySheet(date: date),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text(
                  'Add Activity for this Day',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Wake-Up Sub-Header
  // ---------------------------------------------------------------------------
  Widget _buildWakeUpSubHeader(
      _LocationInfo info, Trip trip, DateTime date) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.8)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.wb_sunny_rounded,
              size: 14,
              color: Color(0xFFD97706),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'WAKE UP AT',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: AppColors.textMuted,
                  ),
                ),
                Text(
                  info.title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: info.isMissing
                        ? Colors.red.shade700
                        : AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (info.stay != null) ...[
            InkWell(
              onTap: () => widget.onStayTap?.call(info.stay!),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.stayContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.hotel_rounded, size: 12, color: AppColors.stay),
                    SizedBox(width: 4),
                    Text(
                      'View Stay',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.stay,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else if (info.isMissing) ...[
            TextButton(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              ),
              onPressed: () {
                if (date == trip.startDate) {
                  _openEditTripLocations(context, trip);
                } else {
                  final prevDate = date.subtract(const Duration(days: 1));
                  _openAddStayModal(prevDate, date);
                }
              },
              child: const Text('+ Add Lodging', style: TextStyle(fontSize: 11)),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Sleep At Footer
  // ---------------------------------------------------------------------------
  Widget _buildSleepAtFooter(
      _LocationInfo info, Trip trip, DateTime date) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        border: Border(top: BorderSide(color: AppColors.border, width: 0.8)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: const Color(0xFFE0E7FF),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.bedtime_rounded,
              size: 14,
              color: Color(0xFF4338CA),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'SLEEP AT',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: AppColors.textMuted,
                  ),
                ),
                Text(
                  info.title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: info.isMissing
                        ? Colors.red.shade700
                        : AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (info.stay != null) ...[
            InkWell(
              onTap: () => widget.onStayTap?.call(info.stay!),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.stayContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.hotel_rounded, size: 12, color: AppColors.stay),
                    SizedBox(width: 4),
                    Text(
                      'View Stay',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.stay,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else if (info.flight != null) ...[
            InkWell(
              onTap: () => _openEditFlightModal(info.flight!),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.flightContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.flight_takeoff_rounded,
                        size: 12, color: AppColors.flight),
                    SizedBox(width: 4),
                    Text(
                      'Flight',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.flight,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else if (info.isMissing) ...[
            TextButton(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              ),
              onPressed: () {
                final nextDate = date.add(const Duration(days: 1));
                _openAddStayModal(date, nextDate);
              },
              child: const Text('+ Book Lodging', style: TextStyle(fontSize: 11)),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 24-Hour Timeline with Proportional Cards
  // ---------------------------------------------------------------------------
  Widget _build24HourTimeline({
    required List<Activity> activities,
    required List<Flight> flights,
    required DateTime date,
    required bool canEdit,
  }) {
    const double hourHeight = 60.0;
    const double totalHeight = 24 * hourHeight; // 1440 dp

    return SingleChildScrollView(
      controller: _timelineScrollController,
      physics: const BouncingScrollPhysics(),
      child: SizedBox(
        height: totalHeight,
        child: Stack(
          children: [
            // 1. Hourly Grid Lines and Labels
            for (int h = 0; h < 24; h++) ...[
              Positioned(
                left: 0,
                right: 0,
                top: h * hourHeight,
                child: Row(
                  children: [
                    SizedBox(
                      width: 52,
                      child: Text(
                        _formatHourLabel(h),
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 1,
                        color: Colors.grey.shade200,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // 2. Proportional Activity Cards
            for (final act in activities) ...[
              Builder(
                builder: (context) {
                  final startMin = _parseMinutes(act.startTime);
                  int durationMin = 60;
                  if (act.endTime != null) {
                    final endMin = _parseMinutes(act.endTime!);
                    if (endMin > startMin) {
                      durationMin = endMin - startMin;
                    }
                  }
                  // Enforce readable minimum height of 40 dp
                  final clampedDuration = max(40, durationMin);
                  final double topPos = startMin * (hourHeight / 60.0);
                  final double cardHeight = clampedDuration * (hourHeight / 60.0);

                  final catColor = _getCategoryColor(act.category);
                  final isSelectedOnMap =
                      _isDesktopMapVisible && _selectedMapActivity?.id == act.id;

                  return Positioned(
                    left: 56,
                    right: 12,
                    top: topPos,
                    height: cardHeight,
                    child: InkWell(
                      onTap: () {
                        if (_isDesktopMapVisible) {
                          setState(() {
                            _selectedMapActivity =
                                _selectedMapActivity?.id == act.id ? null : act;
                          });
                        } else if (widget.onActivityTap != null) {
                          widget.onActivityTap!(act);
                        } else {
                          _openAddActivitySheet(date: date, activityToEdit: act);
                        }
                      },
                      onDoubleTap: () => widget.onActivityTap != null
                          ? widget.onActivityTap!(act)
                          : _openAddActivitySheet(date: date, activityToEdit: act),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelectedOnMap
                              ? AppColors.primaryContainer.withValues(alpha: 0.25)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelectedOnMap
                                ? AppColors.primary
                                : Colors.grey.shade300,
                            width: isSelectedOnMap ? 2.0 : 0.8,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isSelectedOnMap
                                  ? AppColors.primary.withValues(alpha: 0.15)
                                  : Colors.black.withValues(alpha: 0.03),
                              blurRadius: isSelectedOnMap ? 6 : 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(width: 4, color: catColor),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  act.startTime,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    color: catColor,
                                                  ),
                                                ),
                                                if (act.endTime != null) ...[
                                                  Text(
                                                    ' – ${act.endTime}',
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      color: AppColors.textMuted,
                                                    ),
                                                  ),
                                                ],
                                                const SizedBox(width: 6),
                                                Flexible(
                                                  child: Text(
                                                    act.title,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w700,
                                                      color: AppColors.textPrimary,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (act.mealType != null &&
                                                    act.mealType!.isNotEmpty) ...[
                                                  const SizedBox(width: 5),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                        horizontal: 5, vertical: 1),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.diningContainer,
                                                      borderRadius: BorderRadius.circular(4),
                                                      border: Border.all(
                                                        color: AppColors.dining.withValues(alpha: 0.3),
                                                        width: 0.5,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      act.mealType!.toUpperCase(),
                                                      style: const TextStyle(
                                                        fontSize: 8.5,
                                                        fontWeight: FontWeight.w800,
                                                        color: AppColors.dining,
                                                        letterSpacing: 0.3,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            if (act.location != null &&
                                                act.location!.isNotEmpty &&
                                                cardHeight >= 45) ...[
                                              const SizedBox(height: 1),
                                              Text(
                                                act.location!,
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: AppColors.textSecondary,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        _getCategoryIcon(act.category),
                                        size: 14,
                                        color: catColor,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],

            // 3. Proportional Flight Cards
            for (final flt in flights) ...[
              Builder(
                builder: (context) {
                  final depDate = DateTime(
                      flt.departureTime.year, flt.departureTime.month, flt.departureTime.day);
                  final arrDate = DateTime(
                      flt.arrivalTime.year, flt.arrivalTime.month, flt.arrivalTime.day);
                  final effectiveArrDate = arrDate.isAfter(depDate)
                      ? arrDate
                      : (flt.spansAcrossDays ? depDate.add(const Duration(days: 1)) : depDate);

                  final bool isDepDay = _isSameDay(date, depDate);
                  final bool isArrDay = _isSameDay(date, effectiveArrDate);
                  final bool spans = flt.spansAcrossDays || effectiveArrDate.isAfter(depDate);

                  final int startMin;
                  final int endMin;

                  if (!spans) {
                    startMin = flt.departureTime.hour * 60 + flt.departureTime.minute;
                    final rawEnd = flt.arrivalTime.hour * 60 + flt.arrivalTime.minute;
                    endMin = rawEnd > startMin ? rawEnd : min(1440, startMin + max(45, flt.duration.inMinutes));
                  } else if (isDepDay) {
                    // Departure day of multi-day flight: departs at departureTime and covers all hours until 24:00
                    startMin = flt.departureTime.hour * 60 + flt.departureTime.minute;
                    endMin = 1440;
                  } else if (isArrDay) {
                    // Arrival day of multi-day flight: starts at 00:00 midnight and covers all hours until arrivalTime
                    startMin = 0;
                    final rawEnd = flt.arrivalTime.hour * 60 + flt.arrivalTime.minute;
                    endMin = max(45, rawEnd);
                  } else {
                    // Intermediate day: occupies all 24 hours
                    startMin = 0;
                    endMin = 1440;
                  }

                  final int durationMin = max(45, endMin - startMin);
                  final double topPos = startMin * (hourHeight / 60.0);
                  final double cardHeight = durationMin * (hourHeight / 60.0);
                  final durationText =
                      '${flt.duration.inHours}h ${flt.duration.inMinutes.remainder(60)}m';

                  return Positioned(
                    left: 56,
                    right: 12,
                    top: topPos,
                    height: max(68.0, cardHeight),
                    child: InkWell(
                      onTap: () => _openEditFlightModal(flt),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F9FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.blue.shade200,
                            width: 0.8,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.flight.withValues(alpha: 0.05),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(width: 4, color: AppColors.flight),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // 1. Airline & Flight Number + Badges Row
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.flight_takeoff_rounded,
                                            size: 13,
                                            color: AppColors.flight,
                                          ),
                                          const SizedBox(width: 6),
                                          Flexible(
                                            child: Text(
                                              '${flt.airline} ${flt.flightNumber}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.textPrimary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (flt.spansAcrossDays) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 5, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFEF3C7),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                isArrDay && !isDepDay
                                                    ? 'OVERNIGHT (ARRIVING)'
                                                    : 'OVERNIGHT',
                                                style: const TextStyle(
                                                  fontSize: 8,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFFD97706),
                                                ),
                                              ),
                                            ),
                                          ],
                                          if (flt.bookingRef != null &&
                                              flt.bookingRef!.isNotEmpty) ...[
                                            const SizedBox(width: 6),
                                            Text(
                                              'Ref: ${flt.bookingRef}',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w500,
                                                color: AppColors.textMuted,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),

                                      // 2. Departure - Graphic - Arrival Row
                                      Row(
                                        children: [
                                          // Departure Airport & Time
                                          Flexible(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  flt.departureAirport,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w800,
                                                    color: AppColors.textPrimary,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        DateFormatters.time12
                                                            .format(flt
                                                                .departureTime),
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color:
                                                              AppColors.flight,
                                                        ),
                                                      ),
                                                      if (spans &&
                                                          isArrDay &&
                                                          !isDepDay) ...[
                                                        const SizedBox(width: 2),
                                                        const Text(
                                                          '-1d',
                                                          style: TextStyle(
                                                            fontSize: 9,
                                                            fontWeight:
                                                                FontWeight.w800,
                                                            color: Color(
                                                                0xFF0369A1),
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                          // Center Airplane Flight Graphic with Duration
                                          Expanded(
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10.0),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    durationText,
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w700,
                                                      color: AppColors.flight,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Row(
                                                    children: [
                                                      Container(
                                                        width: 5,
                                                        height: 5,
                                                        decoration:
                                                            const BoxDecoration(
                                                          shape:
                                                              BoxShape.circle,
                                                          color:
                                                              AppColors.flight,
                                                        ),
                                                      ),
                                                      Expanded(
                                                        child: Container(
                                                          height: 1.5,
                                                          color: AppColors.flight
                                                              .withValues(
                                                                  alpha: 0.35),
                                                        ),
                                                      ),
                                                      const Padding(
                                                        padding:
                                                            EdgeInsets.symmetric(
                                                                horizontal: 3),
                                                        child: Icon(
                                                          Icons.flight,
                                                          size: 13,
                                                          color:
                                                              AppColors.flight,
                                                        ),
                                                      ),
                                                      Expanded(
                                                        child: Container(
                                                          height: 1.5,
                                                          color: AppColors.flight
                                                              .withValues(
                                                                  alpha: 0.35),
                                                        ),
                                                      ),
                                                      Container(
                                                        width: 5,
                                                        height: 5,
                                                        decoration:
                                                            const BoxDecoration(
                                                          shape:
                                                              BoxShape.circle,
                                                          color:
                                                              AppColors.flight,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 1),
                                                  const Text(
                                                    'Non-stop',
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      color: AppColors.textMuted,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),

                                          // Arrival Airport & Time
                                          Flexible(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  flt.arrivalAirport,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w800,
                                                    color: AppColors.textPrimary,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  alignment:
                                                      Alignment.centerRight,
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        DateFormatters.time12
                                                            .format(flt
                                                                .arrivalTime),
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color:
                                                              AppColors.flight,
                                                        ),
                                                      ),
                                                      if (spans && isDepDay) ...[
                                                        const SizedBox(width: 2),
                                                        const Text(
                                                          '+1d',
                                                          style: TextStyle(
                                                            fontSize: 9,
                                                            fontWeight:
                                                                FontWeight.w800,
                                                            color: Color(
                                                                0xFFBE123C),
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Right Suggestions Pane
  // ---------------------------------------------------------------------------
  Widget _buildSuggestionsPane({
    required List<_SuggestionItem> suggestions,
    required List<_OverlapGroup> overlapGroups,
    required int dayNumber,
    required bool canEdit,
    required List<Activity> dayActivities,
    required DateTime currentDate,
    VoidCallback? onClose,
    bool isModal = false,
  }) {
    return Container(
      key: const ValueKey('suggestions_pane'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: isModal
            ? const BorderRadius.vertical(top: Radius.circular(20))
            : BorderRadius.circular(16),
        border: isModal ? null : Border.all(color: AppColors.border, width: 1),
        boxShadow: isModal
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.lightbulb_rounded,
                  size: 16,
                  color: Color(0xFFD97706),
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'SUGGESTIONS FOR TODAY',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: overlapGroups.isNotEmpty
                      ? const Color(0xFFFEE2E2)
                      : suggestions.isEmpty
                          ? const Color(0xFFDCFCE7)
                          : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: overlapGroups.isNotEmpty
                      ? Border.all(color: const Color(0xFFFECACA))
                      : null,
                ),
                child: Text(
                  overlapGroups.isNotEmpty
                      ? '${overlapGroups.length} CONFLICT${overlapGroups.length == 1 ? '' : 'S'}'
                      : suggestions.isEmpty
                          ? 'ALL SET'
                          : '${suggestions.length} ACTION${suggestions.length == 1 ? '' : 'S'}',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: overlapGroups.isNotEmpty
                        ? const Color(0xFFDC2626)
                        : suggestions.isEmpty
                            ? const Color(0xFF15803D)
                            : AppColors.textSecondary,
                  ),
                ),
              ),
              if (onClose != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  tooltip: 'Hide suggestions',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: onClose,
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 12),

          // Suggestion & Conflict Cards List
          Expanded(
            child: (suggestions.isEmpty && overlapGroups.isEmpty)
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_outline_rounded,
                            size: 36,
                            color: Colors.green.shade400,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Day Plan Complete!',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'No time conflicts. Breakfast, Lunch, Dinner, and Lodging are all confirmed for Day $dayNumber.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: overlapGroups.length + suggestions.length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      if (i < overlapGroups.length) {
                        return _buildOverlapGroupCard(
                          overlapGroups[i],
                          canEdit,
                          currentDate,
                        );
                      }
                      final s = suggestions[i - overlapGroups.length];
                      return _buildSuggestionCard(s, canEdit);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverlapGroupCard(
    _OverlapGroup group,
    bool canEdit,
    DateTime currentDate,
  ) {
    final startTimeStr = DateFormatters.formatTimeString(
        _formatMinutesToHHmm(group.startMinutes));
    final endTimeStr = DateFormatters.formatTimeString(
        _formatMinutesToHHmm(group.endMinutes));

    return Container(
      key: ValueKey('overlap_group_${group.id}'),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFECACA),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row of the overlap group
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    size: 15,
                    color: Color(0xFFDC2626),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Overlap Conflict • Group ${group.id}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF991B1B),
                        ),
                      ),
                      Text(
                        '$startTimeStr – $endTimeStr (${group.activities.length} activities)',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFFB91C1C),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'CONFLICT',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Select an activity below to edit its schedule and resolve the conflict:',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF7F1D1D),
              ),
            ),
            const SizedBox(height: 8),

            // List of overlapping activities in this group
            for (final act in group.activities)
              Container(
                key: ValueKey('overlap_activity_${act.id}'),
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.red.shade100,
                    width: 0.9,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: canEdit
                        ? () => _openAddActivitySheet(
                              date: currentDate,
                              activityToEdit: act,
                            )
                        : null,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: _getCategoryColor(act.category)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              _getCategoryIcon(act.category),
                              size: 14,
                              color: _getCategoryColor(act.category),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  act.title,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Wrap(
                                  crossAxisAlignment:
                                      WrapCrossAlignment.center,
                                  spacing: 6,
                                  runSpacing: 2,
                                  children: [
                                    Text(
                                      '${DateFormatters.formatTimeString(act.startTime)} – ${DateFormatters.formatTimeString(act.endTime ?? _formatMinutesToHHmm(_getActivityEndMinutes(act)))}',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.red.shade700,
                                      ),
                                    ),
                                    if (act.mealType != null &&
                                        act.mealType!.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEF3C7),
                                          borderRadius:
                                              BorderRadius.circular(3),
                                        ),
                                        child: Text(
                                          act.mealType!.toUpperCase(),
                                          style: const TextStyle(
                                            fontSize: 8.5,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFFB45309),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (canEdit) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Edit',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFDC2626),
                                    ),
                                  ),
                                  SizedBox(width: 3),
                                  Icon(
                                    Icons.edit_rounded,
                                    size: 11,
                                    color: Color(0xFFDC2626),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionCard(_SuggestionItem s, bool canEdit) {
    return Container(
      decoration: BoxDecoration(
        color: s.backgroundColor ?? const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: s.borderColor ?? Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: canEdit ? s.onAction : null,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: s.iconBgColor ?? Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.05),
                    ),
                  ),
                  child: Icon(
                    s.icon,
                    size: 16,
                    color: s.iconColor ?? AppColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        s.description,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (s.actionLabel != null && canEdit) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: s.actionBgColor ??
                                      AppColors.primaryContainer,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        s.actionLabel!,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: s.actionTextColor ??
                                              AppColors.primary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 11,
                                      color: s.actionTextColor ??
                                          AppColors.primary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Suggestion Engine Logic (2a, 2b, 2c)
  // ---------------------------------------------------------------------------
  List<_SuggestionItem> _generateSuggestions({
    required Trip trip,
    required DateTime currentDate,
    required int dayNumber,
    required int dayIndex,
    required List<Activity> dayActivities,
    required _LocationInfo wakeUpInfo,
    required _LocationInfo sleepAtInfo,
    required List<String> effectiveLocations,
    required String defaultCountry,
    required List<Stay> stays,
    required List<Flight> allFlights,
    required dynamic repo,
  }) {
    final list = <_SuggestionItem>[];

    // 2b: Check Wake-up location
    if (wakeUpInfo.isMissing) {
      if (dayIndex == 0) {
        list.add(_SuggestionItem(
          icon: Icons.flight_takeoff_rounded,
          iconColor: const Color(0xFFD97706),
          iconBgColor: const Color(0xFFFEF3C7),
          borderColor: const Color(0xFFFDE68A),
          backgroundColor: const Color(0xFFFFFBEB),
          title: 'Missing Trip Starting Location',
          description:
              'Set where your trip begins (e.g. San Francisco) to complete the itinerary.',
          actionLabel: 'Set Starting Location',
          onAction: () => _openEditTripLocations(context, trip),
        ));
      } else {
        final prevDate = currentDate.subtract(const Duration(days: 1));
        list.add(_SuggestionItem(
          icon: Icons.bed_rounded,
          iconColor: Colors.red.shade700,
          iconBgColor: Colors.red.shade50,
          borderColor: Colors.red.shade200,
          backgroundColor: Colors.red.shade50.withValues(alpha: 0.3),
          title: 'Missing Wake-Up Lodging',
          description:
              'No stay or accommodation is recorded for the night before Day $dayNumber.',
          actionLabel: 'Add Lodging',
          onAction: () => _openAddStayModal(prevDate, currentDate),
        ));
      }
    }

    // 2b: Check Sleep At location
    if (sleepAtInfo.isMissing) {
      final nextDate = currentDate.add(const Duration(days: 1));
      list.add(_SuggestionItem(
        icon: Icons.nightlight_round,
        iconColor: const Color(0xFF4338CA),
        iconBgColor: const Color(0xFFE0E7FF),
        borderColor: const Color(0xFFC7D2FE),
        backgroundColor: const Color(0xFFEEF2FF),
        title: 'Missing Sleep At Lodging',
        description:
            'No hotel or accommodation is booked for tonight (Night $dayNumber).',
        actionLabel: 'Book Stay Tonight',
        onAction: () => _openAddStayModal(currentDate, nextDate),
      ));
    }

    // 2a: Check Breakfast
    final bool hasBreakfast = dayActivities.any((a) {
      if (a.mealType != null && a.mealType!.isNotEmpty) {
        return a.mealType!.toLowerCase() == 'breakfast';
      }
      final title = a.title.toLowerCase();
      final minutes = _parseMinutes(a.startTime);
      if (title.contains('breakfast') || title.contains('desayuno')) {
        return true;
      }
      return a.category == ActivityCategory.dining &&
          minutes >= 6 * 60 &&
          minutes <= 11 * 60;
    });

    if (!hasBreakfast) {
      list.add(_SuggestionItem(
        icon: Icons.breakfast_dining_rounded,
        iconColor: const Color(0xFFB45309),
        iconBgColor: const Color(0xFFFEF3C7),
        borderColor: const Color(0xFFFDE68A),
        backgroundColor: const Color(0xFFFFFBEB),
        title: 'Missing Breakfast',
        description:
            'Start your day with energy. Add breakfast around 8:30 AM.',
        actionLabel: 'Add Breakfast (8:30 AM)',
        actionBgColor: const Color(0xFFFEF3C7),
        actionTextColor: const Color(0xFFB45309),
        onAction: () => _openAddActivitySheet(
          date: currentDate,
          initialTitle: 'Breakfast',
          initialCategory: ActivityCategory.dining,
          initialStartTime: const TimeOfDay(hour: 8, minute: 30),
          initialEndTime: const TimeOfDay(hour: 9, minute: 30),
          initialMealType: 'breakfast',
        ),
      ));
    }

    // 2a: Check Lunch
    final bool hasLunch = dayActivities.any((a) {
      if (a.mealType != null && a.mealType!.isNotEmpty) {
        return a.mealType!.toLowerCase() == 'lunch';
      }
      final title = a.title.toLowerCase();
      final minutes = _parseMinutes(a.startTime);
      if (title.contains('lunch') ||
          title.contains('almuerzo') ||
          title.contains('comida')) {
        return true;
      }
      return a.category == ActivityCategory.dining &&
          minutes >= 11 * 60 + 30 &&
          minutes <= 16 * 60;
    });

    if (!hasLunch) {
      list.add(_SuggestionItem(
        icon: Icons.restaurant_rounded,
        iconColor: const Color(0xFF15803D),
        iconBgColor: const Color(0xFFDCFCE7),
        borderColor: const Color(0xFFBBF7D0),
        backgroundColor: const Color(0xFFF0FDF4),
        title: 'Missing Lunch',
        description:
            'No mid-day meal scheduled. Add lunch around 1:00 PM.',
        actionLabel: 'Add Lunch (1:00 PM)',
        actionBgColor: const Color(0xFFDCFCE7),
        actionTextColor: const Color(0xFF15803D),
        onAction: () => _openAddActivitySheet(
          date: currentDate,
          initialTitle: 'Lunch',
          initialCategory: ActivityCategory.dining,
          initialStartTime: const TimeOfDay(hour: 13, minute: 0),
          initialEndTime: const TimeOfDay(hour: 14, minute: 15),
          initialMealType: 'lunch',
        ),
      ));
    }

    // 2a: Check Dinner
    final bool hasDinner = dayActivities.any((a) {
      if (a.mealType != null && a.mealType!.isNotEmpty) {
        return a.mealType!.toLowerCase() == 'dinner';
      }
      final title = a.title.toLowerCase();
      final minutes = _parseMinutes(a.startTime);
      if (title.contains('dinner') || title.contains('cena')) {
        return true;
      }
      return a.category == ActivityCategory.dining &&
          minutes >= 17 * 60 &&
          minutes <= 24 * 60;
    });

    if (!hasDinner) {
      list.add(_SuggestionItem(
        icon: Icons.dinner_dining_rounded,
        iconColor: const Color(0xFF9333EA),
        iconBgColor: const Color(0xFFF3E8FF),
        borderColor: const Color(0xFFE9D5FF),
        backgroundColor: const Color(0xFFFAF5FF),
        title: 'Missing Dinner',
        description:
            'Plan your evening dining. Add dinner around 7:30 PM.',
        actionLabel: 'Add Dinner (7:30 PM)',
        actionBgColor: const Color(0xFFF3E8FF),
        actionTextColor: const Color(0xFF9333EA),
        onAction: () => _openAddActivitySheet(
          date: currentDate,
          initialTitle: 'Dinner',
          initialCategory: ActivityCategory.dining,
          initialStartTime: const TimeOfDay(hour: 19, minute: 30),
          initialEndTime: const TimeOfDay(hour: 21, minute: 0),
          initialMealType: 'dinner',
        ),
      ));
    }

    // 2d: Check activities without end time (flag missing end time)
    for (final act in dayActivities) {
      final hasEndTime = act.endTime != null && act.endTime!.trim().isNotEmpty;
      if (!hasEndTime) {
        list.add(_SuggestionItem(
          icon: Icons.schedule_rounded,
          iconColor: const Color(0xFFD97706),
          iconBgColor: const Color(0xFFFEF3C7),
          borderColor: const Color(0xFFFDE68A),
          backgroundColor: const Color(0xFFFFFBEB),
          title: 'Missing End Time: ${act.title}',
          description:
              'Activity "${act.title}" does not have an end time set. Specifying an end time helps organize your schedule.',
          actionLabel: 'Set End Time',
          actionBgColor: const Color(0xFFFEF3C7),
          actionTextColor: const Color(0xFFB45309),
          onAction: () => _openAddActivitySheet(
            date: currentDate,
            activityToEdit: act,
          ),
        ));
      }
    }

    // Flag Transport activities that are missing to and/or from locations
    for (final act in dayActivities) {
      if (act.category == ActivityCategory.transport) {
        final hasFrom = act.effectiveFromLocation != null &&
            act.effectiveFromLocation!.trim().isNotEmpty;
        final hasTo = act.effectiveToLocation != null &&
            act.effectiveToLocation!.trim().isNotEmpty;

        if (!hasFrom || !hasTo) {
          final String title;
          final String desc;
          final String actionText;

          if (!hasFrom && !hasTo) {
            title = 'Missing Route Locations: ${act.title}';
            desc =
                'Transport "${act.title}" is missing both departure (From) and destination (To) locations.';
            actionText = 'Set Route Locations';
          } else if (!hasFrom) {
            title = 'Missing Departure Location: ${act.title}';
            desc =
                'Transport "${act.title}" is missing a departure (From) location.';
            actionText = 'Set Departure Location';
          } else {
            title = 'Missing Destination Location: ${act.title}';
            desc =
                'Transport "${act.title}" is missing a destination (To) location.';
            actionText = 'Set Destination Location';
          }

          list.add(_SuggestionItem(
            icon: Icons.alt_route_rounded,
            iconColor: AppColors.transport,
            iconBgColor: AppColors.transportContainer,
            borderColor: AppColors.transport.withValues(alpha: 0.35),
            backgroundColor: AppColors.transportContainer.withValues(alpha: 0.2),
            title: title,
            description: desc,
            actionLabel: actionText,
            actionBgColor: AppColors.transportContainer,
            actionTextColor: AppColors.transport,
            onAction: () => _openAddActivitySheet(
              date: currentDate,
              activityToEdit: act,
            ),
          ));
        }
      }
    }

    // Location coverage check: Check if day's locations cover all activity locations
    // Note: Only genuine CITIES must be suggested (no bays, caves, attractions, airports, etc.)
    final missingCities = <String>{};
    for (final act in dayActivities) {
      final loc = act.location?.trim();
      if (loc == null || loc.isEmpty) continue;

      final candidate = _extractCityCandidate(
        loc,
        defaultCountry: defaultCountry,
        trip: trip,
        stays: stays,
        flights: allFlights,
      );
      if (candidate == null || candidate.isEmpty) continue;

      bool covered = false;
      for (final eff in effectiveLocations) {
        final effTrim = eff.trim();
        if (effTrim.isEmpty) continue;
        if (effTrim.toLowerCase() == defaultCountry.trim().toLowerCase()) continue;
        if (candidate.toLowerCase() == effTrim.toLowerCase() ||
            candidate.toLowerCase().contains(effTrim.toLowerCase()) ||
            effTrim.toLowerCase().contains(candidate.toLowerCase())) {
          covered = true;
          break;
        }
      }

      if (!covered) {
        missingCities.add(candidate);
      }
    }

    for (final missingCity in missingCities) {
      list.add(_SuggestionItem(
        icon: Icons.add_location_alt_rounded,
        iconColor: AppColors.primary,
        iconBgColor: AppColors.primaryContainer,
        borderColor: AppColors.primary.withValues(alpha: 0.3),
        backgroundColor: AppColors.primaryContainer.withValues(alpha: 0.3),
        title: 'Add missing location: $missingCity',
        description:
            'Activities on Day $dayNumber take place in "$missingCity", which is not in today\'s locations.',
        actionLabel: '+ Add "$missingCity"',
        actionBgColor: AppColors.primary,
        actionTextColor: Colors.white,
        onAction: () async {
          final current = effectiveLocations
              .where((l) => l.trim().toLowerCase() != defaultCountry.trim().toLowerCase())
              .toList();
          final updated = {...current, missingCity}.toList();
          await repo.updateDayLocations(trip.id, currentDate, updated);
        },
      ));
    }

    return list;
  }

  String? _extractCityCandidate(
    String location, {
    required String defaultCountry,
    required Trip trip,
    required List<Stay> stays,
    required List<Flight> flights,
  }) {
    final parts = location
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return null;

    final countryLower = defaultCountry.toLowerCase();

    // Check comma parts from right to left (skipping country if present)
    for (int i = parts.length - 1; i >= 0; i--) {
      final part = parts[i];
      final partLower = part.toLowerCase();

      // Skip country names
      if (partLower == countryLower || _isCountryName(partLower)) {
        continue;
      }

      if (_isCity(part, trip: trip, stays: stays, flights: flights)) {
        return _canonicalCityName(part);
      }
    }

    // Also check if any substring matches a known city from stays or flights
    for (final s in stays) {
      final stayCity = CityColorHelper.extractCityForStay(s);
      if (stayCity != null && stayCity.isNotEmpty) {
        if (location.toLowerCase().contains(stayCity.toLowerCase())) {
          return stayCity;
        }
      }
    }

    for (final f in flights) {
      final depCity = _extractCityFromAirportString(f.departureAirport);
      if (depCity.isNotEmpty && location.toLowerCase().contains(depCity.toLowerCase())) {
        return depCity;
      }
      final arrCity = _extractCityFromAirportString(f.arrivalAirport);
      if (arrCity.isNotEmpty && location.toLowerCase().contains(arrCity.toLowerCase())) {
        return arrCity;
      }
    }

    return null;
  }

  static String _extractCityFromAirportString(String str) {
    if (str.contains('(') && str.contains(')')) {
      final start = str.indexOf('(') + 1;
      final end = str.indexOf(')');
      if (end > start) {
        final inside = str.substring(start, end).trim();
        if (inside.length == 3 && inside.toUpperCase() == inside) {
          return str.substring(0, start - 1).trim();
        }
        return inside;
      }
    }
    return str.replaceAll(RegExp(r'\b[A-Z]{3}\b'), '').trim();
  }

  static bool _isCountryName(String lower) {
    const countries = {
      'thailand', 'japan', 'vietnam', 'cambodia', 'singapore',
      'south korea', 'korea', 'usa', 'united states', 'france',
      'italy', 'germany', 'spain', 'uk', 'united kingdom',
      'indonesia', 'malaysia', 'philippines', 'mexico', 'canada',
      'australia', 'new zealand', 'china', 'india', 'taiwan',
    };
    return countries.contains(lower);
  }

  static bool _isCity(
    String candidate, {
    required Trip trip,
    required List<Stay> stays,
    required List<Flight> flights,
  }) {
    final clean = candidate.trim();
    if (clean.isEmpty) return false;
    final lower = clean.toLowerCase();

    // Exclude strings containing non-city words (e.g. bay, cave, island, airport, etc.)
    final nonCityKeywords = [
      'bay', 'bahia', 'bahía', 'cave', 'cueva', 'beach', 'playa',
      'island', 'islands', 'isla', 'islas', 'airport', 'aeropuerto',
      'terminal', 'gate', 'station', 'estacion', 'estación', 'pier',
      'port', 'harbor', 'harbour', 'puerto', 'dock', 'cruise',
      'crucero', 'boat', 'ferry', 'park', 'parque', 'lake', 'lago',
      'river', 'rio', 'río', 'mountain', 'montaña', 'mount', 'peak',
      'waterfall', 'cascada', 'temple', 'wat', 'pagoda', 'church',
      'cathedral', 'mosque', 'museum', 'museo', 'market', 'mercado',
      'bazaar', 'mall', 'resort', 'hotel', 'hostel', 'villa', 'palace',
      'palacio', 'castle', 'tower', 'bridge', 'puente', 'street',
      'road', 'avenue', 'boulevard', 'calle', 'plaza', 'square',
      'zoo', 'aquarium', 'sanctuary', 'bar', 'cafe', 'café',
      'restaurant', 'restaurante', 'shop', 'store', 'alley', 'lane',
    ];

    for (final kw in nonCityKeywords) {
      final reg = RegExp(r'\b' + RegExp.escape(kw) + r'\b', caseSensitive: false);
      if (reg.hasMatch(lower)) {
        return false;
      }
    }

    // 1. Matches city from trip stays
    for (final s in stays) {
      final c = CityColorHelper.extractCityForStay(s);
      if (c != null && c.isNotEmpty && c.toLowerCase() == lower) {
        return true;
      }
    }

    // 2. Matches trip start/end location
    if (trip.startLocation != null && trip.startLocation!.trim().toLowerCase() == lower) {
      return true;
    }
    if (trip.endLocation != null && trip.endLocation!.trim().toLowerCase() == lower) {
      return true;
    }

    // 3. Matches flights departure or arrival city
    for (final f in flights) {
      final depCity = _extractCityFromAirportString(f.departureAirport).toLowerCase();
      if (depCity.isNotEmpty && (depCity == lower || lower.contains(depCity))) return true;
      final arrCity = _extractCityFromAirportString(f.arrivalAirport).toLowerCase();
      if (arrCity.isNotEmpty && (arrCity == lower || lower.contains(arrCity))) return true;
    }

    // 4. Matches existing dayLocations in trip
    if (trip.dayLocations.isNotEmpty) {
      for (final locs in trip.dayLocations.values) {
        for (final l in locs) {
          if (l.trim().toLowerCase() == lower) return true;
        }
      }
    }

    // 5. Common travel cities
    const knownCities = {
      'bangkok', 'chiang mai', 'chiang rai', 'phuket', 'krabi', 'pattaya',
      'ayutthaya', 'hua hin', 'surat thani', 'koh samui', 'samui', 'hanoi',
      'ha long', 'halong', 'ninh binh', 'da nang', 'danang', 'hoi an', 'hue',
      'ho chi minh city', 'ho chi minh', 'saigon', 'can tho', 'hai phong',
      'siem reap', 'phnom penh', 'battambang', 'singapore', 'kuala lumpur',
      'penang', 'george town', 'tokyo', 'kyoto', 'osaka', 'hiroshima',
      'nara', 'yokohama', 'sapporo', 'fukuoka', 'nagoya', 'nikko', 'hakone',
      'kamakura', 'kanazawa', 'takayama', 'kobe', 'miyajima', 'okinawa',
      'seoul', 'busan', 'incheon', 'jeju', 'taipei', 'kaohsiung', 'hong kong',
      'macau', 'beijing', 'shanghai', 'london', 'paris', 'rome', 'milan',
      'florence', 'venice', 'barcelona', 'madrid', 'seville', 'amsterdam',
      'berlin', 'munich', 'vienna', 'prague', 'budapest', 'zurich', 'geneva',
      'athens', 'lisbon', 'porto', 'new york', 'san francisco', 'los angeles',
      'seattle', 'chicago', 'boston', 'miami', 'las vegas', 'honolulu',
      'vancouver', 'toronto', 'montreal', 'sydney', 'melbourne', 'auckland',
    };

    return knownCities.contains(lower);
  }

  static String _canonicalCityName(String text) {
    final lower = text.trim().toLowerCase();
    if (lower == 'ha long' || lower == 'halong') return 'Ha Long';
    if (lower == 'ninh binh') return 'Ninh Binh';
    if (lower == 'chiang mai') return 'Chiang Mai';
    if (lower == 'chiang rai') return 'Chiang Rai';
    if (lower == 'siem reap') return 'Siem Reap';
    if (lower == 'ho chi minh city' || lower == 'ho chi minh' || lower == 'saigon') return 'Ho Chi Minh City';
    if (lower == 'da nang' || lower == 'danang') return 'Da Nang';
    if (lower == 'hoi an') return 'Hoi An';
    if (lower == 'san francisco') return 'San Francisco';
    if (lower == 'new york') return 'New York';
    if (lower == 'los angeles') return 'Los Angeles';
    if (lower == 'las vegas') return 'Las Vegas';
    if (lower == 'kuala lumpur') return 'Kuala Lumpur';
    if (lower == 'hong kong') return 'Hong Kong';
    return text.trim().split(' ').map((w) {
      if (w.isEmpty) return w;
      return w[0].toUpperCase() + w.substring(1).toLowerCase();
    }).join(' ');
  }

  // ---------------------------------------------------------------------------
  // Location Resolution Helpers
  // ---------------------------------------------------------------------------
  _LocationInfo _resolveWakeUpLocation({
    required Trip trip,
    required DateTime currentDate,
    required int dayIndex,
    required List<Stay> stays,
    required List<Flight> allFlights,
  }) {
    if (dayIndex == 0) {
      // Day 1
      if (trip.startLocation != null && trip.startLocation!.trim().isNotEmpty) {
        return _LocationInfo(
          title: trip.startLocation!,
          isMissing: false,
        );
      }
      // Check if a stay was already started before or on day 1
      for (final s in stays) {
        if (_normalize(s.checkInDate).isBefore(currentDate)) {
          return _LocationInfo(
            title: s.name,
            stay: s,
            isMissing: false,
          );
        }
      }
      return const _LocationInfo(
        title: 'Not specified (Trip Origin)',
        isMissing: true,
      );
    }

    final prevNight = currentDate.subtract(const Duration(days: 1));
    for (final s in stays) {
      final inD = _normalize(s.checkInDate);
      final outD = _normalize(s.checkOutDate);
      if ((inD.isBefore(prevNight) || _isSameDay(inD, prevNight)) &&
          outD.isAfter(prevNight)) {
        final city = CityColorHelper.extractCityForStay(s);
        final locText = (city != null && city.isNotEmpty) ? '$city • ${s.name}' : s.name;
        return _LocationInfo(
          title: locText,
          stay: s,
          isMissing: false,
        );
      }
    }

    // Check if arrived on an overnight flight this morning
    for (final f in allFlights) {
      if (f.isOvernight && _isSameDay(_normalize(f.arrivalTime), currentDate)) {
        return _LocationInfo(
          title: 'Arrival Flight (${f.departureAirport} → ${f.arrivalAirport})',
          flight: f,
          isMissing: false,
        );
      }
    }

    return const _LocationInfo(
      title: 'No lodging recorded for previous night',
      isMissing: true,
    );
  }

  _LocationInfo _resolveSleepAtLocation({
    required Trip trip,
    required DateTime currentDate,
    required int dayIndex,
    required List<Stay> stays,
    required List<Flight> allFlights,
  }) {
    for (final s in stays) {
      final inD = _normalize(s.checkInDate);
      final outD = _normalize(s.checkOutDate);
      if ((inD.isBefore(currentDate) || _isSameDay(inD, currentDate)) &&
          outD.isAfter(currentDate)) {
        final city = CityColorHelper.extractCityForStay(s);
        final locText = (city != null && city.isNotEmpty) ? '$city • ${s.name}' : s.name;
        return _LocationInfo(
          title: locText,
          stay: s,
          isMissing: false,
        );
      }
    }

    // Check if night is spent on an overnight flight departing today
    for (final f in allFlights) {
      final dep = _normalize(f.departureTime);
      final arr = _normalize(f.arrivalTime);
      if ((f.isOvernight || arr.isAfter(dep)) && _isSameDay(dep, currentDate)) {
        return _LocationInfo(
          title:
              'Overnight Flight: ${f.airline} ${f.flightNumber} (${f.departureAirport} → ${f.arrivalAirport})',
          flight: f,
          isMissing: false,
        );
      }
    }

    // Final day return home
    if (dayIndex == trip.daysCount - 1 &&
        trip.endLocation != null &&
        trip.endLocation!.trim().isNotEmpty) {
      return _LocationInfo(
        title: trip.endLocation!,
        isMissing: false,
      );
    }

    return const _LocationInfo(
      title: 'No lodging booked for tonight',
      isMissing: true,
    );
  }

  // ---------------------------------------------------------------------------
  // Utilities
  // ---------------------------------------------------------------------------
  static DateTime _normalize(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day);

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static int _parseMinutes(String timeStr) {
    try {
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        final h = int.parse(parts[0].trim());
        final m = int.parse(parts[1].trim());
        return h * 60 + m;
      }
    } catch (_) {}
    return 12 * 60;
  }

  static String _formatHourLabel(int hour) {
    if (hour == 0) return '12 AM';
    if (hour < 12) return '$hour AM';
    if (hour == 12) return '12 PM';
    return '${hour - 12} PM';
  }

  static Color _getCategoryColor(ActivityCategory cat) {
    switch (cat) {
      case ActivityCategory.stay:
        return AppColors.stay;
      case ActivityCategory.transport:
        return AppColors.transport;
      case ActivityCategory.dining:
        return AppColors.dining;
      case ActivityCategory.entertainment:
        return AppColors.entertainment;
      case ActivityCategory.attraction:
      case ActivityCategory.custom:
        return AppColors.attraction;
    }
  }

  static IconData _getCategoryIcon(ActivityCategory cat) {
    switch (cat) {
      case ActivityCategory.stay:
        return Icons.hotel_rounded;
      case ActivityCategory.transport:
        return Icons.directions_subway_rounded;
      case ActivityCategory.dining:
        return Icons.restaurant_rounded;
      case ActivityCategory.entertainment:
        return Icons.local_activity_rounded;
      case ActivityCategory.attraction:
        return Icons.account_balance_rounded;
      case ActivityCategory.custom:
        return Icons.place_rounded;
    }
  }
}

class _LocationInfo {
  final String title;
  final Stay? stay;
  final Flight? flight;
  final bool isMissing;

  const _LocationInfo({
    required this.title,
    this.stay,
    this.flight,
    this.isMissing = false,
  });
}

class _SuggestionItem {
  final IconData icon;
  final Color? iconColor;
  final Color? iconBgColor;
  final Color? borderColor;
  final Color? backgroundColor;
  final String title;
  final String description;
  final String? actionLabel;
  final Color? actionBgColor;
  final Color? actionTextColor;
  final VoidCallback? onAction;

  const _SuggestionItem({
    required this.icon,
    this.iconColor,
    this.iconBgColor,
    this.borderColor,
    this.backgroundColor,
    required this.title,
    required this.description,
    this.actionLabel,
    this.actionBgColor,
    this.actionTextColor,
    this.onAction,
  });
}

class _OverlapGroup {
  final int id;
  final List<Activity> activities;
  final int startMinutes;
  final int endMinutes;

  const _OverlapGroup({
    required this.id,
    required this.activities,
    required this.startMinutes,
    required this.endMinutes,
  });
}

