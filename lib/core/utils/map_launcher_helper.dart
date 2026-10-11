import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Helper to launch native map apps on phones or Google Maps in the browser on desktop/web.
class MapLauncherHelper {
  /// Resolves the appropriate map Uri according to platform and web environment.
  static Uri getMapUriForAddress(
    String address, {
    TargetPlatform? platform,
    bool isWeb = kIsWeb,
  }) {
    final encoded = Uri.encodeComponent(address.trim());
    final target = platform ?? defaultTargetPlatform;
    if (!isWeb && target == TargetPlatform.android) {
      return Uri.parse('geo:0,0?q=$encoded');
    } else if (!isWeb && target == TargetPlatform.iOS) {
      return Uri.parse('https://maps.apple.com/?q=$encoded');
    }
    return Uri.parse('https://www.google.com/maps/search/?api=1&query=$encoded');
  }

  /// Opens the address in the default map app or web browser.
  static Future<bool> openAddress(String? address) async {
    if (address == null) return false;
    final query = address.trim();
    if (query.isEmpty) return false;

    final primaryUri = getMapUriForAddress(query);
    try {
      if (await canLaunchUrl(primaryUri)) {
        return await launchUrl(primaryUri, mode: LaunchMode.externalApplication);
      }
      final fallbackUri = getMapUriForAddress(query, platform: TargetPlatform.linux);
      return await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      final fallbackUri = getMapUriForAddress(query, platform: TargetPlatform.linux);
      return await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
    }
  }

  /// Resolves directions Uri between origin and destination.
  static Uri getDirectionsUri({
    required String origin,
    required String destination,
    TargetPlatform? platform,
    bool isWeb = kIsWeb,
  }) {
    final encOrigin = Uri.encodeComponent(origin.trim());
    final encDest = Uri.encodeComponent(destination.trim());
    final target = platform ?? defaultTargetPlatform;
    if (!isWeb && target == TargetPlatform.iOS) {
      return Uri.parse('https://maps.apple.com/?saddr=$encOrigin&daddr=$encDest');
    }
    return Uri.parse('https://www.google.com/maps/dir/?api=1&origin=$encOrigin&destination=$encDest');
  }

  /// Opens directions between origin and destination in native Maps or browser.
  static Future<bool> openDirections({
    required String? origin,
    required String? destination,
  }) async {
    if (origin == null || destination == null) return false;
    final orig = origin.trim();
    final dest = destination.trim();
    if (orig.isEmpty || dest.isEmpty) return false;

    final primaryUri = getDirectionsUri(origin: orig, destination: dest);
    try {
      if (await canLaunchUrl(primaryUri)) {
        return await launchUrl(primaryUri, mode: LaunchMode.externalApplication);
      }
      final fallbackUri = getDirectionsUri(
        origin: orig,
        destination: dest,
        platform: TargetPlatform.linux,
      );
      return await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      final fallbackUri = getDirectionsUri(
        origin: orig,
        destination: dest,
        platform: TargetPlatform.linux,
      );
      return await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
    }
  }
}
