// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:share_plus/share_plus.dart';
// import 'package:intl/intl.dart';

// import 'donor_profile_screen.dart';

// class DonorMatchingScreen extends StatefulWidget {
//   final String requestId;
//   final String bloodGroup;
//   final GeoPoint requestLocation;
//   final DateTime requiredBy;
//   final String hospital;
//   final int units;

//   const DonorMatchingScreen({
//     super.key,
//     required this.requestId,
//     required this.bloodGroup,
//     required this.requestLocation,
//     required this.requiredBy,
//     required this.hospital,
//     required this.units,
//   });

//   @override
//   State<DonorMatchingScreen> createState() => _DonorMatchingScreenState();
// }

// class _DonorMatchingScreenState extends State<DonorMatchingScreen> {
//   List<DocumentSnapshot> _matchedDonors = [];
//   bool _isLoading = true;
//   Position? _currentPosition;
//   bool _isDisposed = false;
//   int _predictedDemand = 0;

//   @override
//   void dispose() {
//     _isDisposed = true;
//     super.dispose();
//   }

//   void _safeSetState(VoidCallback fn) {
//     if (!_isDisposed && mounted) {
//       setState(fn);
//     }
//   }

//   Future<void> _getCurrentLocation() async {
//     try {
//       bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
//       if (!serviceEnabled) return;

//       LocationPermission permission = await Geolocator.checkPermission();
//       if (permission == LocationPermission.denied) {
//         permission = await Geolocator.requestPermission();
//         if (permission == LocationPermission.denied) return;
//       }

//       if (permission == LocationPermission.deniedForever) return;

//       _currentPosition = await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.high,
//       );
//       _safeSetState(() {});
//     } catch (e) {
//       debugPrint('Location error: $e');
//     }
//   }

//   double _calculateDistance(GeoPoint donorLocation) {
//     return Geolocator.distanceBetween(
//       widget.requestLocation.latitude,
//       widget.requestLocation.longitude,
//       donorLocation.latitude,
//       donorLocation.longitude,
//     ) / 1000; // km
//   }

//   Future<int> _predictDemand() async {
//     final snapshot = await FirebaseFirestore.instance
//         .collection('requests')
//         .where('bloodGroup', isEqualTo: widget.bloodGroup)
//         .where('createdAt', isGreaterThan: 
//             DateTime.now().subtract(const Duration(days: 21)))
//         .get();
    
//     final count = snapshot.docs.length;
//     return (count / 3).ceil(); // Weekly average
//   }

//   Future<List<DocumentSnapshot>> _findBestDonors() async {
//     try {
//       final snapshot = await FirebaseFirestore.instance
//           .collection('users')
//           .where('role', isEqualTo: 'donor')
//           .where('bloodGroup', isEqualTo: widget.bloodGroup)
//           .where('isAvailable', isEqualTo: true)
//           .get();

//       final now = DateTime.now();
//       final threeMonthsAgo = DateTime(now.year, now.month - 3, now.day);

//       List<DocumentSnapshot> donors = snapshot.docs.where((doc) {
//         final data = doc.data() as Map<String, dynamic>;

//         // Check last donation date
//         if (data['lastDonation'] != null) {
//           final lastDonation = (data['lastDonation'] as Timestamp).toDate();
//           if (lastDonation.isAfter(threeMonthsAgo)) return false;
//         }

//         // Check distance if location available
//         if (data['location'] != null) {
//           final donorLoc = data['location'] as GeoPoint;
//           final distance = _calculateDistance(donorLoc);
//           return distance <= 20; // within 20km
//         }

//         return true;
//       }).toList();

//       // Sort by distance if possible
//       donors.sort((a, b) {
//         final aData = a.data() as Map<String, dynamic>;
//         final bData = b.data() as Map<String, dynamic>;
//         final aLoc = aData['location'] as GeoPoint?;
//         final bLoc = bData['location'] as GeoPoint?;

//         if (aLoc == null) return 1;
//         if (bLoc == null) return -1;

//         final aDist = _calculateDistance(aLoc);
//         final bDist = _calculateDistance(bLoc);

//         return aDist.compareTo(bDist);
//       });

//       return donors;
//     } catch (e) {
//       debugPrint('Error finding donors: $e');
//       return [];
//     }
//   }

//   Future<void> _contactDonor(String donorId, String donorName) async {
//     try {
//       await FirebaseFirestore.instance
//           .collection('requests')
//           .doc(widget.requestId)
//           .update({
//             'matchedDonorId': donorId,
//             'status': 'matched',
//             'matchedAt': FieldValue.serverTimestamp(),
//           });

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Successfully contacted $donorName'),
//           backgroundColor: Colors.green,
//         ),
//       );
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Failed to contact donor: $e'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     }
//   }

//   @override
//   void initState() {
//     super.initState();
//     _loadData();
//   }

