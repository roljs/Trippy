import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_formatters.dart';
import '../../models/models.dart';
import '../../state/trip_providers.dart';
import 'widgets/day_column_widget.dart';
import 'widgets/manage_day_locations_dialog.dart';
import 'widgets/stay_header_bridge_widget.dart';
import 'widgets/compact_itinerary_view.dart';
import 'widgets/map_itinerary_view.dart';
import 'widgets/calendar_itinerary_view.dart';
import 'widgets/trip_endcap_stay_bridge_widget.dart';
import '../../core/utils/city_color_helper.dart';
import '../../core/utils/location_inference_helper.dart';

import '../common/add_flight_sheet.dart';
import '../common/add_stay_sheet.dart';

class AppHorizontalScrollBehavior extends MaterialScrollBehavior {
  const AppHorizontalScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

class LogisticsView extends ConsumerStatefulWidget {
  final void Function([DateTime? initialDate])? onOpenAddActivity;
  final ValueChanged<Activity>? onActivityTap;
  final ValueChanged<Stay>? onStayTap;
  final ValueChanged<Flight>? onFlightTap;
  final void Function(DateTime checkIn, DateTime checkOut)? onAddStayForDates;

  const LogisticsView({
    super.key,
    this.onOpenAddActivity,
    this.onActivityTap,
    this.onStayTap,
    this.onFlightTap,
    this.onAddStayForDates,
  });

  @override
  ConsumerState<LogisticsView> createState() => _LogisticsViewState();
}

class _LogisticsViewState extends ConsumerState<LogisticsView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToDay(int index) {
    if (!_scrollController.hasClients) return;
    const double totalColumnStride = 310.0;
    const double canvasLeftOffset = 145.0;
    final targetOffset = canvasLeftOffset + (index * totalColumnStride);
    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  void _navigateToDay(int index, List<DateTime> days) {
    if (index < 0 || index >= days.length) return;
    final date = days[index];
    ref.read(focusedTripDateProvider.notifier).setDate(date);
    _scrollToDay(index);
  }

  int _findDayIndex(List<DateTime> days, DateTime targetDate) {
    final t = DateTime(targetDate.year, targetDate.month, targetDate.day);
    for (int i = 0; i < days.length; i++) {
      final d = DateTime(days[i].year, days[i].month, days[i].day);
      if (d == t) return i;
      if (d.isAfter(t)) return i > 0 ? i - 1 : 0;
    }
    return days.length - 1;
  }

