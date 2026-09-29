import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/city_color_helper.dart';
import '../../../core/utils/date_formatters.dart';
import '../../../core/utils/trip_map_helper.dart';
import '../../../models/models.dart';
import '../../common/add_flight_sheet.dart';
import '../../common/add_stay_sheet.dart';
import 'stay_header_bridge_widget.dart';

enum GoogleMapType {
  dark,
  roadmap,
  satellite,
  terrain,
}

/// An interactive map view of the trip displaying all cities in chronological order,
/// connecting flight and ground travel lines with moniker badges, and hover details.
class MapItineraryView extends StatefulWidget {
  final Trip trip;
  final List<Stay> stays;
  final List<Flight> flights;
  final Map<DateTime, List<Activity>> activitiesByDay;
  final bool canEdit;
  final ValueChanged<Stay>? onStayTap;
  final ValueChanged<Flight>? onFlightTap;
  final ValueChanged<Activity>? onActivityTap;

  const MapItineraryView({
    super.key,
    required this.trip,
    required this.stays,
    required this.flights,
    required this.activitiesByDay,
    this.canEdit = true,
    this.onStayTap,
    this.onFlightTap,
    this.onActivityTap,
  });

  @override
  State<MapItineraryView> createState() => _MapItineraryViewState();
}

class _MapItineraryViewState extends State<MapItineraryView> {
  final TransformationController _transformController =
      TransformationController();

  bool _isDarkMode = true;
  GoogleMapType _mapType = GoogleMapType.dark;
  TripMapCityNode? _hoveredCity;
  TripMapConnectionLeg? _hoveredLeg;
  TripMapCityNode? _selectedCity;
  TripMapConnectionLeg? _selectedLeg;

