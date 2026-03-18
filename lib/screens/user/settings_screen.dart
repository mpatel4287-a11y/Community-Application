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

    final bool isStaff = _isAdmin || _role == 'manager' || _role == 'admin';

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: theme.isDarkMode
                ? [Colors.black, Colors.blueGrey.shade900]
                : [Colors.blue.shade50, Colors.white],
          ),
        ),
        child: CustomScrollView(
          slivers: [
            // Premium Sliver App Bar
            SliverAppBar(
              expandedHeight: 220.0,
              floating: false,
              pinned: true,
              stretch: true,
              backgroundColor: Colors.blue.shade900,
              // Remove the centered title to avoid overlap with profile info
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white70),
                  onPressed: () => _showLogoutDialog(lang),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                stretchModes: const [
                  StretchMode.zoomBackground,
                  StretchMode.blurBackground,
                ],
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Background Gradient
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.blue.shade900,
                            Colors.blue.shade800,
                          ],
                        ),
                      ),
                    ),
                    // Decorative patterns
                    Positioned(
                      right: -30,
                      top: -30,
                      child: Icon(
                        Icons.settings,
                        size: 220,
                        color: Colors.white.withOpacity(0.08),
                      ),
                    ),
                    // Profile Info in Header
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),
                        // "Settings" label at the very top
                        Text(
                          lang.translate('settings').toUpperCase(),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 15),
                        Hero(
                          tag: 'profile_pic',
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
                            ),
                            child: CircleAvatar(
                              radius: 38,
                              backgroundColor: Colors.white.withOpacity(0.1),
                              backgroundImage: _currentUser?.photoUrl != null && _currentUser!.photoUrl.isNotEmpty
                                  ? NetworkImage(_currentUser!.photoUrl)
                                  : null,
                              child: _currentUser?.photoUrl == null || _currentUser!.photoUrl.isEmpty
                                  ? Icon(
                                      isStaff ? Icons.admin_panel_settings : Icons.person,
                                      size: 45,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _currentUser?.fullName ?? _familyName ?? 'User',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black12,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_role?.toUpperCase() ?? "MEMBER"} • ${_currentUser?.mid ?? _familyId ?? "N/A"}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Settings Content
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // 1. Personal Section (Always visible)
                  _buildSectionHeader(lang.translate('personal_preferences')),
                  _buildCard([
                    _buildSwitchTile(
                      icon: Icons.notifications_active_outlined,
                      title: lang.translate('notifications'),
                      subtitle: lang.translate('receive_notifications'),
                      value: _notificationsEnabled,
                      onChanged: (value) {
                        setState(() => _notificationsEnabled = value);
                        SessionManager.setNotificationsEnabled(value);
                      },
                      color: Colors.orange,
                    ),
                    _buildSwitchTile(
                      icon: theme.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                      title: lang.translate('Dark Mode'),
                      subtitle: theme.isDarkMode ? 'Deep Shadow' : 'Bright Morning',
                      value: theme.isDarkMode,
                      onChanged: (_) => theme.toggleTheme(),
                      color: Colors.purple,
                    ),
                    _buildActionTile(
                      icon: Icons.text_fields,
                      title: lang.translate('text_size'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildSizeChip('S', _textScale < 0.95, () => _updateTextScale(context, theme, 0.9)),
                          const SizedBox(width: 4),
                          _buildSizeChip('M', _textScale >= 0.95 && _textScale <= 1.05, () => _updateTextScale(context, theme, 1.0)),
                          const SizedBox(width: 4),
                          _buildSizeChip('L', _textScale > 1.05, () => _updateTextScale(context, theme, 1.2)),
                        ],
                      ),
                      color: Colors.teal,
                    ),
                  ]),

                  const SizedBox(height: 24),

                  // 2. Language Section
                  _buildSectionHeader(lang.translate('language')),
                  _buildCard([
                    _buildActionTile(
                      icon: Icons.language,
                      title: 'App Language',
                      subtitle: lang.currentLanguage == 'en' ? 'English' : 'ગુજરાતી',
                      trailing: Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade400),
                      onTap: () => _showLanguagePicker(context, lang),
                      color: Colors.blue,
                    ),
                  ]),

                  const SizedBox(height: 24),

                  // 3. Management Section (STAFF ONLY)
                  if (isStaff) ...[
                    _buildSectionHeader(lang.translate('management')),
                    _buildCard([
                      _buildActionTile(
                        icon: Icons.admin_panel_settings_outlined,
                        title: lang.translate('admin_settings'),
                        subtitle: lang.translate('notification_center'),
                        onTap: () => Navigator.pushNamed(context, '/admin/notifications'),
                        color: Colors.indigo,
                      ),
                      _buildActionTile(
                        icon: Icons.health_and_safety_outlined,
                        title: lang.translate('system_health'),
                        subtitle: lang.translate('view_stats'),
                        onTap: () => Navigator.pushNamed(context, '/admin/system-health'),
                        color: Colors.green,
                        isLast: true,
                      ),
                    ]),
                    const SizedBox(height: 24),
                  ],

                  // 4. Family Section (REGULAR USERS ONLY - Simplified for Admin)
                  if (!isStaff) ...[
                    _buildSectionHeader(lang.translate('family')),
                    _buildCard([
                      _buildActionTile(
                        icon: Icons.account_tree_outlined,
                        title: lang.translate('my_family_tree'),
                        onTap: () {
                          if (_currentUser != null) {
                            Navigator.push(context, MaterialPageRoute(
                              builder: (_) => FamilyTreeView(
                                mainFamilyDocId: _currentUser!.familyDocId,
                                familyName: _currentUser!.familyName,
                              ),
                            ));
                          }
                        },
                        color: Colors.brown,
                      ),
                      _buildActionTile(
                        icon: Icons.people_outline,
                        title: lang.translate('my_family_members'),
                        onTap: () {
                          if (_currentUser != null) {
                            Navigator.push(context, MaterialPageRoute(
                              builder: (_) => MemberListScreen(
                                isGlobal: false,
                                familyDocId: _currentUser!.familyDocId,
                                subFamilyDocId: _currentUser!.subFamilyDocId,
                                familyName: _currentUser!.familyName,
                              ),
                            ));
                          }
                        },
                        color: Colors.blueGrey,
                      ),
                      _buildActionTile(
                        icon: Icons.badge_outlined,
                        title: lang.translate('digital_id'),
                        onTap: () {
                          if (_currentUser != null) {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => DigitalIdScreen(member: _currentUser!)));
                          }
                        },
                        color: Colors.deepOrange,
                        isLast: true,
                      ),
                    ]),
                    const SizedBox(height: 24),
                  ],

                  // 5. Support & About
                  _buildSectionHeader(lang.translate('support')),
                  _buildCard([
                    _buildActionTile(
                      icon: Icons.help_outline,
                      title: lang.translate('help_faq'),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpFaqScreen())),
                      color: Colors.lightBlue,
                    ),
                    _buildActionTile(
                      icon: Icons.info_outline,
                      title: lang.translate('about'),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen())),
                      color: Colors.grey,
                    ),
                    _buildActionTile(
                      icon: Icons.restore,
                      title: lang.translate('reset_settings'),
                      subtitle: 'Restore to default values',
                      onTap: () => _resetSettings(context),
                      color: Colors.redAccent,
                      isLast: true,
                    ),
                  ]),

                  const SizedBox(height: 40),

                  // Logout
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ElevatedButton(
                      onPressed: () => _showLogoutDialog(lang),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.logout),
                          const SizedBox(width: 12),
                          Text(
                            lang.translate('logout').toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Footer
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'Version 1.0.0',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Crafted with premium care by Team',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: Colors.blue.shade900.withOpacity(0.7),
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withOpacity(0.05)
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    Widget? trailing,
    required Color color,
    bool isLast = false,
  }) {
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          subtitle: subtitle != null
              ? Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 12))
              : null,
          trailing: trailing ?? Icon(Icons.chevron_right, color: Colors.grey.shade300),
          onTap: onTap,
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: 70,
            endIndent: 20,
            color: Colors.grey.withOpacity(0.1),
          ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color color,
    bool isLast = false,
  }) {
    return Column(
      children: [
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          secondary: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          subtitle: Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          value: value,
          onChanged: onChanged,
          activeColor: Colors.blue.shade800,
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: 70,
            endIndent: 20,
            color: Colors.grey.withOpacity(0.1),
          ),
      ],
    );
  }

  Widget _buildSizeChip(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade800 : Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.blue.shade800,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  void _showLanguagePicker(BuildContext context, LanguageService lang) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select Language',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              _buildLanguageOption(
                context, 
                'English', 
                lang.currentLanguage == 'en', 
                () => lang.setLanguage('en')
              ),
              const SizedBox(height: 12),
              _buildLanguageOption(
                context, 
                'ગુજરાતી (Gujarati)', 
                lang.currentLanguage == 'gu', 
                () => lang.setLanguage('gu')
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLanguageOption(BuildContext context, String title, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: () {
        onTap();
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue.shade200 : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Text(title, style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.blue.shade900 : Colors.black87,
            )),
            const Spacer(),
            if (isSelected) Icon(Icons.check_circle, color: Colors.blue.shade800),
          ],
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

    // Confirmation dialog for reset
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Settings?'),
        content: const Text('This will restore all preferences (theme, language, text size) to default.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Reset', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

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
        SnackBar(
          content: Text(lang.translate('reset_done')),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _showLogoutDialog(LanguageService lang) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(lang.translate('logout')),
        content: Text(lang.translate('confirm_logout')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(lang.translate('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(lang.translate('logout'), style: const TextStyle(color: Colors.white)),
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
