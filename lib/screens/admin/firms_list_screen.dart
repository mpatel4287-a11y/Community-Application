// lib/screens/admin/firms_list_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/member_model.dart';
import '../../models/firm_model.dart';
import '../../services/member_service.dart';
import '../../services/firm_service.dart';
import '../../services/language_service.dart';
import '../../services/session_manager.dart';
import '../../widgets/animation_utils.dart';
import '../user/member_detail_screen.dart';
import 'create_firm_screen.dart';
import 'firm_detail_screen.dart';

class AggregatedFirmItem {
  final String id;
  final String name;
  final String phone;
  final String mapLink;
  final FirmModel? standaloneFirm;
  final List<MemberModel> members;

  AggregatedFirmItem({
    required this.id,
    required this.name,
    this.phone = '',
    this.mapLink = '',
    this.standaloneFirm,
    this.members = const [],
  });
}

class FirmsListScreen extends StatefulWidget {
  const FirmsListScreen({super.key});

  @override
  State<FirmsListScreen> createState() => _FirmsListScreenState();
}

class _FirmsListScreenState extends State<FirmsListScreen> {
  final FirmService _firmService = FirmService();
  final MemberService _memberService = MemberService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  String _userRole = 'member';
  bool _isAdmin = false;
  bool _isVisitor = false;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserRole() async {
    final role = await SessionManager.getRole();
    final isAdmin = await SessionManager.getIsAdmin();
    final isVisitor = await SessionManager.isVisitor();
    if (mounted) {
      setState(() {
        _userRole = role ?? 'member';
        _isAdmin = isAdmin ?? false;
        _isVisitor = isVisitor;
      });
    }
  }

