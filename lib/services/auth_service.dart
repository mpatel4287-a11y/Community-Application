// lib/services/auth_service.dart
// Phase 2: Family ID + Password authentication

// ignore_for_file: constant_identifier_names

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/login_response.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'session_manager.dart';
import 'admin_management_service.dart';

class AuthService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String ADMIN_ID = '83288';

  Future<LoginResponse> login({
    required String loginId,
    required String password,
  }) async {
    try {
      final id = loginId.trim();
      final pwd = password.trim();

      // ---------------- VALIDATION ----------------
      if (id.isEmpty || pwd.isEmpty) {
        return LoginResponse(
          success: false,
          message: 'ID and password required',
          isAdmin: false,
        );
      }

      // ---------------- DUAL-ADMIN LOGIN (ADM-83288) ----------------
      if (id.startsWith('ADM-')) {
        final adminId = id.substring(4); // Remove 'ADM-'
        if (adminId == ADMIN_ID) {
          final adminSnap = await _firestore
              .collection('families')
              .doc(ADMIN_ID)
              .get();

          final masterPassword = adminSnap.exists ? (adminSnap.data()?['password']?.toString() ?? '') : '';

          // 1. MASTER ADMIN (SUPER ADMIN) LOGIN
          if (masterPassword.isNotEmpty && masterPassword == pwd) {
            await SessionManager.saveSession(
              familyDocId: adminSnap.id,
              familyId: adminSnap.data()?['familyId'] ?? 0,
              isAdmin: true,
              role: 'admin',
              familyName: adminSnap.data()?['familyName'] ?? 'Main Admin',
            );
            await SessionManager.setIsSuperAdmin(true);
            await SessionManager.setAdminPermissions(AdminManagementService.allPermissionKeys);
            await SessionManager.setAdminSessionToken('');

            return LoginResponse(
              success: true,
              message: 'Super Admin login successful',
              isAdmin: true,
              role: 'admin',
            );
          }

          // 2. SECONDARY ADMIN (SUB ADMIN) LOGIN
          final adminService = AdminManagementService();
          final subAdminConfig = await adminService.getSubAdminConfig();
          final subAdminPassword = (subAdminConfig['password'] ?? '').toString();

          if (subAdminPassword.isNotEmpty && subAdminPassword == pwd) {
            // Check if blocked by Super Admin
            if (subAdminConfig['isBlocked'] == true) {
              return LoginResponse(
                success: false,
                message: 'This admin account is currently blocked by Super Admin.',
                isAdmin: false,
              );
            }

            // Generate unique session token & capture client telemetry
            final sessionToken = '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecondsSinceEpoch}';
            final telemetry = await adminService.fetchClientTelemetry();

            await adminService.recordSubAdminLogin(
              sessionToken: sessionToken,
              telemetry: telemetry,
            );

            final permissions = List<String>.from(
              subAdminConfig['permissions'] ?? AdminManagementService.allPermissionKeys,
            );

            await SessionManager.saveSession(
              familyDocId: adminSnap.exists ? adminSnap.id : ADMIN_ID,
              familyId: adminSnap.exists ? (adminSnap.data()?['familyId'] ?? 0) : 0,
              isAdmin: true,
              role: 'admin',
              familyName: 'Admin',
            );
            await SessionManager.setIsSuperAdmin(false);
            await SessionManager.setAdminPermissions(permissions);
            await SessionManager.setAdminSessionToken(sessionToken);

            return LoginResponse(
              success: true,
              message: 'Admin login successful',
              isAdmin: true,
              role: 'admin',
            );
          }

          return LoginResponse(
            success: false,
            message: 'Invalid admin credentials',
            isAdmin: false,
          );
        }
      }

      // ---------------- MEMBER/MANAGER LOGIN (MID) ----------------
      // Use collectionGroup to find the member by MID across all families/subfamilies
      final memberQuery = await _firestore
          .collectionGroup('members')
          .where('mid', isEqualTo: id)
          .limit(1)
          .get();

      if (memberQuery.docs.isEmpty) {
        return LoginResponse(
          success: false,
          message: 'Member not found with this MID',
          isAdmin: false,
        );
      }

      final memberDoc = memberQuery.docs.first;
      final memberData = memberDoc.data();
      
      // Check if member is inactive
      if (memberData['isActive'] == false) {
        return LoginResponse(
          success: false,
          message: 'Your account is currently inactive. Please contact admin.',
          isAdmin: false,
        );
      }

      // Check if family is blocked
      final familyDocId = memberData['familyDocId'] ?? '';
      if (familyDocId.isNotEmpty) {
        final familySnap = await _firestore.collection('families').doc(familyDocId).get();
        if (familySnap.exists && (familySnap.data()?['isBlocked'] == true)) {
          return LoginResponse(
            success: false,
            message: 'Your family account is blocked. Please contact admin.',
            isAdmin: false,
          );
        }
      }

      if (memberData['password'] != pwd) {
        return LoginResponse(
          success: false,
          message: 'Incorrect password',
          isAdmin: false,
        );
      }

      final role = memberData['role'] ?? 'member';
      final isAdmin = role == 'admin'; // Should rarely happen via MID but safety first

      // Save session with detailed member info
      await SessionManager.saveSession(
        familyDocId: memberData['familyDocId'] ?? '',
        familyId: int.tryParse(memberData['familyId']?.toString() ?? '0') ?? 0,
        isAdmin: isAdmin,
        role: role,
        familyName: memberData['familyName'] ?? '',
        memberId: memberData['mid'] ?? '',
      );

      // Also save member-specific session info
      await SessionManager.saveMemberSession(
        mainFamilyDocId: memberData['familyDocId'] ?? '',
        subFamilyDocId: memberData['subFamilyDocId'] ?? '',
        memberDocId: memberDoc.id,
      );

      // --- NEW: Save FCM Token ---
      try {
        final fcmToken = await FirebaseMessaging.instance.getToken();
        if (fcmToken != null) {
          await memberDoc.reference.update({'fcmToken': fcmToken});
        }
      } catch (e) {
        // Silently fail or log to a proper service
      }

      return LoginResponse(
        success: true,
        message: 'Login successful as ${role.toUpperCase()}',
        isAdmin: isAdmin,
        role: role,
      );
    } catch (e) {
      return LoginResponse(
        success: false,
        message: 'Auth error: $e',
        isAdmin: false,
      );
    }
  }

  Future<void> logout() async {
    await SessionManager.clear();
  }
}
