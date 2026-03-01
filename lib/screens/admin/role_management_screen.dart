// lib/screens/admin/role_management_screen.dart

import 'package:flutter/material.dart';
import '../../services/role_service.dart';
import '../../services/member_service.dart';
import '../../models/organizational_role_model.dart';
import '../../models/member_model.dart';
import '../../widgets/animation_utils.dart';
import '../../services/language_service.dart';
import 'package:provider/provider.dart';

class RoleManagementScreen extends StatefulWidget {
  const RoleManagementScreen({super.key});

  @override
  State<RoleManagementScreen> createState() => _RoleManagementScreenState();
}

class _RoleManagementScreenState extends State<RoleManagementScreen> with SingleTickerProviderStateMixin {
  final RoleService _roleService = RoleService();
  final MemberService _memberService = MemberService();
  late TabController _tabController;
  Map<String, MemberModel> _assignedMembersCache = {};
  bool _loading = true;

  String _getTranslatedCategory(String category, LanguageService lang) {
    switch (category) {
      case 'Samaj': return lang.translate('samaj');
      case 'Yuvak Mandal': return lang.translate('yuvak_mandal');
      case 'Mahila Mandal': return lang.translate('mahila_mandal');
      default: return category;
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: RoleService.defaultCategories.length, vsync: this);
    _initData();
  }

  Future<void> _initData() async {
    try {
      // Fetch all members to populate cache (similar to User side for reliability)
      final members = await _memberService.getAllMembers();
      
      if (mounted) {
        setState(() {
          _assignedMembersCache = {for (var m in members) m.mid: m};
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading roles/members: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageService>(context);

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(lang.translate('organizational_roles'), style: const TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.teal,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.teal,
          isScrollable: true,
          tabs: RoleService.defaultCategories.map((c) => Tab(text: _getTranslatedCategory(c, lang))).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: RoleService.defaultCategories.map((category) {
          return _buildRoleList(category, lang);
        }).toList(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddRoleDialog(RoleService.defaultCategories[_tabController.index], lang),
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildRoleList(String category, LanguageService lang) {
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
                    lang.translate('error'),
                    textAlign: TextAlign.center,
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.assignment_ind_outlined, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text('${lang.translate('no_roles_defined')} ${_getTranslatedCategory(category, lang)}', style: TextStyle(color: Colors.grey.shade500)),
              ],
            ),
          );
        }

        final roles = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: roles.length,
          itemBuilder: (context, index) {
            final role = roles[index];
            return _buildRoleCard(role, lang);
          },
        );
      },
    );
  }

  Widget _buildRoleCard(OrganizationalRoleModel role, LanguageService lang) {
    // Get members from cache
    final assignedMembers = role.memberMids
        .map((mid) => _assignedMembersCache[mid])
        .whereType<MemberModel>()
        .toList();

    return AnimatedCard(
      margin: const EdgeInsets.only(bottom: 16),
      borderRadius: 12,
      child: ExpansionTile(
        title: Text(
          lang.translate(role.roleTitle.toLowerCase().replaceAll(' ', '_')),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text('${assignedMembers.length} ${lang.translate('members')}', style: TextStyle(color: Colors.teal.shade700, fontSize: 13)),
        leading: CircleAvatar(
          backgroundColor: Colors.teal.shade50,
          child: const Icon(Icons.badge_outlined, color: Colors.teal),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (val) {
            if (val == 'edit') _showEditRoleDialog(role, lang);
            if (val == 'delete') _confirmDeleteRole(role, lang);
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'edit', child: Text(lang.translate('edit'))),
            PopupMenuItem(value: 'delete', child: Text(lang.translate('delete'))),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(lang.translate('members_assigned'), style: const TextStyle(fontWeight: FontWeight.w600)),
                    TextButton.icon(
                      onPressed: () => _showMemberSelectionDialog(role, lang),
                      icon: const Icon(Icons.person_add_alt_1, size: 18),
                      label: Text(lang.translate('assign_member')),
                      style: TextButton.styleFrom(foregroundColor: Colors.teal),
                    ),
                  ],
                ),
                if (assignedMembers.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(lang.translate('no_members_assigned'), style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                  )
                else
                  ...assignedMembers.map((m) => ListTile(
                        leading: CircleAvatar(
                          backgroundImage: m.photoUrl.isNotEmpty ? NetworkImage(m.photoUrl) : null,
                          child: m.photoUrl.isEmpty ? Text(m.fullName[0].toUpperCase()) : null,
                        ),
                        title: Text(m.fullName),
                        subtitle: Text(m.mid),
                        trailing: IconButton(
                          tooltip: lang.translate('remove_from_role'),
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                          onPressed: () => _removeMemberFromRole(role, m.mid, lang),
                        ),
                      )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddRoleDialog(String category, LanguageService lang) {
    final titleCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${lang.translate('add_role_to')} ${_getTranslatedCategory(category, lang)}'),
        content: TextField(
          controller: titleCtrl,
          decoration: InputDecoration(labelText: lang.translate('role_title_hint')),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(lang.translate('cancel'))),
          ElevatedButton(
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty) return;
              await _roleService.createRole(OrganizationalRoleModel(
                id: '',
                category: category,
                roleTitle: titleCtrl.text.trim(),
                createdAt: DateTime.now(),
              ));
              if (mounted) Navigator.pop(context);
            },
            child: Text(lang.translate('add')),
          ),
        ],
      ),
    );
  }

