// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/family_service.dart';
import '../../services/session_manager.dart';
import '../../widgets/animation_utils.dart';
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

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final role = await SessionManager.getRole();
    setState(() => _userRole = role);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Families'),
        backgroundColor: Colors.blue.shade900,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('families')
            .where('isAdmin', isEqualTo: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No families found'));
          }

          final families = snapshot.data!.docs;
          // Client-side sort by familyId
          families.sort((a, b) {
            final idA = (a.data() as Map<String, dynamic>)['familyId'] ?? '';
            final idB = (b.data() as Map<String, dynamic>)['familyId'] ?? '';
            return idA.toString().compareTo(idB.toString());
          });

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

              final familyName =
                  data['familyName']?.toString() ?? 'Unnamed Family';
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
                        color: isBlocked
                            ? Colors.grey.shade400
                            : Colors.blue.shade200,
                        width: 1.5,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // HEADER WITH ICON
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
                                  boxShadow: [
                                    BoxShadow(
                                      color: (isBlocked
                                              ? Colors.grey
                                              : Colors.blue)
                                          .withOpacity(0.3),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.family_restroom,
                                  size: 20,
                                  color: Colors.white,
                                ),
                              ),
                              const Spacer(),
                              if (isBlocked)
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
                                    'BLOCKED',
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

                          // FAMILY NAME
                          Text(
                            familyName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isBlocked
                                  ? Colors.grey.shade700
                                  : Colors.black87,
                              height: 1.2,
                            ),
                          ),

                          const SizedBox(height: 6),

                          // FAMILY ID
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: (isBlocked
                                      ? Colors.grey
                                      : Colors.teal)
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'ID: $familyId',
                              style: TextStyle(
                                color: isBlocked
                                    ? Colors.grey.shade600
                                    : Colors.teal.shade700,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),

                          const Spacer(),

                          // ACTIONS
                          if (_userRole == 'admin' || _userRole == 'manager')
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
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
                                      icon: isBlocked
                                          ? Icons.lock_open
                                          : Icons.block,
                                      color: isBlocked
                                          ? Colors.green
                                          : Colors.orange,
                                      onTap: () async {
                                        await FamilyService()
                                            .toggleBlockFamily(doc.id);
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
                                                onPressed: () =>
                                                    Navigator.pop(c, false),
                                                child: const Text('Cancel'),
                                              ),
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.red,
                                                ),
                                                onPressed: () =>
                                                    Navigator.pop(c, true),
                                                child: const Text('Delete'),
                                              ),
                                            ],
                                          ),
                                        );

                                        if (ok == true) {
                                          await FamilyService()
                                              .deleteFamily(doc.id);
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
