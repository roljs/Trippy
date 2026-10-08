import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/services/directions_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatters.dart';
import '../../../core/utils/trip_map_helper.dart';
import '../../../models/models.dart';
import '../../logistics/widgets/map_itinerary_view.dart' show GoogleMapType;

/// A marker representing an activity location on the day's map.
class DayMapPin {
  final String id;
  final String title;
  final String time;
  final String locationName;
  final GeoPoint coordinates;
  final Activity activity;
  final ActivityCategory category;
  final bool isTransportStart;
  final bool isTransportEnd;
  final String? markerLetter; // 'A', 'B', etc.

  const DayMapPin({
    required this.id,
    required this.title,
    required this.time,
    required this.locationName,
    required this.coordinates,
    required this.activity,
    required this.category,
    this.isTransportStart = false,
    this.isTransportEnd = false,
    this.markerLetter,
  });
}

/// An interactive Google Maps-based panel for the Day Planner view.
/// Shows all locations from the day's activities as pins when nothing is selected,
/// displays directions with a connecting route from/to when a transport activity is selected,
/// and highlights & centers a single location when a non-transport activity is selected.
class DayPlannerMapPanel extends StatefulWidget {
  final Trip trip;
  final DateTime date;
  final int dayNumber;
  final List<Activity> dayActivities;
  final List<Flight> dayFlights;
  final List<Stay> stays;
  final String defaultCountry;
  final Activity? selectedActivity;
  final ValueChanged<Activity?>? onSelectActivity;
  final VoidCallback? onClose;
  final bool isModal;

  const DayPlannerMapPanel({
    super.key,
    required this.trip,
    required this.date,
    required this.dayNumber,
    required this.dayActivities,
    this.dayFlights = const [],
    this.stays = const [],
    required this.defaultCountry,
    this.selectedActivity,
    this.onSelectActivity,
    this.onClose,
    this.isModal = false,
  });

  @override
  State<DayPlannerMapPanel> createState() => _DayPlannerMapPanelState();
}

class _DayPlannerMapPanelState extends State<DayPlannerMapPanel> {
  final TransformationController _transformController =
      TransformationController();

  GoogleMapType _mapType = GoogleMapType.roadmap;
  final bool _isDarkMode = false;
  static const double _canvasSize = 2400.0;

  Activity? _internalSelectedActivity;
  Activity? get _activeSelectedActivity =>
      widget.selectedActivity ?? _internalSelectedActivity;

  RouteDirections? _activeRouteDirections;
  bool _isLoadingDirections = false;

