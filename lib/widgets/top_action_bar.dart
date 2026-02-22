// lib/widgets/top_action_bar.dart

// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';
import '../services/session_manager.dart';
import '../services/member_service.dart';
import 'animated_theme_toggle.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Top action bar widget with notification, theme toggle, and profile
/// Designed for top-right placement in app bars
class TopActionBar extends StatefulWidget {
  final VoidCallback? onNotificationTap;
  final VoidCallback? onProfileTap;
  final bool showProfile;
  final double iconSize;

  const TopActionBar({
    super.key,
    this.onNotificationTap,
    this.onProfileTap,
    this.showProfile = true,
    this.iconSize = 24,
  });

  @override
  State<TopActionBar> createState() => _TopActionBarState();
}

class _TopActionBarState extends State<TopActionBar> {
  String? _profileImageUrl;
  String? _profileInitials;
  bool _hasNotificationBadge = false;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
    _checkNotifications();
  }

  Future<void> _loadProfileData() async {
    if (!widget.showProfile) return;

    try {
      final memberDocId = await SessionManager.getMemberDocId();
      final mainFamilyDocId = await SessionManager.getFamilyDocId();
      final subFamilyDocId = await SessionManager.getSubFamilyDocId();

      if (memberDocId != null && mainFamilyDocId != null) {
        final memberService = MemberService();
        final member = await memberService.getMember(
          mainFamilyDocId: mainFamilyDocId,
          subFamilyDocId: subFamilyDocId ?? '',
          memberId: memberDocId,
        );

        if (member != null && mounted) {
          setState(() {
            _profileImageUrl = member.photoUrl;
            _profileInitials = member.fullName.isNotEmpty
                ? member.fullName[0].toUpperCase()
                : '?';
          });
        }
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _checkNotifications() async {
    // TODO: Implement actual notification badge check
    // For now, we'll leave it as false
    setState(() {
      _hasNotificationBadge = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final isDark = themeService.isDarkMode;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Notification Icon
        _buildNotificationButton(isDark),

        const SizedBox(width: 8),

        // Animated Theme Toggle
        const AnimatedThemeToggle(size: 40),

        if (widget.showProfile) ...[
          const SizedBox(width: 8),

          // Profile Icon/Avatar
          _buildProfileButton(isDark),
        ],
      ],
    );
  }

  Widget _buildNotificationButton(bool isDark) {
    return Stack(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.transparent,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap:
                  widget.onNotificationTap ??
                  () {
                    // Default action - could show notification list
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Notifications'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
              child: Icon(
                Icons.notifications_outlined,
                size: widget.iconSize,
                color: Colors.white,
              ),
            ),
          ),
        ),
        if (_hasNotificationBadge)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProfileButton(bool isDark) {
    return GestureDetector(
      onTap:
          widget.onProfileTap ??
          () {
            // Default action - navigate to settings (which has profile info)
            Navigator.pushNamed(context, '/user/settings');
          },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
        ),
        child: ClipOval(
          child:
              _profileImageUrl != null &&
                  _profileImageUrl!.isNotEmpty &&
                  _profileImageUrl!.startsWith('http')
              ? CachedNetworkImage(
                  imageUrl: _profileImageUrl!,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) {
                    return _buildProfilePlaceholder();
                  },
                )
              : _buildProfilePlaceholder(),
        ),
      ),
    );
  }

  Widget _buildProfilePlaceholder() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue.shade400, Colors.blue.shade700],
        ),
      ),
      child: Center(
        child: Text(
          _profileInitials ?? '?',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
