import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_formatters.dart';
import '../../models/models.dart';
import '../../state/trip_providers.dart';
import '../common/add_activity_sheet.dart';

class StaysView extends ConsumerWidget {
  final VoidCallback? onAddStay;
  final ValueChanged<Stay>? onStayTap;

  const StaysView({super.key, this.onAddStay, this.onStayTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staysAsync = ref.watch(sortedActiveTripStaysProvider);
    final canEdit = ref.watch(canEditActiveTripProvider);

    return Scaffold(
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              heroTag: 'add_stay_fab',
              onPressed: onAddStay,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Add Stay',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              backgroundColor: AppColors.stay,
            )
          : null,
      body: staysAsync.when(
        data: (stays) {
          if (stays.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.hotel_outlined,
                      size: 56, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  const Text(
                    'No stays added yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Track hotels, vacation rentals, check-in times & bookings',
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                  if (canEdit) ...[
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: onAddStay,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Stay'),
                    ),
                  ],
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            itemCount: stays.length,
            itemBuilder: (context, index) {
              final stay = stays[index];
              return _StayCard(
                stay: stay,
                canEdit: canEdit,
                onTap: () => onStayTap?.call(stay),
                onDelete: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete Stay'),
                      content: Text(
                          'Are you sure you want to remove "${stay.name}"?'),
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
                      await ref
                          .read(tripRepositoryProvider)
                          .deleteStay(activeTrip.id, stay.id);
                    }
                  }
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading stays: $e')),
      ),
    );
  }
}

class _StayCard extends ConsumerWidget {
  final Stay stay;
  final bool canEdit;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const _StayCard({
    required this.stay,
    this.canEdit = true,
    this.onTap,
    this.onDelete,
  });

  IconData _getIconForType(StayType type) {
    switch (type) {
      case StayType.rental:
        return Icons.holiday_village_rounded;
      case StayType.overnightFlight:
        return Icons.flight_takeoff_rounded;
      case StayType.nightTrain:
        return Icons.train_rounded;
      case StayType.hotel:
        return Icons.hotel_rounded;
    }
  }

  Color _getColorForType(StayType type) {
    switch (type) {
      case StayType.rental:
        return const Color(0xFF0D9488);
      case StayType.overnightFlight:
        return AppColors.flight;
      case StayType.nightTrain:
        return const Color(0xFFD97706);
      case StayType.hotel:
        return AppColors.stay;
    }
  }

  Color _getContainerColorForType(StayType type) {
    switch (type) {
      case StayType.rental:
        return const Color(0xFFCCFBF1);
      case StayType.overnightFlight:
        return AppColors.flightContainer;
      case StayType.nightTrain:
        return const Color(0xFFFEF3C7);
      case StayType.hotel:
        return AppColors.stayContainer;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typeColor = _getColorForType(stay.type);
    final containerColor = _getContainerColorForType(stay.type);
    final isOvernightFlight = stay.type == StayType.overnightFlight;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Icon, Name, Type Pill, Nights Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: containerColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _getIconForType(stay.type),
                      color: typeColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stay.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: containerColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                stay.type.displayName.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  color: typeColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEDE9FE),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${stay.nights} ${stay.nights == 1 ? 'NIGHT' : 'NIGHTS'}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  color: AppColors.stay,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (canEdit) ...[
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert,
                          size: 18, color: AppColors.textSecondary),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onSelected: (val) {
                        if (val == 'edit') onTap?.call();
                        if (val == 'delete') onDelete?.call();
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 16),
                              SizedBox(width: 8),
                              Text('Edit Stay'),
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
                              Text('Delete Stay',
                                  style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ] else if (onTap != null) ...[
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textMuted,
                      size: 22,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),

              // Dates Row: Check-in, Connector Line, Check-out
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Check-in Column
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'CHECK-IN',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormatters.dayHeader.format(stay.checkInDate),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (stay.checkInTime != null)
                          Text(
                            DateFormatters.formatTimeString(stay.checkInTime!),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: typeColor,
                            ),
                          ),
                      ],
                    ),

