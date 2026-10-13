import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:screenshot/screenshot.dart';
import 'package:gal/gal.dart';
import '../../widgets/family_tree.dart';
import '../../widgets/custom_export_dialog.dart';
import '../../models/member_model.dart';
import '../../models/person.dart';
import '../../services/member_service.dart';

class SubFamilyTreeDetailScreen extends StatefulWidget {
  final String mainFamilyDocId;
  final String familyName;
  final String subFamilyDocId;
  final String subFamilyId;
  final String subFamilyName;
  final String? seniority;

  const SubFamilyTreeDetailScreen({
    super.key,
    required this.mainFamilyDocId,
    required this.familyName,
    required this.subFamilyDocId,
    required this.subFamilyId,
    required this.subFamilyName,
    this.seniority,
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
    final Map<String, Person> personById = {}; // Document ID -> Person
    final Map<String, List<String>> childrenMap = {}; // Parent MID -> List of child MIDs

    // Helper: calculate exact age
    int calculateMemberAge(MemberModel m) {
      if (m.age > 0) return m.age;
      final parsed = MemberModel.parseBirthDate(m.birthDate);
      if (parsed != null) {
        return MemberModel.calculateAge(m.birthDate);
      }
      return 0;
    }

    // Convert all members to Person objects
    for (final member in members) {
      final nameParts = member.fullName.trim().split(RegExp(r'\s+'));
      final firstName = nameParts.isNotEmpty ? nameParts[0] : member.fullName;
      final lastName = nameParts.length > 1
          ? nameParts.sublist(1).join(' ')
          : member.surname.isNotEmpty
              ? member.surname
              : '';

      final int memberAge = calculateMemberAge(member);
      int birthYear = DateTime.now().year - memberAge;
      if (member.birthDate.isNotEmpty) {
        try {
          final parts = member.birthDate.split('/');
          if (parts.length == 3) {
            birthYear = int.parse(parts[2]);
          }
        } catch (_) {}
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
        age: memberAge > 0 ? memberAge : null,
        birthDate: member.birthDate.isNotEmpty ? member.birthDate : null,
        mid: member.mid,
        relationToHead: member.relationToHead,
        parentIds: member.parentMid.isNotEmpty ? [member.parentMid] : [],
        spouseId: member.spouseMid.isNotEmpty ? member.spouseMid : null,
      );

      personMap[member.mid] = person;
      if (member.id.isNotEmpty) {
        personById[member.id] = person;
      }

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
        final combinedChildren = {...parent.childrenIds, ...entry.value}.toList();
        personMap[parentMid] = Person(
          id: parent.id,
          firstName: parent.firstName,
          lastName: parent.lastName,
          birthYear: parent.birthYear,
          gender: parent.gender,
          photoUrl: parent.photoUrl,
          details: parent.details,
          age: parent.age,
          birthDate: parent.birthDate,
          mid: parent.mid,
          relationToHead: parent.relationToHead,
          parentIds: parent.parentIds,
          childrenIds: combinedChildren,
          spouseId: parent.spouseId,
        );
      }
    }

    // Robust bidirectional spouse matching
    // 1. Explicit spouseMid / spouseId matching
    for (final person in List<Person>.from(personMap.values)) {
      if (person.spouseId != null && person.spouseId!.isNotEmpty) {
        final spouse = personMap[person.spouseId] ?? personById[person.spouseId];
        if (spouse != null && spouse.mid != person.mid) {
          personMap[person.mid!] = _linkSpouses(personMap[person.mid!]!, spouse);
          personMap[spouse.mid!] = _linkSpouses(personMap[spouse.mid!]!, person);
        }
      }
    }

    // 2. Reciprocal spouseId matching
    for (final person in List<Person>.from(personMap.values)) {
      if (person.spouseId == null) {
        final spouse = personMap.values.firstWhere(
          (p) => p.mid != person.mid && (p.spouseId == person.mid || p.spouseId == person.id),
          orElse: () => person,
        );
        if (spouse != person) {
          personMap[person.mid!] = _linkSpouses(personMap[person.mid!]!, spouse);
          personMap[spouse.mid!] = _linkSpouses(personMap[spouse.mid!]!, person);
        }
      }
    }

    // 3. Head & Wife/Husband matching
    Person? headPerson;
    try {
      headPerson = personMap.values.firstWhere(
        (p) => (p.relationToHead ?? '').toLowerCase() == 'head',
      );
    } catch (_) {
      final candidates = personMap.values.where((p) => p.parentIds.isEmpty).toList();
      if (candidates.isNotEmpty) {
        candidates.sort((a, b) => (b.age ?? 0).compareTo(a.age ?? 0));
        headPerson = candidates.first;
      } else if (personMap.isNotEmpty) {
        headPerson = personMap.values.first;
      }
    }

    if (headPerson != null && headPerson.spouseId == null) {
      final targetSpouseRel = headPerson.gender == Gender.female ? 'husband' : 'wife';
      final headSpouse = personMap.values.firstWhere(
        (p) => p.mid != headPerson!.mid &&
            p.spouseId == null &&
            ((p.relationToHead ?? '').toLowerCase() == targetSpouseRel ||
             (p.relationToHead ?? '').toLowerCase() == 'wife'),
        orElse: () => headPerson!,
      );
      if (headSpouse != headPerson) {
        personMap[headPerson.mid!] = _linkSpouses(personMap[headPerson.mid!]!, headSpouse);
        personMap[headSpouse.mid!] = _linkSpouses(personMap[headSpouse.mid!]!, headPerson);
      }
    }

    // 4. Son & Daughter-in-law matching
    final unlinkedSons = personMap.values
        .where((p) => (p.relationToHead ?? '').toLowerCase() == 'son' && p.spouseId == null)
        .toList();
    final unlinkedDILs = personMap.values
        .where((p) => (p.relationToHead ?? '').toLowerCase() == 'daughter_in_law' && p.spouseId == null)
        .toList();

    // Check shared children first
    for (final son in List<Person>.from(unlinkedSons)) {
      for (final dil in List<Person>.from(unlinkedDILs)) {
        final hasSharedChild = personMap.values.any((c) =>
            c.parentIds.contains(son.mid) && c.parentIds.contains(dil.mid));
        if (hasSharedChild) {
          personMap[son.mid!] = _linkSpouses(personMap[son.mid!]!, dil);
          personMap[dil.mid!] = _linkSpouses(personMap[dil.mid!]!, son);
          unlinkedSons.remove(son);
          unlinkedDILs.remove(dil);
          break;
        }
      }
    }

    // Sort remaining by age older to younger and pair in order
    unlinkedSons.sort((a, b) => (b.age ?? 0).compareTo(a.age ?? 0));
    unlinkedDILs.sort((a, b) => (b.age ?? 0).compareTo(a.age ?? 0));
    final sonDilMatches = math.min(unlinkedSons.length, unlinkedDILs.length);
    for (int i = 0; i < sonDilMatches; i++) {
      final s = unlinkedSons[i];
      final d = unlinkedDILs[i];
      personMap[s.mid!] = _linkSpouses(personMap[s.mid!]!, d);
      personMap[d.mid!] = _linkSpouses(personMap[d.mid!]!, s);
    }

    // 5. Daughter & Son-in-law matching
    final unlinkedDtrs = personMap.values
        .where((p) => (p.relationToHead ?? '').toLowerCase() == 'daughter' && p.spouseId == null)
        .toList();
    final unlinkedSILs = personMap.values
        .where((p) => (p.relationToHead ?? '').toLowerCase() == 'son_in_law' && p.spouseId == null)
        .toList();
    final dtrSilMatches = math.min(unlinkedDtrs.length, unlinkedSILs.length);
    for (int i = 0; i < dtrSilMatches; i++) {
      final d = unlinkedDtrs[i];
      final sil = unlinkedSILs[i];
      personMap[d.mid!] = _linkSpouses(personMap[d.mid!]!, sil);
      personMap[sil.mid!] = _linkSpouses(personMap[sil.mid!]!, d);
    }

    // Comparator: Older first (higher age, or earlier birth date)
    int compareOlderFirst(Person a, Person b) {
      final ageA = a.age ?? (DateTime.now().year - a.birthYear);
      final ageB = b.age ?? (DateTime.now().year - b.birthYear);
      if (ageA != ageB) {
        return ageB.compareTo(ageA);
      }
      if (a.birthDate != null && b.birthDate != null) {
        final dA = MemberModel.parseBirthDate(a.birthDate!);
        final dB = MemberModel.parseBirthDate(b.birthDate!);
        if (dA != null && dB != null) {
          return dA.compareTo(dB);
        }
      }
      return a.fullName.compareTo(b.fullName);
    }

    final Set<String> placedMids = {};

    // Helper: pair members with their spouses side-by-side
    List<Person> pairWithSpouses(List<Person> items) {
      final List<Person> result = [];
      for (final p in items) {
        final midKey = p.mid ?? p.id;
        if (placedMids.contains(midKey)) continue;

        Person? spouse;
        if (p.spouseId != null) {
          spouse = personMap[p.spouseId] ?? personById[p.spouseId];
        }

        final spouseKey = spouse != null ? (spouse.mid ?? spouse.id) : null;

        if (spouse != null && spouseKey != null && !placedMids.contains(spouseKey)) {
          // Husband on left, wife on right (or person first)
          if (p.gender == Gender.female && spouse.gender == Gender.male) {
            result.add(spouse);
            result.add(p);
          } else {
            result.add(p);
            result.add(spouse);
          }
          placedMids.add(midKey);
          placedMids.add(spouseKey);
        } else {
          result.add(p);
          placedMids.add(midKey);
        }
      }
      return result;
    }

    final List<List<Person>> generations = [];

    // Gen 0: Ancestors (Parents of Head, e.g. Father, Mother)
    final ancestors = personMap.values.where((p) {
      final rel = (p.relationToHead ?? '').toLowerCase();
      return rel == 'father' || rel == 'mother';
    }).toList();
    if (ancestors.isNotEmpty) {
      ancestors.sort(compareOlderFirst);
      final genAncestors = pairWithSpouses(ancestors);
      if (genAncestors.isNotEmpty) {
        generations.add(genAncestors);
      }
    }

    // Gen: Head of family and Spouse
    final headCandidates = personMap.values.where((p) {
      final key = p.mid ?? p.id;
      return !placedMids.contains(key) && (p.relationToHead ?? '').toLowerCase() == 'head';
    }).toList();

    if (headCandidates.isEmpty && placedMids.isEmpty) {
      final noParents = personMap.values.where((p) => p.parentIds.isEmpty).toList();
      noParents.sort(compareOlderFirst);
      if (noParents.isNotEmpty) {
        headCandidates.add(noParents.first);
      } else if (personMap.isNotEmpty) {
        headCandidates.add(personMap.values.first);
      }
    }

    if (headCandidates.isNotEmpty) {
      final genHead = pairWithSpouses(headCandidates);
      if (genHead.isNotEmpty) {
        generations.add(genHead);
      }
    }

    // Gen: Children of Head, strictly sorted older to younger, paired with spouses
    final updatedHead = personMap.values.firstWhere(
      (p) => (p.relationToHead ?? '').toLowerCase() == 'head',
      orElse: () => personMap.values.first,
    );
    final headSpouseMid = updatedHead.spouseId;

    final children = personMap.values.where((p) {
      final key = p.mid ?? p.id;
      if (placedMids.contains(key)) return false;
      final rel = (p.relationToHead ?? '').toLowerCase();
      if (rel == 'son' || rel == 'daughter') return true;
      if (p.parentIds.contains(updatedHead.mid) || p.parentIds.contains(updatedHead.id)) return true;
      if (headSpouseMid != null &&
          (p.parentIds.contains(headSpouseMid) || p.parentIds.contains(headSpouseMid))) {
        return true;
      }
      return false;
    }).toList();

    children.sort(compareOlderFirst);
    final genChildren = pairWithSpouses(children);
    if (genChildren.isNotEmpty) {
      generations.add(genChildren);
    }

    // Gen: Grandchildren, strictly sorted older to younger, paired with spouses
    final grandchildren = personMap.values.where((p) {
      final key = p.mid ?? p.id;
      if (placedMids.contains(key)) return false;
      final rel = (p.relationToHead ?? '').toLowerCase();
      if (rel == 'grandson' || rel == 'granddaughter') return true;
      if (p.parentIds.any((parentId) =>
          genChildren.any((parent) => parent.mid == parentId || parent.id == parentId))) {
        return true;
      }
      return false;
    }).toList();

    grandchildren.sort(compareOlderFirst);
    final genGrandchildren = pairWithSpouses(grandchildren);
    if (genGrandchildren.isNotEmpty) {
      generations.add(genGrandchildren);
    }

    // Gen: Great-grandchildren (if any)
    final greatGrandchildren = personMap.values.where((p) {
      final key = p.mid ?? p.id;
      if (placedMids.contains(key)) return false;
      if (p.parentIds.any((parentId) =>
          genGrandchildren.any((parent) => parent.mid == parentId || parent.id == parentId))) {
        return true;
      }
      return false;
    }).toList();

    if (greatGrandchildren.isNotEmpty) {
      greatGrandchildren.sort(compareOlderFirst);
      final genGreatGrandchildren = pairWithSpouses(greatGrandchildren);
      if (genGreatGrandchildren.isNotEmpty) {
        generations.add(genGreatGrandchildren);
      }
    }

    // Remaining members: sorted older to younger, paired with spouses
    final remaining = personMap.values.where((p) {
      final key = p.mid ?? p.id;
      return !placedMids.contains(key);
    }).toList();

    if (remaining.isNotEmpty) {
      remaining.sort(compareOlderFirst);
      final genRemaining = pairWithSpouses(remaining);
      if (generations.isEmpty) {
        generations.add(genRemaining);
      } else {
        generations.last.addAll(genRemaining);
      }
    }

    return generations;
  }

