// ignore_for_file: unused_import

import 'package:flutter/material.dart';
import '../../models/subfamily_model.dart';
import '../../services/subfamily_service.dart';
import '../../services/family_service.dart';
import '../../services/member_service.dart';
import '../../widgets/animation_utils.dart';
import 'member_list_screen.dart';
import '../../services/session_manager.dart';
import '../user/family_tree_view.dart';
import '../user/member_detail_screen.dart';
import '../user/member_update_request_screen.dart';
import '../../models/member_model.dart';


class SubFamilyListScreen extends StatefulWidget {
  final String mainFamilyDocId;
  final String mainFamilyId;
  final String mainFamilyName;

  const SubFamilyListScreen({
    super.key,
    required this.mainFamilyDocId,
    required this.mainFamilyId,
    required this.mainFamilyName,
  });

  @override
  State<SubFamilyListScreen> createState() => _SubFamilyListScreenState();
}

class _SubFamilyListScreenState extends State<SubFamilyListScreen> {
  final SubFamilyService _subFamilyService = SubFamilyService();
  final MemberService _memberService = MemberService();
  String _searchQuery = '';
  String? _userRole;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final role = await SessionManager.getRole();
    final isAdmin = await SessionManager.getIsAdmin();
    setState(() {
      _userRole = role;
      _isAdmin = (isAdmin == true) || role == 'admin' || role == 'super_admin';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.mainFamilyName} - Sub Families'),
        backgroundColor: Colors.blue.shade900,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_tree),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FamilyTreeView(
                    mainFamilyDocId: widget.mainFamilyDocId,
                    familyName: widget.mainFamilyName,
                  ),
                ),
              );
            },
            tooltip: 'View Family Tree',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search sub-families...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),

          // Common Parents Side-by-Side Boxes (Father & Mother)
          _buildParentsSection(),
          const SizedBox(height: 4),

          Expanded(
            child: StreamBuilder<List<SubFamilyModel>>(
              stream: _subFamilyService.streamSubFamilies(
                widget.mainFamilyDocId,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        Text('Error: ${snapshot.error}'),
                      ],
                    ),
                  );
                }

                if (snapshot.data!.isEmpty) {
                  return const Center(child: Text('No sub-families found'));
                }

                final subFamilies = snapshot.data!.where((subFamily) {
                  final name = subFamily.subFamilyName.toLowerCase();
                  final head = subFamily.headOfFamily.toLowerCase();
                  final searchLower = _searchQuery.toLowerCase();
                  return name.contains(searchLower) ||
                      head.contains(searchLower);
                }).toList()
                  ..sort((a, b) {
                    final isMainA = a.subFamilyId == '01' ||
                        a.subFamilyId == 'Main' ||
                        a.subFamilyName.toLowerCase().contains('main');
                    final isMainB = b.subFamilyId == '01' ||
                        b.subFamilyId == 'Main' ||
                        b.subFamilyName.toLowerCase().contains('main');
                    if (isMainA && !isMainB) return -1;
                    if (!isMainA && isMainB) return 1;

                    // Order wise: 1 is oldest, 2 is younger than 1, 3 is younger than 2, etc.
                    if (a.orderNumber != b.orderNumber) {
                      return a.orderNumber.compareTo(b.orderNumber);
                    }

                    return a.subFamilyName.compareTo(b.subFamilyName);
                  });

                if (subFamilies.isEmpty) {
                  return const Center(
                    child: Text('No sub-families match your search'),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.85, 
                  ),
                  itemCount: subFamilies.length,
                  itemBuilder: (context, index) {
                    final subFamily = subFamilies[index];
                    final isActive = subFamily.isActive;

                    return SlideInAnimation(
                      delay: Duration(milliseconds: 50 * index),
                      beginOffset: const Offset(0, 0.2),
                      child: AnimatedCard(
                        borderRadius: 16,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MemberListScreen(
                                familyDocId: widget.mainFamilyDocId,
                                familyName: subFamily.subFamilyName,
                                subFamilyDocId: subFamily.id,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: isActive
                                ? LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.purple.shade50,
                                      Colors.white,
                                    ],
                                  )
                                : LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.grey.shade300,
                                      Colors.grey.shade200,
                                    ],
                                  ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isActive
                                  ? Colors.purple.shade200
                                  : Colors.grey.shade400,
                              width: 1.5,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // HEADER
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: isActive
                                              ? [
                                                  Colors.purple.shade600,
                                                  Colors.purple.shade800,
                                                ]
                                              : [
                                                  Colors.grey.shade400,
                                                  Colors.grey.shade500,
                                                ],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: (isActive
                                                    ? Colors.purple
                                                    : Colors.grey)
                                                .withOpacity(0.3),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.groups_2_rounded,
                                        size: 20,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (subFamily.orderNumber > 0 || subFamily.seniority.isNotEmpty) ...[
                                      Builder(
                                        builder: (context) {
                                          final int orderNum = subFamily.orderNumber > 0
                                              ? subFamily.orderNumber
                                              : (subFamily.seniority == 'older'
                                                  ? 1
                                                  : int.tryParse(subFamily.seniority) ?? 0);
                                          if (orderNum <= 0) return const SizedBox.shrink();
                                          final bool isFirst = orderNum == 1;

                                          return Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3.5,
                                            ),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: isFirst
                                                    ? [
                                                        const Color(0xFFFEF3C7),
                                                        const Color(0xFFFDE68A),
                                                      ]
                                                    : [
                                                        const Color(0xFFEEF2FF),
                                                        const Color(0xFFE0E7FF),
                                                      ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                              borderRadius: BorderRadius.circular(16),
                                              border: Border.all(
                                                color: isFirst
                                                    ? const Color(0xFFF59E0B)
                                                    : const Color(0xFF818CF8),
                                                width: 1.1,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: (isFirst
                                                          ? const Color(0xFFF59E0B)
                                                          : const Color(0xFF6366F1))
                                                      .withValues(alpha: 0.15),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 1.5),
                                                ),
                                              ],
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment: CrossAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  isFirst
                                                      ? Icons.workspace_premium_rounded
                                                      : Icons.account_tree_rounded,
                                                  size: 12,
                                                  color: isFirst
                                                      ? const Color(0xFF92400E)
                                                      : const Color(0xFF4338CA),
                                                ),
                                                const SizedBox(width: 3.5),
                                                Text(
                                                  isFirst ? 'Branch #1 (Oldest)' : 'Branch #$orderNum',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    letterSpacing: 0.2,
                                                    color: isFirst
                                                        ? const Color(0xFF92400E)
                                                        : const Color(0xFF3730A3),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(width: 6),
                                    ],
                                    if (!isActive)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade100,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: Colors.red.shade300,
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          'INACTIVE',
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: Colors.red.shade700,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // SUB FAMILY NAME
                                Text(
                                  subFamily.subFamilyName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isActive
                                        ? Colors.black87
                                        : Colors.grey.shade700,
                                    height: 1.2,
                                  ),
                                ),

                                const SizedBox(height: 6),

                                // HEAD OF FAMILY
                                Row(
                                  children: [
                                    Icon(
                                      Icons.person,
                                      size: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        subFamily.headOfFamily,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 6),

                                // REAL-TIME MEMBER COUNT
                                FutureBuilder<int>(
                                  future: MemberService()
                                      .getSubFamilyMemberCount(
                                    widget.mainFamilyDocId,
                                    subFamily.id,
                                  ),
                                  builder: (context, countSnap) {
                                    final count = countSnap.data ?? 0;
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.purple.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.people,
                                            size: 12,
                                            color: Colors.purple.shade700,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '$count members',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.purple.shade700,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),

                                const Spacer(),

                                // ACTIONS
                                if (_userRole == 'admin' || _userRole == 'manager')
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceAround,
                                      children: [
                                        _buildCompactAction(
                                          icon: Icons.edit,
                                          color: Colors.blue,
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    EditSubFamilyScreen(
                                                  subFamily: subFamily,
                                                  mainFamilyDocId:
                                                      widget.mainFamilyDocId,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                        if (_isAdmin)
                                          _buildCompactAction(
                                            icon: isActive
                                                ? Icons.check_circle
                                                : Icons.block,
                                            color: isActive
                                                ? Colors.green
                                                : Colors.grey,
                                            onTap: () async {
                                              await _subFamilyService
                                                  .toggleSubFamilyStatus(
                                                mainFamilyDocId:
                                                    widget.mainFamilyDocId,
                                                subFamilyDocId: subFamily.id,
                                              );
                                            },
                                          ),
                                        if (_isAdmin)
                                          _buildCompactAction(
                                            icon: Icons.delete,
                                            color: Colors.red,
                                            onTap: () async {
                                              final ok = await showDialog<bool>(
                                                context: context,
                                                builder: (c) => AlertDialog(
                                                  title: const Text(
                                                      'Delete Sub Family'),
                                                  content: Text(
                                                    'Are you sure you want to delete "${subFamily.subFamilyName}"?\nThis will permanently delete this sub-family and all its members.',
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(c, false),
                                                      child: const Text('Cancel'),
                                                    ),
                                                    ElevatedButton(
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            Colors.red,
                                                      ),
                                                      onPressed: () =>
                                                          Navigator.pop(c, true),
                                                      child: const Text('Delete'),
                                                    ),
                                                  ],
                                                ),
                                              );

                                              if (ok == true && context.mounted) {
                                                showDialog(
                                                  context: context,
                                                  barrierDismissible: false,
                                                  builder: (_) => const Center(
                                                    child: Card(
                                                      child: Padding(
                                                        padding: EdgeInsets.all(20),
                                                        child: Column(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            CircularProgressIndicator(),
                                                            SizedBox(height: 16),
                                                            Text('Deleting sub-family & members...'),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                );

                                                try {
                                                  await _subFamilyService
                                                      .deleteSubFamily(
                                                    mainFamilyDocId:
                                                        widget.mainFamilyDocId,
                                                    subFamilyDocId: subFamily.id,
                                                  );
                                                  if (context.mounted) {
                                                    Navigator.pop(context); // close progress dialog
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(
                                                        content: Text('"${subFamily.subFamilyName}" deleted successfully'),
                                                        backgroundColor: Colors.green,
                                                      ),
                                                    );
                                                  }
                                                } catch (e) {
                                                  if (context.mounted) {
                                                    Navigator.pop(context); // close progress dialog
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(
                                                        content: Text('Error deleting sub-family: $e'),
                                                        backgroundColor: Colors.red,
                                                      ),
                                                    );
                                                  }
                                                }
                                              }
                                            },
                                          ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: !_isAdmin
          ? null
          : FloatingActionButton(
              backgroundColor: Colors.blue.shade900,
              foregroundColor: Colors.white,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddSubFamilyScreen(
                      mainFamilyDocId: widget.mainFamilyDocId,
                      mainFamilyId: widget.mainFamilyId,
                      mainFamilyName: widget.mainFamilyName,
                    ),
                  ),
                );
              },
              child: const Icon(Icons.add),
            ),
    );
  }

  Widget _buildParentsSection() {
    return StreamBuilder<List<MemberModel>>(
      stream: _memberService.streamSubFamilyMembers(widget.mainFamilyDocId, ''),
      builder: (context, snapshot) {
        final members = snapshot.data ?? [];

        // 1. Identify Father
        MemberModel? father;
        try {
          father = members.firstWhere(
            (m) =>
                m.gender.toLowerCase() == 'male' &&
                (m.relationToHead.toLowerCase().contains('father') ||
                    m.relationToHead.toLowerCase() == 'head'),
          );
        } catch (_) {
          try {
            father = members.firstWhere((m) => m.gender.toLowerCase() == 'male');
          } catch (_) {
            if (members.isNotEmpty) father = members.first;
          }
        }

        // 2. Identify Mother
        MemberModel? mother;
        try {
          mother = members.firstWhere(
            (m) =>
                m.gender.toLowerCase() == 'female' &&
                (m.relationToHead.toLowerCase().contains('mother') ||
                    m.relationToHead.toLowerCase() == 'wife'),
          );
        } catch (_) {
          try {
            mother = members.firstWhere((m) => m.gender.toLowerCase() == 'female');
          } catch (_) {
            final remaining = members.where((m) => m.id != father?.id).toList();
            if (remaining.isNotEmpty) mother = remaining.first;
          }
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    'Parents (માતા-પિતા)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey.shade800,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const Spacer(),
                  if (_isAdmin || _userRole == 'manager')
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MemberListScreen(
                              familyDocId: widget.mainFamilyDocId,
                              familyName: '${widget.mainFamilyName} (Common Elders)',
                              subFamilyDocId: '',
                            ),
                          ),
                        );
                      },
                      child: Text(
                        'Manage Elders >',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _buildParentBox(
                        title: 'Father (પિતા)',
                        member: father,
                        isFather: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildParentBox(
                        title: 'Mother (માતા)',
                        member: mother,
                        isFather: false,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildParentBox({
    required String title,
    required MemberModel? member,
    required bool isFather,
  }) {
    final bool canEdit = _isAdmin || _userRole == 'manager';

    if (member == null) {
      if (!canEdit) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300, width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    isFather ? Icons.person_rounded : Icons.person_2_rounded,
                    size: 14,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Not added',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        );
      }

      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddMemberScreen(
                  familyDocId: widget.mainFamilyDocId,
                  familyName: widget.mainFamilyName,
                  subFamilyDocId: '',
                  initialGender: isFather ? 'male' : 'female',
                  initialRelationToHead: isFather ? 'head' : 'wife',
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300, width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      isFather ? Icons.person_rounded : Icons.person_2_rounded,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.add_circle_outline_rounded, size: 13, color: Colors.blue.shade700),
                    const SizedBox(width: 4),
                    Text(
                      'Add',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    final bool isLate = member.isLate;

    if (isLate) {
      // Deceased / Late member rectangle box:
      final lateCardContent = Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text('🕊️', style: TextStyle(fontSize: 11)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (canEdit)
                  InkWell(
                    onTap: () => _onEditParent(member),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFCBD5E1), width: 0.8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit_outlined, size: 10.5, color: Color(0xFF334155)),
                          SizedBox(width: 3),
                          Text(
                            'Edit',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Late ${member.fullName}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF334155),
                height: 1.25,
              ),
            ),
          ],
        ),
      );

      // Normal users: completely non-clickable, no edit button
      if (!canEdit) {
        return lateCardContent;
      }

      // Admins & Managers: clickable to edit
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _onEditParent(member),
          child: lateCardContent,
        ),
      );
    }

    // Active / Alive member rectangle box:
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MemberDetailScreen(
                memberId: member.id,
                familyDocId: widget.mainFamilyDocId,
                subFamilyDocId: '',
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isFather
                  ? [
                      const Color(0xFFEFF6FF),
                      const Color(0xFFDBEAFE),
                    ]
                  : [
                      const Color(0xFFFFF1F2),
                      const Color(0xFFFFE4E6),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isFather ? const Color(0xFF93C5FD) : const Color(0xFFFECDD3),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: (isFather ? const Color(0xFF3B82F6) : const Color(0xFFF43F5E))
                    .withValues(alpha: 0.08),
                blurRadius: 4,
                offset: const Offset(0, 1.5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    isFather ? Icons.person_rounded : Icons.person_2_rounded,
                    size: 14,
                    color: isFather ? const Color(0xFF1D4ED8) : const Color(0xFFBE123C),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: isFather ? const Color(0xFF1D4ED8) : const Color(0xFFBE123C),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (canEdit) ...[
                    InkWell(
                      onTap: () => _onEditParent(member),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: isFather ? const Color(0xFFDBEAFE) : const Color(0xFFFFE4E6),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isFather ? const Color(0xFF93C5FD) : const Color(0xFFFECDD3),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.edit_outlined,
                              size: 10.5,
                              color: isFather ? const Color(0xFF1D4ED8) : const Color(0xFFBE123C),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'Edit',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: isFather ? const Color(0xFF1D4ED8) : const Color(0xFFBE123C),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 10,
                    color: isFather ? const Color(0xFF2563EB) : const Color(0xFFE11D48),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                member.fullName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                  height: 1.2,
                ),
              ),
              if (member.phone.isNotEmpty) ...[
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(Icons.phone, size: 10, color: Colors.blueGrey.shade600),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        member.phone,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blueGrey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _onEditParent(MemberModel member) {
    if (!(_isAdmin || _userRole == 'manager')) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditMemberScreen(
          memberId: member.id,
          familyDocId: widget.mainFamilyDocId,
          subFamilyDocId: '',
        ),
      ),
    );
  }

  Widget _buildCompactAction({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}

// Add Sub Family Screen
class AddSubFamilyScreen extends StatefulWidget {
  final String mainFamilyDocId;
  final String mainFamilyId;
  final String mainFamilyName;

  const AddSubFamilyScreen({
    super.key,
    required this.mainFamilyDocId,
    required this.mainFamilyId,
    required this.mainFamilyName,
  });

  @override
  State<AddSubFamilyScreen> createState() => _AddSubFamilyScreenState();
}

class _AddSubFamilyScreenState extends State<AddSubFamilyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subFamilyNameCtrl = TextEditingController();
  final _headOfFamilyCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _orderCtrl = TextEditingController(text: '1');
  int _orderNumber = 1;
  bool _loading = false;

  @override
  void dispose() {
    _subFamilyNameCtrl.dispose();
    _headOfFamilyCtrl.dispose();
    _descriptionCtrl.dispose();
    _orderCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      await SubFamilyService().addSubFamily(
        mainFamilyDocId: widget.mainFamilyDocId,
        mainFamilyId: widget.mainFamilyId,
        mainFamilyName: widget.mainFamilyName,
        subFamilyName: _subFamilyNameCtrl.text.trim(),
        headOfFamily: _headOfFamilyCtrl.text.trim(),
        description: _descriptionCtrl.text.trim(),
        orderNumber: _orderNumber,
        seniority: _orderNumber.toString(),
      );

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding sub family: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Sub Family'),
        backgroundColor: Colors.blue.shade900,
      ),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _subFamilyNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Sub Family Name *',
                      hintText: 'e.g., Sharma Family',
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _headOfFamilyCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Head of Family *',
                      hintText: 'e.g., Rajesh Sharma',
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Sub-Family Order Number (Seniority) *',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Enter order number: 1 is oldest/first, 2 is younger than 1, 3 is younger than 1 & 2, etc.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      IconButton.filledTonal(
                        icon: const Icon(Icons.remove),
                        onPressed: _orderNumber > 1
                            ? () {
                                setState(() {
                                  _orderNumber--;
                                  _orderCtrl.text = _orderNumber.toString();
                                });
                              }
                            : null,
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 75,
                        child: TextFormField(
                          controller: _orderCtrl,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onChanged: (val) {
                            final parsed = int.tryParse(val.trim());
                            if (parsed != null && parsed >= 1) {
                              setState(() => _orderNumber = parsed);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        icon: const Icon(Icons.add),
                        onPressed: () {
                          setState(() {
                            _orderNumber++;
                            _orderCtrl.text = _orderNumber.toString();
                          });
                        },
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _orderNumber == 1
                                  ? [
                                      const Color(0xFFFEF3C7),
                                      const Color(0xFFFDE68A),
                                    ]
                                  : [
                                      const Color(0xFFEEF2FF),
                                      const Color(0xFFE0E7FF),
                                    ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _orderNumber == 1
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFF818CF8),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (_orderNumber == 1
                                        ? const Color(0xFFF59E0B)
                                        : const Color(0xFF6366F1))
                                    .withValues(alpha: 0.12),
                                blurRadius: 4,
                                offset: const Offset(0, 1.5),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _orderNumber == 1
                                    ? Icons.workspace_premium_rounded
                                    : Icons.account_tree_rounded,
                                size: 18,
                                color: _orderNumber == 1
                                    ? const Color(0xFF92400E)
                                    : const Color(0xFF4338CA),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _orderNumber == 1
                                      ? 'Branch #1: Oldest / Head Branch'
                                      : 'Branch #$_orderNumber: Younger than #${_orderNumber - 1}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _orderNumber == 1
                                        ? const Color(0xFF92400E)
                                        : const Color(0xFF3730A3),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'Optional description about this sub family',
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _submitForm,
                    child: const Text('Add Sub Family'),
                  ),
                ],
              ),
            ),
          ),
          // Loading overlay
          if (_loading)
            Container(
              color: Colors.black45,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 16),
                    Text(
                      'Adding sub family...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Edit Sub Family Screen
class EditSubFamilyScreen extends StatefulWidget {
  final SubFamilyModel subFamily;
  final String mainFamilyDocId;

  const EditSubFamilyScreen({
    super.key,
    required this.subFamily,
    required this.mainFamilyDocId,
  });

  @override
  State<EditSubFamilyScreen> createState() => _EditSubFamilyScreenState();
}

class _EditSubFamilyScreenState extends State<EditSubFamilyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subFamilyNameCtrl = TextEditingController();
  final _headOfFamilyCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  late final TextEditingController _orderCtrl;
  late int _orderNumber;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _subFamilyNameCtrl.text = widget.subFamily.subFamilyName;
    _headOfFamilyCtrl.text = widget.subFamily.headOfFamily;
    _descriptionCtrl.text = widget.subFamily.description;
    _orderNumber = widget.subFamily.orderNumber > 0 ? widget.subFamily.orderNumber : 1;
    _orderCtrl = TextEditingController(text: _orderNumber.toString());
  }

  @override
  void dispose() {
    _subFamilyNameCtrl.dispose();
    _headOfFamilyCtrl.dispose();
    _descriptionCtrl.dispose();
    _orderCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      await SubFamilyService().updateSubFamily(
        mainFamilyDocId: widget.mainFamilyDocId,
        subFamilyDocId: widget.subFamily.id,
        subFamilyName: _subFamilyNameCtrl.text.trim(),
        headOfFamily: _headOfFamilyCtrl.text.trim(),
        description: _descriptionCtrl.text.trim(),
        orderNumber: _orderNumber,
        seniority: _orderNumber.toString(),
      );

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating sub family: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Sub Family'),
        backgroundColor: Colors.blue.shade900,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            tooltip: 'Delete Sub Family',
            onPressed: _loading ? null : _deleteSubFamily,
          ),
        ],
      ),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _subFamilyNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Sub Family Name *',
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _headOfFamilyCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Head of Family *',
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Sub-Family Order Number (Seniority) *',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Enter order number: 1 is oldest/first, 2 is younger than 1, 3 is younger than 1 & 2, etc.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      IconButton.filledTonal(
                        icon: const Icon(Icons.remove),
                        onPressed: _orderNumber > 1
                            ? () {
                                setState(() {
                                  _orderNumber--;
                                  _orderCtrl.text = _orderNumber.toString();
                                });
                              }
                            : null,
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 75,
                        child: TextFormField(
                          controller: _orderCtrl,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onChanged: (val) {
                            final parsed = int.tryParse(val.trim());
                            if (parsed != null && parsed >= 1) {
                              setState(() => _orderNumber = parsed);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        icon: const Icon(Icons.add),
                        onPressed: () {
                          setState(() {
                            _orderNumber++;
                            _orderCtrl.text = _orderNumber.toString();
                          });
                        },
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _orderNumber == 1
                                  ? [
                                      const Color(0xFFFEF3C7),
                                      const Color(0xFFFDE68A),
                                    ]
                                  : [
                                      const Color(0xFFEEF2FF),
                                      const Color(0xFFE0E7FF),
                                    ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _orderNumber == 1
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFF818CF8),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (_orderNumber == 1
                                        ? const Color(0xFFF59E0B)
                                        : const Color(0xFF6366F1))
                                    .withValues(alpha: 0.12),
                                blurRadius: 4,
                                offset: const Offset(0, 1.5),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _orderNumber == 1
                                    ? Icons.workspace_premium_rounded
                                    : Icons.account_tree_rounded,
                                size: 18,
                                color: _orderNumber == 1
                                    ? const Color(0xFF92400E)
                                    : const Color(0xFF4338CA),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _orderNumber == 1
                                      ? 'Branch #1: Oldest / Head Branch'
                                      : 'Branch #$_orderNumber: Younger than #${_orderNumber - 1}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _orderNumber == 1
                                        ? const Color(0xFF92400E)
                                        : const Color(0xFF3730A3),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionCtrl,
                    decoration: const InputDecoration(labelText: 'Description'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _submitForm,
                    child: const Text('Update Sub Family'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete Sub Family'),
                    onPressed: _deleteSubFamily,
                  ),
                ],
              ),
            ),
          ),
          // Loading overlay
          if (_loading)
            Container(
              color: Colors.black45,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 16),
                    Text(
                      'Updating sub family...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _deleteSubFamily() async {
    final subName = widget.subFamily.subFamilyName;

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete Sub Family'),
        content: Text(
          'Are you sure you want to delete "$subName"?\nThis will permanently delete this sub-family and all its members.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok == true && mounted) {
      setState(() => _loading = true);
      try {
        await SubFamilyService().deleteSubFamily(
          mainFamilyDocId: widget.mainFamilyDocId,
          subFamilyDocId: widget.subFamily.id,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"$subName" deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting sub-family: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _loading = false);
        }
      }
    }
  }
}
