// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/family_service.dart';
import '../../services/member_service.dart';
import '../../services/export_service.dart';
import '../../services/session_manager.dart';
import '../../widgets/animation_utils.dart';
import '../../widgets/custom_export_dialog.dart';
import 'add_family_screen.dart';
import 'edit_family_screen.dart';
import 'subfamily_list_screen.dart';

class FamilyListScreen extends StatefulWidget {
  const FamilyListScreen({super.key});

  @override
  State<FamilyListScreen> createState() => _FamilyListScreenState();
}

class _FamilyListScreenState extends State<FamilyListScreen> {
  bool _isAdmin = false;
  String? _userFamilyDocId;
  bool _isExporting = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final role = await SessionManager.getRole();
    final isAdmin = await SessionManager.getIsAdmin();
    final familyDocId = await SessionManager.getFamilyDocId();
    setState(() {
      _isAdmin = (isAdmin == true) || role == 'admin' || role == 'super_admin';
      _userFamilyDocId = familyDocId;
    });
  }

  Future<void> _exportData(List<QueryDocumentSnapshot> familiesDocs, bool isExcel) async {
    setState(() => _isExporting = true);
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Generating ${isExcel ? "Excel (.xlsx)" : "PDF"} Export...')),
        );
      }

      final memberService = MemberService();
      final allMembers = await memberService.getAllMembers();

      final List<Map<String, dynamic>> exportData = [];

      for (final doc in familiesDocs) {
        final data = doc.data() as Map<String, dynamic>;
        final famId = doc.id;
        final familyIdVal = data['familyId']?.toString() ?? '-';
        final familyNameVal = data['familyName']?.toString() ?? 'Family';

        final familyMembers = allMembers.where((m) => m.familyDocId == famId).toList();

        // Check if any member or doc has a true custom YSK Family ID
        String effectiveYskId = data['yskFamilyId']?.toString() ?? data['dktFamilyId']?.toString() ?? '';
        if (effectiveYskId.isEmpty) {
          for (final m in familyMembers) {
            if (m.familyId.isNotEmpty && m.familyId != '-' && (m.familyId.length > 2 || m.familyId != familyIdVal)) {
              effectiveYskId = m.familyId;
              break;
            }
          }
        }
        if (effectiveYskId.isEmpty) {
          effectiveYskId = familyIdVal;
        }

        exportData.add({
          'familyDocId': famId,
          'familyId': effectiveYskId,
          'yskFamilyId': effectiveYskId,
          'serialFamilyId': familyIdVal,
          'familyName': familyNameVal,
          'members': familyMembers,
        });
      }

      if (isExcel) {
        await ExportService.exportToExcel(
          title: 'Ramanagara_Patidar_Samaj_Families',
          familiesData: exportData,
        );
      } else {
        await ExportService.exportToPdf(
          title: 'Ramanagara Patidar Samaj Families',
          familiesData: exportData,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('families')
          .snapshots(),
      builder: (context, snapshot) {
        List<QueryDocumentSnapshot> families = [];
        if (snapshot.hasData) {
          families = snapshot.data!.docs.where((doc) {
            if (doc.id == '83288') return false; // Hide system admin account
            final d = doc.data() as Map<String, dynamic>;
            return d['isAdmin'] != true;
          }).toList();
          
          // NON-ADMIN RESTRICTION: Regular family users can ONLY view their own family!
          if (!_isAdmin && _userFamilyDocId != null && _userFamilyDocId!.isNotEmpty) {
            families = families.where((doc) => doc.id == _userFamilyDocId).toList();
          }

          if (_searchQuery.trim().isNotEmpty) {
            final q = _searchQuery.trim().toLowerCase();
            families = families.where((doc) {
              final d = doc.data() as Map<String, dynamic>;
              final name = (d['familyName'] ?? '').toString().toLowerCase();
              final id = (d['familyId'] ?? '').toString().toLowerCase();
              return name.contains(q) || id.contains(q);
            }).toList();
          }

          families.sort((a, b) {
            final idA = (a.data() as Map<String, dynamic>)['familyId'] ?? '';
            final idB = (b.data() as Map<String, dynamic>)['familyId'] ?? '';
            return idA.toString().compareTo(idB.toString());
          });
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Families'),
            backgroundColor: Colors.blue.shade900,
            actions: [
              if (_isAdmin && families.isNotEmpty && !_isExporting) ...[
                IconButton(
                  icon: const Icon(Icons.table_chart_rounded),
                  tooltip: 'Export to Excel (.xlsx)',
                  onPressed: () => _exportData(families, true),
                ),
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  tooltip: 'Export to PDF',
                  onPressed: () => _exportData(families, false),
                ),
              ],
              if (_isExporting)
                const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  ),
                ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Search families (e.g. Patel, Demo)...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() => _searchQuery = ''),
                          )
                        : null,
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),
              Expanded(
                child: Builder(
                  builder: (context) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || families.isEmpty) {
                      return Center(
                        child: Text(
                          _searchQuery.isNotEmpty
                              ? 'No families matching "$_searchQuery"'
                              : 'No families found',
                        ),
                      );
                    }

                    return GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.9,
                ),
                itemCount: families.length,
                itemBuilder: (context, index) {
                  final doc = families[index];
                  final data = doc.data() as Map<String, dynamic>;

                  final familyName = data['familyName']?.toString() ?? 'Unnamed Family';
                  final familyId = data['familyId']?.toString() ?? '------';
                  final isBlocked = data['isBlocked'] == true;

                  return SlideInAnimation(
                    delay: Duration(milliseconds: 50 * index),
                    beginOffset: const Offset(0, 0.2),
                    child: AnimatedCard(
                      borderRadius: 16,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SubFamilyListScreen(
                              mainFamilyDocId: doc.id,
                              mainFamilyId: familyId,
                              mainFamilyName: familyName,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: isBlocked
                              ? LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.grey.shade300,
                                    Colors.grey.shade200,
                                  ],
                                )
                              : LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.blue.shade50,
                                    Colors.white,
                                  ],
                                ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isBlocked ? Colors.grey.shade400 : Colors.blue.shade200,
                            width: 1.5,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: isBlocked
                                            ? [Colors.grey.shade400, Colors.grey.shade500]
                                            : [Colors.blue.shade600, Colors.blue.shade800],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.holiday_village_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          familyName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          'ID: $familyId',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildCompactAction(
                                    icon: Icons.file_download_outlined,
                                    color: const Color(0xFF0F766E),
                                    onTap: () {
                                      CustomExportDialog.show(
                                        context,
                                        mainFamilyDocId: doc.id,
                                        familyName: familyName,
                                        familyId: familyId.toString(),
                                        restrictToSingleFamily: false,
                                      );
                                    },
                                  ),
                                  if (_isAdmin)
                                    _buildCompactAction(
                                      icon: Icons.edit,
                                    color: Colors.blue,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => EditFamilyScreen(
                                            docId: doc.id,
                                            data: data,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  if (_isAdmin)
                                    _buildCompactAction(
                                      icon: isBlocked ? Icons.lock_open : Icons.block,
                                      color: isBlocked ? Colors.green : Colors.orange,
                                      onTap: () async {
                                        await FamilyService().toggleBlockFamily(doc.id);
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
                                            title: const Text('Delete Family'),
                                            content: Text(
                                              'Are you sure you want to delete "$familyName"?\nThis will permanently delete this family, all its sub-families, and all members.',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(c, false),
                                                child: const Text('Cancel'),
                                              ),
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.red,
                                                ),
                                                onPressed: () => Navigator.pop(c, true),
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
                                                      Text('Deleting family, sub-families & members...'),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );

                                          try {
                                            await FamilyService().deleteFamily(doc.id);
                                            if (context.mounted) {
                                              Navigator.pop(context); // close progress dialog
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('"$familyName" deleted successfully'),
                                                  backgroundColor: Colors.green,
                                                ),
                                              );
                                            }
                                          } catch (e) {
                                            if (context.mounted) {
                                              Navigator.pop(context); // close progress dialog
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Error deleting family: $e'),
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
                      MaterialPageRoute(builder: (_) => const AddFamilyScreen()),
                    );
                  },
                  child: const Icon(Icons.add),
                ),
        );
      },
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