  Person _linkSpouses(Person p1, Person p2) {
    final spouseKey = p2.mid?.isNotEmpty == true ? p2.mid! : p2.id;
    return Person(
      id: p1.id,
      firstName: p1.firstName,
      lastName: p1.lastName,
      birthYear: p1.birthYear,
      gender: p1.gender,
      photoUrl: p1.photoUrl,
      details: p1.details,
      age: p1.age,
      birthDate: p1.birthDate,
      mid: p1.mid,
      relationToHead: p1.relationToHead,
      parentIds: p1.parentIds,
      childrenIds: p1.childrenIds.isNotEmpty ? p1.childrenIds : p2.childrenIds,
      spouseId: spouseKey,
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.subFamilyName,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
            if (widget.seniority != null && widget.seniority!.isNotEmpty)
              Text(
                widget.seniority == 'older'
                    ? 'Elder Branch (Older / મોટો પરિવાર)'
                    : 'Junior Branch (Younger / નાનો પરિવાર)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                  color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.85),
                ),
              ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0,
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export Family Details (PDF / Excel)',
            onPressed: () {
              CustomExportDialog.show(
                context,
                mainFamilyDocId: widget.mainFamilyDocId,
                familyName: widget.familyName,
                initialSubFamilyDocId: widget.subFamilyDocId,
                initialSubFamilyName: widget.subFamilyName,
                restrictToSingleFamily: true,
              );
            },
          ),
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
              tooltip: 'Download Family Tree Image',
            ),
        ],
      ),
      body: _loading
          ? Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
              ),
              child: const Center(child: CircularProgressIndicator()),
            )
          : _generations.isEmpty
              ? Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
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
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
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
                                color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    widget.subFamilyName,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.primary,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  if (widget.seniority != null && widget.seniority!.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: widget.seniority == 'older' ? Colors.blue.shade50 : Colors.teal.shade50,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: widget.seniority == 'older' ? Colors.blue.shade300 : Colors.teal.shade300,
                                        ),
                                      ),
                                      child: Text(
                                        widget.seniority == 'older'
                                            ? 'Elder Branch (Older / મોટો પરિવાર)'
                                            : 'Junior Branch (Younger / નાનો પરિવાર)',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: widget.seniority == 'older' ? Colors.blue.shade800 : Colors.teal.shade800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Family tree content - Expand to fill remaining space
                        Positioned.fill(
                          child: Padding(
                            padding: EdgeInsets.only(
                              top: widget.seniority != null && widget.seniority!.isNotEmpty ? 90 : 60,
                            ),
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
