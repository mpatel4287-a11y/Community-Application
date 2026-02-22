// lib/screens/user/user_explore_screen.dart

// ignore_for_file: unnecessary_underscores

import 'package:flutter/material.dart';
import '../../models/member_model.dart';
import '../../services/member_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'member_detail_screen.dart';

// Helper widget to handle profile images with error handling
class _ProfileImage extends StatefulWidget {
  final String? photoUrl;
  final String fullName;
  final double radius;

  const _ProfileImage({
    this.photoUrl,
    required this.fullName,
    this.radius = 25,
  });

  @override
  State<_ProfileImage> createState() => __ProfileImageState();
}

class __ProfileImageState extends State<_ProfileImage> {
  bool _hasError = false;

  @override
  Widget build(BuildContext context) {
    final photoUrl = widget.photoUrl ?? '';
    final hasValidUrl = photoUrl.isNotEmpty && photoUrl.startsWith('http');

    if (!hasValidUrl || _hasError) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundColor: Colors.blue.shade900,
        child: Text(
          widget.fullName.isNotEmpty ? widget.fullName[0].toUpperCase() : '?',
          style: TextStyle(fontSize: widget.radius * 0.7, color: Colors.white),
        ),
      );
    }

    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: Colors.blue.shade900,
      backgroundImage: CachedNetworkImageProvider(photoUrl),
      onBackgroundImageError: (_, __) {
        if (mounted) {
          setState(() => _hasError = true);
        }
      },
    );
  }
}

class UserExploreScreen extends StatefulWidget {
  const UserExploreScreen({super.key});

  @override
  State<UserExploreScreen> createState() => _UserExploreScreenState();
}

class _UserExploreScreenState extends State<UserExploreScreen> {
  final MemberService _memberService = MemberService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;

  // Filter state
  String _selectedBloodGroup = '';
  String _selectedMarriageStatus = '';
  String _selectedGotra = '';
  String _ageRange = '';

