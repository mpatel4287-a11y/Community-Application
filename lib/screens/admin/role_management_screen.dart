// lib/screens/admin/role_management_screen.dart

import 'package:flutter/material.dart';
import '../../services/role_service.dart';
import '../../services/member_service.dart';
import '../../models/organizational_role_model.dart';
import '../../models/member_model.dart';
import '../../widgets/animation_utils.dart';

class RoleManagementScreen extends StatefulWidget {
  const RoleManagementScreen({super.key});

  @override
  State<RoleManagementScreen> createState() => _RoleManagementScreenState();
}

class _RoleManagementScreenState extends State<RoleManagementScreen> with SingleTickerProviderStateMixin {
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
          debugPrint('Loading members timed out');
          return [];
        },
      );
      if (mounted) {
        setState(() {
          _allMembers = members;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading members: $e');
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

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Organizational Roles', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.teal,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.teal,
          isScrollable: true,
          tabs: RoleService.defaultCategories.map((c) => Tab(text: c)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: RoleService.defaultCategories.map((category) {
          return _buildRoleList(category);
        }).toList(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddRoleDialog(RoleService.defaultCategories[_tabController.index]),
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildRoleList(String category) {
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
                  const Text(
                    'Database Indexing Issue. If you just added this category, Firestore might still be building the required index.',
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
                Text('No roles defined for $category', style: TextStyle(color: Colors.grey.shade500)),
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
            return _buildRoleCard(role);
          },
        );
      },
    );
  }

  Widget _buildRoleCard(OrganizationalRoleModel role) {
    // Get members assigned to this role
    final assignedMembers = _allMembers.where((m) => role.memberMids.contains(m.mid)).toList();

    return AnimatedCard(
      margin: const EdgeInsets.only(bottom: 16),
      borderRadius: 12,
      child: ExpansionTile(
        title: Text(role.roleTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text('${assignedMembers.length} member(s) assigned', style: TextStyle(color: Colors.teal.shade700, fontSize: 13)),
        leading: CircleAvatar(
          backgroundColor: Colors.teal.shade50,
          child: const Icon(Icons.badge_outlined, color: Colors.teal),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (val) {
            if (val == 'edit') _showEditRoleDialog(role);
            if (val == 'delete') _confirmDeleteRole(role);
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit Title')),
            const PopupMenuItem(value: 'delete', child: Text('Delete Role')),
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
                    const Text('Members Assigned:', style: TextStyle(fontWeight: FontWeight.w600)),
                    TextButton.icon(
                      onPressed: () => _showMemberSelectionDialog(role),
                      icon: const Icon(Icons.person_add_alt_1, size: 18),
                      label: const Text('Assign Member'),
                      style: TextButton.styleFrom(foregroundColor: Colors.teal),
                    ),
                  ],
                ),
                if (assignedMembers.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('No members assigned yet.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
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
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                          onPressed: () => _removeMemberFromRole(role, m.mid),
                        ),
                      )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddRoleDialog(String category) {
    final titleCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Role to $category'),
        content: TextField(
          controller: titleCtrl,
          decoration: const InputDecoration(labelText: 'Role Title (e.g. President)'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
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
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditRoleDialog(OrganizationalRoleModel role) {
    final titleCtrl = TextEditingController(text: role.roleTitle);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Role Title'),
        content: TextField(
          controller: titleCtrl,
          decoration: const InputDecoration(labelText: 'Role Title'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty) return;
              await _roleService.updateRole(role.id, {'roleTitle': titleCtrl.text.trim()});
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteRole(OrganizationalRoleModel role) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Role'),
        content: Text('Are you sure you want to delete "${role.roleTitle}"? This will remove all member assignments.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await _roleService.deleteRole(role.id);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showMemberSelectionDialog(OrganizationalRoleModel role) {
    String searchQuery = '';
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final availableMembers = _allMembers.where((m) => 
            !role.memberMids.contains(m.mid) &&
            (m.fullName.toLowerCase().contains(searchQuery.toLowerCase()) || m.mid.contains(searchQuery))
          ).toList();

          return AlertDialog(
            title: const Text('Assign Member'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   TextField(
                    onChanged: (v) => setDialogState(() => searchQuery = v),
                    decoration: InputDecoration(
                      hintText: 'Search members...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: availableMembers.length,
                      itemBuilder: (context, index) {
                        final m = availableMembers[index];
                        return ListTile(
                          title: Text(m.fullName),
                          subtitle: Text(m.mid),
                          onTap: () async {
                            final newMids = List<String>.from(role.memberMids)..add(m.mid);
                            await _roleService.updateRole(role.id, {'memberMids': newMids});
                            if (mounted) Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _removeMemberFromRole(OrganizationalRoleModel role, String memberMid) async {
    final newMids = List<String>.from(role.memberMids)..remove(memberMid);
    await _roleService.updateRole(role.id, {'memberMids': newMids});
  }
}
