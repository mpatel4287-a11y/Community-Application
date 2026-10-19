// lib/utils/member_sort_helper.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/member_model.dart';

/// Helper utility to sort family members in traditional and hierarchical order:
/// 1. Head of Family
/// 2. Head's Spouse (Wife / Husband)
/// 3. Children of Head, ordered Older to Younger (Big son/daughter first), each followed immediately by their spouse
/// 4. Grandchildren, ordered Older to Younger
/// 5. Remaining family members, ordered Older to Younger
class MemberSortHelper {
  /// Sort a list of [MemberModel] objects strictly from oldest to youngest
  static List<MemberModel> sortOlderToYounger(List<MemberModel> members) {
    if (members.length <= 1) return List.from(members);

    int getMemberAge(MemberModel m) {
      if (m.isDeceased || m.isLate) {
        if (m.age > 0) return m.age;
        final parsed = MemberModel.parseBirthDate(m.birthDate);
        if (parsed != null) return MemberModel.calculateAge(m.birthDate);
        return 999; // Unknown age deceased elder considered oldest ancestor
      }
      if (m.age > 0) return m.age;
      final parsed = MemberModel.parseBirthDate(m.birthDate);
      if (parsed != null) {
        return MemberModel.calculateAge(m.birthDate);
      }
      return 0;
    }

    int compareOlderFirst(MemberModel a, MemberModel b) {
      final ageA = getMemberAge(a);
      final ageB = getMemberAge(b);
      if (ageA != ageB) {
        return ageB.compareTo(ageA); // Higher age (older) first
      }
      final dateA = MemberModel.parseBirthDate(a.birthDate);
      final dateB = MemberModel.parseBirthDate(b.birthDate);
      if (dateA != null && dateB != null && !dateA.isAtSameMomentAs(dateB)) {
        return dateA.compareTo(dateB); // Earlier birth date is older
      }
      if ((a.isDeceased || a.isLate) != (b.isDeceased || b.isLate)) {
        return (a.isDeceased || a.isLate) ? -1 : 1; // Prioritize deceased elder
      }
      return a.fullName.compareTo(b.fullName);
    }

    final sorted = List<MemberModel>.from(members);
    sorted.sort(compareOlderFirst);
    return sorted;
  }

