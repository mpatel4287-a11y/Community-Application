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
import '../admin/family_list_screen.dart';
import 'help_faq_screen.dart';
import 'about_screen.dart';
import 'privacy_policy_screen.dart';
import 'member_update_request_screen.dart';
import '../admin/admin_update_requests_screen.dart';
import '../../widgets/full_screen_image_viewer.dart';
import '../../services/update_request_service.dart';
import '../../models/member_update_request_model.dart';
import '../../services/admin_management_service.dart';
import '../../services/session_watcher_service.dart';

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
  final UpdateRequestService _updateRequestService = UpdateRequestService();
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
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.05),
              Theme.of(context).scaffoldBackgroundColor,
            ],
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
              backgroundColor: Theme.of(context).colorScheme.primary,
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
                            Theme.of(context).colorScheme.primary,
                            Theme.of(context).colorScheme.secondary,
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
                        GestureDetector(
                          onLongPress: () {
                            if (_currentUser?.photoUrl != null && _currentUser!.photoUrl.isNotEmpty) {
                              FullScreenImageViewer.show(context, _currentUser!.photoUrl, tag: 'settings_profile');
                            }
                          },
                          child: Hero(
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
                        icon: Icons.published_with_changes_rounded,
                        title: lang.translate('member_update_requests'),
                        subtitle: lang.translate('manage_update_requests_subtitle'),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AdminUpdateRequestsScreen()),
                        ),
                        color: const Color(0xFF0F766E),
                      ),
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
                        icon: Icons.groups_2_outlined,
                        title: 'All Families & Sub-Families',
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) => const FamilyListScreen(),
                          ));
                        },
                        color: Colors.indigo,
                      ),
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
                      ),
                      _buildActionTile(
                        icon: Icons.published_with_changes_rounded,
                        title: 'Request Profile & Data Update',
                        subtitle: 'Request details or photo update',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MemberUpdateRequestScreen(targetMember: _currentUser),
                            ),
                          );
                        },
                        color: Colors.purple,
                        isLast: true,
                      ),
                    ]),
                    const SizedBox(height: 24),
                  ],

                  // 5. Security & Account
                  _buildSectionHeader(lang.translate('security')),
                  _buildCard([
                    _buildActionTile(
                      icon: Icons.lock_reset_rounded,
                      title: lang.translate('change_password'),
                      subtitle: lang.translate('change_password_subtitle'),
                      onTap: () => _showChangePasswordDialog(lang),
                      color: Colors.blueAccent,
                      isLast: true,
                    ),
                  ]),

                  const SizedBox(height: 24),

                  // 6. Support & Legal
                  _buildSectionHeader(lang.translate('support')),
                  _buildCard([
                    _buildActionTile(
                      icon: Icons.help_outline,
                      title: lang.translate('help_faq'),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpFaqScreen())),
                      color: Colors.lightBlue,
                    ),
                    _buildActionTile(
                      icon: Icons.privacy_tip_outlined,
                      title: 'Privacy Policy & Terms',
                      subtitle: 'Data safety and terms of use',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen())),
                      color: Colors.teal,
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
                      color: Colors.amber.shade700,
                    ),
                    _buildActionTile(
                      icon: Icons.delete_forever_outlined,
                      title: 'Delete Account & Data',
                      subtitle: 'Request permanent account deletion',
                      onTap: () => _showDeleteAccountDialog(),
                      color: Colors.redAccent,
                      isLast: true,
                    ),
                  ]),

                  const SizedBox(height: 32),

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
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
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
          activeColor: Theme.of(context).colorScheme.primary,
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
          color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.primary,
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
          color: isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.1) : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Text(title, style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface,
            )),
            const Spacer(),
            if (isSelected) Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary),
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
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    }
  }

  Future<void> _showDeleteAccountDialog() async {
    // Resolve member details
    final memberDocId = await SessionManager.getMemberDocId() ?? _currentUser?.id ?? '';
    final memberMid = await SessionManager.getMemberId() ?? _currentUser?.mid ?? '';
    final familyDocId = await SessionManager.getFamilyDocId() ?? _currentUser?.familyDocId ?? '';
    final subFamilyDocId = await SessionManager.getSubFamilyDocId() ?? _currentUser?.subFamilyDocId ?? '';

    // Check if there is already an active pending deletion request
    MemberUpdateRequestModel? pendingReq;
    try {
      pendingReq = await _updateRequestService.getPendingDeletionRequest(
        memberId: memberDocId,
        memberMid: memberMid,
      );
    } catch (_) {}

    if (!mounted) return;

    if (pendingReq != null) {
      // Show pending status modal
      final withdraw = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.hourglass_top_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Expanded(
                child: Text('Deletion Request Pending', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Status: Awaiting Administrator Approval',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Requested on: ${pendingReq!.createdAt.day}/${pendingReq.createdAt.month}/${pendingReq.createdAt.year}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Your account remains active and normal as usual. It will only be permanently deleted once an administrator accepts and approves your request.\n\nIf the admin rejects the request, your account will stay normal.',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
              if (pendingReq.description.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Reason note: "${pendingReq.description}"',
                  style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Close'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.cancel_outlined, size: 16, color: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              label: const Text('Withdraw Request', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (withdraw == true && mounted) {
        try {
          await _updateRequestService.cancelRequest(pendingReq.id);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account deletion request withdrawn. Your account remains normal and active.'),
              backgroundColor: Colors.green,
            ),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error withdrawing request: $e'), backgroundColor: Colors.red),
          );
        }
      }
      return;
    }

    // No pending request: show request creation dialog
    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Expanded(
              child: Text('Delete Account & Data', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Are you sure you want to request account deletion?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Under Google Play Data Safety policies, you have the right to request permanent deletion of your profile, authentication credentials, and uploaded photos.',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.25)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• Your deletion request will be sent to the administrator for review.\n• When the admin accepts, your account will get deleted.\n• If the admin rejects, your account will stay normal as usual.\n• Your account remains active while the request is pending.',
                      style: TextStyle(fontSize: 12, height: 1.45, color: Colors.blueGrey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: reasonController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Reason for deletion (Optional)',
                  hintText: 'Enter reason or details...',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.all(10),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Submit Request to Admin', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        final request = MemberUpdateRequestModel(
          id: '',
          memberId: memberDocId.isNotEmpty ? memberDocId : memberMid,
          memberMid: memberMid,
          memberName: _currentUser?.fullName ?? _familyName ?? 'Member',
          familyDocId: familyDocId,
          subFamilyDocId: subFamilyDocId,
          familyName: _familyName ?? _currentUser?.familyName ?? '',
          requestedByPhone: _currentUser?.phone ?? '',
          requestType: 'account_deletion',
          title: 'Permanent Account Deletion Request',
          description: reasonController.text.trim().isNotEmpty
              ? reasonController.text.trim()
              : 'User requested permanent account deletion under Data Safety policy.',
          status: 'pending',
          createdAt: DateTime.now(),
        );

        await _updateRequestService.submitRequest(request: request);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Account deletion request submitted to admin. Your account remains normal until approved.'),
              backgroundColor: Colors.teal.shade700,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to submit deletion request: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _showChangePasswordDialog(LanguageService lang) async {
    final currentPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    String? errorMessage;
    bool isSubmitting = false;

    await showDialog(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.lock_reset_rounded, color: Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      lang.translate('change_password'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.security_update_good_rounded, color: Colors.amber.shade900, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Changing your password will automatically log you out from all active devices.',
                              style: TextStyle(fontSize: 12, color: Colors.amber.shade900, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Current Password
                    TextField(
                      controller: currentPassCtrl,
                      obscureText: obscureCurrent,
                      decoration: InputDecoration(
                        labelText: lang.translate('current_password'),
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(obscureCurrent ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setDialogState(() => obscureCurrent = !obscureCurrent),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // New Password
                    TextField(
                      controller: newPassCtrl,
                      obscureText: obscureNew,
                      decoration: InputDecoration(
                        labelText: lang.translate('new_password'),
                        prefixIcon: const Icon(Icons.lock_reset),
                        suffixIcon: IconButton(
                          icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Confirm New Password
                    TextField(
                      controller: confirmPassCtrl,
                      obscureText: obscureConfirm,
                      decoration: InputDecoration(
                        labelText: lang.translate('confirm_new_password'),
                        prefixIcon: const Icon(Icons.check_circle_outline),
                        suffixIcon: IconButton(
                          icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red.shade700, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
                  child: Text(lang.translate('cancel')),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final currentP = currentPassCtrl.text.trim();
                          final newP = newPassCtrl.text.trim();
                          final confirmP = confirmPassCtrl.text.trim();

                          if (currentP.isEmpty) {
                            setDialogState(() => errorMessage = 'Please enter your current password.');
                            return;
                          }
                          if (newP.length < 4) {
                            setDialogState(() => errorMessage = 'New password must be at least 4 characters long.');
                            return;
                          }
                          if (newP == currentP) {
                            setDialogState(() => errorMessage = 'New password must be different from current password.');
                            return;
                          }
                          if (newP != confirmP) {
                            setDialogState(() => errorMessage = 'New passwords do not match.');
                            return;
                          }

                          setDialogState(() {
                            isSubmitting = true;
                            errorMessage = null;
                          });

                          try {
                            final savedPassword = await SessionManager.getSessionPassword();
                            final isSuper = await SessionManager.isSuperAdmin();
                            final isAdmin = await SessionManager.getIsAdmin() == true;
                            final role = await SessionManager.getRole();

                            // Verify current password against session or member object
                            if (savedPassword != null && savedPassword.isNotEmpty) {
                              if (savedPassword != currentP) {
                                setDialogState(() {
                                  isSubmitting = false;
                                  errorMessage = 'Current password is incorrect.';
                                });
                                return;
                              }
                            } else if (_currentUser != null && _currentUser!.password.isNotEmpty) {
                              if (_currentUser!.password != currentP) {
                                setDialogState(() {
                                  isSubmitting = false;
                                  errorMessage = 'Current password is incorrect.';
                                });
                                return;
                              }
                            }

                            // Perform update based on user role
                            if (isSuper) {
                              await AdminManagementService().updateMainAdminPassword(newP);
                            } else if (isAdmin || role == 'admin') {
                              await AdminManagementService().updateSubAdminPassword(newP);
                            } else {
                              final familyDocId = await SessionManager.getFamilyDocId() ?? _currentUser?.familyDocId ?? '';
                              final subFamilyDocId = await SessionManager.getSubFamilyDocId() ?? _currentUser?.subFamilyDocId ?? '';
                              final memberDocId = await SessionManager.getMemberDocId() ?? _currentUser?.id ?? '';

                              if (familyDocId.isEmpty || memberDocId.isEmpty) {
                                throw Exception('Could not resolve member credentials.');
                              }

                              await _memberService.updateMember(
                                mainFamilyDocId: familyDocId,
                                subFamilyDocId: subFamilyDocId,
                                memberId: memberDocId,
                                updates: {'password': newP},
                              );
                            }

                            Navigator.pop(dialogCtx);

                            // Stop watcher & clear session on this device
                            await SessionWatcherService().stopWatching();
                            await SessionManager.clearSession();

                            if (mounted) {
                              Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil('/login', (route) => false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Password changed successfully! You have been logged out from all devices. Please log in with your new password.'),
                                  backgroundColor: Colors.green,
                                  duration: Duration(seconds: 5),
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() {
                              isSubmitting = false;
                              errorMessage = 'Failed to change password: $e';
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(lang.translate('save')),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
