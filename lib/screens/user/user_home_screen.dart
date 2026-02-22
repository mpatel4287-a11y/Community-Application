// lib/screens/user/user_home_screen.dart

// ignore_for_file: unused_field, unused_import, unnecessary_underscores

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/member_model.dart';
import '../../services/member_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'member_detail_screen.dart';

// Helper widget to handle profile images with error handling
class _HomeProfileImage extends StatefulWidget {
  final String? photoUrl;
  final String fullName;
  final double radius;

  const _HomeProfileImage({
    this.photoUrl,
    required this.fullName,
    this.radius = 25,
  });

  @override
  State<_HomeProfileImage> createState() => __HomeProfileImageState();
}

class __HomeProfileImageState extends State<_HomeProfileImage> {
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

class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({super.key});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  final MemberService _memberService = MemberService();
  String _searchQuery = '';
  String? _selectedFamilyFilter;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community App'),
        backgroundColor: Colors.blue.shade900,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(context: context, delegate: MemberSearchDelegate());
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats Cards
          _buildStatsSection(),

          // Search and Filter
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search members...',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),

          // Member List
          Expanded(
            child: StreamBuilder<List<MemberModel>>(
              stream: _memberService.streamAllMembers(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final members = snapshot.data!;

                // Filter by search query
                final filteredMembers = members.where((member) {
                  final matchesSearch =
                      _searchQuery.isEmpty ||
                      member.fullName.toLowerCase().contains(
                        _searchQuery.toLowerCase(),
                      ) ||
                      member.mid.toLowerCase().contains(
                        _searchQuery.toLowerCase(),
                      );
                  return matchesSearch;
                }).toList();

                if (filteredMembers.isEmpty) {
                  return const Center(child: Text('No members found'));
                }

                return ListView.builder(
                  itemCount: filteredMembers.length,
                  itemBuilder: (context, index) {
                    final member = filteredMembers[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: ListTile(
                        leading: _HomeProfileImage(
                          photoUrl: member.photoUrl,
                          fullName: member.fullName,
                          radius: 25,
                        ),
                        title: Text(member.fullName),
                        subtitle: Text('${member.familyName} • ${member.mid}'),
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return FutureBuilder<Map<String, int>>(
      future: _getStatsData(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final stats = snapshot.data!;
        final totalMembers = stats['total'] ?? 0;
        final activeMembers = stats['active'] ?? 0;
        final newThisMonth = stats['newThisMonth'] ?? 0;
        final married = stats['married'] ?? 0;
        final unmarried = stats['unmarried'] ?? 0;

        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Total Members',
                      totalMembers.toString(),
                      Icons.people,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'Active',
                      activeMembers.toString(),
                      Icons.check_circle,
                      Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'New This Month',
                      newThisMonth.toString(),
                      Icons.new_releases,
                      Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'Married',
                      married.toString(),
                      Icons.favorite,
                      Colors.pink,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'Unmarried',
                      unmarried.toString(),
                      Icons.person,
                      Colors.purple,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<Map<String, int>> _getStatsData() async {
    final allMembers = await _memberService.getAllMembers();

    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    final total = allMembers.length;
    final active = allMembers.where((m) => m.isActive).length;
    final newThisMonth = allMembers
        .where((m) => m.createdAt.isAfter(startOfMonth))
        .length;
    final married = allMembers
        .where((m) => m.marriageStatus.toLowerCase() == 'married')
        .length;
    final unmarried = allMembers
        .where((m) => m.marriageStatus.toLowerCase() == 'unmarried')
        .length;

    return {
      'total': total,
      'active': active,
      'newThisMonth': newThisMonth,
      'married': married,
      'unmarried': unmarried,
    };
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              title,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class MemberSearchDelegate extends SearchDelegate {
  final MemberService _memberService = MemberService();

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    if (query.isEmpty) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<List<MemberModel>>(
      stream: _memberService.searchMembers(query),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final members = snapshot.data!;
        if (members.isEmpty) {
          return const Center(child: Text('No results found'));
        }

        return ListView.builder(
          itemCount: members.length,
          itemBuilder: (context, index) {
            final member = members[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue.shade900,
                child: Text(
                  member.fullName[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: Text(member.fullName),
              subtitle: Text('${member.mid} • ${member.familyName}'),
              onTap: () {
                close(context, null);
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
            );
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return const Center(child: Text('Search for members by name or ID'));
  }
}
