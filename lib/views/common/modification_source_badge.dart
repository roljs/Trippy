import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Clear UI badge displaying whether an entity was last modified via
/// Trippy UI or MCP Server, along with the modification timestamp.
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
    if (lastModifiedAt == null && lastModifiedSource == null) {
      return const SizedBox.shrink();
    }

    final bool isMcp = (lastModifiedSource?.toLowerCase() == 'mcp');
    final String sourceLabel = isMcp ? 'MCP Server' : 'Trippy UI';
    final String compactLabel = isMcp ? 'MCP' : 'UI';

    final Color fgColor = isMcp ? const Color(0xFF7C3AED) : const Color(0xFF475569);
    final Color bgColor = isMcp ? const Color(0xFFF5F3FF) : const Color(0xFFF1F5F9);
    final Color borderColor = isMcp ? const Color(0xFFDDD6FE) : const Color(0xFFE2E8F0);
    final IconData iconData = isMcp ? Icons.smart_toy_rounded : Icons.edit_note_rounded;

    final timeStr = lastModifiedAt != null ? _formatTime(lastModifiedAt!) : '';
    final tooltipText = lastModifiedAt != null
        ? 'Last modified via $sourceLabel at $timeStr'
        : 'Last modified via $sourceLabel';

    final textToShow = isCompact
        ? (showTime && timeStr.isNotEmpty ? '$compactLabel • $timeStr' : compactLabel)
        : (showTime && timeStr.isNotEmpty ? '$sourceLabel • $timeStr' : sourceLabel);

    return Tooltip(
      message: tooltipText,
      child: Container(
        key: ValueKey('modification_badge_${isMcp ? "mcp" : "ui"}'),
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 6 : 8,
          vertical: isCompact ? 2 : 3.5,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(isCompact ? 4 : 6),
          border: Border.all(color: borderColor, width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              iconData,
              size: isCompact ? 11 : 13,
              color: fgColor,
            ),
            const SizedBox(width: 4),
            Text(
              textToShow,
              style: TextStyle(
                fontSize: isCompact ? 10 : 11,
                fontWeight: FontWeight.w600,
                color: fgColor,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