                    // Visual duration connector
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: Column(
                          children: [
                            Text(
                              '${stay.nights} ${stay.nights == 1 ? 'night' : 'nights'}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: typeColor,
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    height: 2,
                                    color: typeColor.withValues(alpha: 0.3),
                                  ),
                                ),
                                Icon(
                                  Icons.bed_rounded,
                                  size: 16,
                                  color: typeColor,
                                ),
                                Expanded(
                                  child: Container(
                                    height: 2,
                                    color: typeColor.withValues(alpha: 0.3),
                                  ),
                                ),
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: typeColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Check-out Column
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'CHECK-OUT',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormatters.dayHeader.format(stay.checkOutDate),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (stay.checkOutTime != null)
                          Text(
                            DateFormatters.formatTimeString(stay.checkOutTime!),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: typeColor,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Address Row
              if (stay.address != null && stay.address!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.place_outlined,
                      size: 16,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        stay.address!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              // Overnight Flight Callout
              if (isOvernightFlight && stay.overnightFlight != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.flightContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.flight.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.flight_takeoff_rounded,
                          size: 18, color: AppColors.flight),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${stay.overnightFlight!.airline} ${stay.overnightFlight!.flightNumber} (${stay.overnightFlight!.departureAirport} → ${stay.overnightFlight!.arrivalAirport})',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Confirmation Code & Notes Row
              if (stay.confirmationCode != null &&
                  stay.confirmationCode!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Confirmation: ',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            stay.confirmationCode!,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'monospace',
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () {
                              Clipboard.setData(
                                  ClipboardData(text: stay.confirmationCode!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Confirmation code copied!'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            child: const Icon(
                              Icons.copy_rounded,
                              size: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],

              if (stay.notes != null && stay.notes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  stay.notes!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textMuted,
                  ),
                ),
              ],

              // Check-in & Check-out Activities Section
              Builder(
                builder: (context) {
                  final activities = ref.watch(activeTripActivitiesProvider).value ?? [];
                  final linkedActivities = activities.where((a) =>
                      stay.linkedActivityIds.contains(a.id) || a.stayId == stay.id
                  ).toList();

                  if (linkedActivities.isEmpty && !canEdit) {
                    return const SizedBox.shrink();
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 14),
                      const Divider(height: 1),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.hotel_rounded, size: 16, color: AppColors.stay),
                              const SizedBox(width: 6),
                              Text(
                                'Check-in / Check-out Activities (${linkedActivities.length})',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.stay,
                                ),
                              ),
                            ],
                          ),
                          if (canEdit)
                            InkWell(
                              onTap: () => _showLinkActivityDialog(context, ref, stay, activities),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.stayContainer.withValues(alpha: 0.3),
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
                      if (linkedActivities.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ...linkedActivities.map((act) {
                          final isCheckIn = act.title.toLowerCase().contains('check-in') || act.title.toLowerCase().contains('check in');
                          final isCheckOut = act.title.toLowerCase().contains('check-out') || act.title.toLowerCase().contains('checkout');
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
                                    if (canEdit) ...[
                                      const SizedBox(width: 4),
                                      IconButton(
                                        icon: const Icon(Icons.link_off_rounded, size: 16, color: Colors.red),
                                        tooltip: 'Unlink Activity',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () async {
                                          final repo = ref.read(tripRepositoryProvider);
                                          final remainingIds = stay.linkedActivityIds.where((id) => id != act.id).toList();
                                          await repo.updateStay(stay.copyWith(linkedActivityIds: remainingIds));
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
                    ],
                  );
                },
              ),
            ],
          ),
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
                        final updatedLinks = List<String>.from(stay.linkedActivityIds);
                        if (!updatedLinks.contains(act.id)) {
                          updatedLinks.add(act.id);
                        }
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
