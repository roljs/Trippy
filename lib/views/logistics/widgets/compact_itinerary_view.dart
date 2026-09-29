import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/compact_itinerary_helper.dart';
import '../../../core/utils/date_formatters.dart';
import '../../../models/models.dart';

/// A vertical tabular summary view of the trip itinerary similar to a spreadsheet.
/// Displays 1 row per day with Date, Day of the Week, Places to Visit, Sleep At
/// (with hover hotel details), and succinct Notes.
class CompactItineraryView extends StatefulWidget {
  final Trip trip;
  final List<Stay> stays;
  final List<Flight> flights;
  final Map<DateTime, List<Activity>> activitiesByDay;
  final bool canEdit;
  final ValueChanged<Stay>? onStayTap;
  final ValueChanged<Flight>? onFlightTap;
  final ValueChanged<Activity>? onActivityTap;
  final void Function(DateTime checkIn, DateTime checkOut)? onAddStayForDates;

  const CompactItineraryView({
    super.key,
    required this.trip,
    required this.stays,
    required this.flights,
    required this.activitiesByDay,
    this.canEdit = true,
    this.onStayTap,
    this.onFlightTap,
    this.onActivityTap,
    this.onAddStayForDates,
  });

  @override
  State<CompactItineraryView> createState() => _CompactItineraryViewState();
}

class _CompactItineraryViewState extends State<CompactItineraryView> {
  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();
  int? _hoveredRowIndex;

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summaries = CompactItineraryHelper.generateSummaries(
      trip: widget.trip,
      stays: widget.stays,
      flights: widget.flights,
      activitiesByDay: widget.activitiesByDay,
    );

