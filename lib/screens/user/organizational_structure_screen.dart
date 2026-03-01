// lib/screens/user/organizational_structure_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/language_service.dart';
import '../../services/role_service.dart';
import '../../services/member_service.dart';
import '../../models/organizational_role_model.dart';
import '../../models/member_model.dart';
import 'member_detail_screen.dart';
import '../../widgets/animation_utils.dart';
import 'package:cached_network_image/cached_network_image.dart';

class OrganizationalStructureScreen extends StatefulWidget {
  const OrganizationalStructureScreen({super.key});

  @override
  State<OrganizationalStructureScreen> createState() => _OrganizationalStructureScreenState();
}

class _OrganizationalStructureScreenState extends State<OrganizationalStructureScreen> with SingleTickerProviderStateMixin {
  final RoleService _roleService = RoleService();
  final MemberService _memberService = MemberService();
  late TabController _tabController;
  List<MemberModel> _allMembers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: RoleService.defaultCategories.length, vsync: this);
    _initData();
  }

  Future<void> _initData() async {
    try {
      final members = await _memberService.getAllMembers().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          debugPrint('Loading timed out after 15s');
          return []; // Return empty list on timeout
        },
      );
      if (mounted) {
        setState(() {
          _allMembers = members;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading organizational data: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(Provider.of<LanguageService>(context).translate('committees_roles'), style: const TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.teal,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.teal,
          isScrollable: true,
          tabs: RoleService.defaultCategories.map((c) {
            // Translate category name for tabs
            final tabLang = Provider.of<LanguageService>(context, listen: false);
            final key = c.toLowerCase().replaceAll(' ', '_');
            final translated = tabLang.translate(key);
            return Tab(text: translated == key ? c : translated);
          }).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: RoleService.defaultCategories.map((category) {
          final lang = Provider.of<LanguageService>(context);
          return _buildRoleView(category, lang);
        }).toList(),
      ),
    );
  }

  Widget _buildRoleView(String category, LanguageService lang) {
    return StreamBuilder<List<OrganizationalRoleModel>>(
      stream: _roleService.streamRolesByCategory(category),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.orange),
                  const SizedBox(height: 16),
                  Text(
                    'Index building or loading error. If this is a new setup, it might take a few minutes.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.isEmpty) {
          return Center(
            child: Text('${lang.translate('coming_soon_for')} $category', style: const TextStyle(color: Colors.grey)),
          );
        }

        final roles = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: roles.length,
          itemBuilder: (context, index) {
            final role = roles[index];
            return _buildRoleRow(role, index, lang);
          },
        );
      },
    );
  }

  Widget _buildRoleRow(OrganizationalRoleModel role, int index, LanguageService lang) {
    final assignedMembers = _allMembers.where((m) => role.memberMids.contains(m.mid)).toList();

    return SlideInAnimation(
      delay: Duration(milliseconds: 100 * index),
      beginOffset: const Offset(0, 0.1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.teal,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  // Show the raw role title — don't try to look it up by key
                  role.roleTitle.toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    fontSize: 14,
                    color: Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
          if (assignedMembers.isEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 20, bottom: 20),
              child: Text(lang.translate('to_be_announced'), style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey, fontSize: 13)),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: assignedMembers.length,
              itemBuilder: (context, i) {
                final m = assignedMembers[i];
                return _buildMemberMiniCard(m);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildMemberMiniCard(MemberModel member) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MemberDetailScreen(memberId: member.id),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Hero(
              tag: 'photo_${member.id}',
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.teal.shade50,
                  image: member.photoUrl.isNotEmpty
                      ? DecorationImage(
                          image: CachedNetworkImageProvider(member.photoUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: member.photoUrl.isEmpty
                    ? Center(
                        child: Text(
                          member.fullName[0].toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.fullName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    member.mid,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