  // Available filter options
  final List<String> _bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'O+',
    'O-',
    'AB+',
    'AB-',
  ];
  final List<String> _marriageStatuses = ['married', 'unmarried'];
  List<String> _availableGotras = [];

  @override
  void initState() {
    super.initState();
    _loadGotras();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadGotras() async {
    final allMembers = await _memberService.getAllMembers();
    final gotras = <String>{};
    for (final member in allMembers) {
      if (member.gotra.isNotEmpty) {
        gotras.add(member.gotra);
      }
    }
    setState(() {
      _availableGotras = gotras.toList()..sort();
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedBloodGroup = '';
      _selectedMarriageStatus = '';
      _selectedGotra = '';
      _ageRange = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore'),
        backgroundColor: Colors.blue.shade900,
        actions: [
          if (_selectedBloodGroup.isNotEmpty ||
              _selectedMarriageStatus.isNotEmpty ||
              _selectedGotra.isNotEmpty ||
              _ageRange.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _clearFilters,
              tooltip: 'Clear Filters',
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(120),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Search by name or MID...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                      _isSearching = value.isNotEmpty;
                    });
                  },
                ),
              ),
              // Filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    // Blood Group filter
                    FilterChip(
                      label: const Text('Blood Group'),
                      avatar: _selectedBloodGroup.isNotEmpty
                          ? CircleAvatar(
                              backgroundColor: Colors.red,
                              radius: 8,
                              child: Text(
                                _selectedBloodGroup,
                                style: const TextStyle(fontSize: 10),
                              ),
                            )
                          : null,
                      selected: _selectedBloodGroup.isNotEmpty,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _showBloodGroupDialog();
                          } else {
                            _selectedBloodGroup = '';
                          }
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    // Marriage Status filter
                    FilterChip(
                      label: const Text('Marriage'),
                      avatar: _selectedMarriageStatus.isNotEmpty
                          ? CircleAvatar(
                              backgroundColor: Colors.pink,
                              radius: 8,
                              child: Icon(
                                _selectedMarriageStatus == 'married'
                                    ? Icons.favorite
                                    : Icons.person,
                                size: 12,
                              ),
                            )
                          : null,
                      selected: _selectedMarriageStatus.isNotEmpty,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _showMarriageStatusDialog();
                          } else {
                            _selectedMarriageStatus = '';
                          }
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    // Gotra filter
                    FilterChip(
                      label: const Text('Gotra'),
                      selected: _selectedGotra.isNotEmpty,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _showGotraDialog();
                          } else {
                            _selectedGotra = '';
                          }
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    // Age Range filter
                    FilterChip(
                      label: const Text('Age'),
                      selected: _ageRange.isNotEmpty,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _showAgeRangeDialog();
                          } else {
                            _ageRange = '';
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: _isSearching ? _buildSearchResults() : _buildQuickFilters(),
    );
  }

  void _showBloodGroupDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Blood Group'),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _bloodGroups.map((bg) {
            final isSelected = _selectedBloodGroup == bg;
            return ChoiceChip(
              label: Text(bg),
              selected: isSelected,
              onSelected: (selected) {
                Navigator.pop(context);
                setState(() {
                  _selectedBloodGroup = selected ? bg : '';
                });
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _selectedBloodGroup = '');
            },
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showMarriageStatusDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Marriage Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _marriageStatuses.map((status) {
            final isSelected = _selectedMarriageStatus == status;
            return ListTile(
              leading: Icon(
                status == 'married' ? Icons.favorite : Icons.person,
                color: isSelected ? Colors.pink : null,
              ),
              title: Text(status[0].toUpperCase() + status.substring(1)),
              trailing: isSelected
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _selectedMarriageStatus = status;
                });
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _selectedMarriageStatus = '');
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showGotraDialog() {
    if (_availableGotras.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No gotras available')));
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Gotra'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _availableGotras.length,
            itemBuilder: (context, index) {
              final gotra = _availableGotras[index];
              final isSelected = _selectedGotra == gotra;
              return ListTile(
                title: Text(gotra),
                trailing: isSelected
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _selectedGotra = gotra;
                  });
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _selectedGotra = '');
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showAgeRangeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Age Range'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('0-18 (Children)'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _ageRange = '0-18');
              },
            ),
            ListTile(
              title: const Text('19-35 (Young)'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _ageRange = '19-35');
              },
            ),
            ListTile(
              title: const Text('36-60 (Adult)'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _ageRange = '36-60');
              },
            ),
            ListTile(
              title: const Text('60+ (Senior)'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _ageRange = '60+');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _ageRange = '');
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  bool _matchesFilters(MemberModel member) {
    // Check blood group
    if (_selectedBloodGroup.isNotEmpty &&
        member.bloodGroup != _selectedBloodGroup) {
      return false;
    }

    // Check marriage status
    if (_selectedMarriageStatus.isNotEmpty &&
        member.marriageStatus.toLowerCase() !=
            _selectedMarriageStatus.toLowerCase()) {
      return false;
    }

    // Check gotra
    if (_selectedGotra.isNotEmpty &&
        member.gotra.toLowerCase() != _selectedGotra.toLowerCase()) {
      return false;
    }

    // Check age range
    if (_ageRange.isNotEmpty) {
      final age = member.age;
      switch (_ageRange) {
        case '0-18':
          if (age > 18) return false;
          break;
        case '19-35':
          if (age < 19 || age > 35) return false;
          break;
        case '36-60':
          if (age < 36 || age > 60) return false;
          break;
        case '60+':
          if (age < 60) return false;
          break;
      }
    }

    return true;
  }

  Widget _buildQuickFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Quick Filters',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: GridView.count(
            crossAxisCount: 2,
            padding: const EdgeInsets.all(16),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              _buildFilterCard('All Members', Icons.people, Colors.blue, null),
              _buildFilterCard(
                'Active',
                Icons.check_circle,
                Colors.green,
                null,
              ),
              _buildFilterCard(
                'New This Month',
                Icons.new_releases,
                Colors.orange,
                'newThisMonth',
              ),
              _buildFilterCard('Recent', Icons.schedule, Colors.purple, null),
              _buildFilterCard(
                'Married',
                Icons.favorite,
                Colors.pink,
                'married',
              ),
              _buildFilterCard(
                'Unmarried',
                Icons.person,
                Colors.purple,
                'unmarried',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterCard(
    String title,
    IconData icon,
    Color color,
    String? filterType,
  ) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () {
          setState(() {
            _isSearching = true;
            if (filterType == 'newThisMonth') {
              _searchQuery = 'new_this_month';
            } else if (filterType == 'married') {
              _selectedMarriageStatus = 'married';
              _searchQuery = '';
            } else if (filterType == 'unmarried') {
              _selectedMarriageStatus = 'unmarried';
              _searchQuery = '';
            } else {
              _searchQuery = '';
              _selectedBloodGroup = '';
              _selectedMarriageStatus = '';
              _selectedGotra = '';
              _ageRange = '';
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    return StreamBuilder<List<MemberModel>>(
      stream: _memberService.streamAllMembers(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final members = snapshot.data!;

        // Apply filters
        final filteredMembers = members.where((member) {
          // Check search query
          final searchLower = _searchQuery.toLowerCase();
          final matchesSearch =
              searchLower.isEmpty ||
              searchLower == 'new_this_month' ||
              member.fullName.toLowerCase().contains(searchLower) ||
              member.mid.toLowerCase().contains(searchLower) ||
              member.surname.toLowerCase().contains(searchLower) ||
              member.familyName.toLowerCase().contains(searchLower);

          if (!matchesSearch) return false;

          // Special case for "New This Month"
          if (_searchQuery == 'new_this_month') {
            final now = DateTime.now();
            final startOfMonth = DateTime(now.year, now.month, 1);
            if (!member.createdAt.isAfter(startOfMonth)) {
              return false;
            }
          }

          // Apply other filters
          return _matchesFilters(member);
        }).toList();

        if (filteredMembers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.search_off, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text('No results found'),
                if (_selectedBloodGroup.isNotEmpty ||
                    _selectedMarriageStatus.isNotEmpty ||
                    _selectedGotra.isNotEmpty ||
                    _ageRange.isNotEmpty)
                  TextButton(
                    onPressed: _clearFilters,
                    child: const Text('Clear Filters'),
                  ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // Results count
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                '${filteredMembers.length} members found',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ),
            // Active filters indicator
            if (_selectedBloodGroup.isNotEmpty ||
                _selectedMarriageStatus.isNotEmpty ||
                _selectedGotra.isNotEmpty ||
                _ageRange.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  children: [
                    if (_selectedBloodGroup.isNotEmpty)
                      Chip(
                        label: Text('Blood: $_selectedBloodGroup'),
                        onDeleted: () =>
                            setState(() => _selectedBloodGroup = ''),
                        deleteIcon: const Icon(Icons.close, size: 16),
                      ),
                    if (_selectedMarriageStatus.isNotEmpty)
                      Chip(
                        label: Text('Married: $_selectedMarriageStatus'),
                        onDeleted: () =>
                            setState(() => _selectedMarriageStatus = ''),
                        deleteIcon: const Icon(Icons.close, size: 16),
                      ),
                    if (_selectedGotra.isNotEmpty)
                      Chip(
                        label: Text('Gotra: $_selectedGotra'),
                        onDeleted: () => setState(() => _selectedGotra = ''),
                        deleteIcon: const Icon(Icons.close, size: 16),
                      ),
                    if (_ageRange.isNotEmpty)
                      Chip(
                        label: Text('Age: $_ageRange'),
                        onDeleted: () => setState(() => _ageRange = ''),
                        deleteIcon: const Icon(Icons.close, size: 16),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: filteredMembers.length,
                itemBuilder: (context, index) {
                  final member = filteredMembers[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: _ProfileImage(
                        photoUrl: member.photoUrl,
                        fullName: member.fullName,
                        radius: 25,
                      ),
                      title: Text(
                        member.fullName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${member.surname} • ${member.familyName}'),
                          if (member.phone.isNotEmpty) Text(member.phone),
                          Row(
                            children: [
                              if (member.bloodGroup.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    member.bloodGroup,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.red.shade700,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              if (member.age > 0)
                                Text(
                                  '${member.age} years',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
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
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
