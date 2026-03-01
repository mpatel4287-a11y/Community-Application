// lib/screens/user/enhanced_user_dashboard.dart

// ignore_for_file: deprecated_member_use, unnecessary_underscores, sized_box_for_whitespace

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../models/member_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/member_service.dart';
import '../../services/session_manager.dart';
import '../../services/theme_service.dart';
import '../../services/language_service.dart';
import '../../services/notification_service.dart';
import '../../services/group_service.dart';
import '../../widgets/animation_utils.dart';


// import 'family_tree_view.dart';
import 'member_detail_screen.dart';
import 'user_calendar_screen.dart';
import 'user_notification_screen.dart';
import 'settings_screen.dart';
import 'user_search_tab.dart'; 
import '../admin/family_list_screen.dart';
import 'organizational_structure_screen.dart';
import 'dart:math';

class EnhancedUserDashboard extends StatefulWidget {
  const EnhancedUserDashboard({super.key});

  @override
  State<EnhancedUserDashboard> createState() => _EnhancedUserDashboardState();
}

class _EnhancedUserDashboardState extends State<EnhancedUserDashboard> {
  final MemberService _memberService = MemberService();
  final NotificationService _notificationService = NotificationService();
  final ScrollController _scrollController = ScrollController();


  List<MemberModel> _allMembers = [];
  List<MemberModel> _randomSuggestions = [];
  List<MemberModel> _newMembers = [];

  final Map<String, dynamic> _stats = {};
  bool _loading = true;
  String? _familyDocId;
  // String? _familyName;


