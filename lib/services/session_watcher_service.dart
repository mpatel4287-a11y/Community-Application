// lib/services/session_watcher_service.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'session_manager.dart';
import '../main.dart'; // Provides navigatorKey

class SessionWatcherService {
  static final SessionWatcherService _instance = SessionWatcherService._internal();
  factory SessionWatcherService() => _instance;
  SessionWatcherService._internal();

  StreamSubscription<DocumentSnapshot>? _subscription;
  bool _isWatching = false;
  bool _isLoggingOut = false;

  bool get isWatching => _isWatching;

  /// Start watching the active user/admin document in real-time
  Future<void> startWatching() async {
    final isVisitor = await SessionManager.isVisitor();
    if (isVisitor) return;

    final hasSession = await SessionManager.hasSession();
    if (!hasSession) {
      await stopWatching();
      return;
    }

    final sessionPassword = await SessionManager.getSessionPassword();
    // If no session password stored (e.g. fresh upgrade before re-login), skip password matching until next login
    if (sessionPassword == null || sessionPassword.isEmpty) {
      return;
    }

    final isSuper = await SessionManager.isSuperAdmin();
    final isAdmin = await SessionManager.getIsAdmin() == true;
    final role = await SessionManager.getRole();
    final memberDocPath = await SessionManager.getMemberDocPath();
    final familyDocId = await SessionManager.getFamilyDocId();
    final subFamilyDocId = await SessionManager.getSubFamilyDocId();
    final memberDocId = await SessionManager.getMemberDocId();

    // Cancel existing subscription before starting a new one
    await _subscription?.cancel();
    _subscription = null;
    _isWatching = true;
    _isLoggingOut = false;

    if (isSuper) {
      // 1. Super Admin watcher on families/83288
      _subscription = FirebaseFirestore.instance
          .collection('families')
          .doc('83288')
          .snapshots()
          .listen((snap) async {
        if (!snap.exists || snap.data() == null) return;
        final data = Map<String, dynamic>.from(snap.data() as Map);
        final currentPwd = (data['password'] ?? '').toString();
        if (currentPwd.isNotEmpty && currentPwd != sessionPassword) {
          await forceLogout(
            'Master password was changed. You have been logged out from all devices.',
          );
        }
      }, onError: (e) => debugPrint('Super Admin watcher error: $e'));
    } else if (isAdmin || role == 'admin') {
      // 2. Sub Admin watcher on admin_settings/sub_admin
      final sessionToken = await SessionManager.getAdminSessionToken();
      _subscription = FirebaseFirestore.instance
          .collection('admin_settings')
          .doc('sub_admin')
          .snapshots()
          .listen((snap) async {
        if (!snap.exists || snap.data() == null) return;
        final data = Map<String, dynamic>.from(snap.data() as Map);
        final currentPwd = (data['password'] ?? '').toString();
        final activeToken = (data['activeSessionToken'] ?? '').toString();
        final isBlocked = data['isBlocked'] == true;

        if (isBlocked) {
          await forceLogout(
            'Your admin access has been blocked by the Super Admin.',
          );
        } else if (currentPwd.isNotEmpty && currentPwd != sessionPassword) {
          await forceLogout(
            'Admin password was changed. You have been logged out from all devices.',
          );
        } else if (sessionToken != null &&
            sessionToken.isNotEmpty &&
            activeToken.isNotEmpty &&
            activeToken != sessionToken) {
          await forceLogout(
            'Your admin session was terminated from another device.',
          );
        }
      }, onError: (e) => debugPrint('Sub Admin watcher error: $e'));
    } else {
      // 3. Regular Member / Manager watcher
      DocumentReference? docRef;
      if (memberDocPath != null && memberDocPath.isNotEmpty) {
        docRef = FirebaseFirestore.instance.doc(memberDocPath);
      } else if (familyDocId != null &&
          familyDocId.isNotEmpty &&
          memberDocId != null &&
          memberDocId.isNotEmpty) {
        if (subFamilyDocId != null && subFamilyDocId.isNotEmpty) {
          docRef = FirebaseFirestore.instance
              .collection('families')
              .doc(familyDocId)
              .collection('sub_families')
              .doc(subFamilyDocId)
              .collection('members')
              .doc(memberDocId);
        } else {
          docRef = FirebaseFirestore.instance
              .collection('families')
              .doc(familyDocId)
              .collection('members')
              .doc(memberDocId);
        }
      }

      if (docRef != null) {
        _subscription = docRef.snapshots().listen((snap) async {
          if (!snap.exists || snap.data() == null) return;
          final data = Map<String, dynamic>.from(snap.data() as Map);
          final currentPwd = (data['password'] ?? '').toString();
          final isActive = data['isActive'] != false;

          if (!isActive) {
            await forceLogout(
              'Your account has been deactivated. Please contact admin.',
            );
          } else if (currentPwd.isNotEmpty && currentPwd != sessionPassword) {
            await forceLogout(
              'Your password was changed. You have been logged out from all devices. Please log in with your new password.',
            );
          }
        }, onError: (e) => debugPrint('Member watcher error: $e'));
      }
    }
  }