  void _openFlightEdit(BuildContext context, Flight flight) {
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

  void _openAddStay(BuildContext context,
      {DateTime? checkIn, DateTime? checkOut}) {
    if (widget.onAddStayForDates != null &&
        checkIn != null &&
        checkOut != null) {
      widget.onAddStayForDates!(checkIn, checkOut);
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => AddStaySheet(
          initialCheckInDate: checkIn,
          initialCheckOutDate: checkOut,
        ),
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
                  helperText: 'Displayed at the start of the Itinerary',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: endController,
                decoration: const InputDecoration(
                  labelText: 'Finishing Location (Return)',
                  hintText: 'e.g. San Francisco or Return City',
                  helperText: 'Displayed at the end of the Itinerary',
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
    final viewMode = ref.watch(itineraryViewModeProvider);

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

    final stays = staysAsync.value ?? [];

    final focusedDate = ref.watch(focusedTripDateProvider);
    final currentDayIndex = (focusedDate != null && days.isNotEmpty)
        ? days.indexWhere((d) =>
            d.year == focusedDate.year &&
            d.month == focusedDate.month &&
            d.day == focusedDate.day)
        : 0;
    final effectiveDayIndex = currentDayIndex != -1 ? currentDayIndex : 0;
    final dayNumber = effectiveDayIndex + 1;

    if (focusedDate != null && days.isNotEmpty) {
      final index = days.indexWhere((d) =>
          d.year == focusedDate.year &&
          d.month == focusedDate.month &&
          d.day == focusedDate.day);
      if (index != -1) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            const double totalColumnStride = 310.0;
            const double canvasLeftOffset = 145.0;
            final targetOffset = canvasLeftOffset + (index * totalColumnStride);
            _scrollController.animateTo(
              targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOut,
            );
          }
        });
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Each column is 290dp with 20dp margin (10dp on each side)
        const double columnWidth = 290.0;
        const double columnMargin = 20.0;
        const double totalColumnStride = columnWidth + columnMargin; // 310.0
        // Canvas left threshold offset giving runway for the Day 1 Arrival Header
        const double canvasLeftOffset = 145.0;

        // Center X coordinate of vertical day column at index i
        double columnCenter(int index) =>
            canvasLeftOffset + (index * totalColumnStride) + 155.0;

        final List<Widget> stayWidgets = [];
        final Set<int> coveredNights = {};
        final List<double> trackEndPositions = [];
        double maxStayRight = 0.0;

        // 1. Add Special Beginning Stay Card (Starts at 50% offset of Day 1, ends at Day 1 midpoint)
        final double startStayLeft = columnCenter(0) - (columnWidth / 2);
        final double startStayWidth = columnWidth / 2;
        final double startStayRight = startStayLeft + startStayWidth; // columnCenter(0)
        trackEndPositions.add(startStayRight);

        stayWidgets.add(
          Positioned(
            left: startStayLeft,
            top: 0,
            child: TripEndcapStayBridgeWidget(
              type: TripEndcapType.start,
              locationName: trip.startLocation ?? 'Origin',
              width: startStayWidth,
              onTap:
                  canEdit ? () => _openEditTripLocations(context, trip) : null,
            ),
          ),
        );

        // 2. Collect Stays and Multi-Day Flights into a single horizontal items list
        final List<_HorizontalStayItem> horizontalItems = [];
        final existingFlightStayIds = stays
            .where((s) => s.overnightFlight != null)
            .map((s) => s.overnightFlight!.id)
            .toSet();

        for (int k = 0; k < stays.length; k++) {
          final stay = stays[k];
          final inD = DateTime(
              stay.checkInDate.year, stay.checkInDate.month, stay.checkInDate.day);
          final outD = DateTime(stay.checkOutDate.year, stay.checkOutDate.month,
              stay.checkOutDate.day);

          int startIndex = _findDayIndex(days, inD);
          int nights = stay.nights;
          if (nights < 1) {
            final diff = outD.difference(inD).inDays;
            nights = diff > 0 ? diff : 1;
          }
          int endIndex = startIndex + nights;

          // Start at center of first day, end at center of checkout day
          final double leftPos = columnCenter(startIndex);
          final double staySpanWidth = nights * totalColumnStride;
          final double rightPos = leftPos + staySpanWidth;

          final isFlight =
              stay.type == StayType.overnightFlight || stay.overnightFlight != null;
          final palette = isFlight
              ? overnightFlightPalette
              : CityColorHelper.getStayPalette(
                  stay: stay,
                  allStaysInTrip: stays,
                );
          final cityName = isFlight && stay.overnightFlight != null
              ? stay.overnightFlight!.arrivalAirport.split(' ').first
              : CityColorHelper.extractCityForStay(stay);
          final onTap = isFlight && stay.overnightFlight != null
              ? () => _openFlightEdit(context, stay.overnightFlight!)
              : () => widget.onStayTap?.call(stay);

          horizontalItems.add(_HorizontalStayItem(
            startIndex: startIndex,
            endIndex: endIndex,
            leftPos: leftPos,
            rightPos: rightPos,
            buildWidget: (trackIndex) => Positioned(
              left: leftPos,
              top: trackIndex * 94.0,
              child: StayHeaderBridgeWidget(
                stay: stay,
                cityName: cityName,
                width: staySpanWidth,
                spanDays: nights,
                startNightNumber: startIndex + 1,
                palette: palette,
                onTap: onTap,
              ),
            ),
          ));
        }

        // 3. Render Multi-Day Flights (ONLY flights spanning 2 or more days not already present in stays)
        final allFlights = flightsAsync.value ?? [];
        final multiDayFlights = allFlights.where((f) {
          if (existingFlightStayIds.contains(f.id)) return false;
          final depD = DateTime(
              f.departureTime.year, f.departureTime.month, f.departureTime.day);
          final arrD = DateTime(
              f.arrivalTime.year, f.arrivalTime.month, f.arrivalTime.day);
          return f.isOvernight || arrD.difference(depD).inDays >= 1;
        }).toList();

        for (final flight in multiDayFlights) {
          final depD = DateTime(flight.departureTime.year,
              flight.departureTime.month, flight.departureTime.day);
          final arrD = DateTime(flight.arrivalTime.year,
              flight.arrivalTime.month, flight.arrivalTime.day);
          int startIdx = _findDayIndex(days, depD);
          int endIdx = _findDayIndex(days, arrD);
          if (endIdx <= startIdx) endIdx = startIdx + 1;
          int spanDays = endIdx - startIdx;

          final double leftPos = columnCenter(startIdx);
          final double flightSpanWidth = spanDays * totalColumnStride;
          final double rightPos = leftPos + flightSpanWidth;

          final flightStay = Stay(
            id: 'stay_flight_${flight.id}',
            tripId: trip.id,
            type: StayType.overnightFlight,
            name: '${flight.airline} ${flight.flightNumber}'.trim(),
            address: '${flight.departureAirport} → ${flight.arrivalAirport}',
            checkInDate: flight.departureTime,
            checkOutDate: flight.arrivalTime,
            overnightFlight: flight,
            confirmationCode: flight.bookingRef,
          );

          horizontalItems.add(_HorizontalStayItem(
            startIndex: startIdx,
            endIndex: endIdx,
            leftPos: leftPos,
            rightPos: rightPos,
            buildWidget: (trackIndex) => Positioned(
              left: leftPos,
              top: trackIndex * 94.0,
              child: StayHeaderBridgeWidget(
                stay: flightStay,
                cityName: flight.arrivalAirport.split(' ').first,
                width: flightSpanWidth,
                spanDays: spanDays,
                startNightNumber: startIdx + 1,
                palette: overnightFlightPalette,
                onTap: () => _openFlightEdit(context, flight),
              ),
            ),
          ));
        }

        // Sort all horizontal stay & overnight flight items chronologically
        horizontalItems.sort((a, b) {
          final cmp = a.startIndex.compareTo(b.startIndex);
          if (cmp != 0) return cmp;
          return a.leftPos.compareTo(b.leftPos);
        });

        // Allocate vertical track lanes in unified chronological order
        for (final item in horizontalItems) {
          if (item.rightPos > maxStayRight) {
            maxStayRight = item.rightPos;
          }

          // Mark covered night transitions
          for (int n = item.startIndex; n < item.endIndex && n < days.length - 1; n++) {
            coveredNights.add(n);
          }

          int trackIndex = -1;
          for (int t = 0; t < trackEndPositions.length; t++) {
            if (trackEndPositions[t] <= item.leftPos + 0.5) {
              trackIndex = t;
              trackEndPositions[t] = item.rightPos;
              break;
            }
          }
          if (trackIndex == -1) {
            trackIndex = trackEndPositions.length;
            trackEndPositions.add(item.rightPos);
          }

          stayWidgets.add(item.buildWidget(trackIndex));
        }

        // 4. Add empty slots for any uncovered night transitions
        for (int i = 0; i < days.length - 1; i++) {
          if (!coveredNights.contains(i)) {
            final checkInDate = days[i];
            final checkOutDate = days[i + 1];
            stayWidgets.add(
              Positioned(
                left: columnCenter(i),
                top: 0,
                child: StayHeaderBridgeWidget(
                  stay: null,
                  cityName:
                      trip.dayLocations[Trip.dateToKey(days[i])]?.lastOrNull,
                  width: totalColumnStride,
                  startNightNumber: i + 1,
                  onTap: canEdit
                      ? () => _openAddStay(context,
                          checkIn: checkInDate, checkOut: checkOutDate)
                      : null,
                ),
              ),
            );
          }
        }

        // 5. Add Special Finishing Stay Card (starts at vertical middle of last day, ends at 50% offset of width)
        final double finishStayLeft = columnCenter(days.length - 1);
        final double finishStayWidth = columnWidth / 2;
        final double finishStayRight = finishStayLeft + finishStayWidth;
        if (finishStayRight > maxStayRight) {
          maxStayRight = finishStayRight;
        }

        int finishTrackIndex = -1;
        for (int t = 0; t < trackEndPositions.length; t++) {
          if (trackEndPositions[t] <= finishStayLeft + 0.5) {
            finishTrackIndex = t;
            trackEndPositions[t] = finishStayRight;
            break;
          }
        }
        if (finishTrackIndex == -1) {
          finishTrackIndex = trackEndPositions.length;
          trackEndPositions.add(finishStayRight);
        }

        stayWidgets.add(
          Positioned(
            left: finishStayLeft,
            top: finishTrackIndex * 94.0,
            child: TripEndcapStayBridgeWidget(
              type: TripEndcapType.finish,
              locationName: trip.endLocation ?? 'Return',
              width: finishStayWidth,
              onTap:
                  canEdit ? () => _openEditTripLocations(context, trip) : null,
            ),
          ),
        );

        final double trackStackHeight =
            (trackEndPositions.isEmpty ? 1 : trackEndPositions.length) * 94.0;

        final double standardWidth =
            canvasLeftOffset + (days.length * totalColumnStride) + 145.0 + 40.0;
        final double totalCanvasWidth =
            standardWidth > (maxStayRight + 20.0) ? standardWidth : (maxStayRight + 20.0);
        final bool isWideScreen = constraints.maxWidth >= 1150;
        final bool showDateRange = constraints.maxWidth >= 1350;

        return Column(
          children: [
            // Top Navigation & Information Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.view_week_rounded,
                      size: 15,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    constraints.maxWidth >= 1350
                        ? 'ITINERARY  •  ${days.length} DAYS'
                        : 'ITINERARY',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (showDateRange) ...[
                    const SizedBox(width: 10),
                    Text(
                      DateFormatters.formatTripDateRange(
                          trip.startDate, trip.endDate),
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const Spacer(),
                  // View Switcher: Full View vs Compact View vs Map View vs Calendar View
                  SegmentedButton<ItineraryViewMode>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                        value: ItineraryViewMode.full,
                        icon: const Icon(Icons.view_week_rounded, size: 13),
                        label: isWideScreen
                            ? const Text('Full View',
                                style: TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.w600))
                            : null,
                        tooltip: 'Full Itinerary View',
                      ),
                      ButtonSegment(
                        value: ItineraryViewMode.compact,
                        icon: const Icon(Icons.table_rows_rounded, size: 13),
                        label: isWideScreen
                            ? const Text('Compact View',
                                style: TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.w600))
                            : null,
                        tooltip: 'Compact Tabular View',
                      ),
                      ButtonSegment(
                        value: ItineraryViewMode.map,
                        icon: const Icon(Icons.map_rounded, size: 13),
                        label: isWideScreen
                            ? const Text('Map View',
                                style: TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.w600))
                            : null,
                        tooltip: 'Interactive Map View',
                      ),
                      ButtonSegment(
                        value: ItineraryViewMode.calendar,
                        icon: const Icon(Icons.calendar_month_rounded, size: 13),
                        label: isWideScreen
                            ? const Text('Calendar View',
                                style: TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.w600))
                            : null,
                        tooltip: 'Monthly Calendar View',
                      ),
                    ],
                    selected: {viewMode},
                    onSelectionChanged: (newSelection) {
                      if (newSelection.isNotEmpty) {
                        ref
                            .read(itineraryViewModeProvider.notifier)
                            .setMode(newSelection.first);
                      }
                    },
                    style: SegmentedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      minimumSize: Size.zero,
                    ),
                  ),
                  if (viewMode == ItineraryViewMode.full && days.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded, size: 20),
                      tooltip: 'Previous Day',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: effectiveDayIndex > 0
                          ? () => _navigateToDay(effectiveDayIndex - 1, days)
                          : null,
                    ),

                    // Jump to Day Dropdown Picker
                    PopupMenuButton<int>(
                      tooltip: 'Jump to specific day',
                      initialValue: effectiveDayIndex,
                      child: Container(
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
                            Icon(Icons.calendar_today_rounded,
                                size: 12, color: Colors.grey.shade700),
                            const SizedBox(width: 4),
                            Text(
                              'Day $dayNumber of ${days.length}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Icon(Icons.arrow_drop_down_rounded, size: 16),
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
                                      fontWeight: k == effectiveDayIndex
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                      color: k == effectiveDayIndex
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
                      onSelected: (idx) => _navigateToDay(idx, days),
                    ),

                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded, size: 20),
                      tooltip: 'Next Day',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: effectiveDayIndex < days.length - 1
                          ? () => _navigateToDay(effectiveDayIndex + 1, days)
                          : null,
                    ),
                  ],
                ],
              ),
            ),

            if (viewMode == ItineraryViewMode.compact)
              Expanded(
                child: CompactItineraryView(
                  trip: trip,
                  stays: stays,
                  flights: flightsAsync.value ?? [],
                  activitiesByDay: activitiesByDay,
                  canEdit: canEdit,
                  onStayTap: widget.onStayTap,
                  onFlightTap: widget.onFlightTap,
                  onActivityTap: widget.onActivityTap,
                  onAddStayForDates: widget.onAddStayForDates,
                ),
              )
            else if (viewMode == ItineraryViewMode.map)
              Expanded(
                child: MapItineraryView(
                  trip: trip,
                  stays: stays,
                  flights: flightsAsync.value ?? [],
                  activitiesByDay: activitiesByDay,
                  canEdit: canEdit,
                  onStayTap: widget.onStayTap,
                  onFlightTap: widget.onFlightTap,
                  onActivityTap: widget.onActivityTap,
                ),
              )
            else if (viewMode == ItineraryViewMode.calendar)
              Expanded(
                child: CalendarItineraryView(
                  trip: trip,
                  stays: stays,
                  flights: flightsAsync.value ?? [],
                  activitiesByDay: activitiesByDay,
                  canEdit: canEdit,
                  onStayTap: widget.onStayTap,
                  onFlightTap: widget.onFlightTap,
                  onAddStayForDates: widget.onAddStayForDates,
                  onDayTap: (date) {
                    ref.read(focusedTripDateProvider.notifier).setDate(date);
                    ref.read(navTabIndexProvider.notifier).setTab(0);
                  },
                ),
              )
            else
              // Main Horizontal Scroll Board with Draggable Scrollbar & Mouse Wheel Translation
              Expanded(
                child: ScrollConfiguration(
                behavior: const AppHorizontalScrollBehavior(),
                child: Listener(
                  onPointerSignal: (pointerSignal) {
                    if (pointerSignal is PointerScrollEvent) {
                      // Forward vertical mouse wheel scrolling into horizontal scrolling
                      final delta = pointerSignal.scrollDelta.dy != 0
                          ? pointerSignal.scrollDelta.dy
                          : pointerSignal.scrollDelta.dx;
                      if (delta != 0 && _scrollController.hasClients) {
                        final target = (_scrollController.offset + delta).clamp(
                            0.0, _scrollController.position.maxScrollExtent);
                        _scrollController.jumpTo(target);
                      }
                    }
                  },
                  child: Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: true,
                    trackVisibility: true,
                    interactive: true,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: SizedBox(
                        width: totalCanvasWidth,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. OVERARCHING MULTI-DAY STAY & TRANSPORT RECTANGLES TRACK
                            SizedBox(
                              height: trackStackHeight,
                              child: Stack(
                                children: stayWidgets,
                              ),
                            ),
                            const SizedBox(height: 6),

                            // 2. SIDE-BY-SIDE VERTICAL DAY COLUMNS
                            Expanded(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const SizedBox(width: canvasLeftOffset),
                                  for (int i = 0; i < days.length; i++) ...[
                                    Builder(
                                      builder: (context) {
                                        final dayDate = days[i];
                                        final customLocations =
                                            trip.getCustomLocationsForDate(dayDate);
                                        final defaultCountry =
                                            LocationInferenceHelper.inferTargetCountryForDay(
                                          date: dayDate,
                                          flights: flightsAsync.value ?? [],
                                          activities: activitiesAsync.value ?? [],
                                          tripDestination: trip.destination,
                                        );
                                        final effectiveLocations =
                                            customLocations ?? [defaultCountry];
                                        final dayFlights =
                                            (flightsAsync.value ?? []).where((f) {
                                          final dep = DateTime(
                                              f.departureTime.year,
                                              f.departureTime.month,
                                              f.departureTime.day);
                                          final target = DateTime(
                                              dayDate.year,
                                              dayDate.month,
                                              dayDate.day);
                                          return dep == target;
                                        }).toList();

                                        return DayColumnWidget(
                                          date: dayDate,
                                          dayNumber: i + 1,
                                          activities:
                                              activitiesByDay[dayDate] ?? [],
                                          flights: dayFlights,
                                          locations: effectiveLocations,
                                          canEdit: canEdit,
                                          onAddActivity: (d) =>
                                              widget.onOpenAddActivity?.call(d),
                                          onActivityTap: widget.onActivityTap,
                                          onFlightTap: (f) =>
                                              _openFlightEdit(context, f),
                                          onManageLocations: canEdit
                                              ? () {
                                                  showDialog(
                                                    context: context,
                                                    builder: (ctx) =>
                                                        ManageDayLocationsDialog(
                                                      dayNumber: i + 1,
                                                      date: dayDate,
                                                      currentLocations:
                                                          effectiveLocations,
                                                      defaultCountry:
                                                          defaultCountry,
                                                      onSave: (newLocations) {
                                                        repo.updateDayLocations(
                                                          trip.id,
                                                          dayDate,
                                                          newLocations,
                                                        );
                                                      },
                                                    ),
                                                  );
                                                }
                                              : null,
                                          onPlanDay: () {
                                            ref
                                                .read(focusedTripDateProvider
                                                    .notifier)
                                                .setDate(dayDate);
                                            ref
                                                .read(navTabIndexProvider
                                                    .notifier)
                                                .setTab(0);
                                          },
                                        );
                                      },
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
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HorizontalStayItem {
  final int startIndex;
  final int endIndex;
  final double leftPos;
  final double rightPos;
  final Widget Function(int trackIndex) buildWidget;

  const _HorizontalStayItem({
    required this.startIndex,
    required this.endIndex,
    required this.leftPos,
    required this.rightPos,
    required this.buildWidget,
  });
}
