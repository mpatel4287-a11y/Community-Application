// lib/screens/user/settings_screen.dart

// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/session_manager.dart';
import '../../services/auth_service.dart';
import '../../services/language_service.dart';
import '../../services/theme_service.dart';
import '../../models/member_model.dart';
import '../../services/member_service.dart';
import 'family_tree_view.dart';
import 'digital_id_screen.dart';
import '../admin/member_list_screen.dart';
import 'help_faq_screen.dart';
import 'about_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  String? _familyName;
  String? _familyId;
  String? _role;
  bool _isAdmin = false;
  double _textScale = 1.0;
  
  final MemberService _memberService = MemberService();
  MemberModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final familyName = await SessionManager.getFamilyName();
    final familyId = await SessionManager.getFamilyId();
    final role = await SessionManager.getRole();
    final isAdmin = await SessionManager.getIsAdmin() ?? false;
    final notificationsEnabled = await SessionManager.getNotificationsEnabled();
    
    final familyDocId = await SessionManager.getFamilyDocId();
    final subFamilyDocId = await SessionManager.getSubFamilyDocId();
    final memberId = await SessionManager.getMemberDocId();

    if (familyDocId != null && memberId != null) {
      _currentUser = await _memberService.getMember(
        mainFamilyDocId: familyDocId,
        subFamilyDocId: subFamilyDocId ?? '',
        memberId: memberId,
      );
    }

    setState(() {
      _familyName = familyName;
      _familyId = familyId?.toString();
      _role = role;
      _isAdmin = isAdmin;
      _notificationsEnabled = notificationsEnabled;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageService>(context);
    final theme = Provider.of<ThemeService>(context);

    _textScale = theme.textScale;

    return Scaffold(
      appBar: AppBar(
        title: Text(lang.translate('settings')),
        backgroundColor: Colors.blue.shade900,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile Section
          _buildSectionHeader(lang.translate('profile')),
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.blue,
                child: Icon(Icons.person, color: Colors.white),
              ),
              title: Text(_familyName ?? 'User'),
              subtitle: Text(
                'ID: ${_familyId ?? "N/A"} • ${_role ?? "member"}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // Navigate to profile edit (can be wired to profile screen)
              },
            ),
          ),
          const SizedBox(height: 24),

          // Preferences Section
          _buildSectionHeader(lang.translate('preferences')),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(lang.translate('notifications')),
                  subtitle: Text(lang.translate('receive_notifications')),
                  value: _notificationsEnabled,
                  onChanged: (value) {
                    setState(() => _notificationsEnabled = value);
                    SessionManager.setNotificationsEnabled(value);
                  },
                ),
                const Divider(),
                SwitchListTile(
                  title: Text(lang.translate('Dark Mode')),
                  subtitle: Text(lang.translate('Use Dark Theme')),
                  value: theme.isDarkMode,
                  onChanged: (_) {
                    theme.toggleTheme();
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.text_fields),
                  title: Text(lang.translate('text_size')),
                  subtitle: Row(
                    children: [
                      ChoiceChip(
                        label: Text(lang.translate('text_size_small')),
                        selected: _textScale < 0.95,
                        onSelected: (_) =>
                            _updateTextScale(context, theme, 0.9),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text(lang.translate('text_size_normal')),
                        selected: _textScale >= 0.95 && _textScale <= 1.05,
                        onSelected: (_) =>
                            _updateTextScale(context, theme, 1.0),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text(lang.translate('text_size_large')),
                        selected: _textScale > 1.05,
                        onSelected: (_) =>
                            _updateTextScale(context, theme, 1.2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Language Section
          _buildSectionHeader(lang.translate('language')),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('English'),
                  trailing: lang.currentLanguage == 'en'
                      ? const Icon(Icons.check, color: Colors.green)
                      : null,
                  onTap: () => lang.setLanguage('en'),
                ),
                const Divider(),
                ListTile(
                  title: const Text('ગુજરાતી (Gujarati)'),
                  trailing: lang.currentLanguage == 'gu'
                      ? const Icon(Icons.check, color: Colors.green)
                      : null,
                  onTap: () => lang.setLanguage('gu'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Family Section
          _buildSectionHeader(lang.translate('family')),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.account_tree),
                  title: Text(lang.translate('my_family_tree')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    if (_currentUser != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FamilyTreeView(
                            mainFamilyDocId: _currentUser!.familyDocId,
                            familyName: _currentUser!.familyName,
                          ),
                        ),
                      );
                    }
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.people),
                  title: Text(lang.translate('my_family_members')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    if (_currentUser != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MemberListScreen(
                            isGlobal: false,
                            familyDocId: _currentUser!.familyDocId,
                            subFamilyDocId: _currentUser!.subFamilyDocId,
                            familyName: _currentUser!.familyName,
                          ),
                        ),
                      );
                    }
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.badge_rounded),
                  title: Text(lang.translate('digital_id')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    if (_currentUser != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DigitalIdScreen(member: _currentUser!),
                        ),
                      );
                    } else {
                       ScaffoldMessenger.of(context).showSnackBar(
                         const SnackBar(content: Text('Loading user data...'))
                       );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Support Section
          _buildSectionHeader(lang.translate('support')),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.help),
                  title: Text(lang.translate('help_faq')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpFaqScreen()));
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.info),
                  title: Text(lang.translate('about')),
                  subtitle: const Text('Community App'),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen()));
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Advanced / Admin Section
          _buildSectionHeader(lang.translate('advanced')),
          Card(
            child: Column(
              children: [
                if (_isAdmin) ...[
                  ListTile(
                    leading: const Icon(Icons.admin_panel_settings),
                    title: Text(lang.translate('admin_settings')),
                    subtitle: Text(lang.translate('notification_center')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.pushNamed(context, '/admin/notifications');
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.health_and_safety),
                    title: Text(lang.translate('system_health')),
                    subtitle: Text(lang.translate('view_stats')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.pushNamed(context, '/admin/system-health');
                    },
                  ),
                  const Divider(),
                ],
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.restore),
                  title: Text(lang.translate('reset_settings')),
                  subtitle: Text(lang.translate('reset_settings_desc')),
                  onTap: () => _resetSettings(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Logout Button
          ElevatedButton.icon(
            icon: const Icon(Icons.logout),
            label: Text(lang.translate('logout')),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => _showLogoutDialog(lang),
          ),
          const SizedBox(height: 16),

          // Version Info
          Center(
            child: Column(
              children: [
                Text(
                  'Version 1.0.0',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
                const SizedBox(height: 8),
                Text(
                  'Created by Meet Patel',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }

  Future<void> _updateTextScale(
    BuildContext context,
    ThemeService theme,
    double scale,
  ) async {
    setState(() {
      _textScale = scale;
    });
    await theme.setTextScale(scale);
  }

  Future<void> _resetSettings(BuildContext context) async {
    final lang = Provider.of<LanguageService>(context, listen: false);
    final theme = Provider.of<ThemeService>(context, listen: false);

    // Ensure light theme
    if (theme.isDarkMode) {
      await theme.toggleTheme();
    }

    await theme.setTextScale(1.0);
    await lang.setLanguage('en');
    await SessionManager.setNotificationsEnabled(true);

    if (mounted) {
      setState(() {
        _notificationsEnabled = true;
        _textScale = 1.0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(lang.translate('reset_done'))),
      );
    }
  }

  Future<void> _showLogoutDialog(LanguageService lang) async {
    final confirm = await showDialog<bool>(
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(lang.translate('logout')),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AuthService().logout();
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

}