  /// Sort a list of [MemberModel] objects
  static List<MemberModel> sortMembers(List<MemberModel> members) {
    if (members.length <= 1) return List.from(members);

    final List<MemberModel> result = [];
    final Set<String> placedIds = {};

    int getMemberAge(MemberModel m) {
      if (m.age > 0) return m.age;
      final parsed = MemberModel.parseBirthDate(m.birthDate);
      if (parsed != null) {
        return MemberModel.calculateAge(m.birthDate);
      }
      return 0;
    }

    int compareOlderFirst(MemberModel a, MemberModel b) {
      final ageA = getMemberAge(a);
      final ageB = getMemberAge(b);
      if (ageA != ageB) {
        return ageB.compareTo(ageA); // Higher age (older) first
      }
      // If ages equal, compare by birth date if possible
      final dateA = MemberModel.parseBirthDate(a.birthDate);
      final dateB = MemberModel.parseBirthDate(b.birthDate);
      if (dateA != null && dateB != null) {
        return dateA.compareTo(dateB); // Earlier birth date is older
      }
      return a.fullName.compareTo(b.fullName);
    }

    // 1. Find Head of family (Prioritize common root elder / parent head)
    MemberModel? head;
    try {
      head = members.firstWhere(
        (m) =>
            (m.isCommon || m.subFamilyDocId.isEmpty) &&
            m.relationToHead.toLowerCase() == 'head' &&
            m.isActive,
      );
    } catch (_) {
      try {
        head = members.firstWhere(
          (m) => m.relationToHead.toLowerCase() == 'head' && m.isActive,
        );
      } catch (_) {
        try {
          head = members.firstWhere(
            (m) => (m.isCommon || m.subFamilyDocId.isEmpty) && m.relationToHead.toLowerCase() == 'head',
          );
        } catch (_) {
          try {
            head = members.firstWhere((m) => m.relationToHead.toLowerCase() == 'head');
          } catch (_) {
            // Fallback: oldest active member without parentMid (prefer common)
            final candidates = members.where((m) => m.parentMid.isEmpty).toList();
            if (candidates.isNotEmpty) {
              candidates.sort((a, b) {
                if (a.isCommon && !b.isCommon) return -1;
                if (!a.isCommon && b.isCommon) return 1;
                return compareOlderFirst(a, b);
              });
              head = candidates.first;
            } else if (members.isNotEmpty) {
              final sortedAll = List<MemberModel>.from(members)..sort(compareOlderFirst);
              head = sortedAll.first;
            }
          }
        }
      }
    }

    if (head != null) {
      result.add(head);
      placedIds.add(head.id.isNotEmpty ? head.id : head.mid);
    }

    // 2. Find Head's Spouse (Wife / Husband)
    MemberModel? headSpouse;
    if (head != null) {
      if (head.spouseMid.isNotEmpty) {
        try {
          headSpouse = members.firstWhere(
            (m) => (m.mid == head!.spouseMid || m.id == head.spouseMid) &&
                !placedIds.contains(m.id.isNotEmpty ? m.id : m.mid),
          );
        } catch (_) {}
      }

      if (headSpouse == null) {
        try {
          headSpouse = members.firstWhere(
            (m) =>
                !placedIds.contains(m.id.isNotEmpty ? m.id : m.mid) &&
                (m.spouseMid == head!.mid ||
                    (head.gender.toLowerCase() == 'male' &&
                        m.relationToHead.toLowerCase() == 'wife') ||
                    (head.gender.toLowerCase() == 'female' &&
                        m.relationToHead.toLowerCase() == 'husband') ||
                    m.relationToHead.toLowerCase() == 'wife'),
          );
        } catch (_) {}
      }

      if (headSpouse != null) {
        result.add(headSpouse);
        placedIds.add(headSpouse.id.isNotEmpty ? headSpouse.id : headSpouse.mid);
      }
    }

    // 3. Find Children of Head
    final List<MemberModel> children = [];
    for (final m in members) {
      final key = m.id.isNotEmpty ? m.id : m.mid;
      if (placedIds.contains(key)) continue;

      final rel = m.relationToHead.toLowerCase();
      final isChildByRelation = rel == 'son' || rel == 'daughter';
      final isChildByParent = head != null &&
          (m.parentMid.isNotEmpty &&
              (m.parentMid == head.mid ||
                  (headSpouse != null && m.parentMid == headSpouse.mid)));

      if (isChildByRelation || isChildByParent) {
        children.add(m);
      }
    }

    // Sort children Older to Younger (Big son / daughter first)
    children.sort(compareOlderFirst);

    // For each child, add child then immediately their spouse
    for (final child in children) {
      final childKey = child.id.isNotEmpty ? child.id : child.mid;
      if (placedIds.contains(childKey)) continue;

      result.add(child);
      placedIds.add(childKey);

      // Find this child's spouse
      MemberModel? childSpouse;
      if (child.spouseMid.isNotEmpty) {
        try {
          childSpouse = members.firstWhere(
            (m) => (m.mid == child.spouseMid || m.id == child.spouseMid) &&
                !placedIds.contains(m.id.isNotEmpty ? m.id : m.mid),
          );
        } catch (_) {}
      }

      if (childSpouse == null) {
        // Try reciprocal spouseMid
        try {
          childSpouse = members.firstWhere(
            (m) => m.spouseMid == child.mid &&
                !placedIds.contains(m.id.isNotEmpty ? m.id : m.mid),
          );
        } catch (_) {}
      }

      if (childSpouse == null) {
        final rel = child.relationToHead.toLowerCase();
        final gender = child.gender.toLowerCase();
        if (rel == 'son' || gender == 'male') {
          // Look for an available daughter_in_law
          final availableDILs = members.where((m) {
            final k = m.id.isNotEmpty ? m.id : m.mid;
            return !placedIds.contains(k) &&
                (m.relationToHead.toLowerCase() == 'daughter_in_law' ||
                    (m.gender.toLowerCase() == 'female' && m.marriageStatus.toLowerCase() == 'married'));
          }).toList();

          if (availableDILs.isNotEmpty) {
            // Pick closest age
            availableDILs.sort((a, b) =>
                (getMemberAge(a) - getMemberAge(child)).abs().compareTo(
                      (getMemberAge(b) - getMemberAge(child)).abs(),
                    ));
            childSpouse = availableDILs.first;
          }
        } else if (rel == 'daughter' || gender == 'female') {
          // Look for an available son_in_law
          final availableSILs = members.where((m) {
            final k = m.id.isNotEmpty ? m.id : m.mid;
            return !placedIds.contains(k) &&
                m.relationToHead.toLowerCase() == 'son_in_law';
          }).toList();

          if (availableSILs.isNotEmpty) {
            availableSILs.sort((a, b) =>
                (getMemberAge(a) - getMemberAge(child)).abs().compareTo(
                      (getMemberAge(b) - getMemberAge(child)).abs(),
                    ));
            childSpouse = availableSILs.first;
          }
        }
      }

      if (childSpouse != null) {
        result.add(childSpouse);
        placedIds.add(childSpouse.id.isNotEmpty ? childSpouse.id : childSpouse.mid);
      }
    }

    // 4. Grandchildren (grandson / granddaughter or children of sons/daughters)
    final List<MemberModel> grandchildren = [];
    for (final m in members) {
      final key = m.id.isNotEmpty ? m.id : m.mid;
      if (placedIds.contains(key)) continue;

      final rel = m.relationToHead.toLowerCase();
      final isGrandchildByRel = rel == 'grandson' || rel == 'granddaughter';
      final isChildOfSonDaughter = children.any((c) => m.parentMid == c.mid);

      if (isGrandchildByRel || isChildOfSonDaughter) {
        grandchildren.add(m);
      }
    }

    grandchildren.sort(compareOlderFirst);
    for (final gc in grandchildren) {
      final gcKey = gc.id.isNotEmpty ? gc.id : gc.mid;
      if (!placedIds.contains(gcKey)) {
        result.add(gc);
        placedIds.add(gcKey);
      }
    }

    // 5. Remaining members (ordered Older to Younger)
    final List<MemberModel> remaining = [];
    for (final m in members) {
      final key = m.id.isNotEmpty ? m.id : m.mid;
      if (!placedIds.contains(key)) {
        remaining.add(m);
      }
    }

    remaining.sort(compareOlderFirst);
    for (final r in remaining) {
      result.add(r);
      placedIds.add(r.id.isNotEmpty ? r.id : r.mid);
    }

    return result;
  }

  /// Sort a list of Firestore QueryDocumentSnapshot documents in the same order
  static List<QueryDocumentSnapshot> sortDocumentSnapshots(
    List<QueryDocumentSnapshot> docs,
  ) {
    if (docs.length <= 1) return List.from(docs);

    final List<MemberModel> models = docs.map((d) {
      final data = d.data() as Map<String, dynamic>;
      return MemberModel.fromMap(d.id, data);
    }).toList();

    final sortedModels = sortMembers(models);
    final Map<String, int> orderMap = {};
    for (int i = 0; i < sortedModels.length; i++) {
      orderMap[sortedModels[i].id] = i;
    }

    final List<QueryDocumentSnapshot> sortedDocs = List.from(docs);
    sortedDocs.sort((a, b) {
      final indexA = orderMap[a.id] ?? 9999;
      final indexB = orderMap[b.id] ?? 9999;
      return indexA.compareTo(indexB);
    });

    return sortedDocs;
  }
}