  // Virtual canvas dimensions for high precision map rendering
  static const double _canvasWidth = 3200.0;
  static const double _canvasHeight = 2000.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fitMapToTrip();
    });
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _fitMapToTrip() {
    final route = TripMapHelper.extractRoute(
      trip: widget.trip,
      stays: widget.stays,
      flights: widget.flights,
      activitiesByDay: widget.activitiesByDay,
    );

    if (route.isEmpty) return;

    final bounds = _calculatePixelBounds(route);
    final size = MediaQuery.of(context).size;

    // Viewport size inside the widget
    final viewportWidth = math.max(size.width - 40, 320.0);
    final viewportHeight = math.max(size.height - 200, 320.0);

    final routeWidth = math.max(bounds.width + 260.0, 400.0);
    final routeHeight = math.max(bounds.height + 260.0, 350.0);

    final scaleX = viewportWidth / routeWidth;
    final scaleY = viewportHeight / routeHeight;
    final targetScale = math.min(scaleX, scaleY).clamp(0.45, 1.8);

    final center = bounds.center;
    final dx = (viewportWidth / 2) - (center.dx * targetScale);
    final dy = (viewportHeight / 2) - (center.dy * targetScale);

    final matrix = Matrix4.diagonal3Values(targetScale, targetScale, 1.0)
      ..setTranslationRaw(dx, dy, 0.0);

    _transformController.value = matrix;
  }

  void _zoom(double factor) {
    final currentScale = _transformController.value.getMaxScaleOnAxis();
    final newScale = (currentScale * factor).clamp(0.3, 3.5);
    final size = MediaQuery.of(context).size;
    final centerViewport = Offset(size.width / 2, (size.height - 200) / 2);

    final translation = _transformController.value.getTranslation();
    final dx = centerViewport.dx - (centerViewport.dx - translation.x) * (newScale / currentScale);
    final dy = centerViewport.dy - (centerViewport.dy - translation.y) * (newScale / currentScale);

    final matrix = Matrix4.diagonal3Values(newScale, newScale, 1.0)
      ..setTranslationRaw(dx, dy, 0.0);

    _transformController.value = matrix;
  }

  void _centerOnCity(TripMapCityNode city, TripMapRoute route) {
    final pt = _projectToCanvas(city.coordinates, route.crossesPacific) + city.calloutOffset;
    final size = MediaQuery.of(context).size;
    const scale = 1.35;
    final dx = (size.width / 2) - (pt.dx * scale);
    final dy = ((size.height - 200) / 2) - (pt.dy * scale);

    final matrix = Matrix4.diagonal3Values(scale, scale, 1.0)
      ..setTranslationRaw(dx, dy, 0.0);

    _transformController.value = matrix;
    setState(() {
      _selectedCity = city;
      _selectedLeg = null;
    });
  }

  Offset _projectToCanvas(GeoPoint coords, bool crossesPacific) {
    double lng = coords.lng;
    if (crossesPacific && lng < 0) {
      lng += 360.0; // Seattle (-122) -> 238
    }

    final minL = crossesPacific ? 70.0 : -130.0;
    final maxL = crossesPacific ? 260.0 : 160.0;
    const minLa = -12.0;
    const maxLa = 62.0;

    double latToMercatorY(double deg) {
      final rad = (deg.clamp(-80.0, 80.0)) * math.pi / 180.0;
      return math.log(math.tan(math.pi / 4.0 + rad / 2.0));
    }

    final yMax = latToMercatorY(maxLa);
    final yMin = latToMercatorY(minLa);
    final yVal = latToMercatorY(coords.lat);

    final xRatio = ((lng - minL) / (maxL - minL)).clamp(0.01, 0.99);
    final yRatio = ((yMax - yVal) / (yMax - yMin)).clamp(0.02, 0.98);

    return Offset(
      xRatio * _canvasWidth,
      yRatio * _canvasHeight,
    );
  }

  Rect _calculatePixelBounds(TripMapRoute route) {
    if (route.isEmpty) {
      return const Rect.fromLTWH(0, 0, _canvasWidth, _canvasHeight);
    }

    double minX = _canvasWidth, maxX = 0;
    double minY = _canvasHeight, maxY = 0;

    for (final c in route.cities) {
      final p = _projectToCanvas(c.coordinates, route.crossesPacific) + c.calloutOffset;
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  void _openFlightModal(Flight flight) {
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

  void _openStayModal(Stay stay) {
    if (widget.onStayTap != null) {
      widget.onStayTap!(stay);
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => AddStaySheet(stayToEdit: stay),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final route = TripMapHelper.extractRoute(
      trip: widget.trip,
      stays: widget.stays,
      flights: widget.flights,
      activitiesByDay: widget.activitiesByDay,
    );

    final activeThemeBg = _isDarkMode ? const Color(0xFF0B132B) : const Color(0xFFF8FAFC);
    final activeThemeGrid = _isDarkMode ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04);
    final activeThemeContinent = _isDarkMode ? const Color(0xFF1C2541) : const Color(0xFFE2E8F0);

    return Container(
      color: activeThemeBg,
      child: Stack(
        children: [
          // 1. Pan & Zoom Map Canvas
          InteractiveViewer(
            transformationController: _transformController,
            minScale: 0.25,
            maxScale: 4.0,
            boundaryMargin: const EdgeInsets.all(1200),
            constrained: false,
            child: SizedBox(
              width: _canvasWidth,
              height: _canvasHeight,
              child: Stack(
                children: [
                  // Vector Custom Painter (Continents, Graticules Grid Fallback)
                  CustomPaint(
                    size: const Size(_canvasWidth, _canvasHeight),
                    painter: _MapCanvasPainter(
                      route: route,
                      isDarkMode: _isDarkMode,
                      bgGridColor: activeThemeGrid,
                      continentColor: activeThemeContinent,
                      projectCoord: (geo) => _projectToCanvas(geo, route.crossesPacific),
                    ),
                  ),

                  // Google Maps Interactive Tile Layer (Roadmap, Satellite, Terrain, Dark)
                  _GoogleMapTileLayer(
                    mapType: _mapType,
                    isDarkMode: _isDarkMode,
                    canvasWidth: _canvasWidth,
                    canvasHeight: _canvasHeight,
                    crossesPacific: route.crossesPacific,
                  ),

                  // Route Leader Stems & Connecting Arcs Overlay
                  CustomPaint(
                    size: const Size(_canvasWidth, _canvasHeight),
                    painter: _MapRoutePainter(
                      route: route,
                      isDarkMode: _isDarkMode,
                      projectCoord: (geo) => _projectToCanvas(geo, route.crossesPacific),
                    ),
                  ),

                  // Flight & Travel Moniker Badges (Interactive Pills)
                  for (final leg in route.legs) ...[
                    _buildLegMonikerBadge(leg, route),
                  ],

                  // City Nodes & Sequence Callout Cards
                  for (final city in route.cities) ...[
                    _buildCityNodeWidget(city, route),
                  ],
                ],
              ),
            ),
          ),

          // 2. Google Maps Attribution & Watermark Badge
          Positioned(
            bottom: 66,
            left: 16,
            child: _buildGoogleAttributionBadge(),
          ),

          // 3. Floating Map Tools (Map Mode Switcher, Zoom In/Out, Reset Fit, Dark Mode)
          Positioned(
            top: 16,
            right: 16,
            child: _buildFloatingControls(),
          ),

          // 4. Floating Hover / Inspection Details Card
          if (_hoveredCity != null || _selectedCity != null)
            Positioned(
              top: 16,
              left: 16,
              child: _buildCityDetailsCard(_selectedCity ?? _hoveredCity!),
            )
          else if (_hoveredLeg != null || _selectedLeg != null)
            Positioned(
              top: 16,
              left: 16,
              child: _buildLegDetailsCard(_selectedLeg ?? _hoveredLeg!),
            ),

          // 5. Bottom Chronological Timeline Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomTimelineBar(route),
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleAttributionBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _isDarkMode
            ? const Color(0xFF0F172A).withValues(alpha: 0.88)
            : Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _isDarkMode ? Colors.white12 : Colors.black12,
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Styled Google text moniker
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                fontFamily: 'sans-serif',
              ),
              children: [
                const TextSpan(text: 'G', style: TextStyle(color: Color(0xFF4285F4))),
                const TextSpan(text: 'o', style: TextStyle(color: Color(0xFFEA4335))),
                const TextSpan(text: 'o', style: TextStyle(color: Color(0xFFFBBC05))),
                const TextSpan(text: 'g', style: TextStyle(color: Color(0xFF4285F4))),
                const TextSpan(text: 'l', style: TextStyle(color: Color(0xFF34A853))),
                const TextSpan(text: 'e', style: TextStyle(color: Color(0xFFEA4335))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Map data ©2026',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: _isDarkMode ? Colors.white60 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingControls() {
    return Container(
      decoration: BoxDecoration(
        color: _isDarkMode
            ? const Color(0xFF1E293B).withValues(alpha: 0.94)
            : Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isDarkMode ? Colors.white.withValues(alpha: 0.12) : Colors.grey.shade300,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Map Type Switcher Buttons
          _buildMapTypeButton(GoogleMapType.dark, Icons.nightlight_round, 'Google Maps: Dark'),
          _buildMapTypeButton(GoogleMapType.roadmap, Icons.map_outlined, 'Google Maps: Roadmap'),
          _buildMapTypeButton(GoogleMapType.satellite, Icons.satellite_alt_rounded, 'Google Maps: Satellite'),
          _buildMapTypeButton(GoogleMapType.terrain, Icons.terrain_rounded, 'Google Maps: Terrain'),

          Divider(height: 1, color: _isDarkMode ? Colors.white12 : Colors.grey.shade200),

          // Zoom In
          IconButton(
            icon: Icon(Icons.add_rounded, size: 20, color: _isDarkMode ? Colors.white : Colors.black87),
            tooltip: 'Zoom In',
            onPressed: () => _zoom(1.25),
          ),
          Divider(height: 1, color: _isDarkMode ? Colors.white12 : Colors.grey.shade200),

          // Zoom Out
          IconButton(
            icon: Icon(Icons.remove_rounded, size: 20, color: _isDarkMode ? Colors.white : Colors.black87),
            tooltip: 'Zoom Out',
            onPressed: () => _zoom(0.8),
          ),
          Divider(height: 1, color: _isDarkMode ? Colors.white12 : Colors.grey.shade200),

          // Fit Route to Screen
          IconButton(
            icon: Icon(Icons.crop_free_rounded, size: 19, color: _isDarkMode ? Colors.white : Colors.black87),
            tooltip: 'Fit Route to Screen',
            onPressed: _fitMapToTrip,
          ),
          Divider(height: 1, color: _isDarkMode ? Colors.white12 : Colors.grey.shade200),

          // Dark/Light Theme Toggle
          IconButton(
            icon: Icon(
              _isDarkMode ? Icons.wb_sunny_outlined : Icons.nightlight_round,
              size: 19,
              color: _isDarkMode ? Colors.amber : Colors.blueGrey,
            ),
            tooltip: _isDarkMode ? 'Switch to Light Map' : 'Switch to Dark Map',
            onPressed: () {
              setState(() {
                _isDarkMode = !_isDarkMode;
                if (!_isDarkMode && _mapType == GoogleMapType.dark) {
                  _mapType = GoogleMapType.roadmap;
                } else if (_isDarkMode && _mapType == GoogleMapType.roadmap) {
                  _mapType = GoogleMapType.dark;
                }
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMapTypeButton(GoogleMapType type, IconData icon, String tooltip) {
    final isActive = _mapType == type;
    return IconButton(
      icon: Icon(
        icon,
        size: 18,
        color: isActive
            ? AppColors.primary
            : (_isDarkMode ? Colors.white70 : Colors.black54),
      ),
      tooltip: tooltip,
      onPressed: () {
        setState(() {
          _mapType = type;
          if (type == GoogleMapType.dark) {
            _isDarkMode = true;
          } else if (type == GoogleMapType.roadmap) {
            _isDarkMode = false;
          }
        });
      },
    );
  }

  Widget _buildCityNodeWidget(TripMapCityNode city, TripMapRoute route) {
    final basePt = _projectToCanvas(city.coordinates, route.crossesPacific);
    final pt = basePt + city.calloutOffset;
    final palette = CityColorHelper.getPaletteForCity(city.cityName);
    final isSelected = _selectedCity?.sequenceNumber == city.sequenceNumber;
    final isHovered = _hoveredCity?.sequenceNumber == city.sequenceNumber;

    final isCallout = city.totalVisitsToThisCity > 1;
    final cLower = city.cityName.toLowerCase();

    // Check label positioning for single-visit cities to avoid overlaps
    final isLabelTop = cLower == 'nikko' || cLower == 'ayutthaya';

    if (isCallout) {
      // Build Call Out Card for repeated visit sequence numbers
      return Positioned(
        left: pt.dx - 92,
        top: pt.dy - 35,
        child: SizedBox(
          width: 184,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hoveredCity = city),
            onExit: (_) => setState(() {
              if (_hoveredCity == city) _hoveredCity = null;
            }),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCity = (_selectedCity == city) ? null : city;
                  _selectedLeg = null;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _isDarkMode
                      ? const Color(0xFF0F172A).withValues(alpha: 0.94)
                      : Colors.white.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected || isHovered
                        ? palette.gradient.first
                        : (_isDarkMode ? Colors.white24 : Colors.black12),
                    width: isSelected || isHovered ? 2.0 : 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isSelected || isHovered
                              ? palette.gradient.first
                              : Colors.black)
                          .withValues(alpha: isSelected || isHovered ? 0.45 : 0.2),
                      blurRadius: isSelected || isHovered ? 12 : 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Sequence Badge Circle
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: palette.gradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: palette.gradient.first.withValues(alpha: 0.5),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          '${city.sequenceNumber}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  city.cityName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: _isDarkMode ? Colors.white : Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: palette.gradient.first.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '#${city.visitIndex + 1}',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: palette.gradient.first,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            city.totalNights > 0
                                ? '${city.totalNights} ${city.totalNights == 1 ? "Night" : "Nights"}'
                                : (city.isOriginOrReturn ? 'Origin Base' : 'Transit'),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: palette.gradient.first,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Single-visit city rendering with collision-free label placement
    return Positioned(
      left: pt.dx - 80,
      top: isLabelTop ? pt.dy - 65 : pt.dy - 35,
      child: SizedBox(
        width: 160,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (isLabelTop) ...[
              _buildCityLabelPill(city, palette, isSelected),
              const SizedBox(height: 4),
              _buildSequenceBadgeCircle(city, palette, isSelected, isHovered),
            ] else ...[
              _buildSequenceBadgeCircle(city, palette, isSelected, isHovered),
              const SizedBox(height: 4),
              _buildCityLabelPill(city, palette, isSelected),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSequenceBadgeCircle(
    TripMapCityNode city,
    StayGradientPalette palette,
    bool isSelected,
    bool isHovered,
  ) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hoveredCity = city),
      onExit: (_) => setState(() {
        if (_hoveredCity == city) _hoveredCity = null;
      }),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedCity = (_selectedCity == city) ? null : city;
            _selectedLeg = null;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: (isSelected || isHovered) ? 38 : 32,
          height: (isSelected || isHovered) ? 38 : 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: palette.gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: Colors.white,
              width: (isSelected || isHovered) ? 2.5 : 2.0,
            ),
            boxShadow: [
              BoxShadow(
                color: palette.gradient.first.withValues(alpha: 0.5),
                blurRadius: (isSelected || isHovered) ? 14 : 8,
                spreadRadius: (isSelected || isHovered) ? 3 : 1,
              ),
            ],
          ),
          child: Center(
            child: Text(
              '${city.sequenceNumber}',
              style: TextStyle(
                color: Colors.white,
                fontSize: (isSelected || isHovered) ? 14 : 12,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCityLabelPill(
    TripMapCityNode city,
    StayGradientPalette palette,
    bool isSelected,
  ) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hoveredCity = city),
      onExit: (_) => setState(() {
        if (_hoveredCity == city) _hoveredCity = null;
      }),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedCity = (_selectedCity == city) ? null : city;
            _selectedLeg = null;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
          decoration: BoxDecoration(
            color: _isDarkMode
                ? const Color(0xFF0F172A).withValues(alpha: 0.92)
                : Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected
                  ? palette.gradient.first
                  : (_isDarkMode ? Colors.white24 : Colors.black12),
              width: isSelected ? 1.5 : 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                city.cityName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _isDarkMode ? Colors.white : Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (city.totalNights > 0)
                Text(
                  '${city.totalNights} ${city.totalNights == 1 ? "Night" : "Nights"}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: palette.gradient.first,
                  ),
                )
              else if (city.isOriginOrReturn)
                const Text(
                  'Origin Base',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegMonikerBadge(TripMapConnectionLeg leg, TripMapRoute route) {
    final pFrom = _projectToCanvas(leg.fromCity.coordinates, route.crossesPacific) +
        leg.fromCity.calloutOffset;
    final pTo = _projectToCanvas(leg.toCity.coordinates, route.crossesPacific) +
        leg.toCity.calloutOffset;

    final dx = pTo.dx - pFrom.dx;
    final dy = pTo.dy - pFrom.dy;
    final dist = math.sqrt(dx * dx + dy * dy);

    final nx = -dy / (dist > 0 ? dist : 1);
    final ny = dx / (dist > 0 ? dist : 1);

    // Reciprocal legs (e.g. Return from Nikko to Tokyo, or Ayutthaya to Bangkok) bow in the opposite direction
    final isReciprocal = route.legs.any((other) =>
        other.sequenceIndex < leg.sequenceIndex &&
        ((other.fromCity.cityName.toLowerCase() == leg.toCity.cityName.toLowerCase() &&
          other.toCity.cityName.toLowerCase() == leg.fromCity.cityName.toLowerCase()) ||
         (other.fromCity.cityName.toLowerCase() == leg.fromCity.cityName.toLowerCase() &&
          other.toCity.cityName.toLowerCase() == leg.toCity.cityName.toLowerCase())));

    final normalSign = isReciprocal ? -1.0 : 1.0;
    final baseDepth = math.min(dist * 0.22, 120.0);
    final curveDepth = math.max(baseDepth, 38.0) * normalSign;

    final midX = (pFrom.dx + pTo.dx) / 2;
    final midY = (pFrom.dy + pTo.dy) / 2;
    final ctrlX = midX + nx * curveDepth;
    final ctrlY = midY + ny * curveDepth;

    // Midpoint along the curve at t = 0.5: 0.25*P0 + 0.5*Pctrl + 0.25*P1
    final apexX = 0.25 * pFrom.dx + 0.5 * ctrlX + 0.25 * pTo.dx;
    final apexY = 0.25 * pFrom.dy + 0.5 * ctrlY + 0.25 * pTo.dy;

    final isSelected = _selectedLeg?.sequenceIndex == leg.sequenceIndex;
    final isHovered = _hoveredLeg?.sequenceIndex == leg.sequenceIndex;

    return Positioned(
      left: apexX - 45,
      top: apexY - 12,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hoveredLeg = leg),
        onExit: (_) => setState(() {
          if (_hoveredLeg == leg) _hoveredLeg = null;
        }),
        child: GestureDetector(
          onTap: () {
            setState(() {
              _selectedLeg = (_selectedLeg == leg) ? null : leg;
              _selectedCity = null;
            });
            if (leg.flight != null) {
              _openFlightModal(leg.flight!);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isSelected || isHovered
                  ? AppColors.flight
                  : (_isDarkMode
                      ? const Color(0xFF1E293B).withValues(alpha: 0.95)
                      : Colors.white.withValues(alpha: 0.95)),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected || isHovered
                    ? Colors.white
                    : (leg.isFlight ? AppColors.flight : Colors.amber.shade700),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: (leg.isFlight ? AppColors.flight : Colors.amber)
                      .withValues(alpha: 0.35),
                  blurRadius: isSelected || isHovered ? 8 : 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  leg.isFlight ? Icons.flight_rounded : Icons.directions_bus_rounded,
                  size: 11,
                  color: isSelected || isHovered
                      ? Colors.white
                      : (leg.isFlight ? AppColors.flight : Colors.amber.shade800),
                ),
                const SizedBox(width: 4),
                Text(
                  leg.moniker,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                    color: isSelected || isHovered
                        ? Colors.white
                        : (_isDarkMode ? Colors.white : Colors.black87),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCityDetailsCard(TripMapCityNode city) {
    final palette = CityColorHelper.getPaletteForCity(city.cityName);

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 320,
        decoration: BoxDecoration(
          color: _isDarkMode
              ? const Color(0xFF1E293B).withValues(alpha: 0.96)
              : Colors.white.withValues(alpha: 0.98),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: palette.gradient.first.withValues(alpha: 0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: palette.gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${city.sequenceNumber}',
                        style: TextStyle(
                          color: palette.gradient.first,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          city.cityName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          city.totalNights > 0
                              ? 'Stop #${city.sequenceNumber}  •  ${city.totalNights} Nights'
                              : 'Stop #${city.sequenceNumber}  •  Origin / Transit',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18, color: Colors.white),
                    onPressed: () => setState(() {
                      _selectedCity = null;
                      _hoveredCity = null;
                    }),
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (city.stays.isEmpty) ...[
                    Row(
                      children: [
                        Icon(Icons.hotel_outlined,
                            size: 16,
                            color: _isDarkMode ? Colors.white60 : Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          city.isOriginOrReturn
                              ? 'Origin / Departure City'
                              : 'No hotel stay recorded for this city',
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: _isDarkMode ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Icon(Icons.hotel_rounded, size: 14, color: palette.gradient.first),
                        const SizedBox(width: 6),
                        Text(
                          'HOTELS & STAYS (${city.stays.length})',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: palette.gradient.first,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (final stay in city.stays) ...[
                      InkWell(
                        onTap: () => _openStayModal(stay),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _isDarkMode
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _isDarkMode ? Colors.white12 : Colors.grey.shade200,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      stay.name,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: _isDarkMode ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${stay.nights}N',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: palette.gradient.first,
                                    ),
                                  ),
                                ],
                              ),
                              if (stay.address != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  stay.address!,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: _isDarkMode ? Colors.white60 : Colors.black54,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              const SizedBox(height: 4),
                              Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                runSpacing: 2,
                                children: [
                                  Text(
                                    '${DateFormatters.shortDate.format(stay.checkInDate)} → ${DateFormatters.shortDate.format(stay.checkOutDate)}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: _isDarkMode ? Colors.white70 : Colors.black87,
                                    ),
                                  ),
                                  if (stay.confirmationCode != null &&
                                      stay.confirmationCode!.isNotEmpty)
                                    Text(
                                      '#${stay.confirmationCode}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'monospace',
                                        color: AppColors.primary,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                  if (city.activities.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.local_activity_rounded,
                            size: 13, color: AppColors.attraction),
                        const SizedBox(width: 6),
                        Text(
                          '${city.activities.length} Activities Scheduled',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.attraction,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegDetailsCard(TripMapConnectionLeg leg) {
    final flight = leg.flight;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 330,
        decoration: BoxDecoration(
          color: _isDarkMode
              ? const Color(0xFF1E293B).withValues(alpha: 0.96)
              : Colors.white.withValues(alpha: 0.98),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.flight.withValues(alpha: 0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.flight_takeoff_rounded,
                      size: 16,
                      color: AppColors.flight,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          flight != null
                              ? '${flight.airline}  ${flight.flightNumber}'
                              : leg.moniker,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${leg.fromCity.cityName} ➔ ${leg.toCity.cityName}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18, color: Colors.white),
                    onPressed: () => setState(() {
                      _selectedLeg = null;
                      _hoveredLeg = null;
                    }),
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (flight != null) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('DEPARTURE',
                                  style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textSecondary)),
                              Text(flight.departureAirport,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: _isDarkMode ? Colors.white : Colors.black87)),
                              Text(
                                  DateFormatters.shortDate.format(flight.departureTime),
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: _isDarkMode ? Colors.white70 : Colors.black54)),
                              Text(
                                  DateFormatters.time12.format(flight.departureTime),
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary)),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_rounded,
                            size: 16, color: AppColors.flight),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('ARRIVAL',
                                  style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textSecondary)),
                              Text(flight.arrivalAirport,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: _isDarkMode ? Colors.white : Colors.black87)),
                              Text(
                                  DateFormatters.shortDate.format(flight.arrivalTime),
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: _isDarkMode ? Colors.white70 : Colors.black54)),
                              Text(
                                  DateFormatters.time12.format(flight.arrivalTime),
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Divider(color: _isDarkMode ? Colors.white12 : Colors.grey.shade200),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (flight.seat != null && flight.seat!.isNotEmpty)
                          _buildDetailPill('Seat', flight.seat!),
                        if (flight.terminal != null && flight.terminal!.isNotEmpty)
                          _buildDetailPill('Term', flight.terminal!),
                        if (flight.gate != null && flight.gate!.isNotEmpty)
                          _buildDetailPill('Gate', flight.gate!),
                        if (flight.bookingRef != null && flight.bookingRef!.isNotEmpty)
                          _buildDetailPill('Ref', flight.bookingRef!),
                      ],
                    ),
                    if (flight.notes != null && flight.notes!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        flight.notes!,
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: _isDarkMode ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ] else ...[
                    Text(
                      'Ground transportation connecting ${leg.fromCity.cityName} and ${leg.toCity.cityName}.',
                      style: TextStyle(
                        fontSize: 12,
                        color: _isDarkMode ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailPill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: _isDarkMode ? Colors.white10 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: _isDarkMode ? Colors.white70 : Colors.black87,
        ),
      ),
    );
  }

  Widget _buildBottomTimelineBar(TripMapRoute route) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _isDarkMode
            ? const Color(0xFF0F172A).withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.96),
        border: Border(
          top: BorderSide(
            color: _isDarkMode ? Colors.white12 : Colors.grey.shade300,
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: route.cities.length,
        itemBuilder: (context, idx) {
          final city = route.cities[idx];
          final palette = CityColorHelper.getPaletteForCity(city.cityName);
          final isSelected = _selectedCity?.sequenceNumber == city.sequenceNumber;

          return Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => _centerOnCity(city, route),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? palette.gradient.first
                          : (_isDarkMode ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade100),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? Colors.white
                            : palette.gradient.first.withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : palette.gradient.first,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${city.sequenceNumber}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: isSelected ? palette.gradient.first : Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          city.cityName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? Colors.white
                                : (_isDarkMode ? Colors.white : Colors.black87),
                          ),
                        ),
                        if (city.totalNights > 0) ...[
                          const SizedBox(width: 4),
                          Text(
                            '(${city.totalNights}N)',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? Colors.white.withValues(alpha: 0.9)
                                  : palette.gradient.first,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (idx < route.cities.length - 1) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: _isDarkMode ? Colors.white30 : Colors.grey.shade400,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Interactive Google Maps tile layer fetching Mercator raster tiles from Google Maps
class _GoogleMapTileLayer extends StatelessWidget {
  final GoogleMapType mapType;
  final bool isDarkMode;
  final double canvasWidth;
  final double canvasHeight;
  final bool crossesPacific;

  const _GoogleMapTileLayer({
    required this.mapType,
    required this.isDarkMode,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.crossesPacific,
  });

  @override
  Widget build(BuildContext context) {
    const int zoom = 4;
    const double worldTiles = 16.0;
    const double worldPixels = 4096.0;

    final minL = crossesPacific ? 70.0 : -130.0;
    final maxL = crossesPacific ? 260.0 : 160.0;
    const minLa = -12.0;
    const maxLa = 62.0;

    double latToMercatorY(double deg) {
      final rad = (deg.clamp(-80.0, 80.0)) * math.pi / 180.0;
      return math.log(math.tan(math.pi / 4.0 + rad / 2.0));
    }

    final xMinWorld = ((minL + 180.0) / 360.0) * worldPixels;
    final xMaxWorld = ((maxL + 180.0) / 360.0) * worldPixels;
    final deltaXWorld = xMaxWorld - xMinWorld;

    final yMaxMerc = latToMercatorY(maxLa);
    final yMinMerc = latToMercatorY(minLa);

    final yMinWorld = (0.5 - (yMaxMerc / (2 * math.pi))) * worldPixels;
    final yMaxWorld = (0.5 - (yMinMerc / (2 * math.pi))) * worldPixels;
    final deltaYWorld = yMaxWorld - yMinWorld;

    final scaleX = canvasWidth / deltaXWorld;
    final scaleY = canvasHeight / deltaYWorld;

    final tileXStart = (xMinWorld / 256.0).floor();
    final tileXEnd = (xMaxWorld / 256.0).ceil();
    final tileYStart = (yMinWorld / 256.0).floor();
    final tileYEnd = (yMaxWorld / 256.0).ceil();

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

    for (int ty = tileYStart; ty < tileYEnd; ty++) {
      if (ty < 0 || ty >= worldTiles) continue;
      for (int tx = tileXStart; tx < tileXEnd; tx++) {
        final wrappedX = (tx % worldTiles.toInt() + worldTiles.toInt()) % worldTiles.toInt();
        final url = 'https://mt1.google.com/vt/lyrs=$lyrs&x=$wrappedX&y=$ty&z=$zoom';

        final left = (tx * 256.0 - xMinWorld) * scaleX;
        final top = (ty * 256.0 - yMinWorld) * scaleY;
        final width = 256.0 * scaleX + 0.5;
        final height = 256.0 * scaleY + 0.5;

        Widget img = Image.network(
          url,
          width: width,
          height: height,
          fit: BoxFit.fill,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) => const SizedBox(),
        );

        if (isDark) {
          img = ColorFiltered(
            colorFilter: darkFilter,
            child: img,
          );
        }

        tileWidgets.add(
          Positioned(
            left: left,
            top: top,
            width: width,
            height: height,
            child: img,
          ),
        );
      }
    }

    return SizedBox(
      width: canvasWidth,
      height: canvasHeight,
      child: Stack(
        children: tileWidgets,
      ),
    );
  }
}

/// Base vector canvas painter providing ocean graticules and continent silhouettes
class _MapCanvasPainter extends CustomPainter {
  final TripMapRoute route;
  final bool isDarkMode;
  final Color bgGridColor;
  final Color continentColor;
  final Offset Function(GeoPoint) projectCoord;

  _MapCanvasPainter({
    required this.route,
    required this.isDarkMode,
    required this.bgGridColor,
    required this.continentColor,
    required this.projectCoord,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawGraticules(canvas, size);
    _drawStylizedContinents(canvas, size);
  }

  void _drawGraticules(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = bgGridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (double lat = -10; lat <= 60; lat += 15) {
      final p1 = projectCoord(GeoPoint(lat, route.crossesPacific ? 70 : -130));
      final p2 = projectCoord(GeoPoint(lat, route.crossesPacific ? 260 : 160));
      canvas.drawLine(Offset(0, p1.dy), Offset(size.width, p2.dy), gridPaint);
    }

    final startLng = route.crossesPacific ? 80.0 : -120.0;
    final endLng = route.crossesPacific ? 250.0 : 150.0;
    for (double lng = startLng; lng <= endLng; lng += 20) {
      final p = projectCoord(GeoPoint(20, lng));
      canvas.drawLine(Offset(p.dx, 0), Offset(p.dx, size.height), gridPaint);
    }
  }

  void _drawStylizedContinents(Canvas canvas, Size size) {
    final continentPaint = Paint()
      ..color = continentColor
      ..style = PaintingStyle.fill;

    final outlinePaint = Paint()
      ..color = isDarkMode ? Colors.white.withValues(alpha: 0.15) : Colors.black12
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final List<List<GeoPoint>> continentPolygons = [
      // Mainland East & Southeast Asia
      [
        const GeoPoint(45, 115),
        const GeoPoint(40, 120),
        const GeoPoint(35, 120),
        const GeoPoint(30, 122),
        const GeoPoint(22, 114),
        const GeoPoint(21, 107), // Ha Long
        const GeoPoint(16, 108), // Da Nang
        const GeoPoint(11, 109),
        const GeoPoint(8, 105), // S. Vietnam
        const GeoPoint(10, 100), // Gulf of Thailand
        const GeoPoint(1, 104),  // Singapore
        const GeoPoint(3, 101),  // Malaysia
        const GeoPoint(8, 98),   // Phuket
        const GeoPoint(14, 100), // Bangkok
        const GeoPoint(13, 103), // Cambodia
        const GeoPoint(21, 105), // Hanoi
        const GeoPoint(25, 100),
        const GeoPoint(35, 105),
        const GeoPoint(45, 110),
      ],
      // Korean Peninsula
      [
        const GeoPoint(40, 124),
        const GeoPoint(38, 128),
        const GeoPoint(35, 129),
        const GeoPoint(34, 126),
        const GeoPoint(37, 125),
      ],
      // Japan Archipelago
      [
        const GeoPoint(44, 142),
        const GeoPoint(41, 141),
        const GeoPoint(36, 140),
        const GeoPoint(35, 137),
        const GeoPoint(34, 132),
        const GeoPoint(31, 131),
        const GeoPoint(33, 130),
        const GeoPoint(36, 136),
        const GeoPoint(38, 139),
      ],
      // North America West Coast (Seattle to California)
      [
        const GeoPoint(60, -145),
        const GeoPoint(54, -130),
        const GeoPoint(48, -123), // Seattle / Vancouver
        const GeoPoint(42, -124),
        const GeoPoint(37, -122), // SFO
        const GeoPoint(33, -118), // LAX
        const GeoPoint(25, -110),
        const GeoPoint(30, -100),
        const GeoPoint(45, -100),
        const GeoPoint(60, -110),
      ],
    ];

    for (final poly in continentPolygons) {
      final path = Path();
      for (int i = 0; i < poly.length; i++) {
        final pt = projectCoord(poly[i]);
        if (i == 0) {
          path.moveTo(pt.dx, pt.dy);
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
      }
      path.close();
      canvas.drawPath(path, continentPaint);
      canvas.drawPath(path, outlinePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MapCanvasPainter oldDelegate) {
    return oldDelegate.isDarkMode != isDarkMode ||
        oldDelegate.route != route;
  }
}

/// Route painter drawing leader stems from city anchors to call out cards,
/// and curved connecting arcs for flights and ground travel.
class _MapRoutePainter extends CustomPainter {
  final TripMapRoute route;
  final bool isDarkMode;
  final Offset Function(GeoPoint) projectCoord;

  _MapRoutePainter({
    required this.route,
    required this.isDarkMode,
    required this.projectCoord,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawCityAnchorsAndLeaderLines(canvas);
    _drawConnectingLegs(canvas);
  }

  void _drawCityAnchorsAndLeaderLines(Canvas canvas) {
    final multiVisitCities = <String, GeoPoint>{};
    for (final city in route.cities) {
      if (city.totalVisitsToThisCity > 1) {
        multiVisitCities[city.cityName.toLowerCase()] = city.coordinates;
      }
    }

    // 1. Draw central geographic anchor beacons for multi-visit cities
    for (final entry in multiVisitCities.entries) {
      final anchor = projectCoord(entry.value);
      final palette = CityColorHelper.getPaletteForCity(entry.key);

      // Glowing outer halo
      final haloPaint = Paint()
        ..color = palette.gradient.first.withValues(alpha: isDarkMode ? 0.35 : 0.25)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(anchor, 14.0, haloPaint);

      final ringPaint = Paint()
        ..color = palette.gradient.first.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8;
      canvas.drawCircle(anchor, 8.0, ringPaint);

      // Solid central pinpoint
      final corePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(anchor, 4.0, corePaint);

      final dotPaint = Paint()
        ..color = palette.gradient.first
        ..style = PaintingStyle.fill;
      canvas.drawCircle(anchor, 2.0, dotPaint);

      // Geographic Anchor Label
      final textPainter = TextPainter(
        text: TextSpan(
          text: entry.key.toUpperCase(),
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            color: isDarkMode ? Colors.white.withValues(alpha: 0.9) : Colors.black87,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final textOffset = Offset(anchor.dx - textPainter.width / 2, anchor.dy - 24);
      final bgRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(textOffset.dx - 5, textOffset.dy - 2, textPainter.width + 10, textPainter.height + 4),
        const Radius.circular(5),
      );
      canvas.drawRRect(
        bgRect,
        Paint()..color = (isDarkMode ? const Color(0xFF0F172A) : Colors.white).withValues(alpha: 0.9),
      );
      canvas.drawRRect(
        bgRect,
        Paint()
          ..color = palette.gradient.first.withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
      textPainter.paint(canvas, textOffset);
    }

    // 2. Draw leader lines (stems) connecting anchor to each call out position
    for (final city in route.cities) {
      if (city.totalVisitsToThisCity > 1 && city.calloutOffset != Offset.zero) {
        final anchor = projectCoord(city.coordinates);
        final calloutTarget = anchor + city.calloutOffset;
        final palette = CityColorHelper.getPaletteForCity(city.cityName);

        final stemPaint = Paint()
          ..color = palette.gradient.first.withValues(alpha: isDarkMode ? 0.75 : 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round;

        _drawDashedLine(canvas, anchor, calloutTarget, stemPaint, dashLength: 6.0, gapLength: 4.0);

        // Anchor termination dot
        canvas.drawCircle(
          anchor,
          3.0,
          Paint()..color = palette.gradient.first,
        );
      }
    }
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint,
      {double dashLength = 6.0, double gapLength = 4.0}) {
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final dist = math.sqrt(dx * dx + dy * dy);
    if (dist == 0) return;

    final dirX = dx / dist;
    final dirY = dy / dist;

    double current = 0.0;
    while (current < dist) {
      final start = Offset(p1.dx + dirX * current, p1.dy + dirY * current);
      final endDist = math.min(current + dashLength, dist);
      final end = Offset(p1.dx + dirX * endDist, p1.dy + dirY * endDist);
      canvas.drawLine(start, end, paint);
      current += dashLength + gapLength;
    }
  }

  void _drawConnectingLegs(Canvas canvas) {
    for (final leg in route.legs) {
      final p1 = projectCoord(leg.fromCity.coordinates) + leg.fromCity.calloutOffset;
      final p2 = projectCoord(leg.toCity.coordinates) + leg.toCity.calloutOffset;

      final dx = p2.dx - p1.dx;
      final dy = p2.dy - p1.dy;
      final dist = math.sqrt(dx * dx + dy * dy);

      final nx = -dy / (dist > 0 ? dist : 1);
      final ny = dx / (dist > 0 ? dist : 1);

      // Reciprocal legs bow in opposite directions to prevent line overlapping
      final isReciprocal = route.legs.any((other) =>
          other.sequenceIndex < leg.sequenceIndex &&
          ((other.fromCity.cityName.toLowerCase() == leg.toCity.cityName.toLowerCase() &&
            other.toCity.cityName.toLowerCase() == leg.fromCity.cityName.toLowerCase()) ||
           (other.fromCity.cityName.toLowerCase() == leg.fromCity.cityName.toLowerCase() &&
            other.toCity.cityName.toLowerCase() == leg.toCity.cityName.toLowerCase())));

      final normalSign = isReciprocal ? -1.0 : 1.0;
      final baseDepth = math.min(dist * 0.22, 120.0);
      final curveDepth = math.max(baseDepth, 38.0) * normalSign;

      final midX = (p1.dx + p2.dx) / 2;
      final midY = (p1.dy + p2.dy) / 2;
      final ctrlX = midX + nx * curveDepth;
      final ctrlY = midY + ny * curveDepth;

      final path = Path()
        ..moveTo(p1.dx, p1.dy)
        ..quadraticBezierTo(ctrlX, ctrlY, p2.dx, p2.dy);

      if (leg.isFlight) {
        // Flight Glow
        final glowPaint = Paint()
          ..color = AppColors.flight.withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6.0;
        canvas.drawPath(path, glowPaint);

        // Flight Core Arc
        final arcPaint = Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFF0284C7), Color(0xFF38BDF8), Color(0xFF0284C7)],
          ).createShader(Rect.fromPoints(p1, p2))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4;
        canvas.drawPath(path, arcPaint);
      } else {
        // Ground Travel
        final groundPaint = Paint()
          ..color = Colors.amber.shade700
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2;
        canvas.drawPath(path, groundPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MapRoutePainter oldDelegate) {
    return oldDelegate.isDarkMode != isDarkMode || oldDelegate.route != route;
  }
}