  /// Stop watching and clean up subscription
  Future<void> stopWatching() async {
    await _subscription?.cancel();
    _subscription = null;
    _isWatching = false;
  }

  /// Verify session once synchronously against Firestore
  Future<bool> verifySessionOnce() async {
    try {
      final isVisitor = await SessionManager.isVisitor();
      if (isVisitor) return true;

      final hasSession = await SessionManager.hasSession();
      if (!hasSession) return false;

      final sessionPassword = await SessionManager.getSessionPassword();
      if (sessionPassword == null || sessionPassword.isEmpty) {
        return true; // No stored password to verify against
      }

      final isSuper = await SessionManager.isSuperAdmin();
      final isAdmin = await SessionManager.getIsAdmin() == true;
      final role = await SessionManager.getRole();

      if (isSuper) {
        final snap = await FirebaseFirestore.instance
            .collection('families')
            .doc('83288')
            .get();
        if (!snap.exists) return false;
        final currentPwd = (snap.data()?['password'] ?? '').toString();
        return currentPwd == sessionPassword;
      } else if (isAdmin || role == 'admin') {
        final snap = await FirebaseFirestore.instance
            .collection('admin_settings')
            .doc('sub_admin')
            .get();
        if (!snap.exists) return false;
        final data = snap.data() ?? {};
        if (data['isBlocked'] == true) return false;
        final currentPwd = (data['password'] ?? '').toString();
        final activeToken = (data['activeSessionToken'] ?? '').toString();
        final sessionToken = await SessionManager.getAdminSessionToken();
        if (sessionToken != null &&
            sessionToken.isNotEmpty &&
            activeToken.isNotEmpty &&
            activeToken != sessionToken) {
          return false;
        }
        return currentPwd == sessionPassword;
      } else {
        final memberDocPath = await SessionManager.getMemberDocPath();
        DocumentReference? docRef;
        if (memberDocPath != null && memberDocPath.isNotEmpty) {
          docRef = FirebaseFirestore.instance.doc(memberDocPath);
        } else {
          final familyDocId = await SessionManager.getFamilyDocId();
          final subFamilyDocId = await SessionManager.getSubFamilyDocId();
          final memberDocId = await SessionManager.getMemberDocId();
          if (familyDocId != null && memberDocId != null) {
            if (subFamilyDocId != null && subFamilyDocId.isNotEmpty) {
              docRef = FirebaseFirestore.instance
                  .collection('families')
                  .doc(familyDocId)
                  .collection('sub_families')
                  .doc(subFamilyDocId)
                  .collection('members')
                  .doc(memberDocId);
            } else {
              docRef = FirebaseFirestore.instance
                  .collection('families')
                  .doc(familyDocId)
                  .collection('members')
                  .doc(memberDocId);
            }
          }
        }

        if (docRef != null) {
          final snap = await docRef.get();
          if (!snap.exists) return false;
          final data = snap.data() as Map<String, dynamic>? ?? {};
          if (data['isActive'] == false) return false;
          final currentPwd = (data['password'] ?? '').toString();
          return currentPwd == sessionPassword;
        }
      }
      return true;
    } catch (e) {
      debugPrint('Error verifying session once: $e');
      return true; // Fail open on transient network errors
    }
  }

  /// Invalidate local session and navigate to login screen immediately
  Future<void> forceLogout(String reason) async {
    if (_isLoggingOut) return;
    _isLoggingOut = true;

    await stopWatching();
    await SessionManager.clearSession();

    final nav = navigatorKey.currentState;
    final ctx = navigatorKey.currentContext;

    if (nav != null) {
      nav.pushNamedAndRemoveUntil('/login', (route) => false);
    }

    if (ctx != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.lock_clock, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(reason)),
              ],
            ),
            backgroundColor: Colors.red.shade800,
            duration: const Duration(seconds: 6),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      });
    }

    _isLoggingOut = false;
  }
}
