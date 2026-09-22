import '../../models/models.dart';

/// Data Transfer Object representing parsed elements from an import source
class ParsedItineraryDraft {
  final List<Stay> stays;
  final List<Activity> activities;
  final List<Flight> flights;
  final String? rawSourceSummary;

  const ParsedItineraryDraft({
    this.stays = const [],
    this.activities = const [],
    this.flights = const [],
    this.rawSourceSummary,
  });

  bool get isEmpty => stays.isEmpty && activities.isEmpty && flights.isEmpty;
  int get totalItemCount => stays.length + activities.length + flights.length;
}

/// Abstract contract for extracting structured trip items from documents, emails, or text
abstract class ItineraryExtractor {
  Future<ParsedItineraryDraft> extractFromText(String rawText, {required String tripId});
  Future<ParsedItineraryDraft> extractFromDocument({
    required List<int> bytes,
    required String mimeType,
    required String tripId,
  });
}

/// Manual Form Extractor implementation
class ManualFormExtractor implements ItineraryExtractor {
  @override
  Future<ParsedItineraryDraft> extractFromText(String rawText, {required String tripId}) async {
    // Basic text parsing or pass-through
    return ParsedItineraryDraft(rawSourceSummary: 'Manual input: $rawText');
  }

  @override
  Future<ParsedItineraryDraft> extractFromDocument({
    required List<int> bytes,
    required String mimeType,
    required String tripId,
  }) async {
    // Ready for integration with Gemini API / multimodal vision
    return const ParsedItineraryDraft(rawSourceSummary: 'Document parser pending');
  }
}
