import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:screenshot/screenshot.dart';
import 'package:gal/gal.dart';
import '../../widgets/family_tree.dart';
import '../../models/member_model.dart';
import '../../models/person.dart';
import '../../services/member_service.dart';

class SubFamilyTreeDetailScreen extends StatefulWidget {
  final String mainFamilyDocId;
  final String familyName;
  final String subFamilyDocId;
  final String subFamilyId;
  final String subFamilyName;

  const SubFamilyTreeDetailScreen({
    super.key,
    required this.mainFamilyDocId,
    required this.familyName,
    required this.subFamilyDocId,
    required this.subFamilyId,
    required this.subFamilyName,
  });

  @override
  State<SubFamilyTreeDetailScreen> createState() => _SubFamilyTreeDetailScreenState();
}

class _SubFamilyTreeDetailScreenState extends State<SubFamilyTreeDetailScreen> {
  final MemberService _memberService = MemberService();
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _loading = true;
  bool _downloading = false;
  List<List<Person>> _generations = [];

  @override
  void initState() {
    super.initState();
    _loadFamilyTree();
  }

  Future<void> _loadFamilyTree() async {
    setState(() => _loading = true);

    try {
      // Get only members for this specific sub-family
      final subFamilyMembers = await _memberService.getSubFamilyMembers(
        widget.mainFamilyDocId, 
        widget.subFamilyDocId == 'Main' ? '' : widget.subFamilyDocId
      );

      if (subFamilyMembers.isEmpty) {
        setState(() {
          _generations = [];
          _loading = false;
        });
        return;
      }

      final generations = _buildFamilyTree(subFamilyMembers);

      setState(() {
        _generations = generations;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading family tree: $e');
      setState(() {
        _generations = [];
        _loading = false;
      });
    }
  }

  List<List<Person>> _buildFamilyTree(List<MemberModel> members) {
    if (members.isEmpty) return [];

    // Create maps for quick lookup
    final Map<String, Person> personMap = {}; // MID -> Person
    final Map<String, List<String>> childrenMap = {}; // Parent MID -> List of child MIDs

    // Convert all members to Person objects
    for (final member in members) {
      final nameParts = member.fullName.split(' ');
      final firstName = nameParts.isNotEmpty ? nameParts[0] : member.fullName;
      final lastName = nameParts.length > 1
          ? nameParts.sublist(1).join(' ')
          : member.surname.isNotEmpty
              ? member.surname
              : '';

      // Extract birth year from birthDate
      int birthYear = DateTime.now().year - member.age;
      if (member.birthDate.isNotEmpty) {
        try {
          final parts = member.birthDate.split('/');
          if (parts.length == 3) {
            birthYear = int.parse(parts[2]);
          }
        } catch (e) {
          // Use calculated year if parsing fails
        }
      }

      final person = Person(
        id: member.id,
        firstName: firstName,
        lastName: lastName,
        birthYear: birthYear,
        gender: member.gender.toLowerCase() == 'female'
            ? Gender.female
            : Gender.male,
        photoUrl: member.photoUrl.isNotEmpty ? member.photoUrl : null,
        details: member.nativeHome.isNotEmpty
            ? 'Native: ${member.nativeHome}'
            : null,
        age: member.age,
        mid: member.mid,
        relationToHead: member.relationToHead,
        parentIds: member.parentMid.isNotEmpty ? [member.parentMid] : [],
      );

      personMap[member.mid] = person;

      // Build children map (parent MID -> children MIDs)
      if (member.parentMid.isNotEmpty && member.parentMid != member.mid) {
        if (!childrenMap.containsKey(member.parentMid)) {
          childrenMap[member.parentMid] = [];
        }
        childrenMap[member.parentMid]!.add(member.mid);
      }
    }

    // Update childrenIds for each person
    for (final entry in childrenMap.entries) {
      final parentMid = entry.key;
      if (personMap.containsKey(parentMid)) {
        final parent = personMap[parentMid]!;
        personMap[parentMid] = Person(
          id: parent.id,
          firstName: parent.firstName,
          lastName: parent.lastName,
          birthYear: parent.birthYear,
          gender: parent.gender,
          photoUrl: parent.photoUrl,
          details: parent.details,
          age: parent.age,
          mid: parent.mid,
          relationToHead: parent.relationToHead,
          parentIds: parent.parentIds,
          childrenIds: entry.value,
          spouseId: parent.spouseId,
        );
      }
    }

    // Match spouses
    final List<Person> allPeople = personMap.values.toList();
    for (final person in allPeople) {
      if (person.spouseId != null) continue;

      if (person.relationToHead?.toLowerCase() == 'head') {
        final wife = allPeople.firstWhere(
          (p) => p.relationToHead?.toLowerCase() == 'wife' && p.spouseId == null,
          orElse: () => allPeople.firstWhere(
            (p) => p.relationToHead?.toLowerCase() == 'husband' && p.spouseId == null && p.mid != person.mid,
            orElse: () => person,
          ),
        );
        if (wife != person) {
          personMap[person.mid!] = _linkSpouses(person, wife);
          personMap[wife.mid!] = _linkSpouses(wife, person);
        }
      } else if (person.relationToHead?.toLowerCase() == 'son') {
        try {
          final dil = allPeople.firstWhere(
            (p) => p.relationToHead?.toLowerCase() == 'daughter_in_law' && p.spouseId == null,
          );
          personMap[person.mid!] = _linkSpouses(person, dil);
          personMap[dil.mid!] = _linkSpouses(dil, person);
        } catch (e) {
          // No unmatched daughter-in-law found
        }
      }
    }

    // Find head of family
    MemberModel? headMember;
    try {
      headMember = members.firstWhere(
        (m) => m.relationToHead == 'head' && m.isActive,
      );
    } catch (e) {
      try {
        headMember = members.firstWhere(
          (m) => m.parentMid.isEmpty && m.isActive,
        );
      } catch (e2) {
        if (members.isNotEmpty) {
          headMember = members.first;
        }
      }
    }

    final generations = <List<Person>>[];
    final processed = <String>{};

    // Build generations starting from head
    if (headMember != null && headMember.mid.isNotEmpty && personMap.containsKey(headMember.mid)) {
      final headPerson = personMap[headMember.mid]!;
      final generation0 = [headPerson];
      processed.add(headPerson.mid!);

      if (headPerson.spouseId != null && personMap.containsKey(headPerson.spouseId)) {
        generation0.add(personMap[headPerson.spouseId!]!);
        processed.add(headPerson.spouseId!);
      }

      generations.add(generation0);
    }

    // Build subsequent generations
    int currentGenIndex = 0;
    while (currentGenIndex < generations.length) {
      final currentLevel = generations[currentGenIndex];
      final nextLevel = <Person>[];

      for (final person in currentLevel) {
        if (person.childrenIds.isNotEmpty) {
          for (final childMid in person.childrenIds) {
            if (personMap.containsKey(childMid) && !processed.contains(childMid)) {
              final child = personMap[childMid]!;
              nextLevel.add(child);
              processed.add(child.mid!);

              if (child.spouseId != null && 
                  personMap.containsKey(child.spouseId) && 
                  !processed.contains(child.spouseId)) {
                nextLevel.add(personMap[child.spouseId!]!);
                processed.add(child.spouseId!);
              }
            }
          }
        }
      }

      if (nextLevel.isNotEmpty) {
        generations.add(nextLevel);
        currentGenIndex++;
      } else {
        break;
      }
    }

    // Add any remaining members
    final remaining = personMap.values.where((p) => !processed.contains(p.mid)).toList();
    if (remaining.isNotEmpty) {
      if (generations.isEmpty) {
        generations.add(remaining);
      } else {
        generations.last.addAll(remaining);
      }
    }

    return generations;
  }

  Person _linkSpouses(Person p1, Person p2) {
    return Person(
      id: p1.id,
      firstName: p1.firstName,
      lastName: p1.lastName,
      birthYear: p1.birthYear,
      gender: p1.gender,
      photoUrl: p1.photoUrl,
      details: p1.details,
      age: p1.age,
      mid: p1.mid,
      relationToHead: p1.relationToHead,
      parentIds: p1.parentIds,
      childrenIds: p1.childrenIds,
      spouseId: p2.mid,
    );
  }

  Future<void> _downloadFamilyTree() async {
    if (_downloading) return;

    setState(() => _downloading = true);

    try {
      // Capture the screenshot
      final image = await _screenshotController.capture();
      
      if (image == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to capture family tree'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Check if running on web
      if (kIsWeb) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Download feature is currently available only on mobile app.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Save to gallery (Mobile only)
      await Gal.putImageBytes(image, album: 'Family Trees');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.subFamilyName} tree saved to gallery!'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error downloading family tree: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving family tree: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _downloading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.subFamilyName,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF4A90E2),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (!_loading && _generations.isNotEmpty)
            IconButton(
              icon: _downloading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.download),
              onPressed: _downloading ? null : _downloadFamilyTree,
              tooltip: 'Download Family Tree',
            ),
        ],
      ),
      body: _loading
          ? Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFE3F2FD),
                    Color(0xFFF3E5F5),
                    Color(0xFFFCE4EC),
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
              child: const Center(child: CircularProgressIndicator()),
            )
          : _generations.isEmpty
              ? Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFE3F2FD),
                        Color(0xFFF3E5F5),
                        Color(0xFFFCE4EC),
                      ],
                      stops: [0.0, 0.5, 1.0],
                    ),
                  ),
                  child: Center(
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
                          'No family members found',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Screenshot(
                  controller: _screenshotController,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFE3F2FD), // Light blue
                          Color(0xFFF3E5F5), // Light purple
                          Color(0xFFFCE4EC), // Light pink
                        ],
                        stops: [0.0, 0.5, 1.0],
                      ),
                    ),
                    child: Stack(
                      children: [
                        // Decorative background pattern
                        Positioned(
                          top: 20,
                          right: 20,
                          child: Opacity(
                            opacity: 0.05,
                            child: Icon(
                              Icons.account_tree,
                              size: 200,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 20,
                          left: 20,
                          child: Opacity(
                            opacity: 0.05,
                            child: Icon(
                              Icons.account_tree,
                              size: 200,
                              color: Colors.purple.shade900,
                            ),
                          ),
                        ),
                        // Family name watermark
                        Positioned(
                          top: 10,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                widget.subFamilyName,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Family tree content - Expand to fill remaining space
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 60),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                // Responsive card sizing
                                final screenWidth = MediaQuery.of(context).size.width;
                                final isSmallScreen = screenWidth < 360;
                                final cardWidth = isSmallScreen ? 100.0 : 120.0;
                                final cardHeight = isSmallScreen ? 125.0 : 140.0;

                                return FamilyTree(
                                  generations: _generations,
                                  cardWidth: cardWidth,
                                  cardHeight: cardHeight,
                                  siblingSpacing: isSmallScreen ? 10 : 15,
                                  generationSpacing: isSmallScreen ? 40 : 60,
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
