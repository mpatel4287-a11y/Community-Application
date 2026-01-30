// lib/screens/user/member_detail_screen.dart

// ignore_for_file: unused_field, unused_element, unnecessary_underscores

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/member_model.dart';
import '../../../services/member_service.dart';
import '../../../services/session_manager.dart';
import '../../../services/language_service.dart';
import 'package:provider/provider.dart';

// Helper widget to handle profile images with error handling
class ProfileImage extends StatefulWidget {
  final String? photoUrl;
  final String fullName;
  final double radius;
  final VoidCallback? onLongPress;

  const ProfileImage({
    super.key,
    this.photoUrl,
    required this.fullName,
    this.radius = 60,
    this.onLongPress,
  });

  @override
  State<ProfileImage> createState() => _ProfileImageState();
}

class _ProfileImageState extends State<ProfileImage> {
  bool _hasError = false;

  @override
  Widget build(BuildContext context) {
    final photoUrl = widget.photoUrl ?? '';
    final hasValidUrl = photoUrl.isNotEmpty && photoUrl.startsWith('http');

    Widget imageContent;
    if (!hasValidUrl || _hasError) {
      imageContent = CircleAvatar(
        radius: widget.radius,
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: Text(
          widget.fullName.isNotEmpty ? widget.fullName[0].toUpperCase() : '?',
          style: TextStyle(
            fontSize: widget.radius * 0.6,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
      );
    } else {
      imageContent = CircleAvatar(
        radius: widget.radius,
        backgroundColor: Colors.blue.shade900,
        backgroundImage: NetworkImage(photoUrl),
        onBackgroundImageError: (_, __) {
          if (mounted) {
            setState(() => _hasError = true);
          }
        },
      );
    }

    if (widget.onLongPress != null) {
      return GestureDetector(
        onLongPress: widget.onLongPress,
        child: imageContent,
      );
    }
    return imageContent;
  }
}

/// Attractive loading spinner widget
class _LoadingSpinner extends StatefulWidget {
  const _LoadingSpinner();

  @override
  State<_LoadingSpinner> createState() => _LoadingSpinnerState();
}

class _LoadingSpinnerState extends State<_LoadingSpinner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _rotationAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.2), weight: 1),
      TweenSequenceItem(tween: Tween<double>(begin: 1.2, end: 1.0), weight: 1),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Transform.rotate(
            angle: _rotationAnimation.value * 2 * 3.14159,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    Colors.blue.shade400,
                    Colors.blue.shade700,
                    Colors.blue.shade900,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.person,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
        );
      },
    );
  }
}

class MemberDetailScreen extends StatefulWidget {
  final String memberId;
  final String? familyDocId;
  final String? subFamilyDocId; // NEW: Optional sub-family ID

  const MemberDetailScreen({
    super.key,
    required this.memberId,
    this.familyDocId,
    this.subFamilyDocId,
  });

  @override
  State<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends State<MemberDetailScreen> {
  final MemberService _memberService = MemberService();
  MemberModel? _member;
  bool _loading = true;
  String? _familyDocId;
  String? _currentUserRole;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadMember();
  }

