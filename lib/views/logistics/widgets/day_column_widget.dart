import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatters.dart';
import '../../../models/models.dart';
import 'activity_card_widget.dart';
import 'flight_day_card_widget.dart';

class DayColumnWidget extends StatelessWidget {
  final DateTime date;
  final int dayNumber;
  final List<Activity> activities;
  final List<Flight> flights;
  final List<String> locations;
  final bool canEdit;
  final void Function(DateTime date)? onAddActivity;
  final ValueChanged<Activity>? onActivityTap;
  final ValueChanged<Flight>? onFlightTap;
  final VoidCallback? onManageLocations;

  const DayColumnWidget({
    super.key,
    required this.date,
    required this.dayNumber,
    required this.activities,
    this.flights = const [],
    this.locations = const [],
    this.canEdit = true,
    this.onAddActivity,
    this.onActivityTap,
    this.onFlightTap,
    this.onManageLocations,
  });

  @override
  Widget build(BuildContext context) {
    final isToday = _isToday(date);

    return Container(
      width: 290,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isToday ? Colors.blue.shade50.withValues(alpha: 0.3) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isToday ? AppColors.primary : AppColors.border,
          width: isToday ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Date & Day Number
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isToday
                  ? AppColors.primary
                  : const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
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
                          for (final loc in locations)
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
                                  Flexible(
                                    child: Text(
                                      loc,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: isToday
                                            ? Colors.white
                                            : AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (canEdit)
                            InkWell(
                              onTap: onManageLocations,
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
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.edit_location_alt_outlined,
                                      size: 11,
                                      color: isToday
                                          ? Colors.white
                                          : AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      locations.isEmpty ? '+ Loc' : 'Edit',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                        color: isToday
                                            ? Colors.white
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Activity & Flight count circle badge
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
                    flights.isEmpty
                        ? '${activities.length} ${activities.length == 1 ? 'activity' : 'activities'}'
                        : '${activities.length + flights.length} ${activities.length + flights.length == 1 ? 'item' : 'items'}',
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

          // Schedule Items Content (Activities & Flights)
          Expanded(
            child: (activities.isEmpty && flights.isEmpty)
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 32,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No activities planned yet',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (canEdit) ...[
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: () => onAddActivity?.call(date),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Add Activity'),
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                : Builder(
                    builder: (context) {
                      final scheduleItems = <_DayScheduleItem>[
                        for (final a in activities) _DayScheduleItem.activity(a),
                        for (final f in flights) _DayScheduleItem.flight(f),
                      ]..sort((a, b) =>
                          a.minutesFromMidnight.compareTo(b.minutesFromMidnight));

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        itemCount: scheduleItems.length,
                        itemBuilder: (context, index) {
                          final item = scheduleItems[index];
                          if (item.isFlight) {
                            return FlightDayCardWidget(
                              flight: item.flight!,
                              onTap: () => onFlightTap?.call(item.flight!),
                            );
                          }
                          return ActivityCardWidget(
                            activity: item.activity!,
                            onTap: () => onActivityTap?.call(item.activity!),
                          );
                        },
                      );
                    },
                  ),
          ),

          // Bottom Quick Add Button
          if (canEdit && (activities.isNotEmpty || flights.isNotEmpty))
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: OutlinedButton.icon(
                onPressed: () => onAddActivity?.call(date),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text(
                  'Add Activity',
                  style: TextStyle(fontSize: 13),
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

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }
}

class _DayScheduleItem {
  final Activity? activity;
  final Flight? flight;
  final int minutesFromMidnight;

  bool get isFlight => flight != null;
  bool get isActivity => activity != null;

  _DayScheduleItem.activity(Activity a)
      : activity = a,
        flight = null,
        minutesFromMidnight = _parseMinutes(a.startTime);

  _DayScheduleItem.flight(Flight f)
      : flight = f,
        activity = null,
        minutesFromMidnight = f.departureTime.hour * 60 + f.departureTime.minute;

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
}
