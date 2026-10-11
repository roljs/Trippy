import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/city_color_helper.dart';
import '../../../core/utils/date_formatters.dart';
import '../../../core/utils/location_inference_helper.dart';
import '../../../models/models.dart';
import '../../common/add_stay_sheet.dart';

/// A traditional monthly calendar view where each day is represented as a square.
/// Shows at a glance:
/// - Where the user is spending the day (locations inside subtle rounded outline rectangles)
/// - Total count of planned activities (bottom-left)
/// - Clickable flight icons (bottom-right)
/// - Clickable stay icon (bottom-right corner) to view Stay details card
/// - Navigates from any day to the same day in the Day Planner view
class CalendarItineraryView extends StatefulWidget {
  final Trip trip;
  final List<Stay> stays;
  final List<Flight> flights;
  final Map<DateTime, List<Activity>> activitiesByDay;
  final bool canEdit;
  final ValueChanged<Stay>? onStayTap;
  final ValueChanged<Flight>? onFlightTap;
  final ValueChanged<DateTime>? onDayTap;
  final void Function(DateTime checkIn, DateTime checkOut)? onAddStayForDates;

  const CalendarItineraryView({
    super.key,
    required this.trip,
    required this.stays,
    required this.flights,
    required this.activitiesByDay,
    this.canEdit = true,
    this.onStayTap,
    this.onFlightTap,
    this.onDayTap,
    this.onAddStayForDates,
  });

  @override
  State<CalendarItineraryView> createState() => _CalendarItineraryViewState();
}

class _CalendarItineraryViewState extends State<CalendarItineraryView> {
  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();
  late List<DateTime> _months;
  late DateTime _focusedMonth;

  // Distinct color palette for flights happening on a given day
  static const List<Color> _flightColors = [
    Color(0xFF2563EB), // Blue
    Color(0xFF7C3AED), // Purple
    Color(0xFF0D9488), // Teal
    Color(0xFFEA580C), // Orange
    Color(0xFFE11D48), // Rose
    Color(0xFF4F46E5), // Indigo
    Color(0xFF059669), // Emerald
  ];

  @override
  void initState() {
    super.initState();
    _computeMonths();
    _focusedMonth = _months.isNotEmpty
        ? _months.first
        : DateTime(widget.trip.startDate.year, widget.trip.startDate.month, 1);
  }