  MemberModel? _currentUser;
  String? _userRole;
  int _selectedIndex = 2; // Default to HOME tab (0=Calendar, 1=Search, 2=Home, 3=Notifications, 4=Profile)

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _setupLiveUpdates();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _loading = true);

    try {
      final familyDocId = await SessionManager.getFamilyDocId();
      // final familyName = await SessionManager.getFamilyName();
      final memberDocId = await SessionManager.getMemberDocId();
      final subFamilyDocId = await SessionManager.getSubFamilyDocId();
      final role = await SessionManager.getRole();
      
      _userRole = role;
      _familyDocId = familyDocId;
      // _familyName = familyName;

      // Load current user
      if (memberDocId != null && familyDocId != null) {
        _currentUser = await _memberService.getMember(
          mainFamilyDocId: familyDocId,
          subFamilyDocId: subFamilyDocId ?? '',
          memberId: memberDocId,
        );
      }

      // Load all members with 15-second timeout safety
      _allMembers = await _memberService.getAllMembers().timeout(const Duration(seconds: 15), onTimeout: () => []);

      // Generate random suggestions
      _generateRandomSuggestions();

      // Get new members (last 7 days)
      _loadNewMembers();

      // Load statistics
      _calculateStats();

      setState(() => _loading = false);
    } catch (e) {
      debugPrint('Error loading dashboard: $e');
      setState(() => _loading = false);
    }
  }

  void _setupLiveUpdates() {
    // Live stream for members
    _memberService.streamAllMembers().listen((members) {
      if (mounted) {
        setState(() {
          _allMembers = members;
          _generateRandomSuggestions();
          _loadNewMembers();
          _calculateStats();
        });
      }
    });

    // Live stream for families
    FirebaseFirestore.instance.collection('families').where('isAdmin', isEqualTo: false).snapshots().listen((snap) {
      if (mounted) {
        setState(() {
          _stats['totalFamilies'] = snap.docs.length;
        });
      }
    });

    // Live stream for groups
    if (_familyDocId != null) {
      GroupService().streamGroups(_familyDocId!).listen((groups) {
        if (mounted) {
          setState(() {
            _stats['totalGroups'] = groups.length;
          });
        }
      });
    }
  }

  void _calculateStats() {
    if (_allMembers.isEmpty) return;

    final total = _allMembers.length;
    final active = _allMembers.where((m) => m.isActive).length;
    
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final newThisMonth = _allMembers.where((m) => m.createdAt.isAfter(startOfMonth)).length;

    int myFamilyCount = 0;
    final familyId = _familyDocId ?? _currentUser?.familyDocId;
    if (familyId != null && familyId.isNotEmpty) {
      myFamilyCount = _allMembers.where((m) => m.familyDocId == familyId).length;
    }

    // Calculate firm stats
    final Map<String, int> firmsMap = {};
    for (final member in _allMembers) {
      for (final firm in member.firms) {
        final firmName = firm['name'] ?? '';
        if (firmName.isNotEmpty) {
          firmsMap[firmName] = (firmsMap[firmName] ?? 0) + 1;
        }
      }
    }

    setState(() {
      _stats['total'] = total;
      _stats['active'] = active;
      _stats['newThisMonth'] = newThisMonth;
      _stats['myFamilyCount'] = myFamilyCount;
      _stats['totalFirms'] = firmsMap.length;
    });
  }

  void _generateRandomSuggestions() {
    if (_allMembers.isEmpty) return;

    final random = Random();
    final suggestions = <MemberModel>[];
    final availableMembers = List<MemberModel>.from(_allMembers);

    // Filter out current user
    if (_currentUser != null) {
      availableMembers.removeWhere((m) => m.id == _currentUser!.id);
    }

    // Get 5 random members
    for (int i = 0; i < 5 && availableMembers.isNotEmpty; i++) {
      final index = random.nextInt(availableMembers.length);
      suggestions.add(availableMembers.removeAt(index));
    }

    setState(() => _randomSuggestions = suggestions);
  }

  void _loadNewMembers() {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));

    _newMembers = _allMembers.where((member) {
      return member.createdAt.isAfter(weekAgo);
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (_newMembers.length > 10) {
      _newMembers = _newMembers.take(10).toList();
    }
  }


  void _navigateToMember(MemberModel member) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MemberDetailScreen(
          memberId: member.id,
          familyDocId: member.familyDocId,
          subFamilyDocId: member.subFamilyDocId,
        ),
      ),
    );
  }

  void _switchTab(int index) {
    setState(() => _selectedIndex = index);
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeIn);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageService>(context);
    final themeService = Provider.of<ThemeService>(context);
    final isDark = themeService.isDarkMode;

    if (_loading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PulseAnimation(
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Colors.blue.shade400,
                        Colors.blue.shade700,
                      ],
                    ),
                  ),
                  child: const Icon(
                    Icons.dashboard,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FadeInAnimation(
                child: Text(
                  lang.translate('loading'),
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return PopScope(
      canPop: _selectedIndex == 2,
      onPopInvoked: (didPop) {
        if (!didPop && _selectedIndex != 2) {
          setState(() => _selectedIndex = 2);
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade50,
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            // 0. CALENDAR (Swapped)
            const UserCalendarScreen(),
            
            // 1. SEARCH
            const UserSearchTab(),
            
            // 2. HOME (Swapped)
            _buildHomeTab(context, lang, isDark),
            
            // 3. NOTIFICATIONS
            const UserNotificationScreen(),
  
            // 4. PROFILE (Settings)
            const SettingsScreen(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            setState(() => _selectedIndex = index);
          },
          indicatorColor: const Color(0xFF122C4F).withOpacity(0.2), // Midnight indicator
          animationDuration: const Duration(milliseconds: 300),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.event_note_outlined),
              selectedIcon: const Icon(Icons.event_note, color: Color(0xFF122C4F)),
              label: lang.translate('events'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.connect_without_contact_outlined),
              selectedIcon: const Icon(Icons.connect_without_contact, color: Color(0xFF122C4F)),
              label: lang.translate('connect'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.dashboard_outlined),
              selectedIcon: const Icon(Icons.dashboard, color: Color(0xFF122C4F)),
              label: lang.translate('home'),
            ),
            NavigationDestination(
              icon: StreamBuilder<int>(
                stream: _notificationService.streamUnreadCount(_familyDocId ?? ''),
                builder: (context, snapshot) {
                  int unreadCount = snapshot.data ?? 0;
                  return Badge(
                    label: Text(unreadCount.toString()),
                    isLabelVisible: unreadCount > 0,
                    child: const Icon(Icons.notifications_active_outlined),
                  );
                },
              ),
              selectedIcon: StreamBuilder<int>(
                stream: _notificationService.streamUnreadCount(_familyDocId ?? ''),
                builder: (context, snapshot) {
                  int unreadCount = snapshot.data ?? 0;
                  return Badge(
                    label: Text(unreadCount.toString()),
                    isLabelVisible: unreadCount > 0,
                    child: const Icon(Icons.notifications_active, color: Color(0xFF122C4F)),
                  );
                },
              ),
              label: lang.translate('notifications'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.account_circle_outlined),
              selectedIcon: const Icon(Icons.account_circle, color: Color(0xFF122C4F)),
              label: lang.translate('profile'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeTab(BuildContext context, LanguageService lang, bool isDark) {
    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      color: Colors.blue.shade900,
      backgroundColor: Colors.white,
      strokeWidth: 3,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // 1. App Bar with Profile Quick Link (Shortened)
          SliverAppBar(
            expandedHeight: 60.0,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF122C4F),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 16, bottom: 12),
              title: Text(
                '${lang.translate('welcome')}, ${_currentUser?.fullName.split(' ')[0] ?? 'User'}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFFBF9E4)),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF122C4F), Color(0xFF0D1E36)],
                  ),
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16, top: 4),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedIndex = 4),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white,
                    backgroundImage: _currentUser?.photoUrl.isNotEmpty == true
                        ? CachedNetworkImageProvider(_currentUser!.photoUrl)
                        : null,
                    child: _currentUser?.photoUrl.isEmpty ?? true
                        ? Text(
                            _currentUser?.fullName.isNotEmpty == true 
                                ? _currentUser!.fullName[0].toUpperCase() 
                                : '?',
                            style: TextStyle(color: Colors.blue.shade900, fontSize: 14),
                          )
                        : null,
                  ),
                ),
              ),
            ],
          ),

          // 2. Dashboard Content
          SliverPadding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Quick Statistics (Unbound layout fix) with animation
                FadeInAnimation(
                  delay: const Duration(milliseconds: 100),
                  child: _buildQuickStats(lang, isDark),
                ),
                const SizedBox(height: 16),

                // Manager Specific Tools with animation
                if (_userRole == 'manager') ...[
                  FadeInAnimation(
                    delay: const Duration(milliseconds: 200),
                    child: _buildManagerTools(lang, isDark),
                  ),
                  const SizedBox(height: 16),
                ],

                // Section: Organizational Structure
                SlideInAnimation(
                  delay: const Duration(milliseconds: 220),
                  beginOffset: const Offset(0.1, 0),
                  child: _buildSectionHeader(
                    lang.translate('committees_roles'),
                    '${lang.translate('samaj')}, ${lang.translate('yuvak_mandal')} & ${lang.translate('mahila_mandal')}',
                    Icons.badge_outlined,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const OrganizationalStructureScreen()),
                    ),
                    lang,
                    isDark,
                  ),
                ),
                const SizedBox(height: 8),
                
                // Section: Firms with animation
                SlideInAnimation(
                  delay: const Duration(milliseconds: 250),
                  beginOffset: const Offset(0.1, 0),
                  child: _buildSectionHeader(
                    lang.translate('firms'),
                    lang.translate('view_firms_subtitle'),
                    Icons.store_outlined,
                    () => Navigator.pushNamed(context, '/admin/firms'),
                    lang,
                    isDark,
                  ),
                ),
                SlideInAnimation(
                  delay: const Duration(milliseconds: 300),
                  beginOffset: const Offset(0.1, 0),
                  child: _buildFirmStats(lang, isDark),
                ),

                // Section: Community Activity (Events) with animation
                SlideInAnimation(
                  delay: const Duration(milliseconds: 350),
                  beginOffset: const Offset(0.1, 0),
                  child: _buildSectionHeader(
                    lang.translate('community_activity'),
                    lang.translate('recent_events'),
                    Icons.celebration_outlined,
                    () => setState(() => _selectedIndex = 0), // Go to Calendar tab
                    lang,
                    isDark,
                  ),
                ),
                FadeInAnimation(
                  delay: const Duration(milliseconds: 400),
                  child: _buildCommunityActivity(lang, isDark),
                ),

                // Section: New Members with animation
                if (_newMembers.isNotEmpty) ...[
                  SlideInAnimation(
                    delay: const Duration(milliseconds: 450),
                    beginOffset: const Offset(0.1, 0),
                    child: _buildSectionHeader(
                    lang.translate('new_members'),
                    lang.translate('recently_joined'),
                    Icons.person_add_alt_1,
                    null,
                      lang,
                      isDark,
                    ),
                  ),
                  FadeInAnimation(
                    delay: const Duration(milliseconds: 500),
                    child: _buildNewMembersSection(lang, isDark),
                  ),
                ],

                // Section: Member Spotlight with animation
                if (_randomSuggestions.isNotEmpty) ...[
                  SlideInAnimation(
                    delay: const Duration(milliseconds: 550),
                    beginOffset: const Offset(0.1, 0),
                    child: _buildSectionHeader(
                    lang.translate('member_spotlight'),
                    lang.translate('discover_members'),
                    Icons.auto_awesome,
                    () => _generateRandomSuggestions(),
                      lang,
                      isDark,
                    ),
                  ),
                  FadeInAnimation(
                    delay: const Duration(milliseconds: 600),
                    child: _buildMemberSuggestions(lang, isDark),
                  ),
                ],

                const SizedBox(height: 90),
              ]),
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildQuickStats(LanguageService lang, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // 1) Total Members
          Expanded(
            child: InkWell(
              onTap: () => _switchTab(1), // Navigate to Search/Connect
              borderRadius: BorderRadius.circular(12),
              child: _buildStatCard(
                lang.translate('total_members'),
                '${_stats['total'] ?? 0}',
                Icons.groups_2,
                Colors.blue,
                isDark,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 2) Total Families
          Expanded(
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FamilyListScreen()),
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: _buildStatCard(
                lang.translate('families'),
                '${_stats['totalFamilies'] ?? 0}',
                Icons.people_alt,
                Colors.purple,
                isDark,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 3) My Family
          Expanded(
            child: _buildStatCard(
              lang.translate('my_family'),
              '${_stats['myFamilyCount'] ?? 0}',
              Icons.family_restroom,
              Colors.orange,
              isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return AnimatedCard(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      borderRadius: 20,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleAnimation(
            delay: const Duration(milliseconds: 100),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
          ),
          const SizedBox(height: 12),
          FadeInAnimation(
            delay: const Duration(milliseconds: 150),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }



  Widget _buildSectionHeader(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback? onTap,
    LanguageService lang,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF5B88B2).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: const Color(0xFF5B88B2), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.arrow_forward_ios_rounded, color: Colors.blue.shade700, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMemberSuggestions(LanguageService lang, bool isDark) {
    if (_randomSuggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _randomSuggestions.length,
        itemBuilder: (context, index) {
          final member = _randomSuggestions[index];
          return _buildMemberCard(member, lang, isDark, true);
        },
      ),
    );
  }

  Widget _buildNewMembersSection(LanguageService lang, bool isDark) {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _newMembers.length,
        itemBuilder: (context, index) {
          final member = _newMembers[index];
          return _buildMemberCard(member, lang, isDark, false);
        },
      ),
    );
  }

  Widget _buildMemberCard(
    MemberModel member,
    LanguageService lang,
    bool isDark,
    bool isSuggestion,
  ) {
    return AnimatedCard(
      margin: const EdgeInsets.only(right: 12),
      backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
      borderRadius: 20,
      onTap: () => _navigateToMember(member),
      child: Container(
        width: 160,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Image
            Container(
              height: 120,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF122C4F).withOpacity(0.8),
                    const Color(0xFF122C4F),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  // ... Keep existing children ...
                  Center(
                    child:
                        member.photoUrl.isNotEmpty &&
                            member.photoUrl.startsWith('http')
                        ? ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(20),
                            ),
                            child: CachedNetworkImage(
                              imageUrl: member.photoUrl,
                              width: double.infinity,
                              height: 120,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) =>
                                  _buildAvatarPlaceholder(member),
                            ),
                          )
                        : _buildAvatarPlaceholder(member),
                  ),
                  if (isSuggestion)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.auto_awesome,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Member Info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.fullName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (member.bloodGroup.isNotEmpty)
                    Row(
                      children: [
                        Icon(
                          Icons.bloodtype,
                          size: 12,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          member.bloodGroup,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  if (member.nativeHome.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 12,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            member.nativeHome,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarPlaceholder(MemberModel member) {
    return Container(
      width: double.infinity,
      height: 120,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF122C4F).withOpacity(0.8),
            const Color(0xFF122C4F),
          ],
        ),
      ),
      child: Center(
        child: Text(
          member.fullName.isNotEmpty ? member.fullName[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 48,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }



  Widget _buildCommunityActivity(LanguageService lang, bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade800 : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        final events = snapshot.data!.docs;

        if (events.isEmpty) {
          return Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade800 : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(Icons.event_available_outlined, color: Colors.grey.shade400, size: 48),
                const SizedBox(height: 12),
                Text(
                  lang.translate('no_events'),
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          );
        }

        // Show recent events
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: events.length,
          itemBuilder: (context, index) {
            final doc = events[index];
            final data = doc.data() as Map<String, dynamic>;
            final lang = Provider.of<LanguageService>(context, listen: false);
            final title = data['title'] ?? lang.translate('events');
            final date = (data['date'] as Timestamp?)?.toDate() ?? DateTime.now();

            return SlideInAnimation(
              delay: Duration(milliseconds: 50 * index),
              beginOffset: const Offset(0.2, 0),
              child: AnimatedCard(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                backgroundColor: isDark ? Colors.grey.shade800 : Colors.white,
                borderRadius: 12,
                border: Border.all(
                  color: Colors.blue.withOpacity(0.3),
                  width: 1,
                ),
                child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          date.day.toString(),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                        Text(
                          _getMonth(date.month),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            );
          },
        );
      },
    );
  }

  String _getMonth(int month) {
    // These should ideally be in LanguageService but for now we handle here
    final locale = Provider.of<LanguageService>(context, listen: false).currentLanguage;
    if (locale == 'gu') {
      const gmonths = [
        'જાન્યુ', 'ફેબ્રુ', 'માર્ચ', 'એપ્રિલ', 'મે', 'જૂન',
        'જુલાઈ', 'ઓગસ્ટ', 'સપ્ટે', 'ઓક્ટો', 'નવે', 'ડિસે'
      ];
      return gmonths[month - 1];
    }
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  Widget _buildManagerTools(LanguageService lang, bool isDark) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${lang.translate('manager')} ${lang.translate('settings')}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildManagerToolCard(
                  icon: Icons.campaign,
                  label: lang.translate('notifications'),
                  color: Colors.redAccent,
                  isDark: isDark,
                  onTap: () => Navigator.pushNamed(context, '/admin/notifications'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildManagerToolCard(
                  icon: Icons.event_available,
                  label: lang.translate('events'),
                  color: Colors.blueAccent,
                  isDark: isDark,
                  onTap: () => Navigator.pushNamed(context, '/admin/events'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildManagerToolCard(
                  icon: Icons.house_siding,
                  label: lang.translate('families'),
                  color: Colors.purple,
                  isDark: isDark,
                  onTap: () => Navigator.pushNamed(context, '/admin/families'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildManagerToolCard(
                  icon: Icons.group_work,
                  label: lang.translate('groups'),
                  color: Colors.green,
                  isDark: isDark,
                  onTap: () => Navigator.pushNamed(context, '/admin/groups'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildManagerToolCard({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return AnimatedCard(
      padding: const EdgeInsets.all(16),
      backgroundColor: isDark ? Colors.grey.shade800 : Colors.white,
      borderRadius: 12,
      border: Border.all(color: color.withOpacity(0.3)),
      onTap: onTap,
      child: Column(
        children: [
          ScaleAnimation(
            delay: const Duration(milliseconds: 100),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
          ),
          const SizedBox(height: 8),
          FadeInAnimation(
            delay: const Duration(milliseconds: 150),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildFirmStats(LanguageService lang, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, '/admin/firms'),
        borderRadius: BorderRadius.circular(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildSmallStat(lang.translate('firms'), '${_stats['totalFirms'] ?? 0}', Colors.orange),
            _buildSmallStat(lang.translate('members'), '${_stats['total'] ?? 0}', Colors.blue),
            _buildSmallStat(lang.translate('families'), '${_stats['totalFamilies'] ?? 0}', Colors.purple),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}
