import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatters.dart';
import '../../../core/utils/map_launcher_helper.dart';
import '../../../models/models.dart';
import '../../common/modification_source_badge.dart';

class ActivityCardWidget extends StatelessWidget {
  final Activity activity;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onToggleCompleted;

  const ActivityCardWidget({
    super.key,
    required this.activity,
    this.onTap,
    this.onToggleCompleted,
  });

  Color _getCategoryColor(ActivityCategory cat) {
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

  Color _getCategoryContainerColor(ActivityCategory cat) {
    switch (cat) {
      case ActivityCategory.stay:
        return AppColors.stayContainer;
      case ActivityCategory.transport:
        return AppColors.transportContainer;
      case ActivityCategory.dining:
        return AppColors.diningContainer;
      case ActivityCategory.entertainment:
        return AppColors.entertainmentContainer;
      case ActivityCategory.attraction:
      case ActivityCategory.custom:
        return AppColors.attractionContainer;
    }
  }

  IconData _getCategoryIcon(ActivityCategory cat) {
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

  @override
  Widget build(BuildContext context) {
    final catColor = _getCategoryColor(activity.category);
    final catContainerColor = _getCategoryContainerColor(activity.category);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: activity.isCompleted
              ? Colors.grey.shade100
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: activity.isCompleted
                ? Colors.grey.shade300
                : AppColors.border,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Time Badge & Category Icon + Status Pill
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: catContainerColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getCategoryIcon(activity.category),
                              size: 13,
                              color: catColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              DateFormatters.formatTimeString(activity.startTime),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: catColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (activity.endTime != null) ...[
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '– ${DateFormatters.formatTimeString(activity.endTime!)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
                const SizedBox(width: 4),
                if (activity.mealType != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.diningContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      activity.mealType!.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: AppColors.dining,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                // Booking Status Badge
                _BookingStatusPill(status: activity.bookingStatus),
                if (activity.lastModifiedAt != null || activity.lastModifiedSource != null) ...[
                  const SizedBox(width: 4),
                  ModificationSourceBadge(
                    lastModifiedAt: activity.lastModifiedAt,
                    lastModifiedSource: activity.lastModifiedSource,
                    isCompact: true,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),

            // Title
            Text(
              activity.title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: activity.isCompleted
                    ? AppColors.textMuted
                    : AppColors.textPrimary,
                decoration: activity.isCompleted
                    ? TextDecoration.lineThrough
                    : null,
              ),
            ),

            // Location
            if (activity.location != null && activity.location!.isNotEmpty) ...[
              const SizedBox(height: 4),
              InkWell(
                onTap: () => MapLauncherHelper.openAddress(activity.location!),
                borderRadius: BorderRadius.circular(4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 13,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        activity.location!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.open_in_new_rounded,
                      size: 11,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
              ),
            ],

            // Confirmation / Ref
            if (activity.confirmationRef != null &&
                activity.confirmationRef!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey.shade300, width: 0.8),
                ),
                child: Text(
                  'Ref: ${activity.confirmationRef}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],

            // Notes
            if (activity.notes != null && activity.notes!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                activity.notes!,
                style: const TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textMuted,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            // Links & Attachments
            if (activity.links.isNotEmpty || activity.attachments.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final link in activity.links)
                    InkWell(
                      onTap: () async {
                        final uri = Uri.tryParse(link);
                        if (uri != null && await canLaunchUrl(uri)) {
                          await launchUrl(uri,
                              mode: LaunchMode.externalApplication);
                        }
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.link_rounded,
                                size: 11, color: AppColors.primary),
                            const SizedBox(width: 3),
                            ConstrainedBox(
                              constraints:
                                  const BoxConstraints(maxWidth: 140),
                              child: Text(
                                link,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  for (final att in activity.attachments)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.attach_file_rounded,
                              size: 11, color: AppColors.textSecondary),
                          const SizedBox(width: 3),
                          ConstrainedBox(
                            constraints:
                                const BoxConstraints(maxWidth: 130),
                            child: Text(
                              att,
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BookingStatusPill extends StatelessWidget {
  final BookingStatus status;

  const _BookingStatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;

    switch (status) {
      case BookingStatus.ticketed:
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF15803D);
        break;
      case BookingStatus.booked:
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF1D4ED8);
        break;
      case BookingStatus.planned:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF475569);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}
