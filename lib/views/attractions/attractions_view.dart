import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_formatters.dart';
import '../../models/models.dart';
import '../../state/trip_providers.dart';
import '../common/add_flight_sheet.dart';
import '../common/add_stay_sheet.dart';

enum ActivityGrouping {
  day,
  category,
}

class AttractionsView extends ConsumerStatefulWidget {
  final VoidCallback? onAddActivity;
  final ValueChanged<Activity>? onActivityTap;

  const AttractionsView({
    super.key,
    this.onAddActivity,
    this.onActivityTap,
  });

  @override
  ConsumerState<AttractionsView> createState() => _AttractionsViewState();
}

class _AttractionsViewState extends ConsumerState<AttractionsView> {
  ActivityGrouping _grouping = ActivityGrouping.day;
  ActivityCategory? _selectedCategory;
  DateTimeRange? _selectedDateRange;
  BookingStatus? _selectedStatus;
  String _searchQuery = '';

  DateTime _normalizeDate(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  Future<void> _pickDateRange(BuildContext context, Trip? activeTrip) async {
    final firstDate = activeTrip?.startDate ?? DateTime(2020);
    final lastDate = activeTrip?.endDate ?? DateTime(2035);

    final picked = await showDateRangePicker(
      context: context,
      firstDate: firstDate.isBefore(DateTime.now().subtract(const Duration(days: 365 * 5)))
          ? firstDate
          : DateTime.now().subtract(const Duration(days: 365 * 5)),
      lastDate: lastDate.isAfter(DateTime.now().add(const Duration(days: 365 * 10)))
          ? lastDate
          : DateTime.now().add(const Duration(days: 365 * 10)),
      initialDateRange: _selectedDateRange ??
          (activeTrip != null
              ? DateTimeRange(start: activeTrip.startDate, end: activeTrip.endDate)
              : null),
    );

    if (picked != null) {
      setState(() => _selectedDateRange = picked);
    }
  }

  IconData _getCategoryIcon(ActivityCategory cat) {
    switch (cat) {
      case ActivityCategory.attraction:
        return Icons.account_balance_rounded;
      case ActivityCategory.dining:
        return Icons.restaurant_rounded;
      case ActivityCategory.transport:
        return Icons.directions_subway_rounded;
      case ActivityCategory.entertainment:
        return Icons.local_activity_rounded;
      case ActivityCategory.flight:
        return Icons.flight_takeoff_rounded;
      case ActivityCategory.stay:
        return Icons.hotel_rounded;
      case ActivityCategory.custom:
        return Icons.place_rounded;
    }
  }

  Color _getCategoryColor(ActivityCategory cat) {
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

  @override
  Widget build(BuildContext context) {
    final activitiesAsync = ref.watch(activeTripActivitiesProvider);
    final activeTrip = ref.watch(activeTripProvider);
    final canEdit = ref.watch(canEditActiveTripProvider);
    final repo = ref.watch(tripRepositoryProvider);

    return Scaffold(
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              heroTag: 'add_activity_fab',
              onPressed: widget.onAddActivity,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Add Activity',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              backgroundColor: AppColors.attraction,
            )
          : null,
      body: Column(
        children: [
          // Filter bar & Search
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search input
                TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search activities, hotels, restaurants, tours...',
                    hintStyle: const TextStyle(fontSize: 13),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setState(() => _searchQuery = ''),
                          )
                        : null,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
                const SizedBox(height: 10),

                // Grouping & Date Range Controls
                Row(
                  children: [
                    // Grouping Switcher
                    SegmentedButton<ActivityGrouping>(
                      showSelectedIcon: false,
                      style: SegmentedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      segments: const [
                        ButtonSegment(
                          value: ActivityGrouping.day,
                          icon: Icon(Icons.calendar_today_outlined, size: 14),
                          label: Text('By Day'),
                        ),
                        ButtonSegment(
                          value: ActivityGrouping.category,
                          icon: Icon(Icons.category_outlined, size: 14),
                          label: Text('By Category'),
                        ),
                      ],
                      selected: {_grouping},
                      onSelectionChanged: (set) => setState(() => _grouping = set.first),
                    ),
                    const SizedBox(width: 8),

                    // Date Range Filter Button / Chip
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: _selectedDateRange == null
                            ? OutlinedButton.icon(
                                onPressed: () => _pickDateRange(context, activeTrip),
                                icon: const Icon(Icons.date_range_rounded, size: 15),
                                label: const Text('All Dates', style: TextStyle(fontSize: 12)),
                                style: OutlinedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                ),
                              )
                            : InputChip(
                                avatar: const Icon(Icons.date_range_rounded, size: 14, color: AppColors.primary),
                                label: Text(
                                  '${DateFormatters.shortDate.format(_selectedDateRange!.start)} – ${DateFormatters.shortDate.format(_selectedDateRange!.end)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                                deleteIcon: const Icon(Icons.close, size: 14),
                                onDeleted: () => setState(() => _selectedDateRange = null),
                                onPressed: () => _pickDateRange(context, activeTrip),
                                visualDensity: VisualDensity.compact,
                                backgroundColor: AppColors.primaryContainer.withValues(alpha: 0.5),
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Category Chips Carousel
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('All Categories'),
                        selected: _selectedCategory == null,
                        onSelected: (_) => setState(() => _selectedCategory = null),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        avatar: const Icon(Icons.account_balance_rounded, size: 14),
                        label: const Text('Attractions'),
                        selected: _selectedCategory == ActivityCategory.attraction,
                        onSelected: (_) => setState(() => _selectedCategory =
                            _selectedCategory == ActivityCategory.attraction
                                ? null
                                : ActivityCategory.attraction),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        avatar: const Icon(Icons.hotel_rounded, size: 14),
                        label: const Text('Stays'),
                        selected: _selectedCategory == ActivityCategory.stay,
                        onSelected: (_) => setState(() => _selectedCategory =
                            _selectedCategory == ActivityCategory.stay
                                ? null
                                : ActivityCategory.stay),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        avatar: const Icon(Icons.restaurant_rounded, size: 14),
                        label: const Text('Dining'),
                        selected: _selectedCategory == ActivityCategory.dining,
                        onSelected: (_) => setState(() => _selectedCategory =
                            _selectedCategory == ActivityCategory.dining
                                ? null
                                : ActivityCategory.dining),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        avatar: const Icon(Icons.directions_subway_rounded, size: 14),
                        label: const Text('Transport'),
                        selected: _selectedCategory == ActivityCategory.transport,
                        onSelected: (_) => setState(() => _selectedCategory =
                            _selectedCategory == ActivityCategory.transport
                                ? null
                                : ActivityCategory.transport),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        avatar: const Icon(Icons.local_activity_rounded, size: 14),
                        label: const Text('Entertainment'),
                        selected: _selectedCategory == ActivityCategory.entertainment,
                        onSelected: (_) => setState(() => _selectedCategory =
                            _selectedCategory == ActivityCategory.entertainment
                                ? null
                                : ActivityCategory.entertainment),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        avatar: const Icon(Icons.flight_takeoff_rounded, size: 14),
                        label: const Text('Flight'),
                        selected: _selectedCategory == ActivityCategory.flight,
                        onSelected: (_) => setState(() => _selectedCategory =
                            _selectedCategory == ActivityCategory.flight
                                ? null
                                : ActivityCategory.flight),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        avatar: const Icon(Icons.more_horiz_rounded, size: 14),
                        label: const Text('Other'),
                        selected: _selectedCategory == ActivityCategory.custom,
                        onSelected: (_) => setState(() => _selectedCategory =
                            _selectedCategory == ActivityCategory.custom
                                ? null
                                : ActivityCategory.custom),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Activity List Content
          Expanded(
            child: activitiesAsync.when(
              data: (allActivities) {
                // Apply Filters
                final filtered = allActivities.where((a) {
                  // Category Filter
                  if (_selectedCategory != null && a.category != _selectedCategory) {
                    return false;
                  }
                  // Status Filter
                  if (_selectedStatus != null && a.bookingStatus != _selectedStatus) {
                    return false;
                  }
                  // Date Range Filter
                  if (_selectedDateRange != null) {
                    final actDay = _normalizeDate(a.date);
                    final startDay = _normalizeDate(_selectedDateRange!.start);
                    final endDay = _normalizeDate(_selectedDateRange!.end);
                    if (actDay.isBefore(startDay) || actDay.isAfter(endDay)) {
                      return false;
                    }
                  }
                  // Text Query Filter
                  if (_searchQuery.isNotEmpty) {
                    final q = _searchQuery.toLowerCase();
                    final titleMatch = a.title.toLowerCase().contains(q);
                    final locMatch = a.location?.toLowerCase().contains(q) ?? false;
                    final refMatch = a.confirmationRef?.toLowerCase().contains(q) ?? false;
                    return titleMatch || locMatch || refMatch;
                  }
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        const Text(
                          'No matching activities found',
                          style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  );
                }

                // Render Grouped by Day
                if (_grouping == ActivityGrouping.day) {
                  final Map<DateTime, List<Activity>> dayMap = {};
                  for (final act in filtered) {
                    final key = _normalizeDate(act.date);
                    dayMap.putIfAbsent(key, () => []).add(act);
                  }

                  final sortedDays = dayMap.keys.toList()..sort();
                  final tripDays = activeTrip?.daysList ?? [];

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: sortedDays.length,
                    itemBuilder: (context, dayIdx) {
                      final dayDate = sortedDays[dayIdx];
                      final dayActs = dayMap[dayDate]!
                        ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));

                      // Calculate trip day index if available
                      int? tripDayNum;
                      if (tripDays.isNotEmpty) {
                        final idx = tripDays.indexWhere((d) =>
                            d.year == dayDate.year &&
                            d.month == dayDate.month &&
                            d.day == dayDate.day);
                        if (idx >= 0) tripDayNum = idx + 1;
                      }

                      final headerTitle = tripDayNum != null
                          ? 'Day $tripDayNum  •  ${DateFormatters.dayHeader.format(dayDate)}'
                          : DateFormatters.dayHeader.format(dayDate);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Section Day Header
                          Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 8),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryContainer.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.calendar_today_rounded, size: 13, color: AppColors.primary),
                                      const SizedBox(width: 6),
                                      Text(
                                        headerTitle,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '(${dayActs.length})',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ),

                          // Activity Cards
                          ...dayActs.map((act) => _buildActivityCard(context, act, canEdit, repo)),
                        ],
                      );
                    },
                  );
                }

                // Render Grouped by Category
                final Map<ActivityCategory, List<Activity>> catMap = {};
                for (final act in filtered) {
                  catMap.putIfAbsent(act.category, () => []).add(act);
                }

                final sortedCats = ActivityCategory.values
                    .where((cat) => catMap.containsKey(cat) && catMap[cat]!.isNotEmpty)
                    .toList();

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: sortedCats.length,
                  itemBuilder: (context, catIdx) {
                    final cat = sortedCats[catIdx];
                    final catActs = catMap[cat]!
                      ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
                    final catColor = _getCategoryColor(cat);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Section Category Header
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 8),
                          child: Row(
                            children: [
                              Icon(_getCategoryIcon(cat), size: 16, color: catColor),
                              const SizedBox(width: 8),
                              Text(
                                cat.displayName,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: catColor,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${catActs.length}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Activity Cards
                        ...catActs.map((act) => _buildActivityCard(context, act, canEdit, repo)),
                      ],
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(
    BuildContext context,
    Activity act,
    bool canEdit,
    dynamic repo,
  ) {
    final activeTrip = ref.read(activeTripProvider);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: Checkbox(
          value: act.isCompleted,
          activeColor: AppColors.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          onChanged: canEdit
              ? (val) {
                  if (val != null) {
                    repo.updateActivity(act.copyWith(isCompleted: val));
                  }
                }
              : null,
        ),
        title: Row(
          children: [
            if (act.stayId != null) ...[
              Builder(
                builder: (context) {
                  final stays = ref.watch(activeTripStaysProvider).value ?? [];
                  final sty = stays.where((s) => s.id == act.stayId).firstOrNull;
                  final label = sty != null ? sty.name : 'Stay';
                  return InkWell(
                    onTap: sty != null
                        ? () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (ctx) => AddStaySheet(stayToEdit: sty),
                            );
                          }
                        : null,
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.stayContainer,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.stay.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.hotel_rounded, size: 12, color: AppColors.stay),
                          const SizedBox(width: 3),
                          Text(
                            label,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.stay,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 8, color: AppColors.stay),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ] else if (act.category == ActivityCategory.stay) ...[
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.stayContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.hotel_rounded, size: 12, color: AppColors.stay),
                    SizedBox(width: 3),
                    Text(
                      'Stay',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.stay,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (act.flightId != null) ...[
              Builder(
                builder: (context) {
                  final flights = ref.watch(activeTripFlightsProvider).value ?? [];
                  final flt = flights.where((f) => f.id == act.flightId).firstOrNull;
                  final label = flt != null ? '${flt.flightNumber} (${flt.airline})' : 'Flight';
                  return InkWell(
                    onTap: flt != null
                        ? () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (ctx) => AddFlightSheet(flightToEdit: flt),
                            );
                          }
                        : null,
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.flight_takeoff_rounded, size: 12, color: Color(0xFF0369A1)),
                          const SizedBox(width: 3),
                          Text(
                            label,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0369A1),
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 8, color: Color(0xFF0369A1)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
            Expanded(
              child: Text(
                act.title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  decoration: act.isCompleted ? TextDecoration.lineThrough : null,
                  color: act.isCompleted ? AppColors.textMuted : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  '${DateFormatters.shortDate.format(act.date)}  •  ${DateFormatters.formatTimeString(act.startTime)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                if (act.location != null) ...[
                  const Text('  •  ', style: TextStyle(color: Colors.grey)),
                  Expanded(
                    child: Text(
                      act.location!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
            if (act.confirmationRef != null && act.confirmationRef!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Confirmation: ${act.confirmationRef}',
                style: const TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ],
        ),
        trailing: canEdit
            ? PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18, color: AppColors.textSecondary),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onSelected: (val) async {
                  if (val == 'edit') {
                    widget.onActivityTap?.call(act);
                  }
                  if (val == 'delete') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete Activity'),
                        content: Text('Are you sure you want to remove "${act.title}"?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Delete', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true && activeTrip != null) {
                      await repo.deleteActivity(activeTrip.id, act.id);
                    }
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 16),
                        SizedBox(width: 8),
                        Text('Edit Activity'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 16, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete Activity', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              )
            : const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
        onTap: () => widget.onActivityTap?.call(act),
      ),
    );
  }
}
