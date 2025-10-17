// blood_donation_utils.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class BloodDonationUtils {
  static Future<int> predictDemand(String bloodGroup) async {
    // Fetch last 3 weeks of request data for the group
    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('requests')
        .where('bloodGroup', isEqualTo: bloodGroup)
        .where('createdAt', isGreaterThan: DateTime.now().subtract(const Duration(days: 21)))
        .get();
    List docs = snapshot.docs;
    if (docs.isEmpty) return 0;
    // Weekly average
    return (docs.length / 3).ceil();
  }

  static Future<List<DocumentSnapshot>> findBestDonors(
    String bloodGroup, 
    GeoPoint requestLocation, 
    DateTime requiredBy
  ) async {
    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'donor')
        .where('isAvailable', isEqualTo: true)
        .where('bloodGroup', isEqualTo: bloodGroup)
        .get();

    List<DocumentSnapshot> candidates = snapshot.docs.where((doc) {
      DateTime? lastDonation;
      try {
        lastDonation = (doc['lastDonation'] as Timestamp?)?.toDate();
      } catch (_) {}
      // Donor must not have donated in the last 60 days
      if (lastDonation != null && lastDonation.isAfter(DateTime.now().subtract(const Duration(days: 60)))) {
        return false;
      }
      // Add distance check (within 10km)
      final donorLoc = doc['location'] as GeoPoint?;
      if (donorLoc == null) return false;
      double dist = Geolocator.distanceBetween(
        requestLocation.latitude, requestLocation.longitude, 
        donorLoc.latitude, donorLoc.longitude
      );
      return dist <= 10000;
    }).toList();
    
    // Sort candidates by least recently donated, closest distance
    candidates.sort((a, b) {
      DateTime? aLast = (a['lastDonation'] as Timestamp?)?.toDate();
      DateTime? bLast = (b['lastDonation'] as Timestamp?)?.toDate();
      return (aLast ?? DateTime(1980)).compareTo(bLast ?? DateTime(1980));
    });
    return candidates;
  }
}