//   Future<void> _loadData() async {
//     await _getCurrentLocation();
//     final demand = await _predictDemand();
//     _safeSetState(() => _predictedDemand = demand);
//     final donors = await _findBestDonors();
//     _safeSetState(() {
//       _matchedDonors = donors;
//       _isLoading = false;
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Matching Donors'),
//         backgroundColor: Colors.red[700],
//         iconTheme: const IconThemeData(color: Colors.white),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.share),
//             onPressed: () {
//               Share.share(
//                 "Urgent blood needed!\nBlood Group: ${widget.bloodGroup}\n"
//                 "Hospital: ${widget.hospital}\n"
//                 "Units Needed: ${widget.units}\n"
//                 "Required by: ${DateFormat('MMMM d, y').format(widget.requiredBy)}\n"
//                 "Please help via PulseSync app!",
//                 subject: "Help Save a Life – Blood Donation Request"
//               );
//             },
//           ),
//         ],
//       ),
//       body: _isLoading
//           ? const Center(child: CircularProgressIndicator())
//           : _matchedDonors.isEmpty
//               ? Center(
//                   child: Column(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       const Icon(
//                         Icons.people_outline,
//                         size: 64,
//                         color: Colors.grey,
//                       ),
//                       const SizedBox(height: 16),
//                       const Text(
//                         'No matching donors found',
//                         style: TextStyle(fontSize: 18, color: Colors.grey),
//                       ),
//                       const SizedBox(height: 8),
//                       Text(
//                         'Blood Group: ${widget.bloodGroup}',
//                         style: const TextStyle(fontSize: 16),
//                       ),
//                       Text(
//                         'Predicted weekly demand: $_predictedDemand units',
//                         style: const TextStyle(fontSize: 16),
//                       ),
//                       const SizedBox(height: 16),
//                       ElevatedButton(
//                         onPressed: _loadData,
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: Colors.red[700],
//                           foregroundColor: Colors.white,
//                         ),
//                         child: const Text('Try Again'),
//                       ),
//                     ],
//                   ),
//                 )
//               : Column(
//                   children: [
//                     Padding(
//                       padding: const EdgeInsets.all(16),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(
//                             'Request Details:',
//                             style: TextStyle(
//                               fontSize: 18,
//                               fontWeight: FontWeight.bold,
//                               color: Colors.red[700],
//                             ),
//                           ),
//                           const SizedBox(height: 8),
//                           Text('Blood Group: ${widget.bloodGroup}'),
//                           Text('Units Needed: ${widget.units}'),
//                           Text('Hospital: ${widget.hospital}'),
//                           Text(
//                             'Required by: ${DateFormat('MMMM d, y').format(widget.requiredBy)}',
//                           ),
//                           const SizedBox(height: 8),
//                           Text(
//                             'Predicted weekly demand: $_predictedDemand units',
//                             style: const TextStyle(fontWeight: FontWeight.bold),
//                           ),
//                         ],
//                       ),
//                     ),
//                     Expanded(
//                       child: ListView.builder(
//                         itemCount: _matchedDonors.length,
//                         itemBuilder: (context, index) {
//                           final donor = _matchedDonors[index];
//                           final data = donor.data() as Map<String, dynamic>;
//                           final location = data['location'] as GeoPoint?;
//                           double? distance;
//                           final lastDonation = data['lastDonation'] != null
//                               ? (data['lastDonation'] as Timestamp).toDate()
//                               : null;
//                           final daysSinceDonation = lastDonation != null
//                               ? DateTime.now().difference(lastDonation).inDays
//                               : null;
//                           final isEligible =
//                               daysSinceDonation == null || daysSinceDonation >= 56;

//                           if (location != null) {
//                             distance = _calculateDistance(location);
//                           }

//                           return Card(
//                             margin: const EdgeInsets.all(8.0),
//                             elevation: 2,
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(10),
//                             ),
//                             child: ListTile(
//                               leading: CircleAvatar(
//                                 backgroundColor: Colors.red[100],
//                                 child: Text(
//                                   data['name']?[0] ?? 'D',
//                                   style: const TextStyle(color: Colors.red),
//                                 ),
//                               ),
//                               title: Text(
//                                 data['name'] ?? 'Anonymous Donor',
//                                 style: const TextStyle(fontWeight: FontWeight.bold),
//                               ),
//                               subtitle: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   Text('Blood Group: ${data['bloodGroup']}'),
//                                   if (distance != null)
//                                     Text('${distance.toStringAsFixed(1)} km away'),
//                                   if (lastDonation != null)
//                                     Text('Last donated: ${daysSinceDonation} days ago'),
//                                   Row(
//                                     children: [
//                                       Chip(
//                                         label: Text(
//                                           isEligible ? 'Eligible' : 'Not eligible',
//                                           style: const TextStyle(color: Colors.white),
//                                         ),
//                                         backgroundColor: isEligible
//                                             ? Colors.green
//                                             : Colors.red,
//                                       ),
//                                     ],
//                                   ),
//                                 ],
//                               ),
//                               trailing: IconButton(
//                                 icon: const Icon(Icons.contact_page, color: Colors.red),
//                                 onPressed: () =>
//                                     _contactDonor(donor.id, data['name'] ?? 'donor'),
//                               ),
//                               onTap: () {
//                                 Navigator.push(
//                                   context,
//                                   MaterialPageRoute(
//                                     builder: (context) => DonorProfileScreen(
//                                       donorId: donor.id,
//                                       donorData: data,
//                                     ),
//                                   ),
//                                 );
//                               },
//                             ),
//                           );
//                         },
//                       ),
//                     ),
//                   ],
//                 ),
//     );
//   }
// }