import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AdminManagementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String settingsCollection = 'admin_settings';
  static const String subAdminDocId = 'sub_admin';
  static const String mainAdminDocId = '83288';

  DocumentReference get _subAdminRef =>
      _firestore.collection(settingsCollection).doc(subAdminDocId);

  DocumentReference get _mainAdminRef =>
      _firestore.collection('families').doc(mainAdminDocId);

  static const List<String> allPermissionKeys = [
    'families',
    'members',
    'member_update_requests',
    'managers',
    'roles',
    'groups',
    'events',
    'firms',
    'notifications',
    'analytics',
    'system_health',
    'settings',
  ];

  static const Map<String, String> permissionLabels = {
    'families': 'Families Management',
    'members': 'Members Directory & Records',
    'member_update_requests': 'Member Profile Update Requests',
    'managers': 'Managers Administration',
    'roles': 'Organizational Roles & Committees',
    'groups': 'Community Groups & Circles',
    'events': 'Events & RSVPs Management',
    'firms': 'Business & Firms Directory',
    'notifications': 'Broadcast Notifications & Alerts',
    'analytics': 'Analytics & Community Demographics',
    'system_health': 'System Health & Telemetry',
    'settings': 'Application Settings & Configurations',
  };

  static const Map<String, String> permissionDescriptions = {
    'families': 'Create, edit, view, delete, and export family records (PDF & Excel)',
    'members': 'View full directory, create new members, edit details, upload photos, and remove members',
    'member_update_requests': 'Review, approve, or reject member change requests with live audit trail',
    'managers': 'Promote members to managers and manage manager access levels',
    'roles': 'Assign and manage organizational titles, leaders, and committee members',
    'groups': 'Create, edit, and organize community activity groups',
    'events': 'Publish upcoming community events, view attendees, and manage programs',
    'firms': 'View and manage business directory listings and owner affiliations',
    'notifications': 'Compose and send global community announcements and push alerts',
    'analytics': 'Inspect member demographics, age distributions, blood groups, and charts',
    'system_health': 'Monitor database latency, system diagnostics, and server metrics',
    'settings': 'Access theme preferences, language, cache controls, and security policies',
  };

  /// Get sub-admin configuration, creating default document if it doesn't exist
  Future<Map<String, dynamic>> getSubAdminConfig() async {
    try {
      final doc = await _subAdminRef.get();
      if (doc.exists && doc.data() != null) {
        return Map<String, dynamic>.from(doc.data() as Map);
      }

      final defaultData = {
        'password': '123456',
        'isBlocked': false,
        'activeSessionToken': '',
        'lastLoginAt': null,
        'lastLoginDevice': 'Not logged in yet',
        'lastLoginLocation': 'Unknown',
        'lastLoginIp': 'Unknown',
        'permissions': allPermissionKeys,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _subAdminRef.set(defaultData);
      return defaultData;
    } catch (e) {
      debugPrint('Error getting sub-admin config: $e');
      return {
        'password': '123456',
        'isBlocked': false,
        'activeSessionToken': '',
        'permissions': allPermissionKeys,
      };
    }
  }

  /// Real-time stream of the sub-admin configuration
  Stream<DocumentSnapshot> streamSubAdminConfig() {
    return _subAdminRef.snapshots();
  }

  /// Update secondary admin permissions list
  Future<void> updateSubAdminPermissions(List<String> permissions) async {
    await _subAdminRef.set({
      'permissions': permissions,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Block or unblock secondary admin
  Future<void> setSubAdminBlocked(bool blocked) async {
    final updates = <String, dynamic>{
      'isBlocked': blocked,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (blocked) {
      // Invalidate current session token when blocked
      updates['activeSessionToken'] = '';
    }
    await _subAdminRef.set(updates, SetOptions(merge: true));
  }

  /// Invalidate secondary admin session token to force immediate logout
  Future<void> forceLogoutSubAdmin() async {
    await _subAdminRef.set({
      'activeSessionToken': '',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Update secondary admin password
  Future<void> updateSubAdminPassword(String newPassword) async {
    await _subAdminRef.set({
      'password': newPassword.trim(),
      'activeSessionToken': '',
      'passwordChangedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Update main admin (super admin) master password in families/83288
  Future<void> updateMainAdminPassword(String newPassword) async {
    await _mainAdminRef.update({
      'password': newPassword.trim(),
      'passwordChangedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Fetch client telemetry (IP, location, device name)
  Future<Map<String, String>> fetchClientTelemetry() async {
    String device = 'Unknown Device';
    String ip = 'Direct Network';
    String location = 'Unknown Location';

    // 1. Detect device & platform
    try {
      if (kIsWeb) {
        device = 'Web (${defaultTargetPlatform.name.toUpperCase()})';
      } else {
        device = defaultTargetPlatform.name.toUpperCase();
      }
    } catch (_) {
      device = 'Client App';
    }

    // 2. Query IP & Location with short timeout
    try {
      final res = await http
          .get(Uri.parse('https://ipapi.co/json/'))
          .timeout(const Duration(milliseconds: 2500));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map) {
          ip = (data['ip'] ?? ip).toString();
          final city = (data['city'] ?? '').toString();
          final country = (data['country_name'] ?? data['country'] ?? '').toString();
          if (city.isNotEmpty && country.isNotEmpty) {
            location = '$city, $country';
          } else if (country.isNotEmpty) {
            location = country;
          }
        }
      }
    } catch (_) {
      // Fallback service
      try {
        final res2 = await http
            .get(Uri.parse('http://ip-api.com/json'))
            .timeout(const Duration(milliseconds: 2000));
        if (res2.statusCode == 200) {
          final data2 = jsonDecode(res2.body);
          if (data2 is Map) {
            ip = (data2['query'] ?? ip).toString();
            final city = (data2['city'] ?? '').toString();
            final country = (data2['country'] ?? '').toString();
            if (city.isNotEmpty && country.isNotEmpty) {
              location = '$city, $country';
            }
          }
        }
      } catch (_) {
        // Silently preserve fallbacks
      }
    }

    return {
      'device': device,
      'ip': ip,
      'location': location,
    };
  }

  /// Record sub-admin login telemetry and new active session token
  Future<void> recordSubAdminLogin({
    required String sessionToken,
    required Map<String, String> telemetry,
  }) async {
    try {
      await _subAdminRef.set({
        'activeSessionToken': sessionToken,
        'lastLoginAt': FieldValue.serverTimestamp(),
        'lastLoginDevice': telemetry['device'] ?? 'Unknown',
        'lastLoginIp': telemetry['ip'] ?? 'Unknown',
        'lastLoginLocation': telemetry['location'] ?? 'Unknown',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error recording sub-admin login telemetry: $e');
    }
  }
}
