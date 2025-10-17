// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:intl/intl.dart';
// import 'package:url_launcher/url_launcher.dart';

// class DonorProfileScreen extends StatelessWidget {
//   final String donorId;
//   final Map<String, dynamic> donorData;

//   const DonorProfileScreen({
//     super.key,
//     required this.donorId,
//     required this.donorData,
//   });

//   Future<void> _launchContact(String phone) async {
//     final url = Uri.parse('tel:$phone');
//     if (await canLaunchUrl(url)) {
//       await launchUrl(url);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final lastDonation = donorData['lastDonation'] != null
//         ? (donorData['lastDonation'] as Timestamp).toDate()
//         : null;
//     final daysSinceLastDonation = lastDonation != null
//         ? DateTime.now().difference(lastDonation).inDays
//         : null;
//     final isEligible =
//         daysSinceLastDonation == null || daysSinceLastDonation >= 56;

//     return Scaffold(
//       appBar: AppBar(
//         title: Text(donorData['name'] ?? 'Donor Profile'),
//         backgroundColor: Colors.red[700],
//         foregroundColor: Colors.white,
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Center(
//               child: CircleAvatar(
//                 radius: 50,
//                 backgroundColor: Colors.red[100],
//                 child: Text(
//                   donorData['name']?[0] ?? 'D',
//                   style: const TextStyle(
//                     fontSize: 40,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.red,
//                   ),
//                 ),
//               ),
//             ),
//             const SizedBox(height: 20),
//             _buildProfileItem(
//               Icons.bloodtype,
//               'Blood Group',
//               donorData['bloodGroup'],
//             ),
//             _buildProfileItem(Icons.email, 'Email', donorData['email']),
//             if (donorData['phone'] != null)
//               _buildProfileItem(Icons.phone, 'Phone', donorData['phone']),
//             if (donorData['location'] != null)
//               _buildProfileItem(
//                 Icons.location_on,
//                 'Approximate Location',
//                 '${(donorData['location'] as GeoPoint).latitude.toStringAsFixed(4)}, '
//                     '${(donorData['location'] as GeoPoint).longitude.toStringAsFixed(4)}',
//               ),
//             if (lastDonation != null) ...[
//               _buildProfileItem(
//                 Icons.calendar_today,
//                 'Last Donation',
//                 DateFormat('MMMM d, y').format(lastDonation),
//               ),
//               _buildProfileItem(
//                 Icons.timelapse,
//                 'Days Since Last Donation',
//                 daysSinceLastDonation.toString(),
//               ),
//             ],
//             const SizedBox(height: 20),
//             Row(
//               children: [
//                 Chip(
//                   label: Text(
//                     donorData['isAvailable'] == true
//                         ? 'Available to donate'
//                         : 'Not currently available',
//                     style: const TextStyle(color: Colors.white),
//                   ),
//                   backgroundColor: donorData['isAvailable'] == true
//                       ? Colors.green
//                       : Colors.orange,
//                 ),
//                 const SizedBox(width: 10),
//                 if (daysSinceLastDonation != null)
//                   Chip(
//                     label: Text(
//                       isEligible ? 'Eligible' : 'Not eligible',
//                       style: const TextStyle(color: Colors.white),
//                     ),
//                     backgroundColor: isEligible ? Colors.green : Colors.red,
//                   ),
//               ],
//             ),
//             if (donorData['notes'] != null && donorData['notes'].isNotEmpty)
//               Padding(
//                 padding: const EdgeInsets.only(top: 16.0),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     const Text(
//                       'Additional Notes:',
//                       style: TextStyle(
//                         fontWeight: FontWeight.bold,
//                         fontSize: 16,
//                       ),
//                     ),
//                     Text(donorData['notes']),
//                   ],
//                 ),
//               ),
//           ],
//         ),
//       ),
//       floatingActionButton: donorData['phone'] != null
//           ? FloatingActionButton(
//               onPressed: () => _launchContact(donorData['phone']),
//               backgroundColor: Colors.red[700],
//               foregroundColor: Colors.white,
//               child: const Icon(Icons.call),
//             )
//           : null,
//     );
//   }

//   Widget _buildProfileItem(IconData icon, String label, String? value) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 8.0),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Icon(icon, color: Colors.red),
//           const SizedBox(width: 12),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   label,
//                   style: const TextStyle(
//                     fontWeight: FontWeight.bold,
//                     fontSize: 16,
//                   ),
//                 ),
//                 Text(value ?? 'Not provided'),
//                 const Divider(),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
