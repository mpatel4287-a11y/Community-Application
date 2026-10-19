import 'package:flutter_test/flutter_test.dart';
import 'package:comm_app/utils/social_launcher.dart';

void main() {
  group('SocialLauncher URL & Handle Tests', () {
    test('Snapchat parsing and URL building', () {
      // Plain username
      expect(SocialLauncher.extractUsername('meet_patel'), 'meet_patel');
      expect(SocialLauncher.buildUrl('snapchat', 'meet_patel'),
          'https://www.snapchat.com/add/meet_patel');

      // Leading @
      expect(SocialLauncher.extractUsername('@meet_patel'), 'meet_patel');
      expect(SocialLauncher.buildUrl('snapchat', '@meet_patel'),
          'https://www.snapchat.com/add/meet_patel');

      // snapchat.com/add/username (without https)
      expect(SocialLauncher.extractUsername('snapchat.com/add/meet_patel'), 'meet_patel');
      expect(SocialLauncher.buildUrl('snapchat', 'snapchat.com/add/meet_patel'),
          'https://www.snapchat.com/add/meet_patel');

      // Full URL with query parameters
      expect(SocialLauncher.extractUsername('https://www.snapchat.com/add/meet_patel?share_id=123'),
          'meet_patel');
      expect(SocialLauncher.buildUrl('snapchat', 'https://www.snapchat.com/add/meet_patel?share_id=123'),
          'https://www.snapchat.com/add/meet_patel');
    });

    test('Instagram parsing and URL building', () {
      // Plain username
      expect(SocialLauncher.extractUsername('patel_ramanagara'), 'patel_ramanagara');
      expect(SocialLauncher.buildUrl('instagram', 'patel_ramanagara'),
          'https://www.instagram.com/patel_ramanagara/');

      // Leading @
      expect(SocialLauncher.extractUsername('@patel_ramanagara'), 'patel_ramanagara');
      expect(SocialLauncher.buildUrl('instagram', '@patel_ramanagara'),
          'https://www.instagram.com/patel_ramanagara/');

      // instagram.com/username (without https)
      expect(SocialLauncher.extractUsername('instagram.com/patel_ramanagara/'), 'patel_ramanagara');
      expect(SocialLauncher.buildUrl('instagram', 'instagram.com/patel_ramanagara/'),
          'https://www.instagram.com/patel_ramanagara/');

      // Full URL with igsh parameter
      expect(
          SocialLauncher.extractUsername('https://www.instagram.com/patel_ramanagara/?igsh=abc123xyz'),
          'patel_ramanagara');
      expect(
          SocialLauncher.buildUrl('instagram', 'https://www.instagram.com/patel_ramanagara/?igsh=abc123xyz'),
          'https://www.instagram.com/patel_ramanagara/');
    });

    test('Facebook & WhatsApp URL building', () {
      expect(SocialLauncher.buildUrl('facebook', 'patel_samaj'), 'https://www.facebook.com/patel_samaj');
      expect(SocialLauncher.buildUrl('facebook', 'https://www.facebook.com/patel_samaj'),
          'https://www.facebook.com/patel_samaj');

      expect(SocialLauncher.buildUrl('whatsapp', '9876543210'), 'https://wa.me/9876543210');
      expect(SocialLauncher.buildUrl('whatsapp', '+91 98765 43210'), 'https://wa.me/+919876543210');
    });
  });
}
