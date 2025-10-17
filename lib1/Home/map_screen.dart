import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  final Set<Marker> _markers = {};
  bool _isLoading = true;
  bool _locationError = false;
  bool _locationServiceEnabled = false;
  LocationPermission? _locationPermission;
  Timer? _locationUpdateTimer;
  StreamSubscription<Position>? _positionStream;

  @override
  void initState() {
    super.initState();
    _initializeMap();
    _startPeriodicLocationUpdates();
  }

  @override
  void dispose() {
    _locationUpdateTimer?.cancel();
    _positionStream?.cancel();
    super.dispose();
  }

  Future<void> _initializeMap() async {
    try {
      await _checkLocationServices();
      await _checkLocationPermissions();
      await _getCurrentLocation();
      await _loadBloodBanks();
      _startPositionUpdates();
    } catch (e) {
      setState(() {
        _locationError = true;
        _isLoading = false;
      });
    }
  }

  void _startPeriodicLocationUpdates() {
    // Initial update
    _updateDonorLocations();

    // Periodic updates every 10 minutes
    _locationUpdateTimer = Timer.periodic(const Duration(minutes: 10), (timer) {
      _updateDonorLocations();
    });
  }

  void _startPositionUpdates() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 100, // Update when moved 100 meters
    );

    _positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
            setState(() {
              _currentPosition = position;
              // Update current location marker
              _markers.removeWhere(
                (marker) => marker.markerId.value == 'current_location',
              );
              _markers.add(
                Marker(
                  markerId: const MarkerId('current_location'),
                  position: LatLng(position.latitude, position.longitude),
                  infoWindow: const InfoWindow(title: 'Your Location'),
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueBlue,
                  ),
                ),
              );
            });
          },
        );
  }

  Future<void> _updateDonorLocations() async {
    try {
      await _loadNearbyDonors();
      if (_mapController != null && _currentPosition != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLng(
            LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error updating donor locations: $e');
    }
  }

  Future<void> _checkLocationServices() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    setState(() => _locationServiceEnabled = serviceEnabled);

    if (!serviceEnabled) {
      throw Exception('Location services are disabled');
    }
  }

  Future<void> _checkLocationPermissions() async {
    var status = await Permission.location.status;

    if (status.isDenied) {
      status = await Permission.location.request();
    }

    if (status.isPermanentlyDenied) {
      await openAppSettings();
      throw Exception('Location permissions are permanently denied');
    }

    if (!status.isGranted) {
      throw Exception('Location permissions are denied');
    }

    final permission = await Geolocator.checkPermission();
    setState(() => _locationPermission = permission);
  }

  Future<void> _getCurrentLocation() async {
    try {
      if (!_locationServiceEnabled ||
          _locationPermission == LocationPermission.denied ||
          _locationPermission == LocationPermission.deniedForever) {
        throw Exception('Location services not available');
      }

      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _markers.add(
          Marker(
            markerId: const MarkerId('current_location'),
            position: LatLng(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
            ),
            infoWindow: const InfoWindow(title: 'Your Location'),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueBlue,
            ),
          ),
        );
      });
    } catch (e) {
      _currentPosition = Position(
        latitude: 0,
        longitude: 0,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      );
      rethrow;
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadBloodBanks() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('blood_banks')
          .get();

      setState(() {
        _markers.addAll(
          snapshot.docs.map((doc) {
            final data = doc.data();
            final location = data['location'] as GeoPoint;
            return Marker(
              markerId: MarkerId(doc.id),
              position: LatLng(location.latitude, location.longitude),
              infoWindow: InfoWindow(
                title: data['name'],
                snippet: data['address'],
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueRed,
              ),
            );
          }),
        );
      });
    } catch (e) {
      debugPrint('Error loading blood banks: $e');
    }
  }

  Future<void> _loadNearbyDonors() async {
    if (_currentPosition == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'donor')
          .where('isAvailable', isEqualTo: true)
          .get();

      setState(() {
        _markers.removeWhere(
          (marker) => marker.markerId.value.startsWith('donor_'),
        );

        _markers.addAll(
          snapshot.docs
              .where((doc) {
                final data = doc.data();
                if (data['location'] == null) return false;
                final location = data['location'] as GeoPoint;
                final distance = Geolocator.distanceBetween(
                  _currentPosition!.latitude,
                  _currentPosition!.longitude,
                  location.latitude,
                  location.longitude,
                );
                return distance <= 10000; // Within 10km
              })
              .map((doc) {
                final data = doc.data();
                final location = data['location'] as GeoPoint;
                return Marker(
                  markerId: MarkerId('donor_${doc.id}'),
                  position: LatLng(location.latitude, location.longitude),
                  infoWindow: InfoWindow(
                    title: data['name'],
                    snippet: 'Blood Group: ${data['bloodGroup']}',
                  ),
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueGreen,
                  ),
                );
              }),
        );
      });
    } catch (e) {
      debugPrint('Error loading nearby donors: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blood Banks & Donors Map'),
        backgroundColor: Colors.red[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _updateDonorLocations,
            tooltip: 'Refresh Map',
          ),
        ],
      ),
      body: _locationError
          ? _buildErrorWidget()
          : _isLoading
          ? const Center(child: CircularProgressIndicator())
          : GoogleMap(
              onMapCreated: (controller) => _mapController = controller,
              initialCameraPosition: CameraPosition(
                target: LatLng(
                  _currentPosition?.latitude ?? 0,
                  _currentPosition?.longitude ?? 0,
                ),
                zoom: 12,
              ),
              markers: _markers,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
            ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: _loadNearbyDonors,
            tooltip: 'Find Donors',
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            child: const Icon(Icons.people),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            onPressed: _loadBloodBanks,
            tooltip: 'Find Blood Banks',
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            child: const Icon(Icons.local_hospital),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            _locationServiceEnabled
                ? 'Location permission required'
                : 'Location services disabled',
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            _locationServiceEnabled
                ? 'Please enable location permissions in app settings'
                : 'Please enable location services on your device',
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _initializeMap,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
            ),
            child: const Text('Try Again'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: openAppSettings,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[700],
              foregroundColor: Colors.white,
            ),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}
