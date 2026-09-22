import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatters.dart';

class ManageDayLocationsDialog extends StatefulWidget {
  final int dayNumber;
  final DateTime date;
  final List<String> currentLocations;
  final String defaultCountry;
  final ValueChanged<List<String>> onSave;

  const ManageDayLocationsDialog({
    super.key,
    required this.dayNumber,
    required this.date,
    required this.currentLocations,
    required this.defaultCountry,
    required this.onSave,
  });

  @override
  State<ManageDayLocationsDialog> createState() =>
      _ManageDayLocationsDialogState();
}

class _ManageDayLocationsDialogState extends State<ManageDayLocationsDialog> {
  late List<String> _locations;
  final _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _locations = List<String>.from(widget.currentLocations);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _addLocation() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    if (!_locations.any((l) => l.toLowerCase() == text.toLowerCase())) {
      setState(() {
        _locations.add(text);
        _textController.clear();
      });
    }
  }

  void _removeLocation(int index) {
    setState(() {
      _locations.removeAt(index);
    });
  }

  void _resetToDefault() {
    setState(() {
      _locations = [widget.defaultCountry];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(22.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.place_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Day ${widget.dayNumber} Locations',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            DateFormatters.dayHeader.format(widget.date),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Default Inferred Location Note
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.flight_land_rounded,
                        size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Default Country: ${widget.defaultCountry}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: _resetToDefault,
                      child: const Text('Use Default',
                          style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Active Location Chips
              const Text(
                'Locations for this day:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              if (_locations.isEmpty)
                Text(
                  'No locations specified. Default (${widget.defaultCountry}) will be used.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontStyle: FontStyle.italic,
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(_locations.length, (index) {
                    final loc = _locations[index];
                    return Chip(
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      avatar: const Icon(Icons.location_on_outlined, size: 14),
                      label: Text(loc, style: const TextStyle(fontSize: 12)),
                      deleteIcon: const Icon(Icons.cancel, size: 16),
                      onDeleted: () => _removeLocation(index),
                      backgroundColor: AppColors.primaryContainer.withValues(alpha: 0.5),
                    );
                  }),
                ),
              const SizedBox(height: 16),

              // Add Location Input
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      onSubmitted: (_) => _addLocation(),
                      decoration: const InputDecoration(
                        hintText: 'e.g. Tokyo, Roppongi, Kyoto...',
                        hintStyle: TextStyle(fontSize: 13),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _addLocation,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),

              // Footer Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      widget.onSave(_locations);
                      Navigator.pop(context);
                    },
                    child: const Text('Save Locations'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
