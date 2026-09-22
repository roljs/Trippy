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
import 'widgets/transport_header_bridge_widget.dart';
import '../../core/utils/location_inference_helper.dart';

import '../common/add_flight_sheet.dart';

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
  final VoidCallback? onOpenAddActivity;
  final ValueChanged<Activity>? onActivityTap;
  final ValueChanged<Stay>? onStayTap;
  final ValueChanged<Flight>? onFlightTap;

  const LogisticsView({
    super.key,
    this.onOpenAddActivity,
    this.onActivityTap,
    this.onStayTap,
    this.onFlightTap,
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

  void _scrollBy(double offset) {
    if (!_scrollController.hasClients) return;
    final target = (_scrollController.offset + offset)
        .clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void _scrollToStart() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0.0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
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

  @override
  Widget build(BuildContext context) {
    final trip = ref.watch(activeTripProvider);
    final canEdit = ref.watch(canEditActiveTripProvider);
    final activitiesByDay = ref.watch(activitiesByDayProvider);
    final staysAsync = ref.watch(sortedActiveTripStaysProvider);
    final flightsAsync = ref.watch(activeTripFlightsProvider);
    final activitiesAsync = ref.watch(activeTripActivitiesProvider);
    final repo = ref.watch(tripRepositoryProvider);

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

        // 1. Resolve Day 1 Arrival Transport Header Data
        final day1 = days.first;
        final lastDay = days.last;

        TransportHeaderData? arrivalData;
        final allFlights = flightsAsync.value ?? [];
        final explicitArrivalFlight =
            allFlights.where((f) => f.isMainArrival).firstOrNull;
        final arrivalFlight = explicitArrivalFlight ??
            allFlights.where((f) {
              final d = DateTime(
                  f.arrivalTime.year, f.arrivalTime.month, f.arrivalTime.day);
              final t = DateTime(day1.year, day1.month, day1.day);
              return d.isAtSameMomentAs(t) || d.isBefore(t);
            }).firstOrNull;

        if (arrivalFlight != null) {
          arrivalData = TransportHeaderData.fromFlight(
              arrivalFlight, TransportHeaderMode.arrival);
        } else {
          final day1Activities = activitiesByDay[day1] ?? [];
          final arrivalAct = day1Activities.where((a) =>
              a.category == ActivityCategory.flight ||
              a.category == ActivityCategory.transport ||
              a.title.toLowerCase().contains('arrival') ||
              a.title.toLowerCase().contains('flight')).firstOrNull;

          if (arrivalAct != null) {
            arrivalData = TransportHeaderData.fromActivity(
                arrivalAct, TransportHeaderMode.arrival);
          } else {
            arrivalData = TransportHeaderData.placeholder(
              mode: TransportHeaderMode.arrival,
              destination: trip.destination,
              type: TransportType.flight,
            );
          }
        }

        // Add Arrival Header on Day 1 (starts 50% width left of Day 1, ends at Day 1 center)
        final double arrivalLeft = columnCenter(0) - columnWidth; // 10.0
        final double arrivalRight = columnCenter(0); // 300.0
        trackEndPositions.add(arrivalRight);

        stayWidgets.add(
          Positioned(
            left: arrivalLeft,
            top: 0,
            child: TransportHeaderBridgeWidget(
              mode: TransportHeaderMode.arrival,
              data: arrivalData,
              width: columnWidth,
              onTap: () {
                if (arrivalData?.flight != null) {
                  _openFlightEdit(context, arrivalData!.flight!);
                } else if (arrivalData?.activity != null) {
                  widget.onActivityTap?.call(arrivalData!.activity!);
                } else {
                  widget.onOpenAddActivity?.call();
                }
              },
            ),
          ),
        );

        // 2. Render Stays
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
          if (rightPos > maxStayRight) {
            maxStayRight = rightPos;
          }

          // Mark covered night transitions
          for (int n = startIndex; n < endIndex && n < days.length - 1; n++) {
            coveredNights.add(n);
          }

          // Allocate vertical lane if stays overlap
          int trackIndex = -1;
          for (int t = 0; t < trackEndPositions.length; t++) {
            if (trackEndPositions[t] <= leftPos + 0.5) {
              trackIndex = t;
              trackEndPositions[t] = rightPos;
              break;
            }
          }
          if (trackIndex == -1) {
            trackIndex = trackEndPositions.length;
            trackEndPositions.add(rightPos);
          }

          final palette = stay.type == StayType.overnightFlight
              ? overnightFlightPalette
              : stayPalettes[k % stayPalettes.length];

          stayWidgets.add(
            Positioned(
              left: leftPos,
              top: trackIndex * 94.0,
              child: StayHeaderBridgeWidget(
                stay: stay,
                width: staySpanWidth,
                spanDays: nights,
                startNightNumber: startIndex + 1,
                palette: palette,
                onTap: () => widget.onStayTap?.call(stay),
              ),
            ),
          );
        }

        // Add empty slots for any uncovered night transitions
        for (int i = 0; i < days.length - 1; i++) {
          if (!coveredNights.contains(i)) {
            stayWidgets.add(
              Positioned(
                left: columnCenter(i),
                top: 0,
                child: const StayHeaderBridgeWidget(
                  stay: null,
                  width: totalColumnStride,
                ),
              ),
            );
          }
        }

        // 3. Resolve Last Day Departure Transport Header Data
        TransportHeaderData? departureData;
        final explicitDepartureFlight =
            allFlights.where((f) => f.isMainDeparture).firstOrNull;
        final departureFlight = explicitDepartureFlight ??
            allFlights.where((f) {
              final d = DateTime(
                  f.departureTime.year, f.departureTime.month, f.departureTime.day);
              final t = DateTime(lastDay.year, lastDay.month, lastDay.day);
              return d.isAtSameMomentAs(t) || d.isAfter(t);
            }).firstOrNull;

        if (departureFlight != null) {
          departureData = TransportHeaderData.fromFlight(
              departureFlight, TransportHeaderMode.departure);
        } else {
          final lastDayActivities = activitiesByDay[lastDay] ?? [];
          final departureAct = lastDayActivities.where((a) =>
              a.category == ActivityCategory.flight ||
              a.category == ActivityCategory.transport ||
              a.title.toLowerCase().contains('departure') ||
              a.title.toLowerCase().contains('return') ||
              a.title.toLowerCase().contains('flight') ||
              a.title.toLowerCase().contains('airport')).firstOrNull;

          if (departureAct != null) {
            departureData = TransportHeaderData.fromActivity(
                departureAct, TransportHeaderMode.departure);
          } else {
            departureData = TransportHeaderData.placeholder(
              mode: TransportHeaderMode.departure,
              destination: trip.destination,
              type: TransportType.flight,
            );
          }
        }

        // Add Departure Header on Last Day (starts at last day center, ends 50% width to right)
        final double departureLeft = columnCenter(days.length - 1);
        final double departureRight = departureLeft + columnWidth;
        if (departureRight > maxStayRight) {
          maxStayRight = departureRight;
        }

        int depTrackIndex = -1;
        for (int t = 0; t < trackEndPositions.length; t++) {
          if (trackEndPositions[t] <= departureLeft + 0.5) {
            depTrackIndex = t;
            trackEndPositions[t] = departureRight;
            break;
          }
        }
        if (depTrackIndex == -1) {
          depTrackIndex = trackEndPositions.length;
          trackEndPositions.add(departureRight);
        }

        stayWidgets.add(
          Positioned(
            left: departureLeft,
            top: depTrackIndex * 94.0,
            child: TransportHeaderBridgeWidget(
              mode: TransportHeaderMode.departure,
              data: departureData,
              width: columnWidth,
              onTap: () {
                if (departureData?.flight != null) {
                  _openFlightEdit(context, departureData!.flight!);
                } else if (departureData?.activity != null) {
                  widget.onActivityTap?.call(departureData!.activity!);
                } else {
                  widget.onOpenAddActivity?.call();
                }
              },
            ),
          ),
        );

        final double trackStackHeight =
            (trackEndPositions.isEmpty ? 1 : trackEndPositions.length) * 94.0;

        final double standardWidth =
            canvasLeftOffset + (days.length * totalColumnStride) + 145.0 + 40.0;
        final double totalCanvasWidth =
            standardWidth > (maxStayRight + 20.0) ? standardWidth : (maxStayRight + 20.0);

        return Column(
          children: [
            // Top Navigation & Information Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.view_week_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'ITINERARY  •  ${days.length} DAYS',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    DateFormatters.formatTripDateRange(
                        trip.startDate, trip.endDate),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  // Quick Horizontal Navigation Controls
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.today_rounded, size: 14),
                    label: const Text('Day 1', style: TextStyle(fontSize: 12)),
                    onPressed: _scrollToStart,
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded, size: 22),
                    tooltip: 'Scroll Left (Previous Day)',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _scrollBy(-totalColumnStride),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded, size: 22),
                    tooltip: 'Scroll Right (Next Day)',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _scrollBy(totalColumnStride),
                  ),
                ],
              ),
            ),

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

                                        return DayColumnWidget(
                                          date: dayDate,
                                          dayNumber: i + 1,
                                          activities:
                                              activitiesByDay[dayDate] ?? [],
                                          locations: effectiveLocations,
                                          canEdit: canEdit,
                                          onAddActivity: widget.onOpenAddActivity,
                                          onActivityTap: widget.onActivityTap,
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
