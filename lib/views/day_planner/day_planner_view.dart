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

    for (final f in flights) {
      allMinutes.add(f.departureTime.hour * 60 + f.departureTime.minute);
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
    if (_selectedDate == null || !days.any((d) => _isSameDay(d, _selectedDate!))) {
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
      return _isSameDay(dep, currentDate);
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

    // Compute Suggestions
    final suggestions = _generateSuggestions(
      trip: trip,
      currentDate: currentDate,
      dayNumber: dayNumber,
      dayIndex: currentDayIndex,
      dayActivities: dayActivities,
      wakeUpInfo: wakeUpInfo,
      sleepAtInfo: sleepAtInfo,
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
                  const Spacer(),

                  // Day Navigation Controls (Prev, Dropdown Selector, Next)
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded, size: 22),
                    tooltip: 'Previous Day',
                    visualDensity: VisualDensity.compact,
                    onPressed: currentDayIndex > 0
                        ? () {
                            setState(() {
                              _selectedDate = days[currentDayIndex - 1];
                              _hasInitialScrolled = false;
                            });
                          }
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
                    onSelected: (idx) {
                      setState(() {
                        _selectedDate = days[idx];
                        _hasInitialScrolled = false;
                      });
                    },
                  ),

                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded, size: 22),
                    tooltip: 'Next Day',
                    visualDensity: VisualDensity.compact,
                    onPressed: currentDayIndex < days.length - 1
                        ? () {
                            setState(() {
                              _selectedDate = days[currentDayIndex + 1];
                              _hasInitialScrolled = false;
                            });
                          }
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
                      onPressed: () {
                        setState(() {
                          _selectedDate = days.firstWhere(
                              (d) => _isSameDay(d, DateTime.now()));
                          _hasInitialScrolled = false;
                        });
                      },
                    ),
                  ],
                ],
              ),
            ),

            // Main Content Area: Single-Day Pane + Right Suggestions Pane
            Expanded(
              child: Container(
                color: const Color(0xFFF8FAFC),
                child: Center(
                  child: SingleChildScrollView(
                    scrollDirection: isWide ? Axis.horizontal : Axis.vertical,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    child: isWide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // 1. Single Day Pane (expanded, ~450dp)
                              SizedBox(
                                width: 450,
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
                              const SizedBox(width: 24),

                              // 2. Right Suggestions Pane (~380dp)
                              SizedBox(
                                width: 380,
                                height: constraints.maxHeight - 75,
                                child: _buildSuggestionsPane(
                                  suggestions: suggestions,
                                  dayNumber: dayNumber,
                                  canEdit: canEdit,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Mobile layout: Single Day Pane
                              SizedBox(
                                height: 600,
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
                              const SizedBox(height: 20),
                              // Mobile layout: Suggestions Pane below
                              _buildSuggestionsPane(
                                suggestions: suggestions,
                                dayNumber: dayNumber,
                                canEdit: canEdit,
                              ),
                            ],
                          ),
                  ),
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
                                    size: 11,
                                    color: isToday
                                        ? Colors.white
                                        : AppColors.primary,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    loc,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: isToday
                                          ? Colors.white
                                          : AppColors.primary,
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

                  return Positioned(
                    left: 56,
                    right: 12,
                    top: topPos,
                    height: cardHeight,
                    child: InkWell(
                      onTap: () => widget.onActivityTap != null
                          ? widget.onActivityTap!(act)
                          : _openAddActivitySheet(date: date, activityToEdit: act),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.grey.shade300,
                            width: 0.8,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
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
                  final startMin =
                      flt.departureTime.hour * 60 + flt.departureTime.minute;
                  int durationMin = max(45, flt.duration.inMinutes);
                  final double topPos = startMin * (hourHeight / 60.0);
                  final double cardHeight = durationMin * (hourHeight / 60.0);

                  return Positioned(
                    left: 56,
                    right: 12,
                    top: topPos,
                    height: max(42.0, cardHeight),
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
                                      horizontal: 8, vertical: 4),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  DateFormatters.time12
                                                      .format(flt.departureTime),
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors.flight,
                                                  ),
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
                                              ],
                                            ),
                                            Text(
                                              '${flt.departureAirport} → ${flt.arrivalAirport}',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w500,
                                                color: AppColors.textSecondary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons.flight_takeoff_rounded,
                                        size: 16,
                                        color: AppColors.flight,
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
    required int dayNumber,
    required bool canEdit,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
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
                  color: suggestions.isEmpty
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  suggestions.isEmpty
                      ? 'ALL SET'
                      : '${suggestions.length} ACTION${suggestions.length == 1 ? '' : 'S'}',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: suggestions.isEmpty
                        ? const Color(0xFF15803D)
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 12),

          // Suggestion Cards List
          Expanded(
            child: suggestions.isEmpty
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
                            'Breakfast, Lunch, Dinner, and Lodging are all confirmed for Day $dayNumber.',
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
                    itemCount: suggestions.length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final s = suggestions[i];
                      return _buildSuggestionCard(s, canEdit);
                    },
                  ),
          ),
        ],
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
      final title = a.title.toLowerCase();
      final minutes = _parseMinutes(a.startTime);
      return a.category == ActivityCategory.dining ||
          title.contains('breakfast') ||
          title.contains('desayuno') ||
          (minutes >= 6 * 60 && minutes <= 11 * 60);
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
        ),
      ));
    }

    // 2a: Check Lunch
    final bool hasLunch = dayActivities.any((a) {
      final title = a.title.toLowerCase();
      final minutes = _parseMinutes(a.startTime);
      return (a.category == ActivityCategory.dining &&
              minutes >= 11 * 60 + 30 &&
              minutes <= 16 * 60) ||
          title.contains('lunch') ||
          title.contains('almuerzo') ||
          title.contains('comida');
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
        ),
      ));
    }

    // 2a: Check Dinner
    final bool hasDinner = dayActivities.any((a) {
      final title = a.title.toLowerCase();
      final minutes = _parseMinutes(a.startTime);
      return (a.category == ActivityCategory.dining && minutes >= 17 * 60) ||
          title.contains('dinner') ||
          title.contains('cena');
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
        ),
      ));
    }

    return list;
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
      case ActivityCategory.flight:
        return AppColors.flight;
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
      case ActivityCategory.flight:
        return Icons.flight_takeoff_rounded;
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
