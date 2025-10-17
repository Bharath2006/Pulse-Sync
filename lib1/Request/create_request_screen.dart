import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

import '../Home/Home_screen.dart';
import '../blood_donation_utils.dart';

class CreateRequestScreen extends StatefulWidget {
  const CreateRequestScreen({super.key});

  @override
  State<CreateRequestScreen> createState() => _CreateRequestScreenState();
}

class _CreateRequestScreenState extends State<CreateRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _bloodGroupController = TextEditingController();
  final _unitsController = TextEditingController();
  final _hospitalController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime? _selectedDate;
  Position? _currentPosition;
  bool _isLoading = false;

  final List<String> _bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled')),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied')),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permissions are permanently denied'),
          ),
        );
        return;
      }

      _currentPosition = await Geolocator.getCurrentPosition();
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting location: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

// In create_request_screen.dart, update the _submitRequest method:
Future<void> _submitRequest() async {
  if (!_formKey.currentState!.validate()) return;
  if (_currentPosition == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please get your current location')),
    );
    return;
  }
  if (_selectedDate == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please select a date')),
    );
    return;
  }

  setState(() => _isLoading = true);
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');

    await FirebaseFirestore.instance.collection('requests').add({
      'userId': user.uid,
      'bloodGroup': _bloodGroupController.text,
      'units': int.parse(_unitsController.text),
      'hospital': _hospitalController.text.trim(),
      'notes': _notesController.text.trim(),
      'requiredDate': Timestamp.fromDate(_selectedDate!),
      'location': GeoPoint(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      ),
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'pending',
      // Add predicted demand
      'predictedDemand': await BloodDonationUtils.predictDemand(_bloodGroupController.text),
    });

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error creating request: ${e.toString()}')),
    );
  } finally {
    setState(() => _isLoading = false);
  }
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Blood Request')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              DropdownButtonFormField<String>(
                value: _bloodGroupController.text.isEmpty
                    ? null
                    : _bloodGroupController.text,
                items: _bloodGroups
                    .map(
                      (group) =>
                          DropdownMenuItem(value: group, child: Text(group)),
                    )
                    .toList(),
                onChanged: (value) => _bloodGroupController.text = value!,
                decoration: const InputDecoration(labelText: 'Blood Group'),
                validator: (value) {
                  if (value == null || value.isEmpty)
                    return 'Please select blood group';
                  return null;
                },
              ),
              TextFormField(
                controller: _unitsController,
                decoration: const InputDecoration(labelText: 'Units Needed'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty)
                    return 'Please enter units';
                  if (int.tryParse(value) == null)
                    return 'Please enter valid number';
                  return null;
                },
              ),
              TextFormField(
                controller: _hospitalController,
                decoration: const InputDecoration(
                  labelText: 'Hospital/Clinic Name',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty)
                    return 'Please enter hospital name';
                  return null;
                },
              ),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Additional Notes',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              ListTile(
                title: Text(
                  _selectedDate == null
                      ? 'Select Required Date'
                      : 'Date: ${_selectedDate!.toLocal().toString().split(' ')[0]}',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _selectDate(context),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: Text(
                  _currentPosition == null
                      ? 'Get Current Location'
                      : 'Location: ${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}',
                ),
                trailing: const Icon(Icons.location_on),
                onTap: _getCurrentLocation,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitRequest,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Submit Request'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