  @override
  void initState() {
    super.initState();
    _internalSelectedActivity = widget.selectedActivity;
    if (_internalSelectedActivity?.category == ActivityCategory.transport) {
      _fetchDirectionsForActivity(_internalSelectedActivity!);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_activeSelectedActivity != null) {
        _focusOnSelectedActivity(_activeSelectedActivity!);
      } else {
        _fitMapToPins();
      }
    });
  }

  @override
  void didUpdateWidget(DayPlannerMapPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedActivity != oldWidget.selectedActivity) {
      _internalSelectedActivity = widget.selectedActivity;
      if (_activeSelectedActivity?.category == ActivityCategory.transport) {
        _fetchDirectionsForActivity(_activeSelectedActivity!);
      } else {
        _activeRouteDirections = null;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_activeSelectedActivity != null) {
          _focusOnSelectedActivity(_activeSelectedActivity!);
        } else {
          _fitMapToPins();
        }
      });
    }
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _setSelectedActivity(Activity? activity) {
    setState(() {
      _internalSelectedActivity = activity;
      if (activity?.category == ActivityCategory.transport) {
        _fetchDirectionsForActivity(activity!);
      } else {
        _activeRouteDirections = null;
      }
    });
    if (widget.onSelectActivity != null) {
      widget.onSelectActivity!(activity);
    }
    if (activity != null) {
      _focusOnSelectedActivity(activity);
    } else {
      _fitMapToPins();
    }
  }

  void _fetchDirectionsForActivity(Activity act) {
    if (act.category != ActivityCategory.transport) {
      _activeRouteDirections = null;
      return;
    }

    final from = act.effectiveFromLocation?.trim();
    final to = act.effectiveToLocation?.trim();
    if (from == null || from.isEmpty || to == null || to.isEmpty) {
      _activeRouteDirections = null;
      return;
    }

    final cFrom = TripMapHelper.resolveCoordinates(from,
        contextCountry: widget.defaultCountry);
    final cTo = TripMapHelper.resolveCoordinates(to,
        contextCountry: widget.defaultCountry);

    setState(() {
      _isLoadingDirections = true;
    });

    DirectionsService.getDirections(
      cFrom,
      cTo,
      fromAddress: from,
      toAddress: to,
      startTime: act.startTime,
    ).then((directions) {
      if (!mounted) return;
      if (_activeSelectedActivity?.id == act.id) {
        setState(() {
          _activeRouteDirections = directions;
          _isLoadingDirections = false;
        });
        _focusOnSelectedActivity(act);
      }
    }).catchError((_) {
      if (mounted) {
        setState(() {
          _isLoadingDirections = false;
        });
      }
    });
  }

  /// Extracts all pins for the day's activities.
  List<DayMapPin> _extractDayPins() {
    final pins = <DayMapPin>[];

    for (final act in widget.dayActivities) {
      if (act.category == ActivityCategory.transport) {
        final from = act.effectiveFromLocation?.trim();
        final to = act.effectiveToLocation?.trim();

        if (from != null && from.isNotEmpty) {
          final cFrom = TripMapHelper.resolveCoordinates(from,
              contextCountry: widget.defaultCountry);
          pins.add(DayMapPin(
            id: '${act.id}_from',
            title: act.title,
            time: act.startTime,
            locationName: from,
            coordinates: cFrom,
            activity: act,
            category: act.category,
            isTransportStart: true,
            markerLetter: 'A',
          ));
        }

        if (to != null && to.isNotEmpty) {
          final cToRaw = TripMapHelper.resolveCoordinates(to,
              contextCountry: widget.defaultCountry);
          // If from and to resolve to identical coordinates, offset slightly so both are visible
          GeoPoint cTo = cToRaw;
          if (from != null && from.isNotEmpty) {
            final cFrom = TripMapHelper.resolveCoordinates(from,
                contextCountry: widget.defaultCountry);
            if ((cFrom.lat - cTo.lat).abs() < 0.0001 &&
                (cFrom.lng - cTo.lng).abs() < 0.0001) {
              cTo = GeoPoint(cTo.lat + 0.015, cTo.lng + 0.015);
            }
          }

          pins.add(DayMapPin(
            id: '${act.id}_to',
            title: act.title,
            time: act.endTime ?? act.startTime,
            locationName: to,
            coordinates: cTo,
            activity: act,
            category: act.category,
            isTransportEnd: true,
            markerLetter: 'B',
          ));
        }
      } else {
        final loc = act.location?.trim();
        if (loc == null || loc.isEmpty) {
          // If any activities do not have locations, ignore them when rendering the map view
          continue;
        }

        final coords = TripMapHelper.resolveCoordinates(loc,
            contextCountry: widget.defaultCountry);

        // Displace slightly if duplicate coordinates to prevent overlapping
        final duplicateCount = pins
            .where((p) =>
                (p.coordinates.lat - coords.lat).abs() < 0.001 &&
                (p.coordinates.lng - coords.lng).abs() < 0.001)
            .length;

        final finalCoords = duplicateCount > 0
            ? GeoPoint(
                coords.lat + (duplicateCount * 0.004),
                coords.lng + (duplicateCount * 0.004),
              )
            : coords;

        pins.add(DayMapPin(
          id: act.id,
          title: act.title,
          time: act.startTime,
          locationName: loc,
          coordinates: finalCoords,
          activity: act,
          category: act.category,
        ));
      }
    }

    return pins;
  }

  static double _latToMercatorY(double latDeg) {
    final rad = (latDeg.clamp(-85.0511, 85.0511)) * math.pi / 180.0;
    return math.log(math.tan(math.pi / 4.0 + rad / 2.0));
  }

  static double _mercatorYToLat(double yMerc) {
    return (2.0 * math.atan(math.exp(yMerc)) - math.pi / 2.0) * 180.0 / math.pi;
  }

  /// Calculates the geographic bounds encompassing all pins or active focus points and optional route coordinates.
  /// Enforces a 1:1 square aspect ratio in Web Mercator projection so the map is never stretched or distorted.
  ({double minLat, double maxLat, double minLng, double maxLng}) _getBounds(
      List<DayMapPin> pins, [List<GeoPoint>? extraPoints]) {
    double minLat;
    double maxLat;
    double minLng;
    double maxLng;

    final allPoints = <GeoPoint>[
      for (final p in pins) p.coordinates,
      ...?extraPoints,
    ];

    if (allPoints.isEmpty) {
      final defaultC = TripMapHelper.resolveCoordinates(
        widget.trip.destination,
        contextCountry: widget.defaultCountry,
      );
      minLat = defaultC.lat - 0.03;
      maxLat = defaultC.lat + 0.03;
      minLng = defaultC.lng - 0.03;
      maxLng = defaultC.lng + 0.03;
    } else {
      minLat = allPoints.first.lat;
      maxLat = allPoints.first.lat;
      minLng = allPoints.first.lng;
      maxLng = allPoints.first.lng;

      for (final pt in allPoints) {
        if (pt.lat < minLat) minLat = pt.lat;
        if (pt.lat > maxLat) maxLat = pt.lat;
        if (pt.lng < minLng) minLng = pt.lng;
        if (pt.lng > maxLng) maxLng = pt.lng;
      }
    }

    // Convert bounds to normalized Mercator coordinates [0, 1]
    final xMinNorm = (minLng + 180.0) / 360.0;
    final xMaxNorm = (maxLng + 180.0) / 360.0;
    final yMinNorm = 0.5 - (_latToMercatorY(maxLat) / (2 * math.pi));
    final yMaxNorm = 0.5 - (_latToMercatorY(minLat) / (2 * math.pi));

    final spanX = (xMaxNorm - xMinNorm).abs();
    final spanY = (yMaxNorm - yMinNorm).abs();

    final centerX = (xMinNorm + xMaxNorm) / 2.0;
    final centerY = (yMinNorm + yMaxNorm) / 2.0;

    // Enforce 1:1 square aspect ratio with 35% margin for comfortable padding
    final squareSpan =
        math.max(0.003, math.max(spanX, spanY) * 1.35).clamp(0.001, 1.0);

    final squareXMin = centerX - squareSpan / 2.0;
    final squareXMax = centerX + squareSpan / 2.0;
    final squareYMin = centerY - squareSpan / 2.0;
    final squareYMax = centerY + squareSpan / 2.0;

    // Convert square normalized Mercator box back to Lat/Lng
    final finalMinLng = squareXMin * 360.0 - 180.0;
    final finalMaxLng = squareXMax * 360.0 - 180.0;
    final finalMaxLat = _mercatorYToLat((0.5 - squareYMin) * (2 * math.pi));
    final finalMinLat = _mercatorYToLat((0.5 - squareYMax) * (2 * math.pi));

    return (
      minLat: finalMinLat,
      maxLat: finalMaxLat,
      minLng: finalMinLng,
      maxLng: finalMaxLng,
    );
  }

  /// Converts a GeoPoint to Canvas pixel offset using conformal Web Mercator projection.
  Offset _projectToCanvas(GeoPoint geo,
      ({double minLat, double maxLat, double minLng, double maxLng}) b) {
    final xNorm = (geo.lng + 180.0) / 360.0;
    final yNorm = 0.5 - (_latToMercatorY(geo.lat) / (2 * math.pi));

    final bXMin = (b.minLng + 180.0) / 360.0;
    final bXMax = (b.maxLng + 180.0) / 360.0;
    final bYMin = 0.5 - (_latToMercatorY(b.maxLat) / (2 * math.pi));
    final bYMax = 0.5 - (_latToMercatorY(b.minLat) / (2 * math.pi));

    final spanX = math.max(0.00001, bXMax - bXMin);
    final spanY = math.max(0.00001, bYMax - bYMin);

    final x = ((xNorm - bXMin) / spanX).clamp(0.02, 0.98) * _canvasSize;
    final y = ((yNorm - bYMin) / spanY).clamp(0.02, 0.98) * _canvasSize;

    return Offset(x, y);
  }

  void _fitMapToPins() {
    if (!mounted) return;
    final pins = _extractDayPins();
    final bounds = _getBounds(pins);
    _fitToBounds(bounds);
  }

  void _focusOnSelectedActivity(Activity act) {
    if (!mounted) return;
    final pins = _extractDayPins().where((p) => p.activity.id == act.id).toList();
    if (pins.isEmpty) {
      _fitMapToPins();
      return;
    }

    if (act.category == ActivityCategory.transport && pins.length >= 2) {
      // Directions: fit both From and To points, plus any active road route curve coordinates
      final routeCoords = _activeRouteDirections?.coordinates;
      final bounds = _getBounds(pins, routeCoords);
      _fitToBounds(bounds);
    } else {
      // Single location: center and zoom in directly
      final targetPin = pins.first;
      final allPins = _extractDayPins();
      final bounds = _getBounds(allPins);
      final pt = _projectToCanvas(targetPin.coordinates, bounds);

      final renderBox = context.findRenderObject() as RenderBox?;
      final viewport = renderBox?.size ?? const Size(600, 500);

      const targetScale = 1.6;
      final dx = (viewport.width / 2) - (pt.dx * targetScale);
      final dy = (viewport.height / 2) - (pt.dy * targetScale);

      final matrix = Matrix4.diagonal3Values(targetScale, targetScale, 1.0)
        ..setTranslationRaw(dx, dy, 0.0);

      _transformController.value = matrix;
    }
  }

  void _fitToBounds(
      ({double minLat, double maxLat, double minLng, double maxLng}) b) {
    if (!mounted) return;
    final renderBox = context.findRenderObject() as RenderBox?;
    final viewport = renderBox?.size ?? const Size(600, 500);

    final targetScale = (math.min(viewport.width / _canvasSize,
                viewport.height / _canvasSize) *
            0.92)
        .clamp(0.1, 3.0);
    final centerPixel = Offset(_canvasSize / 2, _canvasSize / 2);

    final dx = (viewport.width / 2) - (centerPixel.dx * targetScale);
    final dy = (viewport.height / 2) - (centerPixel.dy * targetScale);

    final matrix = Matrix4.diagonal3Values(targetScale, targetScale, 1.0)
      ..setTranslationRaw(dx, dy, 0.0);

    _transformController.value = matrix;
  }

  void _zoom(double factor) {
    final currentScale = _transformController.value.getMaxScaleOnAxis();
    final newScale = (currentScale * factor).clamp(0.1, 4.0);
    final renderBox = context.findRenderObject() as RenderBox?;
    final viewport = renderBox?.size ?? const Size(600, 500);
    final centerViewport = Offset(viewport.width / 2, viewport.height / 2);

    final translation = _transformController.value.getTranslation();
    final dx = centerViewport.dx -
        (centerViewport.dx - translation.x) * (newScale / currentScale);
    final dy = centerViewport.dy -
        (centerViewport.dy - translation.y) * (newScale / currentScale);

    final matrix = Matrix4.diagonal3Values(newScale, newScale, 1.0)
      ..setTranslationRaw(dx, dy, 0.0);

    _transformController.value = matrix;
  }

  @override
  Widget build(BuildContext context) {
    final pins = _extractDayPins();
    final activeSelected = _activeSelectedActivity;
    final isTransportSelected =
        activeSelected?.category == ActivityCategory.transport;

    final routeCoords = (isTransportSelected && _activeRouteDirections != null)
        ? _activeRouteDirections!.coordinates
        : null;
    final bounds = _getBounds(pins, routeCoords);

    final isDark = _mapType == GoogleMapType.dark ||
        (_isDarkMode && _mapType == GoogleMapType.roadmap);

    // Filter pins when transport directions are active vs all pins
    final selectedPins = activeSelected != null
        ? pins.where((p) => p.activity.id == activeSelected.id).toList()
        : <DayMapPin>[];

    DayMapPin? startPin;
    DayMapPin? endPin;
    if (isTransportSelected) {
      startPin = selectedPins.where((p) => p.isTransportStart).firstOrNull;
      endPin = selectedPins.where((p) => p.isTransportEnd).firstOrNull;
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: widget.isModal
            ? const BorderRadius.vertical(top: Radius.circular(20))
            : BorderRadius.circular(16),
        border: widget.isModal ? null : Border.all(color: AppColors.border, width: 1),
        boxShadow: widget.isModal
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: widget.isModal
            ? const BorderRadius.vertical(top: Radius.circular(20))
            : BorderRadius.circular(16),
        child: Stack(
          children: [
            // 1. Google Maps Interactive Canvas (Pannable & Zoomable)
            Positioned.fill(
              child: InteractiveViewer(
                transformationController: _transformController,
                minScale: 0.1,
                maxScale: 5.0,
                boundaryMargin: const EdgeInsets.all(800),
                constrained: false,
                child: SizedBox(
                  width: _canvasSize,
                  height: _canvasSize,
                  child: Stack(
                    children: [
                      // Vector Grid & Base Canvas
                      CustomPaint(
                        size: const Size(_canvasSize, _canvasSize),
                        painter: _DayMapVectorPainter(
                          isDarkMode: isDark,
                          mapType: _mapType,
                        ),
                      ),

                      // Google Maps Raster Tiles Layer
                      _DayGoogleMapTileLayer(
                        mapType: _mapType,
                        isDarkMode: isDark,
                        canvasSize: _canvasSize,
                        bounds: bounds,
                      ),

                      // Transport Route Connecting Line (Directions)
                      if (isTransportSelected &&
                          startPin != null &&
                          endPin != null)
                        CustomPaint(
                          size: const Size(_canvasSize, _canvasSize),
                          painter: _TransportDirectionsPainter(
                            startOffset:
                                _projectToCanvas(startPin.coordinates, bounds),
                            endOffset:
                                _projectToCanvas(endPin.coordinates, bounds),
                            routeOffsets: (_activeRouteDirections != null &&
                                    _activeRouteDirections!.coordinates.isNotEmpty)
                                ? _activeRouteDirections!.coordinates
                                    .map((c) => _projectToCanvas(c, bounds))
                                    .toList()
                                : null,
                            isDarkMode: isDark,
                          ),
                        ),

                      // Activity Pins
                      for (final pin in pins)
                        _buildPinWidget(
                          pin: pin,
                          bounds: bounds,
                          isSelected: activeSelected?.id == pin.activity.id,
                          isDimmed: activeSelected != null &&
                              activeSelected.id != pin.activity.id,
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // 2. Top Header Bar (Title, Activity Chips, Map Controls, Close Button)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildTopHeader(pins),
            ),

            // 3. Floating Map Controls (Zoom In, Zoom Out, Fit, Map Style)
            Positioned(
              right: 14,
              top: 104,
              child: _buildFloatingControls(),
            ),

            // 4. Google Maps Attribution Watermark (Bottom-Left)
            Positioned(
              left: 14,
              bottom: activeSelected != null ? 140 : 14,
              child: _buildGoogleAttributionBadge(isDark),
            ),

            // 5. Bottom Detail Card (When Activity / Directions Selected)
            if (activeSelected != null)
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: _buildSelectionDetailCard(
                  activeSelected,
                  startPin: startPin,
                  endPin: endPin,
                  isDark: isDark,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Builds the top header with title, close button, and horizontal activity chips.
  Widget _buildTopHeader(List<DayMapPin> pins) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _isDarkMode
            ? const Color(0xFF0F172A).withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.95),
        border: Border(
          bottom: BorderSide(
            color: _isDarkMode ? Colors.white12 : Colors.grey.shade200,
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.map_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DAY ${widget.dayNumber} MAP • ${DateFormatters.shortDate.format(widget.date).toUpperCase()}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${pins.length} locations on map • Google Maps',
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.onClose != null)
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  tooltip: 'Close map',
                  onPressed: widget.onClose,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Horizontal Activity Selector Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // "All Locations" chip
                _buildFilterChip(
                  label: 'All Pins (${pins.length})',
                  icon: Icons.place_rounded,
                  isSelected: _activeSelectedActivity == null,
                  onTap: () => _setSelectedActivity(null),
                ),
                const SizedBox(width: 6),
                for (final act in widget.dayActivities
                    .where((act) => pins.any((p) => p.activity.id == act.id))) ...[
                  _buildFilterChip(
                    key: ValueKey('map_chip_${act.id}'),
                    label: '${act.startTime} ${act.title}',
                    icon: _getCategoryIcon(act.category),
                    isSelected: _activeSelectedActivity?.id == act.id,
                    badgeColor: _getCategoryColor(act.category),
                    onTap: () => _setSelectedActivity(
                      _activeSelectedActivity?.id == act.id ? null : act,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    Key? key,
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    Color? badgeColor,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? (badgeColor ?? AppColors.primary)
              : (_isDarkMode
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : (_isDarkMode ? Colors.white12 : Colors.grey.shade300),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected
                  ? Colors.white
                  : (badgeColor ?? AppColors.textSecondary),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : (_isDarkMode ? Colors.white70 : AppColors.textPrimary),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  /// Builds an interactive pin on the map.
  Widget _buildPinWidget({
    required DayMapPin pin,
    required ({double minLat, double maxLat, double minLng, double maxLng})
        bounds,
    required bool isSelected,
    required bool isDimmed,
  }) {
    final offset = _projectToCanvas(pin.coordinates, bounds);
    final catColor = pin.isTransportStart
        ? const Color(0xFF16A34A) // Green for Start
        : (pin.isTransportEnd
            ? const Color(0xFFDC2626) // Red for Destination
            : _getCategoryColor(pin.category));

    return Positioned(
      left: offset.dx - 22,
      top: offset.dy - 44,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => _setSelectedActivity(
            _activeSelectedActivity?.id == pin.activity.id ? null : pin.activity,
          ),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: isDimmed ? 0.35 : 1.0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Label Callout Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? catColor
                        : Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: catColor,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (pin.markerLetter != null) ...[
                        Text(
                          pin.markerLetter!,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: isSelected ? Colors.white : catColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        '${pin.time} ${pin.title}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),

                // Pin Marker Icon
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: isSelected ? 36 : 28,
                  height: isSelected ? 36 : 28,
                  decoration: BoxDecoration(
                    color: catColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: isSelected ? 2.5 : 1.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: catColor.withValues(alpha: isSelected ? 0.6 : 0.3),
                        blurRadius: isSelected ? 10 : 5,
                        spreadRadius: isSelected ? 3 : 0,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      pin.markerLetter != null
                          ? (pin.isTransportStart
                              ? Icons.trip_origin_rounded
                              : Icons.flag_rounded)
                          : _getCategoryIcon(pin.category),
                      size: isSelected ? 18 : 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Floating map controls (+, -, fit, map type).
  Widget _buildFloatingControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildCircleButton(
          icon: Icons.add_rounded,
          tooltip: 'Zoom in',
          onTap: () => _zoom(1.3),
        ),
        const SizedBox(height: 6),
        _buildCircleButton(
          icon: Icons.remove_rounded,
          tooltip: 'Zoom out',
          onTap: () => _zoom(0.75),
        ),
        const SizedBox(height: 6),
        _buildCircleButton(
          icon: Icons.fit_screen_rounded,
          tooltip: 'Fit all locations',
          onTap: () {
            _setSelectedActivity(null);
            _fitMapToPins();
          },
        ),
        const SizedBox(height: 6),
        PopupMenuButton<GoogleMapType>(
          tooltip: 'Map style',
          icon: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.layers_outlined, size: 18, color: AppColors.textPrimary),
          ),
          onSelected: (t) => setState(() => _mapType = t),
          itemBuilder: (ctx) => [
            const PopupMenuItem(value: GoogleMapType.roadmap, child: Text('Roadmap')),
            const PopupMenuItem(value: GoogleMapType.satellite, child: Text('Satellite')),
            const PopupMenuItem(value: GoogleMapType.terrain, child: Text('Terrain')),
            const PopupMenuItem(value: GoogleMapType.dark, child: Text('Dark Mode')),
          ],
        ),
      ],
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 18, color: AppColors.textPrimary),
        tooltip: tooltip,
        onPressed: onTap,
      ),
    );
  }

  /// Google watermark badge.
  Widget _buildGoogleAttributionBadge(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0F172A).withValues(alpha: 0.88)
            : Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black12,
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Google',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              color: Color(0xFF4285F4),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'Maps',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  /// Bottom Detail Card showing directions or location details.
  Widget _buildSelectionDetailCard(
    Activity act, {
    DayMapPin? startPin,
    DayMapPin? endPin,
    required bool isDark,
  }) {
    final isTransport = act.category == ActivityCategory.transport;
    final catColor = _getCategoryColor(act.category);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0F172A).withValues(alpha: 0.95)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: catColor.withValues(alpha: 0.4),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: catColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isTransport
                  ? Icons.directions_transit_rounded
                  : _getCategoryIcon(act.category),
              color: catColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: catColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isTransport
                            ? 'DIRECTIONS'
                            : act.category.displayName.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${act.startTime}${act.endTime != null ? " – ${act.endTime}" : ""}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: catColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  act.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (isTransport) ...[
                  if (_activeRouteDirections != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.directions_car_rounded,
                            size: 13, color: Color(0xFF1A73E8)),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${_activeRouteDirections!.formattedDuration} (${_activeRouteDirections!.formattedDistanceMiles}) • ${_activeRouteDirections!.summary}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A73E8),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F0FE),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Google Maps Route',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1967D2),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else if (_isLoadingDirections) ...[
                    const SizedBox(height: 2),
                    const Row(
                      children: [
                        SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(strokeWidth: 1.5),
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Calculating route from Google Maps...',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontStyle: FontStyle.italic,
                            color: Color(0xFF1A73E8),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.trip_origin_rounded,
                          size: 11, color: Color(0xFF16A34A)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'From: ${act.effectiveFromLocation ?? "Origin"}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white70 : AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.flag_rounded,
                          size: 11, color: Color(0xFFDC2626)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'To: ${act.effectiveToLocation ?? "Destination"}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white70 : AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ] else if (act.location != null && act.location!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    act.location!,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white70 : AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          TextButton.icon(
            onPressed: () => _setSelectedActivity(null),
            icon: const Icon(Icons.clear_rounded, size: 14),
            label: const Text('Show All', style: TextStyle(fontSize: 11)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              backgroundColor: isDark ? Colors.white12 : Colors.grey.shade100,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(ActivityCategory cat) {
    switch (cat) {
      case ActivityCategory.attraction:
        return Icons.museum_rounded;
      case ActivityCategory.dining:
        return Icons.restaurant_rounded;
      case ActivityCategory.transport:
        return Icons.directions_bus_rounded;
      case ActivityCategory.entertainment:
        return Icons.theater_comedy_rounded;
      case ActivityCategory.stay:
        return Icons.hotel_rounded;
      case ActivityCategory.custom:
        return Icons.star_rounded;
    }
  }

  Color _getCategoryColor(ActivityCategory cat) {
    switch (cat) {
      case ActivityCategory.attraction:
        return AppColors.attraction;
      case ActivityCategory.dining:
        return AppColors.dining;
      case ActivityCategory.transport:
        return AppColors.transport;
      case ActivityCategory.entertainment:
        return AppColors.entertainment;
      case ActivityCategory.stay:
        return AppColors.stay;
      case ActivityCategory.custom:
        return AppColors.attraction;
    }
  }
}

/// Painter for drawing transport direction routes between From and To points.
class _TransportDirectionsPainter extends CustomPainter {
  final Offset startOffset;
  final Offset endOffset;
  final List<Offset>? routeOffsets;
  final bool isDarkMode;

  _TransportDirectionsPainter({
    required this.startOffset,
    required this.endOffset,
    this.routeOffsets,
    required this.isDarkMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (routeOffsets != null && routeOffsets!.length >= 2) {
      _paintGoogleMapsRoute(canvas);
    } else {
      _paintDirectRoute(canvas);
    }
  }

  void _paintGoogleMapsRoute(Canvas canvas) {
    final points = routeOffsets!;
    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    // 1. Google Maps Route Shadow / Glow
    final glowPaint = Paint()
      ..color = const Color(0xFF1558B0).withValues(alpha: 0.3)
      ..strokeWidth = 9.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, glowPaint);

    // 2. Google Maps Dark Blue Outer Casing (crisp highway styling)
    final casingPaint = Paint()
      ..color = const Color(0xFF1558B0)
      ..strokeWidth = 6.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, casingPaint);

    // 3. Google Maps Vibrant Blue Core Line
    final corePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..strokeWidth = 4.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, corePaint);

    // 4. Direction chevrons along the route (every ~10-15 segments depending on density)
    if (points.length >= 8) {
      final step = math.max(4, points.length ~/ 6);
      for (int i = step; i < points.length - step ~/ 2; i += step) {
        final pPrev = points[i - 1];
        final pCurr = points[i];
        final dx = pCurr.dx - pPrev.dx;
        final dy = pCurr.dy - pPrev.dy;
        final segLen = math.sqrt(dx * dx + dy * dy);
        if (segLen < 2.0) continue;

        final angle = math.atan2(dy, dx);
        _drawDirectionChevron(canvas, pCurr, angle);
      }
    }
  }

  void _drawDirectionChevron(Canvas canvas, Offset center, double angle) {
    const size = 5.0;
    final chevronPath = Path();
    chevronPath.moveTo(
      center.dx + math.cos(angle) * size,
      center.dy + math.sin(angle) * size,
    );
    chevronPath.lineTo(
      center.dx + math.cos(angle + 2.4) * (size * 1.2),
      center.dy + math.sin(angle + 2.4) * (size * 1.2),
    );
    chevronPath.lineTo(
      center.dx,
      center.dy,
    );
    chevronPath.lineTo(
      center.dx + math.cos(angle - 2.4) * (size * 1.2),
      center.dy + math.sin(angle - 2.4) * (size * 1.2),
    );
    chevronPath.close();

    final chevronPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;
    canvas.drawPath(chevronPath, chevronPaint);
  }

  void _paintDirectRoute(Canvas canvas) {
    // Fallback: Subtle quadratic bezier curve
    final path = Path();
    path.moveTo(startOffset.dx, startOffset.dy);

    final midX = (startOffset.dx + endOffset.dx) / 2;
    final midY = (startOffset.dy + endOffset.dy) / 2;
    final dx = endOffset.dx - startOffset.dx;
    final dy = endOffset.dy - startOffset.dy;
    final normalX = -dy * 0.12;
    final normalY = dx * 0.12;
    final controlPoint = Offset(midX + normalX, midY + normalY);

    path.quadraticBezierTo(
      controlPoint.dx,
      controlPoint.dy,
      endOffset.dx,
      endOffset.dy,
    );

    // Glow background line
    final glowPaint = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.35)
      ..strokeWidth = 8.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, glowPaint);

    // Main line
    final routePaint = Paint()
      ..color = const Color(0xFF0284C7)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, routePaint);

    // Direction arrow at midpoint
    final angle = math.atan2(endOffset.dy - startOffset.dy, endOffset.dx - startOffset.dx);
    final arrowLength = 12.0;
    final arrowPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final arrowPath = Path();
    final arrowTip = Offset(midX, midY);
    arrowPath.moveTo(
      arrowTip.dx + math.cos(angle) * arrowLength,
      arrowTip.dy + math.sin(angle) * arrowLength,
    );
    arrowPath.lineTo(
      arrowTip.dx + math.cos(angle + 2.5) * arrowLength,
      arrowTip.dy + math.sin(angle + 2.5) * arrowLength,
    );
    arrowPath.lineTo(
      arrowTip.dx + math.cos(angle - 2.5) * arrowLength,
      arrowTip.dy + math.sin(angle - 2.5) * arrowLength,
    );
    arrowPath.close();

    canvas.drawCircle(arrowTip, 10, Paint()..color = const Color(0xFF0284C7));
    canvas.drawPath(arrowPath, arrowPaint);
  }

  @override
  bool shouldRepaint(covariant _TransportDirectionsPainter oldDelegate) {
    return oldDelegate.startOffset != startOffset ||
        oldDelegate.endOffset != endOffset ||
        oldDelegate.routeOffsets != routeOffsets ||
        oldDelegate.isDarkMode != isDarkMode;
  }
}

/// Fallback vector canvas painter with landmasses, roads, and grids.
class _DayMapVectorPainter extends CustomPainter {
  final bool isDarkMode;
  final GoogleMapType mapType;

  _DayMapVectorPainter({
    required this.isDarkMode,
    required this.mapType,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..color = isDarkMode ? const Color(0xFF0B132B) : const Color(0xFFF1F5F9);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final gridPaint = Paint()
      ..color = isDarkMode
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.black.withValues(alpha: 0.035)
      ..strokeWidth = 1.0;

    const spacing = 120.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DayMapVectorPainter oldDelegate) =>
      oldDelegate.isDarkMode != isDarkMode || oldDelegate.mapType != mapType;
}

/// Google Maps raster tile layer for city street level.
class _DayGoogleMapTileLayer extends StatelessWidget {
  final GoogleMapType mapType;
  final bool isDarkMode;
  final double canvasSize;
  final ({double minLat, double maxLat, double minLng, double maxLng}) bounds;

  static final Set<String> _failedUrls = {};

  const _DayGoogleMapTileLayer({
    required this.mapType,
    required this.isDarkMode,
    required this.canvasSize,
    required this.bounds,
  });

  @override
  Widget build(BuildContext context) {
    double latToMercatorY(double deg) {
      final rad = (deg.clamp(-85.0511, 85.0511)) * math.pi / 180.0;
      return math.log(math.tan(math.pi / 4.0 + rad / 2.0));
    }

    final xMinNorm = (bounds.minLng + 180.0) / 360.0;
    final xMaxNorm = (bounds.maxLng + 180.0) / 360.0;
    final yMinNorm = 0.5 - (latToMercatorY(bounds.maxLat) / (2 * math.pi));
    final yMaxNorm = 0.5 - (latToMercatorY(bounds.minLat) / (2 * math.pi));

    final spanNorm =
        math.max(0.00001, math.max(xMaxNorm - xMinNorm, yMaxNorm - yMinNorm));

    // Dynamic zoom so each tile is rendered close to native 256x256 resolution
    int zoom = ((math.log(canvasSize / (256.0 * spanNorm)) / math.ln2).round())
        .clamp(2, 17);

    int worldTiles = 1 << zoom;
    int tileXStart = (xMinNorm * worldTiles).floor();
    int tileXEnd = (xMaxNorm * worldTiles).ceil();
    int tileYStart = (yMinNorm * worldTiles).floor();
    int tileYEnd = (yMaxNorm * worldTiles).ceil();

    // Safety guard: ensure the total tile count never exceeds 64 tiles
    while (zoom > 2 &&
        (tileXEnd - tileXStart + 1) * (tileYEnd - tileYStart + 1) > 64) {
      zoom--;
      worldTiles = 1 << zoom;
      tileXStart = (xMinNorm * worldTiles).floor();
      tileXEnd = (xMaxNorm * worldTiles).ceil();
      tileYStart = (yMinNorm * worldTiles).floor();
      tileYEnd = (yMaxNorm * worldTiles).ceil();
    }

    // Exact uniform tile dimension: 1 tile in normalized coords is 1.0 / worldTiles
    final double tileSizeOnCanvas =
        (1.0 / (worldTiles * spanNorm)) * canvasSize;
    final double size = tileSizeOnCanvas + 0.5;

    final lyrs = switch (mapType) {
      GoogleMapType.roadmap => 'm',
      GoogleMapType.satellite => 'y',
      GoogleMapType.terrain => 'p',
      GoogleMapType.dark => 'm',
    };

    final isDark = mapType == GoogleMapType.dark ||
        (isDarkMode && mapType == GoogleMapType.roadmap);

    const darkFilter = ColorFilter.matrix([
      -0.65,  0.00,  0.00, 0.0, 195,
       0.00, -0.65,  0.00, 0.0, 205,
       0.00,  0.00, -0.55, 0.0, 220,
       0.00,  0.00,  0.00, 1.0,   0,
    ]);

    final List<Widget> tileWidgets = [];
    const maxAllowedTiles = 64;

    for (int ty = tileYStart;
        ty <= tileYEnd && tileWidgets.length < maxAllowedTiles;
        ty++) {
      if (ty < 0 || ty >= worldTiles) continue;
      for (int tx = tileXStart;
          tx <= tileXEnd && tileWidgets.length < maxAllowedTiles;
          tx++) {
        final wrappedX = (tx % worldTiles + worldTiles) % worldTiles;
        final url =
            'https://mt1.google.com/vt/lyrs=$lyrs&x=$wrappedX&y=$ty&z=$zoom';

        if (_failedUrls.contains(url)) continue;

        // Position on canvas: uniform square positioning
        final left =
            ((tx.toDouble() / worldTiles - xMinNorm) / spanNorm) * canvasSize;
        final top =
            ((ty.toDouble() / worldTiles - yMinNorm) / spanNorm) * canvasSize;

        tileWidgets.add(
          Positioned(
            left: left,
            top: top,
            width: size,
            height: size,
            child: Image.network(
              url,
              width: size,
              height: size,
              fit: BoxFit.fill,
              errorBuilder: (context, error, stackTrace) {
                _failedUrls.add(url);
                return const SizedBox.shrink();
              },
            ),
          ),
        );
      }
    }

    Widget content = Stack(children: tileWidgets);
    if (isDark) {
      content = ColorFiltered(colorFilter: darkFilter, child: content);
    }
    return content;
  }
}
