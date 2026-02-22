// lib/screens/user/advanced_search_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/member_model.dart';
import '../../services/language_service.dart';
import '../../services/theme_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'member_detail_screen.dart';

class AdvancedSearchScreen extends StatefulWidget {
  final List<MemberModel> allMembers;

  const AdvancedSearchScreen({
    super.key,
    required this.allMembers,
  });

  @override
  State<AdvancedSearchScreen> createState() => _AdvancedSearchScreenState();
}

class _AdvancedSearchScreenState extends State<AdvancedSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<MemberModel> _filteredMembers = [];
  List<MemberModel> _displayedMembers = [];

  // Filters
  String? _selectedBloodGroup;
  String? _selectedCity;
  String? _selectedFamily;
  String? _selectedMaritalStatus;
  String? _selectedAgeRange;
  bool _showFilters = false;

  // Available options
  List<String> _bloodGroups = [];
  List<String> _cities = [];
  List<String> _families = [];

  @override
  void initState() {
    super.initState();
    _extractFilterOptions();
    _filteredMembers = widget.allMembers;
    _displayedMembers = widget.allMembers;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _extractFilterOptions() {
    final bloodGroupsSet = <String>{};
    final citiesSet = <String>{};
    final familiesSet = <String>{};

    for (final member in widget.allMembers) {
      if (member.bloodGroup.isNotEmpty) {
        bloodGroupsSet.add(member.bloodGroup);
      }
      if (member.nativeHome.isNotEmpty) {
        citiesSet.add(member.nativeHome);
      }
      if (member.familyName.isNotEmpty) {
        familiesSet.add(member.familyName);
      }
    }

    setState(() {
      _bloodGroups = bloodGroupsSet.toList()..sort();
      _cities = citiesSet.toList()..sort();
      _families = familiesSet.toList()..sort();
    });
  }

  void _onSearchChanged() {
    _applyFilters();
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase().trim();
    
    _filteredMembers = widget.allMembers.where((member) {
      // Text search
      final matchesSearch = query.isEmpty ||
          member.fullName.toLowerCase().contains(query) ||
          member.mid.toLowerCase().contains(query) ||
          member.surname.toLowerCase().contains(query) ||
          member.familyName.toLowerCase().contains(query);

      // Blood group filter
      final matchesBloodGroup = _selectedBloodGroup == null ||
          _selectedBloodGroup!.isEmpty ||
          member.bloodGroup == _selectedBloodGroup;

      // City filter
      final matchesCity = _selectedCity == null ||
          _selectedCity!.isEmpty ||
          member.nativeHome.toLowerCase().contains(_selectedCity!.toLowerCase());

      // Family filter
      final matchesFamily = _selectedFamily == null ||
          _selectedFamily!.isEmpty ||
          member.familyName == _selectedFamily;

      // Marital status filter
      final matchesMaritalStatus = _selectedMaritalStatus == null ||
          _selectedMaritalStatus!.isEmpty ||
          member.marriageStatus == _selectedMaritalStatus;

      // Age range filter
      bool matchesAgeRange = true;
      if (_selectedAgeRange != null && _selectedAgeRange!.isNotEmpty) {
        final age = member.age;
        switch (_selectedAgeRange) {
          case 'Under 18': matchesAgeRange = age < 18; break;
          case '18-25': matchesAgeRange = age >= 18 && age <= 25; break;
          case '26-35': matchesAgeRange = age >= 26 && age <= 35; break;
          case '36-45': matchesAgeRange = age >= 36 && age <= 45; break;
          case '46-60': matchesAgeRange = age >= 46 && age <= 60; break;
          case '60+': matchesAgeRange = age > 60; break;
        }
      }

      return matchesSearch &&
          matchesBloodGroup &&
          matchesCity &&
          matchesFamily &&
          matchesMaritalStatus &&
          matchesAgeRange;
    }).toList();

    setState(() {
      _displayedMembers = _filteredMembers;
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedBloodGroup = null;
      _selectedCity = null;
      _selectedFamily = null;
      _selectedMaritalStatus = null;
      _selectedAgeRange = null;
      _searchController.clear();
    });
    _applyFilters();
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageService>(context);
    final theme = Provider.of<ThemeService>(context);
    final isDark = theme.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
      body: Column(

      children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: isDark ? Colors.grey.shade800 : Colors.white,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: lang.translate('search_members'),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
              ),
            ),
          ),

          // Filters
          if (_showFilters)
            Container(
              padding: const EdgeInsets.all(16),
              color: isDark ? Colors.grey.shade800 : Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filters',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.clear_all, size: 20),
                        label: Text(lang.translate('clear_filters')),
                        onPressed: _clearFilters,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip(
                          lang.translate('blood_group'),
                          _selectedBloodGroup,
                          _bloodGroups,
                          (value) {
                            setState(() => _selectedBloodGroup = value);
                            _applyFilters();
                          },
                          isDark,
                          lang,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          lang.translate('city'),
                          _selectedCity,
                          _cities,
                          (value) {
                            setState(() => _selectedCity = value);
                            _applyFilters();
                          },
                          isDark,
                          lang,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          lang.translate('family'),
                          _selectedFamily,
                          _families,
                          (value) {
                            setState(() => _selectedFamily = value);
                            _applyFilters();
                          },
                          isDark,
                          lang,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          'Age Range',
                          _selectedAgeRange,
                          ['Under 18', '18-25', '26-35', '36-45', '46-60', '60+'],
                          (value) {
                            setState(() => _selectedAgeRange = value);
                            _applyFilters();
                          },
                          isDark,
                          lang,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          lang.translate('marital_status'),
                          _selectedMaritalStatus,
                          ['married', 'unmarried'],
                          (value) {
                            setState(() => _selectedMaritalStatus = value);
                            _applyFilters();
                          },
                          isDark,
                          lang,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Results Count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: isDark ? Colors.grey.shade800 : Colors.white,
            child: Row(
              children: [
                Text(
                  '${lang.translate('total_members')}: ${_displayedMembers.length}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),

          // Results List
          Expanded(
            child: _displayedMembers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          lang.translate('no_results'),
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _displayedMembers.length,
                    itemBuilder: (context, index) {
                      final member = _displayedMembers[index];
                      return _buildMemberCard(member, lang, isDark);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'filter_fab',
            onPressed: () {
              setState(() => _showFilters = !_showFilters);
            },
            backgroundColor: _showFilters ? Colors.orange : Colors.blue.shade700,
            foregroundColor: Colors.white,
            child: Icon(_showFilters ? Icons.filter_list_off : Icons.filter_list),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'qr_fab',
            onPressed: () => Navigator.pushNamed(context, '/user/qr-scanner'),
            backgroundColor: Colors.blue.shade900,
            foregroundColor: Colors.white,
            child: const Icon(Icons.qr_code_scanner),
          ),
        ],
      ),

    );
  }


  Widget _buildFilterChip(
    String label,
    String? selectedValue,
    List<String> options,
    Function(String?) onSelected,
    bool isDark,
    LanguageService lang,
  ) {
    return PopupMenuButton<String>(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selectedValue != null
              ? Colors.blue.shade900
              : isDark
                  ? Colors.grey.shade700
                  : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selectedValue != null
                    ? Colors.white
                    : isDark
                        ? Colors.white
                        : Colors.black87,
                fontWeight: selectedValue != null
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
            if (selectedValue != null) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '1',
                  style: TextStyle(
                    color: Colors.blue.shade900,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              color: selectedValue != null
                  ? Colors.white
                  : isDark
                      ? Colors.white
                      : Colors.black87,
            ),
          ],
        ),
      ),
      itemBuilder: (context) {
        final langService = Provider.of<LanguageService>(context, listen: false);
        return [
          PopupMenuItem(
            value: null,
            child: Text(langService.translate('all')),
            onTap: () => Future.delayed(
              const Duration(milliseconds: 100),
              () => onSelected(null),
            ),
          ),
          ...options.map((option) => PopupMenuItem(
                value: option,
                child: Text(option),
                onTap: () => Future.delayed(
                  const Duration(milliseconds: 100),
                  () => onSelected(option),
                ),
              )),
        ];
      },
    );
  }

  Widget _buildMemberCard(MemberModel member, LanguageService lang, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isDark ? Colors.grey.shade800 : Colors.white,
      child: ListTile(
        leading: CircleAvatar(
          radius: 28,
          backgroundColor: Colors.blue.shade900,
          backgroundImage: member.photoUrl.isNotEmpty &&
                  member.photoUrl.startsWith('http')
              ? CachedNetworkImageProvider(member.photoUrl)
              : null,
          child: member.photoUrl.isEmpty ||
                  !member.photoUrl.startsWith('http')
              ? Text(
                  member.fullName.isNotEmpty
                      ? member.fullName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(color: Colors.white),
                )
              : null,
        ),
        title: Text(
          member.fullName,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${member.surname} • ${member.mid}'),
            const SizedBox(height: 4),
            Row(
              children: [
                if (member.bloodGroup.isNotEmpty) ...[
                  Icon(Icons.bloodtype, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(member.bloodGroup,
                      style: TextStyle(color: Colors.grey.shade600)),
                  const SizedBox(width: 12),
                ],
                if (member.nativeHome.isNotEmpty) ...[
                  Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(member.nativeHome,
                        style: TextStyle(color: Colors.grey.shade600),
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MemberDetailScreen(
                memberId: member.id,
                familyDocId: member.familyDocId,
                subFamilyDocId: member.subFamilyDocId,
              ),
            ),
          );
        },
      ),
    );
  }
}
