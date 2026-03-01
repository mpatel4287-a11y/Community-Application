// lib/screens/admin/firms_list_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/member_model.dart';
import '../../models/firm_model.dart';
import '../../models/sub_firm_model.dart';
import '../../services/member_service.dart';
import '../../services/firm_service.dart';
import '../../services/language_service.dart';
import '../../widgets/animation_utils.dart';
import 'create_firm_screen.dart';
import 'firm_detail_screen.dart';

class FirmsListScreen extends StatefulWidget {
  const FirmsListScreen({super.key});

  @override
  State<FirmsListScreen> createState() => _FirmsListScreenState();
}

class _FirmsListScreenState extends State<FirmsListScreen> {
  final FirmService _firmService = FirmService();
  final MemberService _memberService = MemberService();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageService>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(lang.translate('firms')),
        backgroundColor: Colors.blue.shade900,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Create Firm',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CreateFirmScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: 'Search firms...',
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          
          // Firms List
          Expanded(
            child: StreamBuilder<List<FirmModel>>(
              stream: _firmService.getFirmsStream(),
              builder: (context, firmSnapshot) {
                if (firmSnapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        PulseAnimation(
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blue.shade400,
                                  Colors.blue.shade700,
                                ],
                              ),
                            ),
                            child: const Icon(
                              Icons.store,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Loading firms...',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (!firmSnapshot.hasData || firmSnapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.business_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No firms found',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const CreateFirmScreen()),
                            );
                          },
                          child: const Text('Create Firm'),
                        )
                      ],
                    ),
                  );
                }

                final firms = firmSnapshot.data!.where((firm) {
                  if (_searchQuery.isEmpty) return true;
                  return firm.name.toLowerCase().contains(_searchQuery.toLowerCase());
                }).toList();

                if (firms.isEmpty) {
                  return Center(
                    child: Text(
                      'No firms match your search',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  );
                }

                // Wrap in Member stream to calculate member counts
                return StreamBuilder<List<MemberModel>>(
                  stream: _memberService.streamAllMembers(),
                  builder: (context, memberSnapshot) {
                    final members = memberSnapshot.data ?? [];

                    return ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: firms.length,
                      itemBuilder: (context, index) {
                        final firm = firms[index];
                        
                        // Calculate total members associated with this firm
                        int memberCount = 0;
                        for (final member in members) {
                          for (final memberFirm in member.firms) {
                            if ((memberFirm['name'] ?? '').toString().toLowerCase() == firm.name.toLowerCase()) {
                              memberCount++;
                              break;
                            }
                          }
                        }
                        
                        return StreamBuilder<List<SubFirmModel>>(
                          stream: _firmService.getSubFirmsStream(firm.id),
                          builder: (context, subFirmSnapshot) {
                            final subFirmsCount = subFirmSnapshot.data?.length ?? 0;

                            return SlideInAnimation(
                              delay: Duration(milliseconds: 50 * index),
                              beginOffset: const Offset(0, 0.2),
                              child: AnimatedCard(
                                borderRadius: 16,
                                margin: const EdgeInsets.only(bottom: 12),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => FirmDetailScreen(
                                        firm: firm,
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.orange.shade50,
                                        Colors.white,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.orange.shade200,
                                      width: 1.5,
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      // Firm Icon
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.shade100,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          Icons.store,
                                          color: Colors.orange.shade700,
                                          size: 32,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      
                                      // Firm Info
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              firm.name,
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black87,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.apartment,
                                                  size: 14,
                                                  color: Colors.grey.shade600,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '$subFirmsCount Sub-firms',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Icon(
                                                  Icons.groups_2,
                                                  size: 16,
                                                  color: Colors.grey.shade600,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '$memberCount Members',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      
                                      // Arrow
                                      Icon(
                                        Icons.arrow_forward_ios,
                                        color: Colors.grey.shade400,
                                        size: 16,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }
                        );
                      },
                    );
                  }
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