  void _showEditRoleDialog(OrganizationalRoleModel role, LanguageService lang) {
    final titleCtrl = TextEditingController(text: role.roleTitle);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lang.translate('edit_role_title')),
        content: TextField(
          controller: titleCtrl,
          decoration: InputDecoration(labelText: lang.translate('role_title_hint')),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(lang.translate('cancel'))),
          ElevatedButton(
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty) return;
              await _roleService.updateRole(role.id, {'roleTitle': titleCtrl.text.trim()});
              if (mounted) Navigator.pop(context);
            },
            child: Text(lang.translate('save')),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteRole(OrganizationalRoleModel role, LanguageService lang) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lang.translate('delete')),
        content: Text('${lang.translate('confirm_delete_role')} "${role.roleTitle}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(lang.translate('cancel'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await _roleService.deleteRole(role.id);
              if (mounted) Navigator.pop(context);
            },
            child: Text(lang.translate('delete')),
          ),
        ],
      ),
    );
  }

  void _showMemberSelectionDialog(OrganizationalRoleModel role, LanguageService lang) {
    String searchQuery = '';
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(lang.translate('assign_member')),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    onChanged: (v) => setDialogState(() => searchQuery = v),
                    decoration: InputDecoration(
                      hintText: lang.translate('search_members_hint'),
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (searchQuery.isNotEmpty)
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                      child: FutureBuilder<List<MemberModel>>(
                        future: _memberService.getAllMembers(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          
                          final all = snapshot.data ?? [];
                          final filtered = all.where((m) {
                            final q = searchQuery.toLowerCase().trim();
                            return m.fullName.toLowerCase().contains(q) || 
                                   m.mid.toLowerCase().contains(q);
                          }).toList();

                          if (filtered.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(lang.translate('no_results')),
                            );
                          }

                          return ListView.builder(
                            shrinkWrap: true,
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final m = filtered[index];
                              final isAlreadyAssigned = role.memberMids.contains(m.mid);
                              
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundImage: m.photoUrl.isNotEmpty ? NetworkImage(m.photoUrl) : null,
                                  child: m.photoUrl.isEmpty ? Text(m.fullName[0].toUpperCase()) : null,
                                ),
                                title: Text(m.fullName),
                                subtitle: Text(m.mid),
                                trailing: isAlreadyAssigned ? const Icon(Icons.check_circle, color: Colors.green) : null,
                                onTap: isAlreadyAssigned 
                                  ? () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.translate('member_already_assigned'))))
                                  : () async {
                                    final newMids = List<String>.from(role.memberMids)..add(m.mid);
                                    await _roleService.updateRole(role.id, {'memberMids': newMids});
                                    // Update cache
                                    setState(() {
                                      _assignedMembersCache[m.mid] = m;
                                    });
                                    if (mounted) Navigator.pop(context);
                                  },
                              );
                            },
                          );
                        },
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(lang.translate('search_members_hint')),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _removeMemberFromRole(OrganizationalRoleModel role, String memberMid, LanguageService lang) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lang.translate('remove_from_role')),
        content: Text(lang.translate('confirm_delete_role')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(lang.translate('cancel'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(lang.translate('delete')),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final newMids = List<String>.from(role.memberMids)..remove(memberMid);
      await _roleService.updateRole(role.id, {'memberMids': newMids});
    }
  }
}
