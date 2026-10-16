// lib/screens/admin/firms_list_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/member_model.dart';
import '../../models/firm_model.dart';
import '../../models/sub_firm_model.dart';
import '../../services/member_service.dart';
import '../../services/firm_service.dart';
import '../../services/language_service.dart';
import '../../services/session_manager.dart';
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

  String _userRole = 'member';
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final role = await SessionManager.getRole();
    final isAdmin = await SessionManager.getIsAdmin();
    if (mounted) {
      setState(() {
        _userRole = role ?? 'member';
        _isAdmin = isAdmin ?? false;
      });
    }
  }

  void _deleteFirm(FirmModel firm) async {
    final lang = Provider.of<LanguageService>(context, listen: false);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lang.translate('delete_firm')),
        content: Text('Are you sure you want to delete ${firm.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(lang.translate('cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(lang.translate('delete')),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _firmService.deleteFirm(firm.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageService>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(lang.translate('firms')),
        actions: [
          if (_isAdmin)
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
                                  Theme.of(context).colorScheme.primary.withOpacity(0.6),
                                  Theme.of(context).colorScheme.primary,
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
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                          color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No firms found',
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (_isAdmin) ...[
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const CreateFirmScreen()),
                              );
                            },
                            child: const Text('Create Firm'),
                          ),
                        ],
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
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                            final isDark = Theme.of(context).brightness == Brightness.dark;

                            return SlideInAnimation(
                              delay: Duration(milliseconds: 50 * index),
                              beginOffset: const Offset(0, 0.2),
                              child: AnimatedCard(
                                borderRadius: 16,
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
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
                                child: Row(
                                  children: [
                                    // Firm Icon
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isDark ? Colors.orange.withOpacity(0.2) : Colors.orange.shade100,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.store,
                                        color: isDark ? Colors.orange.shade300 : Colors.orange.shade700,
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
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(context).colorScheme.onSurface,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerLeft,
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.apartment,
                                                  size: 14,
                                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '$subFirmsCount Sub-firms',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Icon(
                                                  Icons.groups_2,
                                                  size: 16,
                                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '$memberCount Members',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    
                                    // Actions
                                    if (_isAdmin || _userRole == 'manager')
                                      IconButton(
                                        icon: Icon(Icons.edit_outlined, color: Theme.of(context).colorScheme.primary),
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => CreateFirmScreen(editFirm: firm),
                                            ),
                                          );
                                        },
                                      ),
                                    if (_isAdmin)
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                                        onPressed: () => _deleteFirm(firm),
                                      ),
                                    
                                    // Arrow
                                    Icon(
                                      Icons.arrow_forward_ios,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
                                      size: 16,
                                    ),
                                  ],
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
