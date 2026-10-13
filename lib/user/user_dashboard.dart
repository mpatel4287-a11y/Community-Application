// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/session_manager.dart';
import '../models/member_model.dart';
import '../utils/member_sort_helper.dart';
import '../screens/user/member_detail_screen.dart';
import '../screens/user/qr_scanner_screen.dart';
import '../screens/admin/family_list_screen.dart';
import '../services/theme_service.dart';
import '../services/language_service.dart';
import 'package:provider/provider.dart';

class UserDashboard extends StatefulWidget {
  const UserDashboard({super.key});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  bool _loading = true;
  String _familyName = '';
  String _familyDocId = '';
  int _memberCount = 0;
  MemberModel? _member;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final familyDocId = await SessionManager.getFamilyDocId() ?? '';
      final familyName = await SessionManager.getFamilyName() ?? '';

      final snapshot = await FirebaseFirestore.instance
          .collectionGroup('members')
          .where('familyDocId', isEqualTo: familyDocId)
          .count()
          .get();

      // Fetch current member details
      final memberDocId = await SessionManager.getMemberDocId();
      final subFamilyDocId = await SessionManager.getSubFamilyDocId();
      MemberModel? member;
      if (memberDocId != null) {
        final memberDoc = await FirebaseFirestore.instance
            .collection('families')
            .doc(familyDocId)
            .collection('subfamilies')
            .doc(subFamilyDocId ?? '')
            .collection('members')
            .doc(memberDocId)
            .get();
        if (memberDoc.exists) {
          member = MemberModel.fromMap(memberDoc.id, memberDoc.data()!);
        }
      }

      setState(() {
        _familyDocId = familyDocId;
        _familyName = familyName;
        _memberCount = snapshot.count ?? 0;
        _member = member;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading dashboard: $e');
      if (mounted) {
        setState(() {
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading dashboard: $e')),
        );
      }
    }
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
      await SessionManager.clear();
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageService>(context);

    if (_loading) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final themeService = Provider.of<ThemeService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(lang.translate('user_dashboard')),
        actions: [
          IconButton(
            icon: Icon(themeService.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => themeService.toggleTheme(),
          ),
          // Language switcher
          TextButton(
            onPressed: () {
              final newLang = lang.currentLanguage == 'en' ? 'gu' : 'en';
              lang.setLanguage(newLang);
            },
            child: Text(
              lang.currentLanguage == 'en' ? 'GUJ' : 'ENG',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, '/user/settings');
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Family Card
            Card(
              color: Theme.of(context).colorScheme.primary,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _familyName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${lang.translate('family_members')}: $_memberCount',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Quick Actions
            Text(
              lang.translate('quick_actions'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildQuickAction(
                    icon: Icons.people,
                    label: lang.translate('view_members'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              UserMemberListScreen(familyDocId: _familyDocId),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickAction(
                    icon: Icons.badge_rounded,
                    label: lang.translate('digital_id'),
                    onTap: () {
                      if (_member != null) {
                        Navigator.pushNamed(
                          context,
                          '/user/digital-id',
                          arguments: _member,
                        );
                      } else {
                         ScaffoldMessenger.of(context).showSnackBar(
                           SnackBar(content: Text(lang.translate('member_not_found')))
                         );
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildQuickAction(
                    icon: Icons.qr_code_scanner,
                    label: lang.translate('scan_qr'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const QRScannerScreen(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickAction(
                    icon: Icons.groups_2_rounded,
                    label: 'All Families',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const FamilyListScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Upcoming Events
            Text(
              lang.translate('upcoming_events'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('events')
                  .where('date', isGreaterThanOrEqualTo: DateTime.now())
                  .orderBy('date')
                  .limit(5)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: Text(
                          lang.translate('no_events'),
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                    ),
                  );
                }

                return Column(
                  children: snapshot.data!.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final date = (data['date'] as dynamic)?.toDate();
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(Icons.event, color: Colors.blue),
                        title: Text(data['title'] ?? ''),
                        subtitle: date != null
                            ? Text('${date.day}/${date.month}/${date.year}')
                            : null,
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}

class UserMemberListScreen extends StatelessWidget {
  final String familyDocId;

  const UserMemberListScreen({super.key, required this.familyDocId});

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageService>(context);
    return Scaffold(
      appBar: AppBar(title: Text(lang.translate('family_members'))),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collectionGroup('members')
            .where('familyDocId', isEqualTo: familyDocId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.data!.docs.isEmpty) {
            return Center(child: Text(lang.translate('no_members_found')));
          }

          final rawMembers = snapshot.data!.docs
              .map((doc) => MemberModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
              .toList();
          final members = MemberSortHelper.sortMembers(rawMembers);

          return ListView.builder(
            itemCount: members.length,
            itemBuilder: (context, index) {
              final member = members[index];

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade900,
                    child: Text(
                      member.fullName.isNotEmpty
                          ? member.fullName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(member.fullName),
                  subtitle: Text('${member.surname} • ${member.age} years • ${member.relationToHead.toUpperCase()}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
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
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