  Future<void> _loadMember() async {
    setState(() => _loading = true);
    
    try {
      MemberModel? member;
      
      // If familyDocId and subFamilyDocId are provided, use them
      if (widget.familyDocId != null && widget.familyDocId!.isNotEmpty &&
          widget.subFamilyDocId != null && widget.subFamilyDocId!.isNotEmpty) {
        member = await _memberService.getMember(
          mainFamilyDocId: widget.familyDocId!,
          subFamilyDocId: widget.subFamilyDocId!,
          memberId: widget.memberId,
        );
        if (member != null) {
          setState(() {
            _member = member;
            _familyDocId = widget.familyDocId;
            _loading = false;
          });
          return;
        }
      }
      
      // If not found or IDs not provided, search across all families
      final allMembers = await _memberService.getAllMembers();
      member = allMembers.firstWhere(
        (m) => m.id == widget.memberId,
        orElse: () => allMembers.firstWhere(
          (m) => m.mid == widget.memberId,
          orElse: () => throw Exception('Member not found'),
        ),
      );
      
      final isAdmin = await SessionManager.getIsAdmin() ?? false;
      final userRole = await SessionManager.getRole() ?? 'member';

      setState(() {
        _member = member;
        _familyDocId = member?.familyDocId ?? widget.familyDocId ?? '';
        _isAdmin = isAdmin;
        _currentUserRole = userRole;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading member: $e');
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  String _generateShareText() {
    if (_member == null) return '';
    final m = _member!;
    return '''
${m.fullName} ${m.surname}
Member ID: ${m.mid}
Family: ${m.familyName}
Phone: ${m.phone}
${m.address.isNotEmpty ? 'Address: ${m.address}' : ''}
${m.bloodGroup.isNotEmpty ? 'Blood Group: ${m.bloodGroup}' : ''}
''';
  }

  Future<void> _shareNormally() async {
    if (_member == null) return;
    await Share.share(
      _generateShareText(),
      subject: '${_member!.fullName} Profile',
    );
  }

  void _showShareOptions() {
    final lang = Provider.of<LanguageService>(context, listen: false);
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              lang.translate('share_profile'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.badge_rounded, color: Colors.blue),
              title: Text(lang.translate('digital_id')),
              onTap: () {
                Navigator.pop(context);
                if (_member != null) {
                  Navigator.pushNamed(
                    context,
                    '/user/digital-id',
                    arguments: _member,
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.share, color: Colors.green),
              title: Text(lang.translate('share')),
              onTap: () {
                Navigator.pop(context);
                _shareNormally();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleManagerRole() async {
    if (_member == null || _familyDocId == null) return;
    
    final lang = Provider.of<LanguageService>(context, listen: false);
    final isCurrentlyManager = _member!.role == 'manager';
    final nextRole = isCurrentlyManager ? 'member' : 'manager';
    final actionText = isCurrentlyManager ? lang.translate('demote_to_member').toLowerCase() : lang.translate('promote_to_manager').toLowerCase();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isCurrentlyManager ? lang.translate('demote_member') : lang.translate('promote_member')),
        content: Text('${lang.translate('are_you_sure_role')} $actionText ${_member!.fullName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(lang.translate('cancel'))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(isCurrentlyManager ? lang.translate('demote') : lang.translate('promote')),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _loading = true);
      try {
        await _memberService.updateMemberRole(
          mainFamilyDocId: _familyDocId!,
          subFamilyDocId: widget.subFamilyDocId ?? '',
          memberId: _member!.id,
          newRole: nextRole,
        );
        await _loadMember(); // Reload to update UI
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(isCurrentlyManager ? lang.translate('demoted_success') : lang.translate('promoted_success'))),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${lang.translate('error')}: $e'), backgroundColor: Colors.red),
          );
        }
        setState(() => _loading = false);
      }
    }
  }

  void _showFullScreenImage(String? photoUrl, String fullName) {
    if (photoUrl == null || photoUrl.isEmpty || !photoUrl.startsWith('http')) return;

    showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (context) => Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 30),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: InteractiveViewer(
            panEnabled: true,
            minScale: 0.5,
            maxScale: 4.0,
            child: Hero(
              tag: 'full_profile_$photoUrl',
              child: Image.network(
                photoUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const _LoadingSpinner();
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageService>(context);

    if (_loading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const _LoadingSpinner(),
              const SizedBox(height: 24),
              Text(
                lang.translate('loading'),
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_member == null) {
      return Scaffold(
        appBar: AppBar(backgroundColor: Theme.of(context).colorScheme.primary),
        body: Center(child: Text(lang.translate('member_not_found'))),
      );
    }

    final member = _member!;

    // Theme colors
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? theme.scaffoldBackgroundColor : const Color(0xFFF8FAFC);
    final cardColor = isDark ? theme.cardColor : Colors.white;
    final primaryText = theme.textTheme.bodyLarge?.color ?? (isDark ? Colors.white : const Color(0xFF1E293B));
    final secondaryText = theme.textTheme.bodyMedium?.color?.withOpacity(0.7) ?? (isDark ? Colors.white70 : const Color(0xFF64748B));

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0,
        centerTitle: true,
        title: Text(
          lang.translate('member_details'),
          style: TextStyle(
            color: primaryText,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: secondaryText, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.share_outlined, color: theme.colorScheme.primary),
            onPressed: _showShareOptions,
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // Immersive Profile Header
            _buildPremiumHeader(member, lang),
            
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(
                children: [
                  // Quick Action Row (Integrated style)
                  _buildPremiumQuickActions(member, lang),
                  
                  const SizedBox(height: 24),
                  
                  // Personal Information Block
                  _buildPremiumSection(
                    title: lang.translate('personal_info'),
                    icon: Icons.person_rounded,
                    children: [
                      _buildPremiumRow(
                        lang.translate('full_name'), 
                        member.surname.isNotEmpty 
                          ? '${member.fullName} ${member.surname}' 
                          : member.fullName, 
                        Icons.person_outline
                      ),
                      _buildPremiumRow(lang.translate('age'), '${member.age} ${lang.translate('years')}', Icons.cake_outlined),
                      _buildPremiumRow(lang.translate('birth_date'), member.birthDate, Icons.calendar_today_rounded),
                      if (member.bloodGroup.isNotEmpty)
                        _buildPremiumRow(lang.translate('blood_group'), member.bloodGroup, Icons.bloodtype_outlined),
                      _buildPremiumRow(lang.translate('marriage_status'), lang.translate(member.marriageStatus.toLowerCase()), Icons.favorite_border_rounded),
                      if (member.education.isNotEmpty)
                        _buildPremiumRow(lang.translate('education'), member.education, Icons.school_outlined),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Heritage & Origins Block
                  _buildPremiumSection(
                    title: 'Heritage & Origins',
                    icon: Icons.history_edu_rounded,
                    children: [
                      if (member.fatherName.isNotEmpty)
                        _buildPremiumRow(lang.translate('father_name'), member.fatherName, Icons.person_pin_rounded),
                      if (member.motherName.isNotEmpty)
                        _buildPremiumRow(lang.translate('mother_name'), member.motherName, Icons.person_pin_rounded),
                      if (member.nativeHome.isNotEmpty)
                        _buildPremiumRow(lang.translate('native_home'), member.nativeHome, Icons.home_rounded),
                      if (member.gotra.isNotEmpty)
                        _buildPremiumRow(lang.translate('gotra'), member.gotra, Icons.account_tree_outlined),
                      _buildPremiumRow('Surdhan', member.surdhan, Icons.auto_awesome_rounded),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Family Details Block
                  _buildPremiumSection(
                    title: lang.translate('Family Info'),
                    icon: Icons.people_alt_rounded,
                    children: [
                      _buildPremiumRow(lang.translate('Family Name'), member.familyName, Icons.family_restroom_rounded),
                      _buildPremiumRow('DKT Family ID', member.familyId, Icons.vpn_key_rounded),
                      if (member.parentMid.isNotEmpty)
                        _buildPremiumRow(lang.translate('parent_mid'), member.parentMid, Icons.link_rounded),
                      if (member.tod.isNotEmpty)
                        _buildPremiumRow(lang.translate('date_of_death'), member.tod, Icons.heart_broken_rounded, isDestructive: true),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Contact & Location Block
                  _buildPremiumSection(
                    title: lang.translate('contact_info'),
                    icon: Icons.contact_mail_rounded,
                    children: [
                      _buildPremiumRow(lang.translate('phone'), member.phone, Icons.phone_enabled_rounded),
                      if (member.email.isNotEmpty)
                        _buildPremiumRow('Email Address', member.email, Icons.alternate_email_rounded),
                      _buildPremiumLocationRow(
                        lang.translate('address'),
                        member.address,
                        member.googleMapLink,
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Social Presence Block
                  _buildPremiumSection(
                    title: 'Social Presence',
                    icon: Icons.public_rounded,
                    children: [
                      if (member.whatsapp.isNotEmpty)
                        _buildPremiumSocialRow('WhatsApp', member.whatsapp, Icons.chat_bubble_outline_rounded),
                      if (member.instagram.isNotEmpty)
                        _buildPremiumSocialRow('Instagram', member.instagram, Icons.camera_alt_outlined),
                      if (member.facebook.isNotEmpty)
                        _buildPremiumSocialRow('Facebook', member.facebook, Icons.facebook_rounded),
                    ],
                  ),

                  if (member.firms.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildPremiumSection(
                      title: 'Firms & Business',
                      icon: Icons.business_center_rounded,
                      children: member.firms.map((firm) => _buildPremiumFirmRow(firm)).toList(),
                    ),
                  ],

                  if (_isAdmin) ...[
                    const SizedBox(height: 24),
                    _buildAdminControlCard(member, lang),
                  ],
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumHeader(MemberModel member, LanguageService lang) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? theme.cardColor : Colors.white;
    final primaryText = theme.textTheme.bodyLarge?.color ?? (isDark ? Colors.white : const Color(0xFF1E293B));
    final secondaryText = theme.textTheme.bodyMedium?.color?.withOpacity(0.6) ?? (isDark ? Colors.white60 : const Color(0xFF64748B));
    final borderColor = isDark ? Colors.white12 : const Color(0xFFF1F5F9);
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : const Color(0x08000000),
            offset: const Offset(0, 4),
            blurRadius: 20,
          ),
        ],
      ),
      padding: const EdgeInsets.only(bottom: 32, top: 16),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: borderColor, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? Colors.black38 : const Color(0x10000000),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ProfileImage(
                  photoUrl: member.photoUrl,
                  fullName: member.fullName,
                  radius: 60,
                  onLongPress: () => _showFullScreenImage(member.photoUrl, member.fullName),
                ),
              ),
              if (member.role == 'manager')
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.verified_rounded, color: theme.colorScheme.onPrimary, size: 20),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            member.fullName,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: primaryText,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (member.relationToHead.toLowerCase() != 'none') ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? theme.colorScheme.primary.withOpacity(0.2) : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    lang.translate(member.relationToHead.toLowerCase()),
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                'MID: ${member.mid}',
                style: TextStyle(
                  color: secondaryText,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumQuickActions(MemberModel member, LanguageService lang) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? theme.cardColor : Colors.white;
    
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : const Color(0x06000000),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildPremiumActionButton(
            onPressed: () => _callPhone(member.phone),
            icon: Icons.phone,
            label: 'Call',
            color: const Color(0xFF10B981),
            enabled: member.phone.isNotEmpty,
          ),
          _buildPremiumActionButton(
            onPressed: () => _openWhatsapp(member.whatsapp),
            icon: Icons.chat_bubble_rounded,
            label: 'WhatsApp',
            color: const Color(0xFF25D366),
            enabled: member.whatsapp.isNotEmpty,
          ),
          _buildPremiumActionButton(
            onPressed: () {
              Navigator.pushNamed(
                context,
                '/user/digital-id',
                arguments: member,
              );
            },
            icon: Icons.badge_rounded,
            label: 'ID Card',
            color: const Color(0xFF4F46E5),
          ),
          _buildPremiumActionButton(
            onPressed: () => _openMap(member.googleMapLink),
            icon: Icons.location_on_rounded,
            label: 'Map',
            color: const Color(0xFFEF4444),
            enabled: member.googleMapLink.isNotEmpty,
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumActionButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
    bool enabled = true,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final disabledColor = isDark ? Colors.grey.shade700 : Colors.grey.shade50;
    final disabledIconColor = isDark ? Colors.grey.shade600 : const Color(0xFFCBD5E1);
    final labelColor = enabled ? (isDark ? Colors.white70 : const Color(0xFF475569)) : (isDark ? Colors.grey.shade600 : const Color(0xFF94A3B8));
    
    return InkWell(
      onTap: enabled ? onPressed : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: enabled ? color.withOpacity(0.08) : disabledColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: enabled ? color : disabledIconColor,
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: labelColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? theme.cardColor : Colors.white;
    final iconBgColor = isDark ? Colors.white.withOpacity(0.1) : const Color(0xFFF1F5F9);
    final iconColor = isDark ? Colors.white70 : const Color(0xFF475569);
    final primaryText = theme.textTheme.bodyLarge?.color ?? (isDark ? Colors.white : const Color(0xFF1E293B));
    
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.transparent, width: 0),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : const Color(0x04000000),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: iconColor),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: primaryText,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumRow(String label, String value, IconData icon, {bool isDestructive = false}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final iconColor = isDestructive ? const Color(0xFFEF4444) : (isDark ? Colors.white38 : const Color(0xFF94A3B8));
    final labelColor = isDark ? Colors.white54 : const Color(0xFF94A3B8);
    final valueColor = isDestructive ? const Color(0xFFEF4444) : (theme.textTheme.bodyLarge?.color ?? (isDark ? Colors.white : const Color(0xFF334155)));
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: labelColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty ? '-' : value,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: valueColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumLocationRow(String label, String address, String mapLink) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final displayAddress = address.isEmpty ? '-' : address;
    final hasMapLink = mapLink.isNotEmpty;
    final labelColor = isDark ? Colors.white54 : const Color(0xFF94A3B8);
    final valueColor = theme.textTheme.bodyLarge?.color ?? (isDark ? Colors.white : const Color(0xFF334155));
    final iconColor = isDark ? Colors.white38 : const Color(0xFF94A3B8);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.location_on_rounded, size: 18, color: iconColor),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: labelColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  displayAddress,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: valueColor,
                    height: 1.4,
                  ),
                ),
                if (hasMapLink)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: InkWell(
                      onTap: () => _openMap(mapLink),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark ? theme.colorScheme.primary.withOpacity(0.2) : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.map_outlined, color: theme.colorScheme.primary, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              'View on Map',
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumSocialRow(String platform, String value, IconData icon) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryText = theme.textTheme.bodyLarge?.color ?? (isDark ? Colors.white : const Color(0xFF334155));
    final secondaryText = isDark ? Colors.white54 : const Color(0xFF94A3B8);
    final arrowColor = isDark ? Colors.white24 : const Color(0xFFCBD5E1);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: InkWell(
        onTap: () => _openSocialMedia(platform, value),
        child: Row(
          children: [
            Icon(icon, size: 20, color: _getSocialColor(platform)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    platform,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: primaryText),
                  ),
                  Text(
                    value,
                    style: TextStyle(color: secondaryText, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: arrowColor),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumFirmRow(Map<String, String> firm) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryText = theme.textTheme.bodyLarge?.color ?? (isDark ? Colors.white : const Color(0xFF334155));
    final secondaryText = isDark ? Colors.white60 : const Color(0xFF64748B);
    final iconColor = isDark ? Colors.white38 : const Color(0xFF64748B);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.business_center_rounded, color: iconColor, size: 18),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  firm['name'] ?? '',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: primaryText),
                ),
              ),
            ],
          ),
          if ((firm['phone'] ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 34, top: 4),
              child: Text(
                'Phone: ${firm['phone']}',
                style: TextStyle(color: secondaryText, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          if ((firm['mapLink'] ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 34, top: 8),
              child: InkWell(
                onTap: () => _openMap(firm['mapLink']!),
                child: Text(
                  'View Location',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAdminControlCard(MemberModel member, LanguageService lang) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? theme.cardColor : const Color(0xFFF8FAFC);
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE2E8F0);
    final titleColor = member.role == 'manager' ? const Color(0xFFB91C1C) : (isDark ? Colors.greenAccent : const Color(0xFF15803D)); // Keep manager red distinct
    final subtitleColor = isDark ? Colors.white60 : const Color(0xFF64748B);
    final arrowColor = isDark ? Colors.white24 : const Color(0xFF94A3B8);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _toggleManagerRole,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (member.role == 'manager' ? const Color(0xFFFEE2E2) : (isDark ? Colors.green.withOpacity(0.2) : const Color(0xFFDCFCE7))),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    member.role == 'manager' ? Icons.person_remove_rounded : Icons.person_add_rounded,
                    color: member.role == 'manager' ? const Color(0xFFB91C1C) : (isDark ? Colors.greenAccent : const Color(0xFF15803D)),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.role == 'manager' ? lang.translate('demote_to_member') : lang.translate('promote_to_manager'),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        member.role == 'manager' ? lang.translate('demote_subtitle') : lang.translate('promote_subtitle'),
                        style: TextStyle(fontSize: 12, color: subtitleColor, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: arrowColor),
              ],
            ),
          ),
        ),
      ),
    );
  }







  Color _getSocialColor(String platform) {
    switch (platform.toLowerCase()) {
      case 'whatsapp':
        return Colors.green;
      case 'instagram':
        return Colors.pink;
      case 'facebook':
        return Colors.blue.shade800;
      default:
        return Colors.blue.shade900;
    }
  }

  void _callPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _openWhatsapp(String phone) async {
    // Remove any non-digit characters except +
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('https://wa.me/$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _sendSms(String phone) async {
    final uri = Uri.parse('sms:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _openMap(String url) async {
    if (url.isEmpty) return;

    // Check if URL is a valid URL format
    final uri = Uri.tryParse(url);
    if (uri != null && (uri.scheme.isNotEmpty || url.startsWith('http'))) {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } else {
      // If it's not a full URL, search on Google Maps
      final searchUrl = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(url)}',
      );
      if (await canLaunchUrl(searchUrl)) {
        await launchUrl(searchUrl, mode: LaunchMode.externalApplication);
      }
    }
  }

  void _openSocialMedia(String platform, String value) async {
    String? url;

    switch (platform.toLowerCase()) {
      case 'whatsapp':
        final cleanPhone = value.replaceAll(RegExp(r'[^\d+]'), '');
        url = 'https://wa.me/$cleanPhone';
        break;
      case 'instagram':
        // Handle both username and URL
        if (value.startsWith('http')) {
          url = value;
        } else {
          url = 'https://instagram.com/$value';
        }
        break;
      case 'facebook':
        // Handle both username and URL
        if (value.startsWith('http')) {
          url = value;
        } else {
          url = 'https://facebook.com/$value';
        }
        break;
    }

    if (url != null) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }
}