  void _callPhone(String phone) async {
    final cleanPhone = phone.trim().replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.isEmpty) return;
    final uri = Uri.parse('tel:$cleanPhone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error making call: $e');
    }
  }

  void _openMap(String mapLink) async {
    final trimmed = mapLink.trim();
    if (trimmed.isEmpty) return;
    Uri? uri;
    final parsed = Uri.tryParse(trimmed);
    if (parsed != null && (parsed.scheme.isNotEmpty || trimmed.startsWith('http'))) {
      uri = parsed;
    } else {
      uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(trimmed)}');
    }
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      debugPrint('Error launching map: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open map link.')),
        );
      }
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(lang.translate('firms')),
        centerTitle: true,
        actions: [
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.add_business_rounded),
              tooltip: 'Create Standalone Firm',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CreateFirmScreen()),
                );
              },
            ),
        ],
      ),
      body: StreamBuilder<List<MemberModel>>(
        stream: _memberService.streamAllMembers(),
        builder: (context, memberSnapshot) {
          if (memberSnapshot.connectionState == ConnectionState.waiting) {
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
                    'Loading firms directory...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          final allMembers = memberSnapshot.data ?? [];

          return StreamBuilder<List<FirmModel>>(
            stream: _firmService.getFirmsStream(),
            builder: (context, firmSnapshot) {
              final standaloneFirms = firmSnapshot.data ?? [];

              // Aggregate firms across all living members and standalone FirmModel
              final Map<String, AggregatedFirmItem> aggregated = {};

              // 1. Seed with standalone firms if present
              for (final sf in standaloneFirms) {
                final key = sf.name.trim().toLowerCase();
                if (key.isEmpty) continue;
                aggregated[key] = AggregatedFirmItem(
                  id: sf.id,
                  name: sf.name.trim(),
                  standaloneFirm: sf,
                  members: [],
                );
              }

              // 2. Aggregate from living members' firm entries
              for (final member in allMembers) {
                if (member.isLate) continue; // Exclude late/deceased members
                if (_isVisitor && !member.canVisitorSee('firms')) continue;
                for (final f in member.firms) {
                  final rawName = (f['name'] ?? '').toString().trim();
                  if (rawName.isEmpty) continue;
                  final key = rawName.toLowerCase();
                  final phone = (f['phone'] ?? '').toString().trim();
                  final mapLink = (f['mapLink'] ?? '').toString().trim();

                  if (aggregated.containsKey(key)) {
                    final existing = aggregated[key]!;
                    final membersList = List<MemberModel>.from(existing.members);
                    if (!membersList.any((m) => m.id == member.id)) {
                      membersList.add(member);
                    }
                    aggregated[key] = AggregatedFirmItem(
                      id: existing.id,
                      name: existing.name,
                      phone: existing.phone.isNotEmpty ? existing.phone : phone,
                      mapLink: existing.mapLink.isNotEmpty ? existing.mapLink : mapLink,
                      standaloneFirm: existing.standaloneFirm,
                      members: membersList,
                    );
                  } else {
                    aggregated[key] = AggregatedFirmItem(
                      id: key,
                      name: rawName,
                      phone: phone,
                      mapLink: mapLink,
                      members: [member],
                    );
                  }
                }
              }

              final allFirmsList = aggregated.values.toList()
                ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

              // Filter by search query
              final filteredFirms = allFirmsList.where((firm) {
                if (_searchQuery.trim().isEmpty) return true;
                final q = _searchQuery.trim().toLowerCase();
                if (firm.name.toLowerCase().contains(q)) return true;
                if (firm.phone.toLowerCase().contains(q)) return true;
                for (final m in firm.members) {
                  if (m.fullName.toLowerCase().contains(q)) return true;
                  if (m.nativeHome.toLowerCase().contains(q)) return true;
                }
                return false;
              }).toList();

              return Column(
                children: [
                  // Search Bar & Stats Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            hintText: 'Search firms by name, owner, phone...',
                            filled: true,
                            fillColor: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          onChanged: (value) => setState(() => _searchQuery = value),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${filteredFirms.length} ${filteredFirms.length == 1 ? 'Firm' : 'Firms'} found',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (_isVisitor)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Visitor Directory',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber.shade800,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Firm Cards List
                  Expanded(
                    child: filteredFirms.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.store_mall_directory_outlined,
                                  size: 64,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'No firms match "$_searchQuery"'
                                      : 'No firms registered yet',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'Try searching with a different term'
                                      : 'Firms added under member profiles will appear here.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            itemCount: filteredFirms.length,
                            itemBuilder: (context, index) {
                              final firm = filteredFirms[index];
                              return _buildFirmCard(firm, index, isDark);
                            },
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildFirmCard(AggregatedFirmItem firm, int index, bool isDark) {
    final theme = Theme.of(context);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final secondaryTextColor = isDark ? Colors.white70 : const Color(0xFF64748B);

    return SlideInAnimation(
      delay: Duration(milliseconds: 40 * (index % 15)),
      beginOffset: const Offset(0, 0.15),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black26 : const Color(0x08000000),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Icon, Title, Actions
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary.withOpacity(0.85),
                          theme.colorScheme.primary,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          firm.name,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: primaryTextColor,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.people_alt_rounded,
                              size: 14,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '${firm.members.length} ${firm.members.length == 1 ? 'Owner / Associate' : 'Associates'}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (firm.standaloneFirm != null && (_isAdmin || _userRole == 'manager'))
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit_outlined, size: 20, color: theme.colorScheme.primary),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CreateFirmScreen(editFirm: firm.standaloneFirm),
                              ),
                            );
                          },
                        ),
                        if (_isAdmin)
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                            onPressed: () => _deleteFirm(firm.standaloneFirm!),
                          ),
                      ],
                    ),
                ],
              ),

              // Contact & Map Actions Row (if phone or map link present)
              if (firm.phone.isNotEmpty || firm.mapLink.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    if (firm.phone.isNotEmpty)
                      InkWell(
                        onTap: () => _callPhone(firm.phone),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.phone_in_talk_rounded, size: 16, color: Color(0xFF10B981)),
                              const SizedBox(width: 6),
                              Text(
                                firm.phone,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF047857),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (firm.mapLink.isNotEmpty)
                      InkWell(
                        onTap: () => _openMap(firm.mapLink),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.location_on_rounded, size: 16, color: Color(0xFFEF4444)),
                              SizedBox(width: 6),
                              Text(
                                'Directions / Map',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFB91C1C),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],

              // Associated Members Chips
              if (firm.members.isNotEmpty) ...[
                const SizedBox(height: 14),
                Divider(
                  height: 1,
                  color: isDark ? Colors.white10 : Colors.grey.shade200,
                ),
                const SizedBox(height: 10),
                Text(
                  'Associated Community Members:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: secondaryTextColor,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: firm.members.map((member) {
                    return ActionChip(
                      avatar: CircleAvatar(
                        backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
                        child: Text(
                          member.fullName.isNotEmpty ? member.fullName[0].toUpperCase() : '?',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      label: Text(
                        member.fullName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: primaryTextColor,
                        ),
                      ),
                      backgroundColor: isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFF1F5F9),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isDark ? Colors.white12 : const Color(0xFFCBD5E1),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MemberDetailScreen(
                              memberId: member.id,
                              familyDocId: member.familyDocId,
                              subFamilyDocId: member.subFamilyDocId,
                            ),
                          ),
                        );
                      },
                    );
                  }).toList(),
                ),
              ],

              // Standalone Sub-firm Info Link (if standalone firm exists)
              if (firm.standaloneFirm != null) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    icon: const Icon(Icons.apartment_rounded, size: 16),
                    label: const Text('View Sub-Firms Details', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FirmDetailScreen(firm: firm.standaloneFirm!),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
