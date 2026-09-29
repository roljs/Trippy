import 'package:flutter/material.dart';

enum TripEndcapType {
  start,
  finish;

  bool get isStart => this == TripEndcapType.start;
}

class TripEndcapStayBridgeWidget extends StatelessWidget {
  final TripEndcapType type;
  final String? locationName;
  final double width;
  final VoidCallback? onTap;

  const TripEndcapStayBridgeWidget({
    super.key,
    required this.type,
    required this.locationName,
    this.width = 145.0,
    this.onTap,
  });

  // Distinctive slate/gray gradient shared between start and finish endcaps
  static const List<Color> _grayGradient = [
    Color(0xFF64748B), // Slate 500
    Color(0xFF475569), // Slate 600
  ];
  static const Color _shadowColor = Color(0xFF334155);

  @override
  Widget build(BuildContext context) {
    final isStart = type.isStart;
    final fallbackText = isStart ? 'Starting Location' : 'Finishing Location';
    final effectiveLocation =
        (locationName != null && locationName!.trim().isNotEmpty)
            ? locationName!.trim()
            : fallbackText;

    return SizedBox(
      width: width,
      height: 90,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top Label Indicator
          SizedBox(
            width: width,
            height: 18,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 1.5),
                decoration: BoxDecoration(
                  color: _grayGradient.first.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.45),
                    width: 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Text(
                  isStart ? 'START' : 'FINISH',
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),

          // 2. Main Gray Rectangle
          SizedBox(
            width: width,
            height: 70,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: _grayGradient,
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: _shadowColor.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Icon Badge
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isStart
                            ? Icons.flight_takeoff_rounded
                            : Icons.flag_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Details
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            effectiveLocation,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  isStart ? 'Origin' : 'Return',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(
                                Icons.edit_rounded,
                                size: 10,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
