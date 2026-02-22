import 'package:flutter/material.dart';
import '../../models/member_model.dart';
import '../../services/member_service.dart';
import '../../services/subfamily_service.dart';
import 'sub_family_tree_detail_screen.dart';

class FamilyTreeView extends StatefulWidget {
  final String mainFamilyDocId;
  final String familyName;
  final String? subFamilyDocId;

  const FamilyTreeView({
    super.key,
    required this.mainFamilyDocId,
    required this.familyName,
    this.subFamilyDocId,
  });

  @override
  State<FamilyTreeView> createState() => _FamilyTreeViewState();
}

class _FamilyTreeViewState extends State<FamilyTreeView> {
  final MemberService _memberService = MemberService();
  final SubFamilyService _subFamilyService = SubFamilyService();
  bool _loading = true;
  List<Map<String, dynamic>> _subFamilies = [];

  @override
  void initState() {
    super.initState();
    _loadSubFamilies();
  }

  Future<void> _loadSubFamilies() async {
    setState(() => _loading = true);

    try {
      debugPrint('Loading family tree for: ${widget.mainFamilyDocId}');
      
      // 1. Fetch sub-families first
      // Add timeout to prevent hanging
      final subFamilies = await _subFamilyService
          .getSubFamilies(widget.mainFamilyDocId)
          .timeout(const Duration(seconds: 10));
      
      debugPrint('Sub-families fetched: ${subFamilies.length}');

      if (subFamilies.isEmpty) {
        if (mounted) {
           debugPrint('No sub-families found for ${widget.mainFamilyDocId}');
           setState(() {
             _subFamilies = [];
             _loading = false;
           });
        }
        return;
      }

      // 2. Fetch members for each sub-family in parallel
      final List<Future<List<MemberModel>>> memberFutures = [];
      for (final sf in subFamilies) {
        memberFutures.add(
          _memberService.getSubFamilyMembers(widget.mainFamilyDocId, sf.id)
              .timeout(const Duration(seconds: 5))
              .catchError((e) {
                debugPrint('Error fetching members for ${sf.id}: $e');
                // Return empty list on error instead of failing everything
                return <MemberModel>[];
              })
        );
      }

      final List<List<MemberModel>> results = await Future.wait(memberFutures);
      debugPrint('Members fetched for ${results.length} sub-families');

      // 3. Aggregate data
      final List<Map<String, dynamic>> subFamilyList = [];
      
      // Sort sub-families: Main Family first, then alphabetical
      // Create a list of indices to sort
      final List<int> indices = List.generate(subFamilies.length, (i) => i);
      indices.sort((a, b) {
        final sfA = subFamilies[a];
        final sfB = subFamilies[b];
        
        // Check if one is Main (usually empty subFamilyId or specific name)
        // Adjust logic based on your convention. Assuming 'Main' name or empty ID
        final isMainA = sfA.subFamilyId == 'Main' || sfA.subFamilyName.contains('Main');
        final isMainB = sfB.subFamilyId == 'Main' || sfB.subFamilyName.contains('Main');

        if (isMainA && !isMainB) return -1;
        if (!isMainA && isMainB) return 1;
        
        return sfA.subFamilyName.compareTo(sfB.subFamilyName);
      });

      for (int index in indices) {
        final sf = subFamilies[index];
        final members = results[index];
        
        // Filter by subFamilyDocId if widget.subFamilyDocId is set
        if (widget.subFamilyDocId != null && sf.id != widget.subFamilyDocId) {
          continue;
        }

        if (members.isNotEmpty) {
           subFamilyList.add({
             'docId': sf.id,
             'id': sf.subFamilyId.isEmpty ? 'Main' : sf.subFamilyId,
             'name': sf.subFamilyName,
             'memberCount': members.length,
             'members': members,
           });
        }
      }

      debugPrint('Sub-family list built: ${subFamilyList.length} items');

      if (mounted) {
        setState(() {
          _subFamilies = subFamilyList;
          _loading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('Error loading sub-families: $e');
      debugPrint(stackTrace.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading family tree: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
        setState(() {
          _subFamilies = [];
          _loading = false;
        });
      }
    }
  }

  void _navigateToSubFamilyTree(Map<String, dynamic> subFamily) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SubFamilyTreeDetailScreen(
          mainFamilyDocId: widget.mainFamilyDocId,
          familyName: widget.familyName,
          subFamilyDocId: subFamily['docId'],
          subFamilyId: subFamily['id'],
          subFamilyName: subFamily['name'],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.familyName} - Family Trees',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF4A90E2),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: Colors.grey[100],
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4A90E2)),
              ),
            )
          : _subFamilies.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.account_tree,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No sub-families found',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _subFamilies.length,
                  itemBuilder: (context, index) {
                      final subFamily = _subFamilies[index];
                      final memberCount = subFamily['memberCount'] as int;
                      final subFamilyName = subFamily['name'] as String;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: InkWell(
                          onTap: () => _navigateToSubFamilyTree(subFamily),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.blue.shade50,
                                  Colors.purple.shade50,
                                ],
                              ),
                            ),
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4A90E2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.account_tree,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        subFamilyName,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF2C3E50),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '$memberCount ${memberCount == 1 ? 'member' : 'members'}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  color: Colors.grey.shade400,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
    );
  }
}