  @override
  void didUpdateWidget(covariant CalendarItineraryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trip.startDate != widget.trip.startDate ||
        oldWidget.trip.endDate != widget.trip.endDate) {
      _computeMonths();
      if (_months.isNotEmpty &&
          !_months.any((m) =>
              m.year == _focusedMonth.year && m.month == _focusedMonth.month)) {
        _focusedMonth = _months.first;
      }
    }
  }

  void _computeMonths() {
    final start = widget.trip.startDate;
    final end = widget.trip.endDate;
    final months = <DateTime>[];

    var curr = DateTime(start.year, start.month, 1);
    final last = DateTime(end.year, end.month, 1);

    while (!curr.isAfter(last)) {
      months.add(curr);
      curr = DateTime(curr.year, curr.month + 1, 1);
    }

    if (months.isEmpty) {
      months.add(DateTime(start.year, start.month, 1));
    }

    _months = months;
  }

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Stay? _resolveNightStayForDate(DateTime date) {
    // A stay bridges the night from date into date + 1
    for (final s in widget.stays) {
      final inD = DateTime(s.checkInDate.year, s.checkInDate.month, s.checkInDate.day);
      final outD = DateTime(s.checkOutDate.year, s.checkOutDate.month, s.checkOutDate.day);

      if (!inD.isAfter(date) && outD.isAfter(date)) {
        return s;
      }
    }

    // Also check for overnight flights that bridge across days as a Stay
    for (final f in widget.flights) {
      if (f.spansAcrossDays || f.isNightStay || f.isOvernight) {
        final depD = DateTime(f.departureTime.year, f.departureTime.month, f.departureTime.day);
        final arrD = DateTime(f.arrivalTime.year, f.arrivalTime.month, f.arrivalTime.day);
        if (!depD.isAfter(date) && arrD.isAfter(date)) {
          return Stay(
            id: 'flight_stay_${f.id}',
            tripId: widget.trip.id,
            name: 'Flight ${f.flightNumber} (${f.airline})',
            address: '${f.departureAirport} → ${f.arrivalAirport}',
            checkInDate: f.departureTime,
            checkOutDate: f.arrivalTime,
            type: StayType.overnightFlight,
            confirmationCode: f.bookingRef,
          );
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final days = widget.trip.daysList;
    if (days.isEmpty) {
      return const Center(
        child: Text(
          'No days configured for this trip.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    final monthName = DateFormatters.monthYear.format(_focusedMonth);

    return LayoutBuilder(
      builder: (context, constraints) {
        const double minGridWidth = 960.0;
        final double gridWidth = constraints.maxWidth > minGridWidth
            ? constraints.maxWidth
            : minGridWidth;

        return Column(
          children: [
            // Month Switcher Header with full month navigator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE2E8F0), width: 0.8),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.calendar_month_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '(${widget.trip.daysList.length} Days total)',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),

                  // Month Navigator controls
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded),
                        tooltip: 'Previous Month',
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          setState(() {
                            _focusedMonth = DateTime(
                              _focusedMonth.year,
                              _focusedMonth.month - 1,
                              1,
                            );
                          });
                        },
                      ),
                      PopupMenuButton<DateTime>(
                        tooltip: 'Select Month',
                        initialValue: _focusedMonth,
                        onSelected: (date) {
                          setState(() {
                            _focusedMonth = date;
                          });
                        },
                        itemBuilder: (context) {
                          return _months.map((m) {
                            final isSelected = m.year == _focusedMonth.year &&
                                m.month == _focusedMonth.month;
                            return PopupMenuItem<DateTime>(
                              value: m,
                              child: Row(
                                children: [
                                  Icon(
                                    isSelected
                                        ? Icons.check_circle_rounded
                                        : Icons.calendar_today_outlined,
                                    size: 16,
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    DateFormatters.monthYear.format(m).toUpperCase(),
                                    style: TextStyle(
                                      fontWeight: isSelected
                                          ? FontWeight.w800
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? AppColors.primary
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                monthName.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.arrow_drop_down_rounded,
                                size: 18,
                                color: AppColors.textSecondary,
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded),
                        tooltip: 'Next Month',
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          setState(() {
                            _focusedMonth = DateTime(
                              _focusedMonth.year,
                              _focusedMonth.month + 1,
                              1,
                            );
                          });
                        },
                      ),
                    ],
                  ),

                  // Reset to Trip Start if outside trip range, or balance spacer
                  if (!_months.any((m) =>
                      m.year == _focusedMonth.year &&
                      m.month == _focusedMonth.month))
                    TextButton.icon(
                      icon: const Icon(Icons.restore_rounded, size: 14),
                      label: const Text('Trip Start',
                          style: TextStyle(fontSize: 11)),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: () {
                        setState(() {
                          _focusedMonth = _months.isNotEmpty
                              ? _months.first
                              : DateTime(
                                  widget.trip.startDate.year,
                                  widget.trip.startDate.month,
                                  1,
                                );
                        });
                      },
                    )
                  else
                    const SizedBox(width: 80),
                ],
              ),
            ),

            // Scrollable Calendar Grid
            Expanded(
              child: Scrollbar(
                controller: _horizontalController,
                thumbVisibility: true,
                trackVisibility: true,
                child: SingleChildScrollView(
                  controller: _horizontalController,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: gridWidth,
                    child: Scrollbar(
                      controller: _verticalController,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _verticalController,
                        padding: const EdgeInsets.all(16),
                        child: _buildMonthCalendar(
                          context: context,
                          month: _focusedMonth,
                          gridWidth: gridWidth - 32,
                        ),
                      ),
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

  Widget _buildMonthCalendar({
    required BuildContext context,
    required DateTime month,
    required double gridWidth,
  }) {
    const weekdays = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];

    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    // Sunday = 0, Monday = 1, ..., Saturday = 6
    final leadingBlanks = firstDayOfMonth.weekday % 7;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final totalCells = leadingBlanks + daysInMonth;
    final rowsCount = (totalCells / 7).ceil();

    final colWidth = gridWidth / 7.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Weekday Header Row
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            border: Border.all(color: const Color(0xFFCBD5E1), width: 0.8),
          ),
          child: Row(
            children: [
              for (int w = 0; w < 7; w++)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border(
                        right: w < 6
                            ? const BorderSide(
                                color: Color(0xFFE2E8F0), width: 0.8)
                            : BorderSide.none,
                      ),
                    ),
                    child: Text(
                      weekdays[w],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: (w == 0 || w == 6)
                            ? Colors.blueGrey.shade400
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),        // 2. Calendar Rows Grid
        for (int r = 0; r < rowsCount; r++) ...[
          SizedBox(
            height: 145.0,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int c = 0; c < 7; c++) ...[
                  Builder(
                    builder: (context) {
                      final cellIndex = (r * 7) + c;
                      final dayNum = cellIndex - leadingBlanks + 1;

                      if (dayNum < 1 || dayNum > daysInMonth) {
                        return Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAFAFA),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                                width: 0.5,
                              ),
                            ),
                          ),
                        );
                      }

                      final cellDate =
                          DateTime(month.year, month.month, dayNum);
                      return Expanded(
                        child: _buildDaySquare(
                          context: context,
                          date: cellDate,
                          colWidth: colWidth,
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStayIcon(BuildContext context, Stay stay, DateTime date) {
    final isFlight =
        stay.type == StayType.overnightFlight || stay.overnightFlight != null;
    final palette = isFlight
        ? CityColorHelper.flightPalette
        : CityColorHelper.getStayPalette(
            stay: stay,
            allStaysInTrip: widget.stays,
          );
    final stayColor = palette.gradient.first;

    final IconData stayIcon;
    if (isFlight) {
      stayIcon = Icons.flight_takeoff_rounded;
    } else if (stay.type == StayType.rental) {
      stayIcon = Icons.holiday_village_rounded;
    } else if (stay.type == StayType.nightTrain) {
      stayIcon = Icons.train_rounded;
    } else {
      stayIcon = Icons.hotel_rounded;
    }

    final tooltipText =
        'Stay: ${stay.name}${stay.address != null && stay.address!.isNotEmpty ? " (${stay.address})" : ""} • Click to view stay details';

    return Tooltip(
      message: tooltipText,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('calendar_stay_icon_${date.year}_${date.month}_${date.day}'),
          onTap: () => _handleStayTap(context, stay),
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 1.0),
            child: Icon(
              stayIcon,
              size: 13,
              color: stayColor,
            ),
          ),
        ),
      ),
    );
  }

  void _handleStayTap(BuildContext context, Stay stay) {
    if (widget.onStayTap != null) {
      widget.onStayTap!(stay);
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => AddStaySheet(stayToEdit: stay),
      );
    }
  }

  Color _resolveDayBackgroundColor(DateTime date, Stay? nightStay) {
    if (nightStay != null) {
      if (nightStay.type == StayType.overnightFlight ||
          nightStay.overnightFlight != null) {
        return CityColorHelper.flightPastel;
      }
      final city =
          CityColorHelper.extractCityForStay(nightStay) ?? nightStay.name;
      final palette =
          CityColorHelper.getPaletteForCity(city, allStaysInTrip: widget.stays);
      return Color.lerp(palette.gradient.first, Colors.white, 0.90)!;
    }

    final customLocations = widget.trip.getCustomLocationsForDate(date);
    final city = (customLocations != null && customLocations.isNotEmpty)
        ? customLocations.last
        : null;
    if (city != null && city.isNotEmpty) {
      final palette =
          CityColorHelper.getPaletteForCity(city, allStaysInTrip: widget.stays);
      return Color.lerp(palette.gradient.first, Colors.white, 0.92)!;
    }

    return Colors.white;
  }

  Color _resolveCityColor(String loc, DateTime date, Stay? nightStay) {
    if (nightStay != null &&
        (nightStay.type == StayType.overnightFlight ||
            nightStay.overnightFlight != null)) {
      return AppColors.flight;
    }
    final palette =
        CityColorHelper.getPaletteForCity(loc, allStaysInTrip: widget.stays);
    return palette.gradient.first;
  }

  ({String mainLocation, List<String> otherLocations}) _partitionDayLocations({
    required List<String> effectiveLocations,
    required Stay? nightStay,
  }) {
    if (effectiveLocations.isEmpty) {
      return (mainLocation: '', otherLocations: <String>[]);
    }

    if (effectiveLocations.length == 1) {
      return (mainLocation: effectiveLocations.first, otherLocations: <String>[]);
    }

    // If there is a stay, try to match which effective location corresponds to the stay
    if (nightStay != null) {
      final stayCity =
          CityColorHelper.extractCityForStay(nightStay)?.toLowerCase() ?? '';
      final stayName = nightStay.name.toLowerCase();
      final stayAddr = nightStay.address?.toLowerCase() ?? '';

      // 1. Highest priority: Match extracted stay CITY (e.g. "Tokyo" from "Grand Hyatt Tokyo")
      if (stayCity.isNotEmpty) {
        for (int i = 0; i < effectiveLocations.length; i++) {
          final loc = effectiveLocations[i];
          final locLower = loc.toLowerCase();
          if (locLower == stayCity ||
              locLower.contains(stayCity) ||
              stayCity.contains(locLower)) {
            final others = List<String>.from(effectiveLocations)..removeAt(i);
            return (mainLocation: loc, otherLocations: others);
          }
        }
      }

      // 2. Second priority: Match stay name (e.g. "Nikko Ryokan" contains "nikko")
      for (int i = 0; i < effectiveLocations.length; i++) {
        final loc = effectiveLocations[i];
        final locLower = loc.toLowerCase();
        if (stayName.contains(locLower)) {
          final others = List<String>.from(effectiveLocations)..removeAt(i);
          return (mainLocation: loc, otherLocations: others);
        }
      }

      // 3. Third priority: Match address parts from last to first (city before country in address)
      for (int i = effectiveLocations.length - 1; i >= 0; i--) {
        final loc = effectiveLocations[i];
        final locLower = loc.toLowerCase();
        if (stayAddr.contains(locLower)) {
          final others = List<String>.from(effectiveLocations)..removeAt(i);
          return (mainLocation: loc, otherLocations: others);
        }
      }
    }

    // Default fallback: The last location in effectiveLocations is where you end the day / stay
    final mainLoc = effectiveLocations.last;
    final others = effectiveLocations.sublist(0, effectiveLocations.length - 1);
    return (mainLocation: mainLoc, otherLocations: others);
  }

  Widget _buildDaySquare({
    required BuildContext context,
    required DateTime date,
    required double colWidth,
  }) {
    final days = widget.trip.daysList;
    final tripDayIndex = days.indexWhere((d) => _isSameDay(d, date));
    final isTripDay = tripDayIndex != -1;
    final isToday = _isSameDay(date, DateTime.now());

    if (!isTripDay) {
      // Day is outside the trip range
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFFBFBFB),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 0.5),
        ),
        child: Align(
          alignment: Alignment.topLeft,
          child: Text(
            '${date.day}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFFCBD5E1),
            ),
          ),
        ),
      );
    }

    final dayNumber = tripDayIndex + 1;
    final customLocations = widget.trip.getCustomLocationsForDate(date);
    final defaultCountry = LocationInferenceHelper.inferTargetCountryForDay(
      date: date,
      flights: widget.flights,
      activities: widget.activitiesByDay.values.expand((x) => x).toList(),
      tripDestination: widget.trip.destination,
    );
    final effectiveLocations = customLocations ?? [defaultCountry];
    final dayActivities = widget.activitiesByDay[date] ?? [];

    // Flights occurring on this day (departing or arriving)
    final dayFlights = widget.flights.where((f) {
      return _isSameDay(f.departureTime, date) ||
          _isSameDay(f.arrivalTime, date);
    }).toList();

    // Night stay bridging this day to next day
    final nightStay = _resolveNightStayForDate(date);
    final Color bgColor = _resolveDayBackgroundColor(date, nightStay);

    final partitioned = _partitionDayLocations(
      effectiveLocations: effectiveLocations,
      nightStay: nightStay,
    );
    final mainLocation = partitioned.mainLocation;
    final otherLocations = partitioned.otherLocations;

    return InkWell(
      onTap: () => widget.onDayTap?.call(date),
      child: Container(
        decoration: BoxDecoration(
          color: isToday
              ? Color.lerp(bgColor, AppColors.primaryContainer, 0.45)!
              : bgColor,
          border: Border.all(
            color: isToday ? AppColors.primary : const Color(0xFFCBD5E1),
            width: isToday ? 1.8 : 0.6,
          ),
          boxShadow: isToday
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    blurRadius: 4,
                  ),
                ]
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Day Header: Date Number + Day of Week + "Day X" pill + Day Planner shortcut
            Row(
              children: [
                Text(
                  '${date.day}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isToday ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  DateFormatters.weekdayShort.format(date).toUpperCase(),
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color:
                        isToday ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: isToday
                        ? AppColors.primary
                        : AppColors.primaryContainer.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Day $dayNumber',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      color: isToday ? Colors.white : AppColors.primary,
                    ),
                  ),
                ),
                const Spacer(),
                Tooltip(
                  message: 'View Day $dayNumber in Day Planner',
                  child: InkWell(
                    onTap: () => widget.onDayTap?.call(date),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: Icon(
                        Icons.open_in_new_rounded,
                        size: 13,
                        color: isToday
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // 2. Main Center Element: Location where you are staying in bigger font inside a rectangle,
            // with other cities/locations shown in small grayed-out font on top of the rectangle.
            // Equal-flex architecture guarantees the main city rectangle is ALWAYS vertically centered.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  children: [
                    // Top area: other locations aligned to bottom of this flexible space
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: otherLocations.isEmpty
                            ? const SizedBox.shrink()
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  for (final otherLoc in otherLocations) ...[
                                    Text(
                                      otherLoc,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF64748B),
                                        letterSpacing: 0.2,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 1),
                                  ],
                                  const SizedBox(height: 1),
                                ],
                              ),
                      ),
                    ),

                    // Main city/location where you are staying in bigger font inside a rectangle
                    if (mainLocation.isNotEmpty)
                      Builder(
                        builder: (context) {
                          final locColor =
                              _resolveCityColor(mainLocation, date, nightStay);
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: locColor,
                                width: 1.0,
                              ),
                            ),
                            child: Text(
                              mainLocation,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: locColor,
                                letterSpacing: 0.2,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        },
                      ),

                    // Bottom area: equal flex so main city rectangle is perfectly centered
                    const Expanded(
                      child: SizedBox(),
                    ),
                  ],
                ),
              ),
            ),

            // 3. Bottom Row: Total activities count (aligned LEFT) & Flight / Stay icons (aligned RIGHT)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Left: Total count of planned activities (number only, without 'acts' suffix)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.event_note_rounded,
                      size: 11,
                      color: dayActivities.isNotEmpty
                          ? AppColors.textSecondary
                          : AppColors.textMuted,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${dayActivities.length}',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: dayActivities.isNotEmpty
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                // Right: Flight icon(s) and Stay icon
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (dayFlights.isNotEmpty) ...[
                      for (int idx = 0; idx < dayFlights.length; idx++) ...[
                        Builder(
                          builder: (context) {
                            final flt = dayFlights[idx];
                            final fltColor =
                                _flightColors[idx % _flightColors.length];
                            final isDep = _isSameDay(flt.departureTime, date);
                            final tooltipText =
                                '${flt.airline} ${flt.flightNumber} • ${flt.departureAirport} → ${flt.arrivalAirport} • ${DateFormatters.time12.format(flt.departureTime)} • Click for details';

                            return Tooltip(
                              message: tooltipText,
                              child: InkWell(
                                onTap: () => widget.onFlightTap?.call(flt),
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 1.5),
                                  margin: const EdgeInsets.only(left: 3),
                                  decoration: BoxDecoration(
                                    color: fltColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: fltColor.withValues(alpha: 0.5),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isDep
                                            ? Icons.flight_takeoff_rounded
                                            : Icons.flight_land_rounded,
                                        size: 11,
                                        color: fltColor,
                                      ),
                                      if (dayFlights.length == 1 &&
                                          flt.flightNumber.isNotEmpty) ...[
                                        const SizedBox(width: 2),
                                        Text(
                                          flt.flightNumber,
                                          style: TextStyle(
                                            fontSize: 8.5,
                                            fontWeight: FontWeight.w800,
                                            color: fltColor,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                    if (nightStay != null) ...[
                      if (dayFlights.isNotEmpty) const SizedBox(width: 4),
                      _buildStayIcon(context, nightStay, date),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

