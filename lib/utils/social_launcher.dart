import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class SocialLauncher {
  /// Extract a clean username / handle from input (handles @username, full URLs, query params, etc.)
  static String extractUsername(String input) {
    String text = input.trim();
    if (text.isEmpty) return '';

    // Strip query parameters and hash fragments
    text = text.split('?').first.split('#').first.trim();

    // If it contains a slash, parse path segments
    if (text.contains('/')) {
      if (!text.startsWith('http://') && !text.startsWith('https://')) {
        text = 'https://$text';
      }
      try {
        final uri = Uri.parse(text);
        final segments = uri.pathSegments
            .where((s) => s.isNotEmpty && s != 'add' && s != '_u' && s != 'p')
            .toList();
        if (segments.isNotEmpty) {
          text = segments.last;
        }
      } catch (_) {}
    }

    if (text.startsWith('@')) {
      text = text.substring(1);
    }
    return text.replaceAll('/', '').trim();
  }

  /// Build the correct web URL for any social platform
  static String buildUrl(String platform, String rawValue) {
    final trimmed = rawValue.trim();
    if (trimmed.isEmpty) return '';

    switch (platform.toLowerCase()) {
      case 'instagram':
        final handle = extractUsername(trimmed);
        return handle.isNotEmpty ? 'https://www.instagram.com/$handle/' : '';

      case 'snapchat':
        final handle = extractUsername(trimmed);
        return handle.isNotEmpty ? 'https://www.snapchat.com/add/$handle' : '';

      case 'facebook':
        if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
          return trimmed;
        }
        if (trimmed.contains('facebook.com/')) {
          return 'https://$trimmed';
        }
        final handle = extractUsername(trimmed);
        return handle.isNotEmpty ? 'https://www.facebook.com/$handle' : '';

      case 'whatsapp':
        if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
          return trimmed;
        }
        final clean = trimmed.replaceAll(RegExp(r'[^\d+]'), '');
        return clean.isNotEmpty ? 'https://wa.me/$clean' : '';

      default:
        return trimmed.startsWith('http') ? trimmed : 'https://$trimmed';
    }
  }

  /// Launch social media across Web, iOS, and Android seamlessly
  static Future<bool> open(String platform, String rawValue) async {
    final url = buildUrl(platform, rawValue);
    if (url.isEmpty) return false;

    final uri = Uri.tryParse(url);
    if (uri == null) return false;

    try {
      if (kIsWeb) {
        // On Web, opening directly with _blank prevents popup blocker issues
        return await launchUrl(
          uri,
          mode: LaunchMode.platformDefault,
          webOnlyWindowName: '_blank',
        );
      } else {
        // On mobile, externalApplication allows iOS Universal Links and Android App Links
        // to directly open native Instagram/Snapchat/WhatsApp app if installed,
        // or fallback to system browser if not.
        final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!launched) {
          return await launchUrl(uri, mode: LaunchMode.platformDefault);
        }
        return launched;
      }
    } catch (e) {
      debugPrint('Error launching $platform URL ($url): $e');
      try {
        return await launchUrl(uri, mode: LaunchMode.platformDefault);
      } catch (_) {
        return false;
      }
    }
  }
}
