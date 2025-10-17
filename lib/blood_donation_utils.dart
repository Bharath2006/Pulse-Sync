// // blood_donation_utils.dart
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:geolocator/geolocator.dart';

// class BloodDonationUtils {
//   static Future<int> predictDemand(String bloodGroup) async {
//     // Fetch last 3 weeks of request data for the group
//     QuerySnapshot snapshot = await FirebaseFirestore.instance
//         .collection('requests')
//         .where('bloodGroup', isEqualTo: bloodGroup)
//         .where(
//           'createdAt',
//           isGreaterThan: DateTime.now().subtract(const Duration(days: 21)),
//         )
//         .get();
//     List docs = snapshot.docs;
//     if (docs.isEmpty) return 0;
//     // Weekly average
//     return (docs.length / 3).ceil();
//   }

//   static Future<List<DocumentSnapshot>> findBestDonors(
//     String bloodGroup,
//     GeoPoint requestLocation,
//     DateTime requiredBy,
//   ) async {
//     QuerySnapshot snapshot = await FirebaseFirestore.instance
//         .collection('users')
//         .where('role', isEqualTo: 'donor')
//         .where('isAvailable', isEqualTo: true)
//         .where('bloodGroup', isEqualTo: bloodGroup)
//         .get();

//     List<DocumentSnapshot> candidates = snapshot.docs.where((doc) {
//       DateTime? lastDonation;
//       try {
//         lastDonation = (doc['lastDonation'] as Timestamp?)?.toDate();
//       } catch (_) {}
//       // Donor must not have donated in the last 60 days
//       if (lastDonation != null &&
//           lastDonation.isAfter(
//             DateTime.now().subtract(const Duration(days: 60)),
//           )) {
//         return false;
//       }
//       // Add distance check (within 10km)
//       final donorLoc = doc['location'] as GeoPoint?;
//       if (donorLoc == null) return false;
//       double dist = Geolocator.distanceBetween(
//         requestLocation.latitude,
//         requestLocation.longitude,
//         donorLoc.latitude,
//         donorLoc.longitude,
//       );
//       return dist <= 10000;
//     }).toList();

//     // Sort candidates by least recently donated, closest distance
//     candidates.sort((a, b) {
//       DateTime? aLast = (a['lastDonation'] as Timestamp?)?.toDate();
//       DateTime? bLast = (b['lastDonation'] as Timestamp?)?.toDate();
//       return (aLast ?? DateTime(1980)).compareTo(bLast ?? DateTime(1980));
//     });
//     return candidates;
//   }
// }

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class BloodDonationUtils {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<int> predictDemand(String bloodGroup) async {
    try {
      final requestsSnapshot = await _firestore
          .collection('requests')
          .where('bloodGroup', isEqualTo: bloodGroup)
          .orderBy('requiredDate', descending: true)
          .limit(100)
          .get();

      final inventorySnapshot = await _firestore
          .collection('inventory')
          .doc(bloodGroup)
          .get();

      int currentInventory = inventorySnapshot.exists
          ? (inventorySnapshot.data()?['units'] ?? 0)
          : 0;
      if (requestsSnapshot.docs.isEmpty) {
        return _getDefaultDemand(bloodGroup);
      }

      final now = DateTime.now();
      final oneYearAgo = DateTime(now.year - 1, now.month, now.day);

      int totalRequests = 0;
      int weekCount = 0;
      DateTime? firstRequestDate;
      DateTime? lastRequestDate;

      for (final doc in requestsSnapshot.docs) {
        final requestDate = (doc['requiredDate'] as Timestamp).toDate();
        if (requestDate.isAfter(oneYearAgo)) {
          totalRequests++;
          firstRequestDate ??= requestDate;
          lastRequestDate = requestDate;
        }
      }

      if (totalRequests == 0) {
        return _getDefaultDemand(bloodGroup);
      }

      final days = lastRequestDate!.difference(firstRequestDate!).inDays;
      final weeks = (days / 7).ceil();
      weekCount = weeks > 0 ? weeks : 1;

      final averageWeeklyDemand = (totalRequests / weekCount).ceil();

      final seasonalFactor = _getSeasonalFactor(now);
      final adjustedDemand = (averageWeeklyDemand * seasonalFactor).ceil();

      final inventoryFactor = _getInventoryFactor(
        currentInventory,
        adjustedDemand,
      );
      final finalDemand = (adjustedDemand * inventoryFactor).ceil();

      return finalDemand.clamp(5, 100);
    } catch (e) {
      return _getDefaultDemand(bloodGroup);
    }
  }

  static int _getDefaultDemand(String bloodGroup) {
    const defaultDemands = {
      'A+': 25,
      'A-': 8,
      'B+': 15,
      'B-': 5,
      'AB+': 5,
      'AB-': 2,
      'O+': 30,
      'O-': 10,
    };
    return defaultDemands[bloodGroup] ?? 10;
  }

  static double _getSeasonalFactor(DateTime date) {
    if (date.month >= 6 && date.month <= 8) {
      return 1.2;
    } else if (date.month == 12) {
      return 1.3;
    } else if (date.month == 1 || date.month == 2) {
      return 0.9; 
    }
    return 1.0;
  }

  static double _getInventoryFactor(int currentInventory, int predictedDemand) {
    if (currentInventory <= 0) {
      return 1.5;
    } else if (currentInventory < predictedDemand / 2) {
      return 1.2;
    } else if (currentInventory > predictedDemand * 2) {
      return 0.8;
    }
    return 1.0;
  }

  static Future<List<DocumentSnapshot>> findBestDonors(
    String bloodGroup,
    GeoPoint location,
    DateTime requiredDate,
  ) async {
    try {
      final donorsSnapshot = await _firestore
          .collection('donors')
          .where('bloodGroup', isEqualTo: bloodGroup)
          .where(
            'lastDonationDate',
            isLessThan: Timestamp.fromDate(
              requiredDate.subtract(const Duration(days: 90)),
            ),
          )
          .get();

      if (donorsSnapshot.docs.isEmpty) {
        return [];
      }

      final donorsWithDistance = donorsSnapshot.docs.map((doc) {
        final donorLocation = doc['location'] as GeoPoint;
        final distance = Geolocator.distanceBetween(
          location.latitude,
          location.longitude,
          donorLocation.latitude,
          donorLocation.longitude,
        );
        return {'doc': doc, 'distance': distance};
      }).toList();

      donorsWithDistance.sort(
        (a, b) => (a['distance'] as double).compareTo(b['distance'] as double),
      );

      final nearestDonors = donorsWithDistance
          .take(20)
          .map((item) => item['doc'] as DocumentSnapshot)
          .toList();

      return nearestDonors;
    } catch (e) {
      return [];
    }
  }
}
