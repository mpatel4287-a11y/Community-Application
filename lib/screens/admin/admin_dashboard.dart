// ignore_for_file: use_build_context_synchronously, deprecated_member_use, unused_import

import 'package:flutter/material.dart';
import 'member_list_screen.dart';
import 'role_management_screen.dart';
import '../../services/auth_service.dart';
import '../../services/session_manager.dart';
import '../../services/theme_service.dart';
import '../../services/language_service.dart';
import '../../widgets/top_action_bar.dart';
import '../../widgets/animation_utils.dart';
import 'package:provider/provider.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  String? _role;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final role = await SessionManager.getRole();
    setState(() => _role = role);
  }

  Future<void> _logout(BuildContext context) async {
    final lang = Provider.of<LanguageService>(context, listen: false);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(lang.translate('logout')),
        content: Text(lang.translate('confirm_logout')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(lang.translate('cancel')),
          ),
          ElevatedButton(
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

    return Scaffold(
      appBar: AppBar(
        title: Text(lang.translate('admin_dashboard')),
        actions: [
          // Language Switcher in App Bar for quick access
          TextButton(
            onPressed: () {
              final newLang = lang.currentLanguage == 'en' ? 'gu' : 'en';
              lang.setLanguage(newLang);
            },
            child: Text(
              lang.currentLanguage == 'en' ? 'GUJ' : 'ENG',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Animated Top Action Bar (Notification, Theme, Profile)
          TopActionBar(
            showProfile: true,
            onNotificationTap: () {
              Navigator.pushNamed(context, '/admin/notifications');
            },
            onProfileTap: () {
              Navigator.pushNamed(context, '/user/settings');
            },
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FadeInAnimation(
              delay: const Duration(milliseconds: 100),
              child: _buildSectionTitle(lang.translate('family_members')),
            ),
            const SizedBox(height: 12),
            if (!isManager)
              SlideInAnimation(
                delay: const Duration(milliseconds: 150),
                beginOffset: const Offset(-0.2, 0),
                child: _buildDashboardCard(
                  context,
                  icon: Icons.house_siding,
                  title: lang.translate('families'),
                  subtitle: lang.translate('manage_families'),
                  color: Colors.blue,
                  onTap: () => Navigator.pushNamed(context, '/admin/families'),
                ),
              ),
            if (!isManager) const SizedBox(height: 12),
            SlideInAnimation(
              delay: const Duration(milliseconds: 200),
              beginOffset: const Offset(-0.2, 0),
              child: _buildDashboardCard(
                context,
                icon: Icons.groups_2,
                title: lang.translate('members'),
                subtitle: lang.translate('manage_members'),
                color: Colors.teal,
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
            const SizedBox(height: 12),

            const SizedBox(height: 24),
            FadeInAnimation(
              delay: const Duration(milliseconds: 300),
              child: _buildSectionTitle(lang.translate('organization')),
            ),
            const SizedBox(height: 12),
            SlideInAnimation(
              delay: const Duration(milliseconds: 350),
              beginOffset: const Offset(-0.2, 0),
              child: _buildDashboardCard(
                context,
                icon: Icons.badge_outlined,
                title: lang.translate('organizational_roles'),
                subtitle: lang.translate('manage_roles_subtitle'),
                color: Colors.teal,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RoleManagementScreen()),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SlideInAnimation(
              delay: const Duration(milliseconds: 380),
              beginOffset: const Offset(-0.2, 0),
              child: _buildDashboardCard(
                context,
                icon: Icons.group_work,
                title: lang.translate('groups'),
                subtitle: lang.translate('manage_groups_subtitle'),
                color: Colors.purple,
                onTap: () => Navigator.pushNamed(context, '/admin/groups'),
              ),
            ),
            const SizedBox(height: 12),
            SlideInAnimation(
              delay: const Duration(milliseconds: 400),
              beginOffset: const Offset(-0.2, 0),
              child: _buildDashboardCard(
                context,
                icon: Icons.event_available,
                title: lang.translate('events'),
                subtitle: lang.translate('manage_events_subtitle'),
                color: Colors.blueAccent,
                onTap: () => Navigator.pushNamed(context, '/admin/events'),
              ),
            ),
            const SizedBox(height: 12),
            SlideInAnimation(
              delay: const Duration(milliseconds: 450),
              beginOffset: const Offset(-0.2, 0),
              child: _buildDashboardCard(
                context,
                icon: Icons.store,
                title: lang.translate('firms'),
                subtitle: lang.translate('view_firms_subtitle'),
                color: Colors.orange,
                onTap: () => Navigator.pushNamed(context, '/admin/firms'),
              ),
            ),
            const SizedBox(height: 12),
            SlideInAnimation(
              delay: const Duration(milliseconds: 500),
              beginOffset: const Offset(-0.2, 0),
              child: _buildDashboardCard(
                context,
                icon: Icons.admin_panel_settings_outlined,
                title: lang.translate('manage_managers'),
                subtitle: lang.translate('manage_managers_subtitle'),
                color: Colors.orange,
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
            const SizedBox(height: 12),
            SlideInAnimation(
              delay: const Duration(milliseconds: 550),
              beginOffset: const Offset(-0.2, 0),
              child: _buildDashboardCard(
                context,
                icon: Icons.campaign,
                title: lang.translate('notification_center'),
                subtitle: lang.translate('send_custom_messages'),
                color: Colors.redAccent,
                onTap: () => Navigator.pushNamed(context, '/admin/notifications'),
              ),
            ),

            if (!isManager) ...[
              const SizedBox(height: 24),
              FadeInAnimation(
                delay: const Duration(milliseconds: 600),
                child: _buildSectionTitle(lang.translate('insights')),
              ),
              const SizedBox(height: 12),
              SlideInAnimation(
                delay: const Duration(milliseconds: 650),
                beginOffset: const Offset(-0.2, 0),
                child: _buildDashboardCard(
                  context,
                  icon: Icons.insights,
                  title: lang.translate('analytics'),
                  subtitle: lang.translate('view_stats'),
                  color: Colors.teal,
                  onTap: () => Navigator.pushNamed(context, '/admin/analytics'),
                ),
              ),
            ],
            const SizedBox(height: 24),
            FadeInAnimation(
              delay: const Duration(milliseconds: 700),
              child: _buildSectionTitle(lang.translate('settings')),
            ),
            const SizedBox(height: 12),
            SlideInAnimation(
              delay: const Duration(milliseconds: 750),
              beginOffset: const Offset(-0.2, 0),
              child: _buildDashboardCard(
                context,
                icon: Icons.tune,
                title: lang.translate('settings'),
                subtitle: lang.translate('advanced'),
                color: Colors.indigo,
                onTap: () => Navigator.pushNamed(context, '/user/settings'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.grey,
      ),
    );
  }

  Widget _buildDashboardCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return AnimatedCard(
      borderRadius: 8,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ScaleAnimation(
              delay: const Duration(milliseconds: 100),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FadeInAnimation(
                    delay: const Duration(milliseconds: 150),
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            FadeInAnimation(
              delay: const Duration(milliseconds: 200),
              child: Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey.shade400,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
