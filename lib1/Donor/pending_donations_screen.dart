import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class PendingDonationsScreen extends StatefulWidget {
  final String userId;

  const PendingDonationsScreen({super.key, required this.userId});

  @override
  State<PendingDonationsScreen> createState() => _PendingDonationsScreenState();
}

class _PendingDonationsScreenState extends State<PendingDonationsScreen> {
  bool _isLoading = true;
  List<DocumentSnapshot> _pendingDonations = [];
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadPendingDonations();
  }

  Future<void> _loadPendingDonations() async {
    try {
      setState(() => _isLoading = true);

      final snapshot = await FirebaseFirestore.instance
          .collection('donations')
          .where('donorId', isEqualTo: widget.userId)
          .where('status', whereIn: ['accepted', 'scheduled'])
          .orderBy('donationDate', descending: true)
          .get();

      setState(() {
        _pendingDonations = snapshot.docs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackbar('Error loading donations: ${e.toString()}');
    }
  }

  Future<void> _completeDonation(String donationId, String requestId) async {
    try {
      final batch = FirebaseFirestore.instance.batch();

      final donationRef = FirebaseFirestore.instance
          .collection('donations')
          .doc(donationId);

      batch.update(donationRef, {
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
      });

      if (requestId.isNotEmpty) {
        final requestRef = FirebaseFirestore.instance
            .collection('requests')
            .doc(requestId);

        batch.update(requestRef, {
          'status': 'completed',
          'completedAt': FieldValue.serverTimestamp(),
        });
      }

      if (_currentUser != null) {
        final donorRef = FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUser!.uid);

        batch.update(donorRef, {
          'lastDonation': FieldValue.serverTimestamp(),
          'isAvailable': false,
        });
      }

      await batch.commit();
      _showSuccessSnackbar('Donation marked as completed');
      await _loadPendingDonations();
    } catch (e) {
      _showErrorSnackbar('Error completing donation: ${e.toString()}');
    }
  }

  Future<void> _cancelDonation(String donationId, String requestId) async {
    try {
      final batch = FirebaseFirestore.instance.batch();

      final donationRef = FirebaseFirestore.instance
          .collection('donations')
          .doc(donationId);

      batch.update(donationRef, {
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });

      if (requestId.isNotEmpty) {
        final requestRef = FirebaseFirestore.instance
            .collection('requests')
            .doc(requestId);

        batch.update(requestRef, {
          'status': 'open',
          'matchedDonorId': FieldValue.delete(),
          'matchedAt': FieldValue.delete(),
        });
      }

      if (_currentUser != null) {
        final donorRef = FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUser!.uid);

        batch.update(donorRef, {'isAvailable': true});
      }

      await batch.commit();
      _showSuccessSnackbar('Donation cancelled');
      await _loadPendingDonations();
    } catch (e) {
      _showErrorSnackbar('Error cancelling donation: ${e.toString()}');
    }
  }

  Future<void> _openMap(double latitude, double longitude) async {
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      _showErrorSnackbar('Could not launch maps');
    }
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Widget _buildStatusChip(String status) {
    Color? backgroundColor;
    String label;

    switch (status) {
      case 'accepted':
        backgroundColor = Colors.blue[700];
        label = 'ACCEPTED';
        break;
      case 'scheduled':
        backgroundColor = Colors.orange[700];
        label = 'SCHEDULED';
        break;
      default:
        backgroundColor = Colors.grey;
        label = status.toUpperCase();
    }

    return Chip(
      label: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      backgroundColor: backgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Donations'),
        backgroundColor: Colors.red[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPendingDonations,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pendingDonations.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.bloodtype, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No pending donations',
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _loadPendingDonations,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[700],
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Refresh'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadPendingDonations,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _pendingDonations.length,
                itemBuilder: (context, index) {
                  final donation = _pendingDonations[index];
                  final data = donation.data() as Map<String, dynamic>;
                  final donationDate = (data['donationDate'] as Timestamp)
                      .toDate();
                  final requestId = data['requestId'] ?? '';
                  final status = data['status'] ?? 'accepted';
                  final location = data['location'] as GeoPoint?;
                  final hospital = data['hospital'] ?? 'Not specified';
                  final locationName = data['locationName'] ?? '';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
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
                                '${data['bloodGroup']} - ${data['units']} unit(s)',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              _buildStatusChip(status),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Hospital: $hospital',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Date: ${DateFormat('MMMM d, y - hh:mm a').format(donationDate)}',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          if (location != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                children: [
                                  Text(
                                    'Location: ${locationName.isNotEmpty ? locationName : 'View on map'}',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.location_on,
                                      color: Colors.red,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => _openMap(
                                      location.latitude,
                                      location.longitude,
                                    ),
                                    tooltip: 'Open in Maps',
                                  ),
                                ],
                              ),
                            ),
                          if (data['notes'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Notes: ${data['notes']}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () =>
                                      _cancelDonation(donation.id, requestId),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red[700],
                                    side: BorderSide(color: Colors.red[700]!),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                  child: const Text('Cancel'),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () =>
                                      _completeDonation(donation.id, requestId),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                  child: const Text('Complete'),
                                ),
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
    );
  }
}
