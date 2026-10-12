import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Clear UI badge displaying whether an entity was last modified via
/// MCP Server, showing a small robot icon with tooltip. Objects modified via UI
/// do not show a badge.
class ModificationSourceBadge extends StatelessWidget {
  final DateTime? lastModifiedAt;
  final String? lastModifiedSource;
  final bool isCompact;
  final bool showTime;

  const ModificationSourceBadge({
    super.key,
    required this.lastModifiedAt,
    this.lastModifiedSource,
    this.isCompact = false,
    this.showTime = true,
  });

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final isToday = now.year == dt.year && now.month == dt.month && now.day == dt.day;
    final isYesterday = now.year == dt.year &&
        now.month == dt.month &&
        now.day - dt.day == 1;

    final timeStr = DateFormat('h:mm a').format(dt);
    if (isToday) {
      return 'Today $timeStr';
    } else if (isYesterday) {
      return 'Yest $timeStr';
    } else {
      return '${DateFormat('MMM d').format(dt)}, $timeStr';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMcp = (lastModifiedSource?.toLowerCase() == 'mcp');
    if (!isMcp) {
      return const SizedBox.shrink();
    }

    const Color fgColor = Color(0xFF7C3AED);
    const Color bgColor = Color(0xFFF5F3FF);
    const Color borderColor = Color(0xFFDDD6FE);
    const IconData iconData = Icons.smart_toy_rounded;

    final timeStr = lastModifiedAt != null ? _formatTime(lastModifiedAt!) : '';
    final tooltipText = lastModifiedAt != null
        ? 'Last modified via MCP Server at $timeStr'
        : 'Last modified via MCP Server';

    return Tooltip(
      message: tooltipText,
      child: Container(
        key: const ValueKey('modification_badge_mcp'),
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 4.0 : 6.0,
          vertical: isCompact ? 2.5 : 3.5,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(isCompact ? 4 : 6),
          border: Border.all(color: borderColor, width: 0.8),
        ),
        child: Icon(
          iconData,
          size: isCompact ? 12 : 14,
          color: fgColor,
        ),
      ),
    );
  }
}
