// ignore_for_file: no_leading_underscores_for_local_identifiers, use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import '../../../services/group_service.dart';
import '../../../services/member_service.dart';
import '../../../services/session_manager.dart';
import '../../../models/group_model.dart';
import '../../../models/member_model.dart';

class GroupManagementScreen extends StatefulWidget {
  const GroupManagementScreen({super.key});

  @override
  State<GroupManagementScreen> createState() => _GroupManagementScreenState();
}

class _GroupManagementScreenState extends State<GroupManagementScreen> {
  final GroupService _groupService = GroupService();
  final MemberService _memberService = MemberService();
  final _nameCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _groupSearchCtrl = TextEditingController();
  String _selectedType = 'community';
  String? _familyDocId;
  String? _userRole;
  List<MemberModel> _allMembers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    final docId = await SessionManager.getFamilyDocId();
    final role = await SessionManager.getRole();
    final members = await _memberService.streamAllMembers().first;
    if (mounted) {
      setState(() {
        _familyDocId = docId;
        _userRole = role;
        _allMembers = members;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _familyDocId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Group Management',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _groupSearchCtrl,
              onChanged: (v) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search groups...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<GroupModel>>(
              stream: _groupService.streamGroups(_familyDocId!),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final query = _groupSearchCtrl.text.toLowerCase();
                final groups = snapshot.data!.where((g) {
                  return g.name.toLowerCase().contains(query) ||
                      g.description.toLowerCase().contains(query) ||
                      g.type.toLowerCase().contains(query);
                }).toList();

                if (groups.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.groups_outlined, size: 64, color: Colors.grey.shade400),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          query.isEmpty ? 'No groups yet' : 'No matching groups',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    return _buildGroupCard(group);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _userRole == 'admin'
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF1E293B),
              onPressed: () => _showAddDialog(),
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text('New Group', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }

  Widget _buildGroupCard(GroupModel group) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _getTypeColor(group.type).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(_getTypeIcon(group.type), color: _getTypeColor(group.type), size: 24),
        ),
        title: Text(
          group.name,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF1E293B)),
        ),
        subtitle: Text(
          '${group.memberIds.length} members • ${group.type.toUpperCase()}',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w500),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (group.description.isNotEmpty) ...[
                  Text(
                    group.description,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                ],
                const Text(
                  'Members',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF475569)),
                ),
                const SizedBox(height: 8),
                if (group.memberIds.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('No members in this group', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                  )
                else
                  Column(
                    children: group.memberIds.map((memberId) {
                      final member = _allMembers.firstWhere(
                        (m) => m.id == memberId,
                        orElse: () => MemberModel.empty().copyWith(fullName: 'Unknown'),
                      );
                      return _buildMemberListItem(group, member);
                    }).toList(),
                  ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _showAddMembersDialog(group),
                      icon: const Icon(Icons.person_add_outlined, size: 20),
                      label: const Text('Add Members'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                    if (_userRole == 'admin') ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF64748B)),
                        onPressed: () => _showEditDialog(group),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Color(0xFFEF4444)),
                        onPressed: () => _confirmDeleteGroup(group),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberListItem(GroupModel group, MemberModel member) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        dense: true,
        leading: CircleAvatar(
          radius: 14,
          backgroundColor: const Color(0xFFE2E8F0),
          child: Text(
            member.fullName.isNotEmpty ? member.fullName[0].toUpperCase() : '?',
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
          ),
        ),
        title: Text(
          member.fullName,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
        ),
        subtitle: Text(
          member.mid,
          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.remove_circle_outline_rounded, size: 18, color: Color(0xFFEF4444)),
          onPressed: () => _confirmRemoveMember(group, member),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'yuvak':
        return Icons.rocket_launch_outlined;
      case 'mahila':
        return Icons.face_retouching_natural_outlined;
      case 'sanskar':
        return Icons.auto_stories_outlined;
      case 'community':
        return Icons.groups_3_outlined;
      default:
        return Icons.group_outlined;
    }
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'yuvak':
        return Colors.blue;
      case 'mahila':
        return Colors.pink;
      case 'sanskar':
        return Colors.orange;
      case 'community':
        return Colors.indigo;
      default:
        return Colors.blueGrey;
    }
  }

  Future<void> _confirmDeleteGroup(GroupModel group) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Group'),
        content: Text('Are you sure you want to delete "${group.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _groupService.deleteGroup(_familyDocId!, group.id);
    }
  }

  Future<void> _confirmRemoveMember(GroupModel group, MemberModel member) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text('Remove ${member.fullName} from ${group.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _groupService.removeMemberFromGroup(
        familyDocId: _familyDocId!,
        groupId: group.id,
        memberId: member.id,
      );
    }
  }

  void _showAddMembersDialog(GroupModel group) {
    final availableMembers = _allMembers
        .where((m) => !group.memberIds.contains(m.id))
        .toList();

    if (availableMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All members are already in this group')),
      );
      return;
    }

    final Set<String> _selectedMembers = {};
    String _searchQuery = '';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final filteredMembers = availableMembers.where((m) => 
            m.fullName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            m.mid.toLowerCase().contains(_searchQuery.toLowerCase())
          ).toList();

          return AlertDialog(
            title: const Text('Add Members'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    onChanged: (v) => setDialogState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: 'Search members...',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: filteredMembers.length,
                      itemBuilder: (context, index) {
                        final member = filteredMembers[index];
                        return CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(member.fullName, style: const TextStyle(fontSize: 14)),
                          subtitle: Text(member.mid, style: const TextStyle(fontSize: 11)),
                          value: _selectedMembers.contains(member.id),
                          onChanged: (checked) {
                            setDialogState(() {
                              if (checked == true) {
                                _selectedMembers.add(member.id);
                              } else {
                                _selectedMembers.remove(member.id);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: _selectedMembers.isEmpty ? null : () async {
                  Navigator.pop(context);
                  for (final memberId in _selectedMembers) {
                    await _groupService.addMemberToGroup(
                      familyDocId: _familyDocId!,
                      groupId: group.id,
                      memberId: memberId,
                    );
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Members added successfully')),
                  );
                },
                child: Text('Add (${_selectedMembers.length})'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddDialog() {
    _nameCtrl.clear();
    _descriptionCtrl.clear();
    _selectedType = 'community';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Group'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Group Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionCtrl,
                decoration: InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: InputDecoration(
                  labelText: 'Group Type',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: [
                  {'value': 'community', 'label': 'Community'},
                  {'value': 'yuvak', 'label': 'Yuvak'},
                  {'value': 'mahila', 'label': 'Mahila'},
                  {'value': 'sanskar', 'label': 'Sanskar'},
                ].map((t) => DropdownMenuItem(
                  value: t['value'] as String,
                  child: Text(t['label'] as String),
                )).toList(),
                onChanged: (v) => _selectedType = v!,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (_nameCtrl.text.trim().isEmpty) return;
              await _groupService.createGroupWithDetails(
                familyDocId: _familyDocId!,
                name: _nameCtrl.text.trim(),
                description: _descriptionCtrl.text.trim(),
                type: _selectedType,
                createdBy: 'admin',
              );
              Navigator.pop(context);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(GroupModel group) {
    _nameCtrl.text = group.name;
    _descriptionCtrl.text = group.description;
    _selectedType = group.type;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Group'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Group Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionCtrl,
                decoration: InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: InputDecoration(
                  labelText: 'Group Type',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: [
                  {'value': 'community', 'label': 'Community'},
                  {'value': 'yuvak', 'label': 'Yuvak'},
                  {'value': 'mahila', 'label': 'Mahila'},
                  {'value': 'sanskar', 'label': 'Sanskar'},
                ].map((t) => DropdownMenuItem(
                  value: t['value'] as String,
                  child: Text(t['label'] as String),
                )).toList(),
                onChanged: (v) => _selectedType = v!,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (_nameCtrl.text.trim().isEmpty) return;
              await _groupService.updateGroupWithDetails(
                familyDocId: _familyDocId!,
                groupId: group.id,
                name: _nameCtrl.text.trim(),
                description: _descriptionCtrl.text.trim(),
                type: _selectedType,
              );
              Navigator.pop(context);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }
}


