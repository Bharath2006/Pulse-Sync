import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class RequestDetailScreen extends StatefulWidget {
  final String requestId;
  final Map<String, dynamic> requestData;
  final double distance;

  const RequestDetailScreen({
    super.key,
    required this.requestId,
    required this.requestData,
    required this.distance,
  });

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  bool _isResponding = false;
  bool _isRequestFulfilled = false;

  @override
  void initState() {
    super.initState();
    _isRequestFulfilled = widget.requestData['status'] == 'matched';
  }

  Future<void> _respondToRequest(BuildContext context, bool canDonate) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isResponding = true);

    try {
      final requestRef = FirebaseFirestore.instance
          .collection('requests')
          .doc(widget.requestId);

      // Check request availability
      final doc = await requestRef.get();
      if (!doc.exists || doc['status'] != 'pending') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request no longer available')),
        );
        return;
      }

      // Start Firestore batch for atomic operations
      final batch = FirebaseFirestore.instance.batch();

      // Update request
      batch.update(requestRef, {
        'status': canDonate ? 'matched' : 'pending',
        'respondedDonors': FieldValue.arrayUnion([user.uid]),
        if (canDonate) 'matchedDonorId': user.uid,
        if (canDonate) 'matchedAt': FieldValue.serverTimestamp(),
      });

      // Create donation record if donating
      if (canDonate) {
        final donationRef = FirebaseFirestore.instance
            .collection('donations')
            .doc(); // Auto-generated ID

        batch.set(donationRef, {
          'donorId': user.uid,
          'recipientId': widget.requestData['userId'],
          'requestId': widget.requestId,
          'bloodGroup': widget.requestData['bloodGroup'],
          'units': widget.requestData['units'],
          'hospital': widget.requestData['hospital'],
          'location': widget.requestData['location'],
          'donationDate': FieldValue.serverTimestamp(),
          'status': 'scheduled', // or 'completed' if confirmed immediately
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Also update donor's last donation date
        final donorRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid);

        batch.update(donorRef, {
          'lastDonation': FieldValue.serverTimestamp(),
          'isAvailable': false, // Mark as unavailable after donation
        });
      }

      await batch.commit();

      if (canDonate) {
        setState(() => _isRequestFulfilled = true);
        await _contactRecipient(context);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _isResponding = false);
    }
  }

  Future<void> _contactRecipient(BuildContext context) async {
    try {
      final recipient = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.requestData['userId'])
          .get();

      final recipientData = recipient.data();
      final phone = recipientData?['phone'];
      final name = recipientData?['name'] ?? 'Recipient';

      if (phone == null) {
        throw Exception('No contact information available');
      }

      final url = Uri.parse('tel:$phone');
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        throw Exception('Could not launch phone call');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Contact failed: ${e.toString()}')),
        );
      }
    }
  }

  Widget _buildActionButtons() {
    if (_isRequestFulfilled) {
      return Chip(
        label: const Text('Request Fulfilled'),
        backgroundColor: Colors.green[100],
        side: BorderSide.none,
        labelStyle: const TextStyle(color: Colors.green),
        avatar: const Icon(Icons.check_circle, color: Colors.green),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      );
    }

    return Column(
      children: [
        if (_isResponding) const LinearProgressIndicator(),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red[700],
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: Colors.red[700]!),
                ),
                onPressed: _isResponding
                    ? null
                    : () => _respondToRequest(context, false),
                icon: const Icon(Icons.close),
                label: const Text('Cannot Donate'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _isResponding
                    ? null
                    : () => _respondToRequest(context, true),
                icon: const Icon(Icons.bloodtype),
                label: const Text('I Can Donate'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final requiredDate = (widget.requestData['requiredDate'] as Timestamp)
        .toDate();
    final createdAt = (widget.requestData['createdAt'] as Timestamp).toDate();
    final location = widget.requestData['location'] as GeoPoint;
    final bloodGroup = widget.requestData['bloodGroup'] ?? 'Unknown';
    final hospital = widget.requestData['hospital'] ?? 'Not specified';
    final units = widget.requestData['units']?.toString() ?? 'Not specified';
    final notes = widget.requestData['notes'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Details'),
        backgroundColor: Colors.red[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.map),
            tooltip: 'Open in Maps',
            onPressed: () {
              final url = Uri.parse(
                'https://www.google.com/maps/search/?api=1&query=${location.latitude},${location.longitude}',
              );
              launchUrl(url);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$bloodGroup Blood Needed',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.red[700],
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildDetailItem(Icons.local_hospital, 'Hospital/Clinic', hospital),
            _buildDetailItem(Icons.bloodtype, 'Units Required', units),
            _buildDetailItem(
              Icons.calendar_today,
              'Required By',
              DateFormat('MMMM d, y').format(requiredDate),
            ),
            if (widget.distance >= 0)
              _buildDetailItem(
                Icons.directions,
                'Distance',
                '${widget.distance.toStringAsFixed(1)} km',
              ),
            _buildDetailItem(
              Icons.location_on,
              'Location',
              '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}',
            ),
            _buildDetailItem(
              Icons.access_time,
              'Posted',
              DateFormat('MMMM d, y - hh:mm a').format(createdAt),
            ),
            if (notes != null && notes.isNotEmpty)
              _buildDetailItem(Icons.notes, 'Additional Notes', notes),
            const SizedBox(height: 24),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.red[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
                const Divider(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
