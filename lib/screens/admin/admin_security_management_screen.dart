// lib/screens/admin/admin_security_management_screen.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/admin_management_service.dart';
import '../../services/session_manager.dart';

class AdminSecurityManagementScreen extends StatefulWidget {
  const AdminSecurityManagementScreen({super.key});

  @override
  State<AdminSecurityManagementScreen> createState() =>
      _AdminSecurityManagementScreenState();
}

class _AdminSecurityManagementScreenState
    extends State<AdminSecurityManagementScreen> {
  final AdminManagementService _adminService = AdminManagementService();
  bool _isLoading = true;

  final TextEditingController _subAdminPassCtrl = TextEditingController();
  bool _obscureSubAdminPass = true;

  List<String> _currentPermissions = [];
  bool _isSavingPermissions = false;

  @override
  void initState() {
    super.initState();
    _checkAuthorization();
  }

  @override
  void dispose() {
    _subAdminPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkAuthorization() async {
    final isSuper = await SessionManager.isSuperAdmin();
    if (!isSuper) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Access Denied: Only Super Admin can access this screen.'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pop(context);
      }
      return;
    }

    // Load initial config
    final config = await _adminService.getSubAdminConfig();
    if (mounted) {
      setState(() {
        _isLoading = false;
        _currentPermissions = List<String>.from(
          config['permissions'] ?? AdminManagementService.allPermissionKeys,
        );
      });
    }
  }

  Future<void> _toggleBlockStatus(bool currentBlocked) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              currentBlocked ? Icons.lock_open_rounded : Icons.block_rounded,
              color: currentBlocked ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 8),
            Text(currentBlocked ? 'Unblock Secondary Admin' : 'Block Secondary Admin'),
          ],
        ),
        content: Text(
          currentBlocked
              ? 'Are you sure you want to unblock the secondary admin? They will be able to log in again.'
              : 'Are you sure you want to block the secondary admin? Their active session will be immediately terminated and future logins prevented.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: currentBlocked ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(currentBlocked ? 'Unblock' : 'Block Admin'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _adminService.setSubAdminBlocked(!currentBlocked);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(currentBlocked
                ? 'Secondary admin has been unblocked.'
                : 'Secondary admin has been blocked and logged out.'),
            backgroundColor: currentBlocked ? Colors.green : Colors.orange.shade800,
          ),
        );
      }
    }
  }

  Future<void> _forceLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.power_settings_new_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Force Logout Secondary Admin'),
          ],
        ),
        content: const Text(
          'This will revoke the secondary admin\'s active session immediately. They will be logged out of their device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade800,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Force Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _adminService.forceLogoutSubAdmin();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Secondary admin active session has been revoked.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _updateSubAdminPassword() async {
    final pwd = _subAdminPassCtrl.text.trim();
    if (pwd.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 4 characters long.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await _adminService.updateSubAdminPassword(pwd);
      _subAdminPassCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Secondary admin password successfully updated!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating password: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _savePermissions() async {
    setState(() => _isSavingPermissions = true);
    try {
      await _adminService.updateSubAdminPermissions(_currentPermissions);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Permissions saved successfully (${_currentPermissions.length} modules granted).',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving permissions: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingPermissions = false);
    }
  }

  String _formatTimestamp(dynamic ts) {
    if (ts == null) return 'Never logged in';
    if (ts is Timestamp) {
      return DateFormat('dd MMM yyyy, hh:mm a').format(ts.toDate());
    }
    return ts.toString();
  }

  IconData _getModuleIcon(String key) {
    switch (key) {
      case 'families':
        return Icons.holiday_village_rounded;
      case 'members':
        return Icons.people_alt_rounded;
      case 'member_update_requests':
        return Icons.published_with_changes_rounded;
      case 'managers':
        return Icons.admin_panel_settings_rounded;
      case 'roles':
        return Icons.military_tech_rounded;
      case 'groups':
        return Icons.diversity_3_rounded;
      case 'events':
        return Icons.event_available_rounded;
      case 'firms':
        return Icons.storefront_rounded;
      case 'notifications':
        return Icons.campaign_rounded;
      case 'analytics':
        return Icons.analytics_rounded;
      case 'system_health':
        return Icons.health_and_safety_rounded;
      case 'settings':
        return Icons.settings_suggest_rounded;
      default:
        return Icons.apps_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Admin Security & Access',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Super Admin Badge Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.shield_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Super Admin Master Console',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'You hold permanent, non-removable access. Track the secondary admin, revoke access, and customize module permissions below.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 2. Secondary Admin Live Telemetry & Control Card
            StreamBuilder<DocumentSnapshot>(
              stream: _adminService.streamSubAdminConfig(),
              builder: (context, snapshot) {
                final data = (snapshot.hasData && snapshot.data!.exists)
                    ? Map<String, dynamic>.from(snapshot.data!.data() as Map)
                    : <String, dynamic>{};

                final isBlocked = data['isBlocked'] == true;
                final activeToken = (data['activeSessionToken'] ?? '').toString();
                final hasActiveSession = activeToken.isNotEmpty && !isBlocked;
                final lastLogin = _formatTimestamp(data['lastLoginAt']);
                final device = (data['lastLoginDevice'] ?? 'No activity yet').toString();
                final location = (data['lastLoginLocation'] ?? 'Unknown location').toString();
                final ip = (data['lastLoginIp'] ?? 'Unknown IP').toString();

                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isBlocked ? Colors.red.withOpacity(0.5) : Colors.transparent,
                    ),
                  ),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.person_pin_rounded,
                                  color: isBlocked ? Colors.red : Colors.blue.shade700,
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Secondary Admin Status',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isBlocked
                                    ? Colors.red.withOpacity(0.15)
                                    : Colors.green.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                isBlocked ? 'BLOCKED' : (hasActiveSession ? 'ONLINE / ACTIVE' : 'OFFLINE'),
                                style: TextStyle(
                                  color: isBlocked ? Colors.red : Colors.green.shade700,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),

                        // Telemetry details grid
                        _buildTelemetryRow(
                          icon: Icons.access_time_rounded,
                          label: 'Last Login',
                          value: lastLogin,
                        ),
                        const SizedBox(height: 8),
                        _buildTelemetryRow(
                          icon: Icons.devices_rounded,
                          label: 'Device / Client',
                          value: device,
                        ),
                        const SizedBox(height: 8),
                        _buildTelemetryRow(
                          icon: Icons.location_on_rounded,
                          label: 'Location',
                          value: location,
                        ),
                        const SizedBox(height: 8),
                        _buildTelemetryRow(
                          icon: Icons.lan_rounded,
                          label: 'IP Address',
                          value: ip,
                        ),

                        const SizedBox(height: 16),

                        // Action Buttons: Force Logout & Block/Unblock
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.orange.shade800,
                                  side: BorderSide(color: Colors.orange.shade400),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                icon: const Icon(Icons.power_settings_new_rounded, size: 18),
                                label: const Text('Force Logout'),
                                onPressed: hasActiveSession ? _forceLogout : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isBlocked ? Colors.green : Colors.red,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                icon: Icon(
                                  isBlocked ? Icons.lock_open_rounded : Icons.block_rounded,
                                  size: 18,
                                ),
                                label: Text(isBlocked ? 'Unblock Admin' : 'Block Admin'),
                                onPressed: () => _toggleBlockStatus(isBlocked),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // 3. Password Management Section
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.password_rounded, color: Colors.indigo, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Password Management',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Change 2nd Admin Password
                    const Text(
                      'Secondary Admin Password',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _subAdminPassCtrl,
                            obscureText: _obscureSubAdminPass,
                            decoration: InputDecoration(
                              hintText: 'Enter new password for 2nd admin',
                              isDense: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureSubAdminPass ? Icons.visibility_off : Icons.visibility,
                                  size: 20,
                                ),
                                onPressed: () =>
                                    setState(() => _obscureSubAdminPass = !_obscureSubAdminPass),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: _updateSubAdminPassword,
                          child: const Text('Update'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 4. Granular Permissions Checklist
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.rule_folder_rounded, color: Colors.teal, size: 22),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Secondary Admin Permissions',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'Granted: ${_currentPermissions.length} of ${AdminManagementService.allPermissionKeys.length}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _currentPermissions =
                                      List.from(AdminManagementService.allPermissionKeys);
                                });
                              },
                              child: const Text('Select All', style: TextStyle(fontSize: 12)),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _currentPermissions.clear();
                                });
                              },
                              child: const Text('Clear All', style: TextStyle(fontSize: 12, color: Colors.red)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Tick the features that the secondary admin is authorized to see and operate:',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),

                    // Permission Items
                    ...AdminManagementService.allPermissionKeys.map((key) {
                      final isGranted = _currentPermissions.contains(key);
                      final label = AdminManagementService.permissionLabels[key] ?? key;
                      final desc = AdminManagementService.permissionDescriptions[key] ?? '';
                      final icon = _getModuleIcon(key);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isGranted
                              ? Colors.teal.withOpacity(0.06)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isGranted ? Colors.teal.withOpacity(0.3) : Colors.grey.withOpacity(0.2),
                          ),
                        ),
                        child: CheckboxListTile(
                          value: isGranted,
                          activeColor: Colors.teal,
                          secondary: Icon(icon, color: isGranted ? Colors.teal : Colors.grey),
                          title: Text(
                            label,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: isGranted ? null : Colors.grey.shade600,
                            ),
                          ),
                          subtitle: Text(
                            desc,
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                          ),
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                if (!_currentPermissions.contains(key)) {
                                  _currentPermissions.add(key);
                                }
                              } else {
                                _currentPermissions.remove(key);
                              }
                            });
                          },
                        ),
                      );
                    }),

                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: _isSavingPermissions
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.check_circle_rounded),
                        label: Text(
                          _isSavingPermissions ? 'Saving Permissions...' : 'Save Permissions Now',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: _isSavingPermissions ? null : _savePermissions,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildTelemetryRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        SizedBox(
          width: 95,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        const Text(': ', style: TextStyle(fontSize: 12, color: Colors.grey)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