    if (summaries.isEmpty) {
      return const Center(
        child: Text(
          'No days configured for this trip.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Table minimum width to prevent columns from cramping
        const double minTableWidth = 980.0;
        final double tableWidth = constraints.maxWidth > minTableWidth
            ? constraints.maxWidth
            : minTableWidth;

        return Scrollbar(
          controller: _horizontalController,
          thumbVisibility: true,
          trackVisibility: true,
          child: SingleChildScrollView(
            controller: _horizontalController,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              child: Scrollbar(
                controller: _verticalController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _verticalController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFD1D5DB)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. TABLE HEADER
                        _buildTableHeader(),

                        // 2. TABLE BODY (1 ROW PER DAY)
                        for (int i = 0; i < summaries.length; i++)
                          _buildTableRow(summaries[i], i),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Builds the top header row of the table
  Widget _buildTableHeader() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF9FAFB),
        border: Border(
          bottom: BorderSide(color: Color(0xFFD1D5DB), width: 1.5),
        ),
      ),
      child: const IntrinsicHeight(
        child: Row(
          children: [
            _HeaderCell(label: 'Date', width: 95),
            _HeaderCell(label: 'Day of the Week', width: 130),
            _HeaderCell(label: 'Places to Visit', width: 220),
            _HeaderCell(label: 'Sleep At', width: 200),
            Expanded(
              child: _HeaderCell(label: 'Notes', isLast: true),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds an individual tabular row for a given day
  Widget _buildTableRow(CompactDaySummary day, int index) {
    final isHovered = _hoveredRowIndex == index;
    final rowBg = day.rowColor;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredRowIndex = index),
      onExit: (_) => setState(() {
        if (_hoveredRowIndex == index) _hoveredRowIndex = null;
      }),
      child: Container(
        decoration: BoxDecoration(
          color: isHovered
              ? Color.alphaBlend(Colors.black.withValues(alpha: 0.04), rowBg)
              : rowBg,
          border: const Border(
            bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1.0),
          ),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Date (e.g. 1-Nov)
              _DataCell(
                width: 95,
                child: Text(
                  day.formattedDate,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),

              // 2. Day of the Week (e.g. Domingo / Sunday)
              _DataCell(
                width: 130,
                child: Text(
                  day.dayOfWeek,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),

              // 3. Places to Visit (e.g. Volar, Tokyo or Tokyo, Nikko)
              _DataCell(
                width: 220,
                child: Text(
                  day.placesToVisit,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),

              // 4. Sleep At (with hover hotel details)
              _DataCell(
                width: 200,
                child: _buildSleepAtCell(day),
              ),

              // 5. Notes (succinct summary of flight & day activities)
              Expanded(
                child: _DataCell(
                  isLast: true,
                  child: _buildNotesCell(day),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the Sleep At cell with rich hover card tooltip and click interaction
  Widget _buildSleepAtCell(CompactDaySummary day) {
    final stay = day.stayTonight;
    final flight = day.flightTonight;
    final hasDetails = stay != null || flight != null;

    IconData getIcon() {
      if (stay != null) {
        if (stay.type == StayType.overnightFlight) return Icons.flight_takeoff_rounded;
        if (stay.name.toLowerCase().contains('cruise')) return Icons.directions_boat_rounded;
        return Icons.hotel_rounded;
      }
      if (flight != null) return Icons.flight_takeoff_rounded;
      return Icons.bed_rounded;
    }

    final cellContent = Row(
      children: [
        if (hasDetails) ...[
          Icon(
            getIcon(),
            size: 15,
            color: const Color(0xFF475569),
          ),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Text(
            day.sleepAt.isNotEmpty ? day.sleepAt : '—',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: hasDetails ? const Color(0xFF0F172A) : AppColors.textMuted,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (hasDetails) ...[
          const SizedBox(width: 4),
          Icon(
            Icons.info_outline_rounded,
            size: 13,
            color: Colors.black.withValues(alpha: 0.35),
          ),
        ],
      ],
    );

    if (!hasDetails) {
      return InkWell(
        onTap: widget.canEdit
            ? () {
                final checkIn = day.date;
                final checkOut = day.date.add(const Duration(days: 1));
                widget.onAddStayForDates?.call(checkIn, checkOut);
              }
            : null,
        child: cellContent,
      );
    }

    // Rich Tooltip with complete hotel/lodging info on hover
    return Tooltip(
      richMessage: WidgetSpan(
        child: _HotelHoverCard(
          stay: stay,
          flight: flight,
          sleepCity: day.sleepAt,
        ),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      preferBelow: false,
      verticalOffset: 16,
      waitDuration: const Duration(milliseconds: 120),
      showDuration: const Duration(seconds: 5),
      child: InkWell(
        onTap: () {
          if (stay != null) {
            widget.onStayTap?.call(stay);
          } else if (flight != null) {
            widget.onFlightTap?.call(flight);
          }
        },
        borderRadius: BorderRadius.circular(4),
        child: cellContent,
      ),
    );
  }

  /// Builds the Notes cell with click/hover capability
  Widget _buildNotesCell(CompactDaySummary day) {
    if (day.notes.isEmpty) {
      return const SizedBox.shrink();
    }

    final textWidget = Text(
      day.notes,
      style: const TextStyle(
        fontSize: 13,
        color: Color(0xFF334155),
        height: 1.35,
      ),
    );

    // If note is long, wrap in Tooltip so entire note can be viewed effortlessly
    if (day.notes.length > 60) {
      return Tooltip(
        message: day.notes,
        waitDuration: const Duration(milliseconds: 300),
        child: textWidget,
      );
    }

    return textWidget;
  }
}

/// Header cell with subtle divider border
class _HeaderCell extends StatelessWidget {
  final String label;
  final double? width;
  final bool isLast;

  const _HeaderCell({
    required this.label,
    this.width,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final child = Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                right: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
              ),
      ),
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFF334155),
          letterSpacing: 0.2,
        ),
      ),
    );

    return child;
  }
}

/// Data cell with subtle vertical grid divider
class _DataCell extends StatelessWidget {
  final Widget child;
  final double? width;
  final bool isLast;

  const _DataCell({
    required this.child,
    this.width,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                right: BorderSide(color: Color(0xFFE5E7EB), width: 1.0),
              ),
      ),
      alignment: Alignment.centerLeft,
      child: child,
    );
  }
}

/// Rich hover card popup displaying all details of the hotel / stay / overnight flight
class _HotelHoverCard extends StatelessWidget {
  final Stay? stay;
  final Flight? flight;
  final String sleepCity;

  const _HotelHoverCard({
    this.stay,
    this.flight,
    required this.sleepCity,
  });

  @override
  Widget build(BuildContext context) {
    final title = stay?.name ?? flight?.airline ?? sleepCity;
    final address = stay?.address ?? (flight != null ? '${flight!.departureAirport} → ${flight!.arrivalAirport}' : '');
    final confCode = stay?.confirmationCode ?? flight?.bookingRef;
    final notes = stay?.notes ?? flight?.notes;

    IconData headerIcon;
    String typeLabel;
    Color badgeColor;

    if (stay?.type == StayType.overnightFlight || flight != null) {
      headerIcon = Icons.flight_takeoff_rounded;
      typeLabel = 'OVERNIGHT FLIGHT';
      badgeColor = AppColors.flight;
    } else if (stay?.name.toLowerCase().contains('cruise') ?? false) {
      headerIcon = Icons.directions_boat_rounded;
      typeLabel = 'CRUISE / VESSEL';
      badgeColor = const Color(0xFF0284C7);
    } else {
      headerIcon = Icons.hotel_rounded;
      typeLabel = stay?.type.name.toUpperCase() ?? 'LODGING';
      badgeColor = AppColors.stay;
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Badge & Type
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(headerIcon, size: 12, color: badgeColor),
                    const SizedBox(width: 4),
                    Text(
                      typeLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: badgeColor,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (confCode != null && confCode.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Text(
                    'Ref: $confCode',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Title / Hotel Name
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),

          // Address
          if (address.isNotEmpty) ...[
            const SizedBox(height: 3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined, size: 12, color: Color(0xFF64748B)),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    address,
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 8),

          // Dates & Times
          if (stay != null) ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CHECK-IN',
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8)),
                      ),
                      Text(
                        '${DateFormatters.shortDate.format(stay!.checkInDate)} ${stay!.checkInTime != null ? DateFormatters.formatTimeString(stay!.checkInTime!) : ''}'.trim(),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_rounded, size: 13, color: Color(0xFF94A3B8)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'CHECK-OUT',
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8)),
                      ),
                      Text(
                        '${DateFormatters.shortDate.format(stay!.checkOutDate)} ${stay!.checkOutTime != null ? DateFormatters.formatTimeString(stay!.checkOutTime!) : ''}'.trim(),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ] else if (flight != null) ...[
            Text(
              '${flight!.airline} ${flight!.flightNumber} • Dep: ${DateFormatters.time12.format(flight!.departureTime)} → Arr: ${DateFormatters.time12.format(flight!.arrivalTime)}',
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
            ),
          ],

          // Notes
          if (notes != null && notes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                notes,
                style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF475569)),
              ),
            ),
          ],

          const SizedBox(height: 6),
          const Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Tap row to edit',
              style: TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
