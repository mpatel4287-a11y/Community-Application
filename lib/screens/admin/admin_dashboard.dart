// lib/screens/admin/admin_dashboard.dart
// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import 'member_list_screen.dart';
import 'role_management_screen.dart';
import 'admin_update_requests_screen.dart';
import 'system_health_screen.dart';
import '../../services/auth_service.dart';
import '../../services/session_manager.dart';
import '../../services/language_service.dart';
import '../../widgets/top_action_bar.dart';
import '../../widgets/animation_utils.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  String? _role;
  String? _adminName;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadAdminSession();
  }

  Future<void> _loadAdminSession() async {
    final role = await SessionManager.getRole();
    final name = await SessionManager.getFamilyName();
    if (mounted) {
      setState(() {
        _role = role;
        _adminName = name ?? 'Administrator';
      });
    }
  }

  Future<void> _logout(BuildContext context) async {
    final lang = Provider.of<LanguageService>(context, listen: false);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.logout_rounded, color: Colors.red),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                lang.translate('logout'),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Text(lang.translate('confirm_logout')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(lang.translate('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(lang.translate('logout')),
          ),
        ],
      ),
    );

    if (ok == true) {
      await AuthService().logout();
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isManager = _role == 'manager';
    final lang = Provider.of<LanguageService>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFF1E293B),
        title: Text(
          lang.translate('admin_dashboard'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          // Language Switcher Chip (Compact & Overflow-proof)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: InkWell(
              onTap: () {
                final newLang = lang.currentLanguage == 'en' ? 'gu' : 'en';
                lang.setLanguage(newLang);
              },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.language, size: 13, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      lang.currentLanguage == 'en' ? 'GUJ' : 'ENG',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          TopActionBar(
            showProfile: true,
            onNotificationTap: () => Navigator.pushNamed(context, '/admin/notifications'),
            onProfileTap: () => Navigator.pushNamed(context, '/user/settings'),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white70, size: 20),
            tooltip: lang.translate('logout'),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [


            // 2. Realtime Quick Counters Grid
            SlideInAnimation(
              delay: const Duration(milliseconds: 200),
              beginOffset: const Offset(0, 0.1),
              child: _buildRealtimeMetricsRow(context),
            ),

            const SizedBox(height: 22),

            // 3. Section: Directory & Community Members
            FadeInAnimation(
              delay: const Duration(milliseconds: 250),
              child: _buildSectionHeader(
                title: lang.translate('family_members'),
                subtitle: 'Manage community records & approvals',
                icon: Icons.badge_outlined,
                accentColor: const Color(0xFF0284C7),
              ),
            ),
            const SizedBox(height: 12),

            if (!isManager) ...[
              SlideInAnimation(
                delay: const Duration(milliseconds: 280),
                beginOffset: const Offset(-0.1, 0),
                child: _buildActionTile(
                  context: context,
                  icon: Icons.holiday_village_rounded,
                  title: lang.translate('families'),
                  subtitle: lang.translate('manage_families'),
                  gradientColors: const [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                  onTap: () => Navigator.pushNamed(context, '/admin/families'),
                ),
              ),
              const SizedBox(height: 10),
            ],

            SlideInAnimation(
              delay: const Duration(milliseconds: 310),
              beginOffset: const Offset(-0.1, 0),
              child: _buildActionTile(
                context: context,
                icon: Icons.people_alt_rounded,
                title: lang.translate('members'),
                subtitle: lang.translate('manage_members'),
                gradientColors: const [Color(0xFF0D9488), Color(0xFF0F766E)],
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MemberListScreen(
                      isGlobal: true,
                      showOnlyManagers: false,
                      familyName: lang.translate('all_members'),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Member Update Requests with Live Stream Badge
            SlideInAnimation(
              delay: const Duration(milliseconds: 340),
              beginOffset: const Offset(-0.1, 0),
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('member_update_requests')
                    .where('status', isEqualTo: 'pending')
                    .snapshots(),
                builder: (context, snap) {
                  final pendingCount = snap.hasData ? snap.data!.docs.length : 0;
                  return _buildActionTile(
                    context: context,
                    icon: Icons.published_with_changes_rounded,
                    title: lang.translate('member_update_requests'),
                    subtitle: lang.translate('manage_update_requests_subtitle'),
                    gradientColors: const [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                    badgeCount: pendingCount,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AdminUpdateRequestsScreen()),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),

            SlideInAnimation(
              delay: const Duration(milliseconds: 370),
              beginOffset: const Offset(-0.1, 0),
              child: _buildActionTile(
                context: context,
                icon: Icons.admin_panel_settings_rounded,
                title: lang.translate('manage_managers'),
                subtitle: lang.translate('manage_managers_subtitle'),
                gradientColors: const [Color(0xFFEA580C), Color(0xFFC2410C)],
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MemberListScreen(
                      isGlobal: true,
                      showOnlyManagers: true,
                      familyName: lang.translate('managers'),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 22),

            // 4. Section: Organization & Activities
            FadeInAnimation(
              delay: const Duration(milliseconds: 400),
              child: _buildSectionHeader(
                title: lang.translate('organization'),
                subtitle: 'Community committees, groups & events',
                icon: Icons.account_tree_outlined,
                accentColor: const Color(0xFF7C3AED),
              ),
            ),
            const SizedBox(height: 12),

            SlideInAnimation(
              delay: const Duration(milliseconds: 430),
              beginOffset: const Offset(-0.1, 0),
              child: _buildActionTile(
                context: context,
                icon: Icons.military_tech_rounded,
                title: lang.translate('organizational_roles'),
                subtitle: lang.translate('manage_roles_subtitle'),
                gradientColors: const [Color(0xFF059669), Color(0xFF047857)],
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RoleManagementScreen()),
                ),
              ),
            ),
            const SizedBox(height: 10),

            SlideInAnimation(
              delay: const Duration(milliseconds: 460),
              beginOffset: const Offset(-0.1, 0),
              child: _buildActionTile(
                context: context,
                icon: Icons.diversity_3_rounded,
                title: lang.translate('groups'),
                subtitle: lang.translate('manage_groups_subtitle'),
                gradientColors: const [Color(0xFF9333EA), Color(0xFF7E22CE)],
                onTap: () => Navigator.pushNamed(context, '/admin/groups'),
              ),
            ),
            const SizedBox(height: 10),

            SlideInAnimation(
              delay: const Duration(milliseconds: 490),
              beginOffset: const Offset(-0.1, 0),
              child: _buildActionTile(
                context: context,
                icon: Icons.event_available_rounded,
                title: lang.translate('events'),
                subtitle: lang.translate('manage_events_subtitle'),
                gradientColors: const [Color(0xFF3B82F6), Color(0xFF2563EB)],
                onTap: () => Navigator.pushNamed(context, '/admin/events'),
              ),
            ),
            const SizedBox(height: 10),

            SlideInAnimation(
              delay: const Duration(milliseconds: 520),
              beginOffset: const Offset(-0.1, 0),
              child: _buildActionTile(
                context: context,
                icon: Icons.storefront_rounded,
                title: lang.translate('firms'),
                subtitle: lang.translate('view_firms_subtitle'),
                gradientColors: const [Color(0xFFF59E0B), Color(0xFFD97706)],
                onTap: () => Navigator.pushNamed(context, '/admin/firms'),
              ),
            ),
            const SizedBox(height: 10),

            SlideInAnimation(
              delay: const Duration(milliseconds: 550),
              beginOffset: const Offset(-0.1, 0),
              child: _buildActionTile(
                context: context,
                icon: Icons.campaign_rounded,
                title: lang.translate('notification_center'),
                subtitle: lang.translate('send_custom_messages'),
                gradientColors: const [Color(0xFFE11D48), Color(0xFFBE123C)],
                onTap: () => Navigator.pushNamed(context, '/admin/notifications'),
              ),
            ),

            const SizedBox(height: 22),

            // 5. Section: Developer & System Diagnostics Hub
            FadeInAnimation(
              delay: const Duration(milliseconds: 580),
              child: _buildSectionHeader(
                title: 'Developer & Diagnostics Hub',
                subtitle: 'Real-time telemetry, health & system controls',
                icon: Icons.terminal_rounded,
                accentColor: const Color(0xFF10B981),
              ),
            ),
            const SizedBox(height: 12),

            if (!isManager) ...[
              SlideInAnimation(
                delay: const Duration(milliseconds: 610),
                beginOffset: const Offset(-0.1, 0),
                child: _buildActionTile(
                  context: context,
                  icon: Icons.analytics_rounded,
                  title: lang.translate('analytics'),
                  subtitle: 'Demographics, community growth & charts',
                  gradientColors: const [Color(0xFF0F766E), Color(0xFF115E59)],
                  onTap: () => Navigator.pushNamed(context, '/admin/analytics'),
                ),
              ),
              const SizedBox(height: 10),
            ],

            SlideInAnimation(
              delay: const Duration(milliseconds: 640),
              beginOffset: const Offset(-0.1, 0),
              child: _buildActionTile(
                context: context,
                icon: Icons.health_and_safety_rounded,
                title: lang.translate('system_health'),
                subtitle: 'Firestore latency, latency checks & services status',
                gradientColors: const [Color(0xFF059669), Color(0xFF047857)],
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SystemHealthScreen()),
                ),
              ),
            ),
            const SizedBox(height: 10),

            SlideInAnimation(
              delay: const Duration(milliseconds: 670),
              beginOffset: const Offset(-0.1, 0),
              child: _buildActionTile(
                context: context,
                icon: Icons.settings_suggest_rounded,
                title: lang.translate('settings'),
                subtitle: 'App configuration, security rules & cache management',
                gradientColors: const [Color(0xFF475569), Color(0xFF334155)],
                onTap: () => Navigator.pushNamed(context, '/user/settings'),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ---------------- HERO BANNER ----------------


  // ---------------- METRICS ROW ----------------
  Widget _buildRealtimeMetricsRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('families').where('isAdmin', isEqualTo: false).snapshots(),
            builder: (context, snap) {
              final count = snap.hasData ? snap.data!.docs.length : 0;
              return _buildMetricBadge(
                label: 'Families',
                value: snap.hasData ? '$count' : '...',
                icon: Icons.holiday_village_rounded,
                color: const Color(0xFF2563EB),
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore.collectionGroup('members').snapshots(),
            builder: (context, snap) {
              final count = snap.hasData ? snap.data!.docs.length : 0;
              return _buildMetricBadge(
                label: 'Members',
                value: snap.hasData ? '$count' : '...',
                icon: Icons.people_alt_rounded,
                color: const Color(0xFF0D9488),
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('member_update_requests')
                .where('status', isEqualTo: 'pending')
                .snapshots(),
            builder: (context, snap) {
              final count = snap.hasData ? snap.data!.docs.length : 0;
              return _buildMetricBadge(
                label: 'Requests',
                value: snap.hasData ? '$count' : '...',
                icon: Icons.published_with_changes_rounded,
                color: count > 0 ? const Color(0xFFEF4444) : const Color(0xFF8B5CF6),
                hasAlert: count > 0,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMetricBadge({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    bool hasAlert = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasAlert ? Colors.red.shade400 : (isDark ? Colors.white10 : Colors.black.withOpacity(0.06)),
          width: hasAlert ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: color),
              if (hasAlert) ...[
                const SizedBox(width: 3),
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: hasAlert ? Colors.red.shade600 : color,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ---------------- SECTION HEADER (OVERFLOW-SAFE) ----------------
  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: accentColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------- ACTION TILE (OVERFLOW-SAFE) ----------------
  Widget _buildActionTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradientColors,
    required VoidCallback onTap,
    int? badgeCount,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.07) : Colors.black.withOpacity(0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(11),
                    gradient: LinearGradient(
                      colors: gradientColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: gradientColors.first.withOpacity(0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (badgeCount != null && badgeCount > 0) ...[
                  const SizedBox(width: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.red.shade600,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$badgeCount PENDING',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 6),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: isDark ? Colors.white38 : Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
