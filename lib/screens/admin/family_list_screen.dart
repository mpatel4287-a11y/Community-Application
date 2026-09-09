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
  String? _userRole;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final role = await SessionManager.getRole();
    setState(() => _userRole = role);
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

        exportData.add({
          'familyDocId': famId,
          'familyId': familyIdVal,
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
          .where('isAdmin', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        List<QueryDocumentSnapshot> families = [];
        if (snapshot.hasData) {
          families = List.from(snapshot.data!.docs);
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
              if (families.isNotEmpty && !_isExporting) ...[
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
          body: Builder(
            builder: (context) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || families.isEmpty) {
                return const Center(child: Text('No families found'));
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
                                  if (_userRole == 'admin')
                                    _buildCompactAction(
                                      icon: isBlocked ? Icons.lock_open : Icons.block,
                                      color: isBlocked ? Colors.green : Colors.orange,
                                      onTap: () async {
                                        await FamilyService().toggleBlockFamily(doc.id);
                                      },
                                    ),
                                  if (_userRole == 'admin')
                                    _buildCompactAction(
                                      icon: Icons.delete,
                                      color: Colors.red,
                                      onTap: () async {
                                        final ok = await showDialog<bool>(
                                          context: context,
                                          builder: (c) => AlertDialog(
                                            title: const Text('Delete Family'),
                                            content: const Text(
                                              'Are you sure? This deletes all members.',
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

                                        if (ok == true) {
                                          await FamilyService().deleteFamily(doc.id);
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
          floatingActionButton: _userRole != 'admin'
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
