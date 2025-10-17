import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class CompletedDonationsScreen extends StatefulWidget {
  final String userId;

  const CompletedDonationsScreen({super.key, required this.userId});

  @override
  State<CompletedDonationsScreen> createState() =>
      _CompletedDonationsScreenState();
}

class _CompletedDonationsScreenState extends State<CompletedDonationsScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDonations();
  }

  Future<void> _loadDonations() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 300));
    setState(() => _isLoading = false);
  }

  Future<void> _openMap(double? latitude, double? longitude) async {
    if (latitude == null || longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location data not available')),
      );
      return;
    }

    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not launch maps')));
    }
  }

  void _showDonationDetails(BuildContext context, Map<String, dynamic> data) {
    final donationDate = (data['donationDate'] as Timestamp).toDate();
    final location = data['location'] as GeoPoint?;
    final locationName = data['locationName'] ?? 'Unknown location';
    final notes = data['notes'] ?? 'No additional notes';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Added to prevent overflow
      builder: (context) {
        return SingleChildScrollView(
          // Wrapped in SingleChildScrollView
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Donation Details',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Divider(),
                _buildDetailRow(
                  Icons.bloodtype,
                  'Blood Group: ${data['bloodGroup'] ?? 'Unknown'}',
                ),
                _buildDetailRow(
                  Icons.water_drop,
                  'Units: ${data['units'] ?? 0}',
                ),
                _buildDetailRow(
                  Icons.calendar_today,
                  'Date: ${DateFormat('MMMM d, y').format(donationDate)}',
                ),
                GestureDetector(
                  onTap: () =>
                      _openMap(location?.latitude, location?.longitude),
                  child: _buildDetailRow(
                    Icons.location_on,
                    'Location: $locationName',
                    isClickable: location != null,
                  ),
                ),
                if (notes.isNotEmpty)
                  _buildDetailRow(Icons.notes, 'Notes: $notes'),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String text, {
    bool isClickable = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.red[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isClickable ? Colors.blue : Colors.black87,
                decoration: isClickable ? TextDecoration.underline : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Completed Donations'),
        backgroundColor: Colors.red[700],
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('donations')
            .where('donorId', isEqualTo: widget.userId)
            .where('status', isEqualTo: 'completed')
            .orderBy('donationDate', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (_isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'Error loading donations',
                    style: TextStyle(fontSize: 18),
                  ),
                  Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.bloodtype, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No completed donations',
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your completed donations will appear here',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          final donations = snapshot.data!.docs;
          final totalUnits = donations.fold<double>(
            0,
            (sum, doc) =>
                sum +
                ((doc.data() as Map<String, dynamic>)['units'] as num)
                    .toDouble(),
          );

          return Column(
            children: [
              Card(
                margin: const EdgeInsets.all(16),
                color: Colors.red[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Icon(
                            Icons.bloodtype,
                            size: 32,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            donations.length.toString(),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                          const Text(
                            'Total Donations',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          const Icon(
                            Icons.water_drop,
                            size: 32,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            totalUnits.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                          const Text(
                            'Total Units',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: donations.length,
                  itemBuilder: (context, index) {
                    final donation = donations[index];
                    final data = donation.data() as Map<String, dynamic>;
                    final donationDate = (data['donationDate'] as Timestamp)
                        .toDate();
                    final bloodGroup = data['bloodGroup'] ?? 'Unknown';
                    final units = data['units'] ?? 0;
                    final locationName =
                        data['locationName'] ?? 'Unknown location';
                    final location = data['location'] as GeoPoint?;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '$bloodGroup - $units unit(s)',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.info_outline),
                                  onPressed: () =>
                                      _showDonationDetails(context, data),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  tooltip: 'View Details',
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Date: ${DateFormat('MMMM d, y').format(donationDate)}',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Location: $locationName',
                                    style: TextStyle(color: Colors.grey[600]),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (location != null)
                                  IconButton(
                                    icon: const Icon(Icons.map, size: 20),
                                    onPressed: () => _openMap(
                                      location.latitude,
                                      location.longitude,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    tooltip: 'Open in Maps',
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
