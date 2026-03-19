// lib/services/analytics_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class AnalyticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Single fetch for high-level overview stats using optimal .count() aggregation
  Future<Map<String, int>> getOverviewStats() async {
    final futures = await Future.wait([
      _firestore.collection('families').where('isAdmin', isEqualTo: false).count().get(),
      _firestore.collectionGroup('members').count().get(),
      _firestore.collection('events').count().get(),
    ]);

    return {
      'totalFamilies': futures[0].count ?? 0,
      'totalMembers': futures[1].count ?? 0,
      'totalEvents': futures[2].count ?? 0,
    };
  }

  // Single fetch for detailed member distribution
  Future<Map<String, dynamic>> getMemberDistribution() async {
    final snapshot = await _firestore.collectionGroup('members').get();

    int active = 0;
    int inactive = 0;
    int male = 0;
    int female = 0;
    int married = 0;
    int unmarried = 0;
    
    Map<String, int> ageRanges = {
      '0-18': 0,
      '19-35': 0,
      '36-50': 0,
      '50+': 0,
    };

    for (var doc in snapshot.docs) {
      final data = doc.data();
      
      // Status
      if (data['isActive'] == true) {
        active++;
      } else {
        inactive++;
      }
      
      // Gender
      String gender = (data['gender'] ?? '').toString().trim().toLowerCase();
      if (gender == 'male' || gender == 'm') {
        male++;
      } else if (gender == 'female' || gender == 'f') {
        female++;
      }
      
      // Marriage Status
      String mStatus = (data['marriageStatus'] ?? '').toString().trim().toLowerCase();
      if (mStatus == 'married') {
        married++;
      } else {
        unmarried++;
      }

      // Age
      int age = data['age'] ?? 0;
      if (age <= 18) {
        ageRanges['0-18'] = ageRanges['0-18']! + 1;
      } else if (age <= 35) {
        ageRanges['19-35'] = ageRanges['19-35']! + 1;
      } else if (age <= 50) {
        ageRanges['36-50'] = ageRanges['36-50']! + 1;
      } else {
        ageRanges['50+'] = ageRanges['50+']! + 1;
      }
    }

    return {
      'active': active,
      'inactive': inactive,
      'male': male,
      'female': female,
      'married': married,
      'unmarried': unmarried,
      'ageRanges': ageRanges,
    };
  }

  // Single fetch for family status distribution
  Future<Map<String, int>> getFamilyDistribution() async {
    final snapshot = await _firestore.collection('families').where('isAdmin', isEqualTo: false).get();
    
    int active = 0;
    int blocked = 0;
    
    for (var doc in snapshot.docs) {
      if (doc.data()['isBlocked'] == true) {
        blocked++;
      } else {
        active++;
      }
    }
    
    return {
      'active': active,
      'blocked': blocked,
      'total': snapshot.docs.length,
    };
  }

  // Single fetch for user growth (last 6 months)
  Future<List<Map<String, dynamic>>> getGrowthData() async {
    final snapshot = await _firestore.collectionGroup('members').get();
    
    Map<String, int> months = {};
    final now = DateTime.now();
    
    for (int i = 0; i < 6; i++) {
      final date = DateTime(now.year, now.month - i, 1);
      final key = "${date.year}-${date.month.toString().padLeft(2, '0')}";
      months[key] = 0;
    }

    for (var doc in snapshot.docs) {
       final data = doc.data();
       if (data['createdAt'] != null) {
         DateTime created;
         if (data['createdAt'] is Timestamp) {
           created = (data['createdAt'] as Timestamp).toDate();
         } else if (data['createdAt'] is String) {
           created = DateTime.tryParse(data['createdAt']) ?? DateTime.now();
         } else {
           continue;
         }
         
         final key = "${created.year}-${created.month.toString().padLeft(2, '0')}";
         if (months.containsKey(key)) {
           months[key] = months[key]! + 1;
         }
       }
    }

    return months.entries
        .map((e) => {'month': e.key, 'count': e.value})
        .toList()
        .reversed
        .toList();
  }
}
