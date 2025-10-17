import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import 'request_detail_screen.dart';

class RequestListScreen extends StatefulWidget {
  const RequestListScreen({super.key});

  @override
  State<RequestListScreen> createState() => _RequestListScreenState();
}

class _RequestListScreenState extends State<RequestListScreen> {
  List<DocumentSnapshot> _requests = [];
  bool _isLoading = true;
  bool _isDisposed = false;
  String? _userId;
  Position? _currentPosition;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  void _safeSetState(VoidCallback fn) {
    if (!_isDisposed && mounted) {
      setState(fn);
    }
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      _safeSetState(() {
        _userId = user.uid;
      });

      await _getCurrentLocation();
    } catch (e) {
      debugPrint('Error loading user data: $e');
      _safeSetState(() => _isLoading = false);
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      debugPrint('Location error: $e');
    }
  }

  Future<void> _fetchRequests() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('requests')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .get();

      _safeSetState(() {
        _requests = snapshot.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['respondedDonors'] != null &&
              data['respondedDonors'].contains(_userId)) {
            return false;
          }
          return true;
        }).toList();
      });
    } catch (e) {
      debugPrint('Error fetching requests: $e');
    } finally {
      _safeSetState(() => _isLoading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _loadUserData();
    await _fetchRequests();
  }

  Future<void> _refreshData() async {
    _safeSetState(() => _isLoading = true);
    await _fetchRequests();
  }

  double _calculateDistance(GeoPoint requestLocation) {
    if (_currentPosition == null) return -1;
    return Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          requestLocation.latitude,
          requestLocation.longitude,
        ) /
        1000; // Convert to km
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blood Requests'),
        backgroundColor: Colors.red[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.bloodtype, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No pending requests found',
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _refreshData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[700],
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _refreshData,
              color: Colors.red[700],
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: _requests.length,
                itemBuilder: (context, index) {
                  final request = _requests[index];
                  final data = request.data() as Map<String, dynamic>;
                  final requiredDate = (data['requiredDate'] as Timestamp)
                      .toDate();
                  final createdAt = (data['createdAt'] as Timestamp).toDate();
                  final location = data['location'] as GeoPoint;
                  final distance = _calculateDistance(location);

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: CircleAvatar(
                        backgroundColor: Colors.red[100],
                        child: Text(
                          data['bloodGroup'][0],
                          style: TextStyle(
                            color: Colors.red[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        '${data['bloodGroup']} - ${data['hospital']}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          Text('${data['units']} units needed'),
                          if (distance >= 0)
                            Text(
                              '${distance.toStringAsFixed(1)} km away',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          Text(
                            'Required by: ${DateFormat('MMMM d, y').format(requiredDate)}',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          Text(
                            'Posted: ${DateFormat('MMM d, h:mm a').format(createdAt)}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          if (data['notes'] != null && data['notes'].isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Notes: ${data['notes']}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.share, size: 20),
                            onPressed: () {
                              Share.share(
                                "Urgent blood needed!\nBlood Group: ${data['bloodGroup']}\n"
                                "Hospital: ${data['hospital']}\n"
                                "Required by: ${DateFormat('MMMM d, y').format(requiredDate)}\n"
                                "Please help via PulseSync app!",
                                subject:
                                    "Help Save a Life – Blood Donation Request",
                              );
                            },
                          ),
                          const Icon(Icons.arrow_forward, color: Colors.red),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RequestDetailScreen(
                              requestId: request.id,
                              requestData: data,
                              distance: distance,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
    );
  }
}