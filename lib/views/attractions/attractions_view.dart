import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_formatters.dart';
import '../../models/models.dart';
import '../../state/trip_providers.dart';

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
  ActivityCategory? _selectedCategory;
  BookingStatus? _selectedStatus;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final activitiesAsync = ref.watch(activeTripActivitiesProvider);
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
            children: [
              // Search input
              TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search activities, restaurants, tours...',
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

              // Filter Chips Carousel
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('All Categories'),
                      selected: _selectedCategory == null,
                      onSelected: (_) =>
                          setState(() => _selectedCategory = null),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      avatar: const Icon(Icons.account_balance_rounded, size: 14),
                      label: const Text('Attractions'),
                      selected:
                          _selectedCategory == ActivityCategory.attraction,
                      onSelected: (_) => setState(() => _selectedCategory =
                          _selectedCategory == ActivityCategory.attraction
                              ? null
                              : ActivityCategory.attraction),
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
                      selected:
                          _selectedCategory == ActivityCategory.entertainment,
                      onSelected: (_) => setState(() => _selectedCategory =
                          _selectedCategory == ActivityCategory.entertainment
                              ? null
                              : ActivityCategory.entertainment),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // List
        Expanded(
          child: activitiesAsync.when(
            data: (allActivities) {
              final filtered = allActivities.where((a) {
                if (_selectedCategory != null &&
                    a.category != _selectedCategory) {
                  return false;
                }
                if (_selectedStatus != null &&
                    a.bookingStatus != _selectedStatus) {
                  return false;
                }
                if (_searchQuery.isNotEmpty) {
                  final q = _searchQuery.toLowerCase();
                  final titleMatch = a.title.toLowerCase().contains(q);
                  final locMatch =
                      a.location?.toLowerCase().contains(q) ?? false;
                  final refMatch =
                      a.confirmationRef?.toLowerCase().contains(q) ?? false;
                  return titleMatch || locMatch || refMatch;
                }
                return true;
              }).toList();

              // Sort by date and time
              filtered.sort((a, b) => a.startDateTime.compareTo(b.startDateTime));

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off_rounded,
                          size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      const Text(
                        'No matching activities found',
                        style: TextStyle(
                            fontSize: 15, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final act = filtered[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      leading: Checkbox(
                        value: act.isCompleted,
                        activeColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4)),
                        onChanged: canEdit
                            ? (val) {
                                if (val != null) {
                                  repo.updateActivity(
                                      act.copyWith(isCompleted: val));
                                }
                              }
                            : null,
                      ),
                      title: Text(
                        act.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          decoration: act.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          color: act.isCompleted
                              ? AppColors.textMuted
                              : AppColors.textPrimary,
                        ),
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
                                const Text('  •  ',
                                    style: TextStyle(color: Colors.grey)),
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
                          if (act.confirmationRef != null &&
                              act.confirmationRef!.isNotEmpty) ...[
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
                              icon: const Icon(Icons.more_vert,
                                  size: 18, color: AppColors.textSecondary),
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
                                      content: Text(
                                          'Are you sure you want to remove "${act.title}"?'),
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
                                    final activeTrip = ref.read(activeTripProvider);
                                    if (activeTrip != null) {
                                      await repo.deleteActivity(activeTrip.id, act.id);
                                    }
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
                                      Icon(Icons.delete_outline,
                                          size: 16, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Delete Activity',
                                          style: TextStyle(color: Colors.red)),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : const Icon(Icons.chevron_right,
                              color: AppColors.textMuted, size: 20),
                      onTap: () => widget.onActivityTap?.call(act),
                    ),
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
}
