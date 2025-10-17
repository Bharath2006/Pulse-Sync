import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../Home/Home_screen.dart';
import '../blood_donation_utils.dart';

class CreateRequestScreen extends StatefulWidget {
  const CreateRequestScreen({super.key});

  @override
  State<CreateRequestScreen> createState() => _CreateRequestScreenState();
}

class _CreateRequestScreenState extends State<CreateRequestScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _bloodGroupController = TextEditingController();
  final _unitsController = TextEditingController();
  final _hospitalController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime? _selectedDate;
  Position? _currentPosition;
  bool _isLoading = false;
  String _availabilityMessage = '';
  AnimationController? _animationController;
  Animation<double>? _fadeAnimation;

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

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController!,
      curve: Curves.easeIn,
    );
    _animationController!.forward();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnack('Location services are disabled');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnack('Location permissions are denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showSnack('Location permissions are permanently denied');
        return;
      }

      _currentPosition = await Geolocator.getCurrentPosition();
      setState(() {});
    } catch (e) {
      _showSnack('Error getting location: $e');
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

  Future<void> _checkAvailability() async {
    final bloodGroup = _bloodGroupController.text;
    if (bloodGroup.isEmpty) return;

    final predicted = await BloodDonationUtils.predictDemand(bloodGroup);
    final snapshot = await FirebaseFirestore.instance
        .collection('inventory')
        .doc(bloodGroup)
        .get();

    final inventory = snapshot.exists ? (snapshot.data()?['units'] ?? 0) : 0;
    String msg = '';

    if (inventory >= predicted) {
      msg = '🟢 Sufficient inventory available for $bloodGroup';
    } else if (inventory > 0) {
      msg = '🟡 Limited stock available. High demand!';
    } else {
      msg = '🔴 Out of stock. Try another group.';
    }

    setState(() => _availabilityMessage = msg);
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (_currentPosition == null) return _showSnack('Get your location first');
    if (_selectedDate == null) return _showSnack('Select required date');

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      final bloodGroup = _bloodGroupController.text;
      final demand = await BloodDonationUtils.predictDemand(bloodGroup);

      await FirebaseFirestore.instance.collection('requests').add({
        'userId': user.uid,
        'bloodGroup': bloodGroup,
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
        'predictedDemand': demand,
      });

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      _showSnack('Error creating request: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _animationController?.dispose();
    _bloodGroupController.dispose();
    _unitsController.dispose();
    _hospitalController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('🩸 Blood Request'),
        backgroundColor: Colors.redAccent,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation!,
        child: Padding(
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
                        (group) => DropdownMenuItem(
                          value: group,
                          child: Text(
                            group,
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (val) async {
                    _bloodGroupController.text = val!;
                    await _checkAvailability();
                  },
                  decoration: const InputDecoration(
                    labelText: 'Blood Group',
                    prefixIcon: Icon(Icons.water_drop),
                  ),
                  validator: (val) =>
                      val == null ? 'Please select blood group' : null,
                ),
                if (_availabilityMessage.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _availabilityMessage,
                    style: TextStyle(
                      color: _availabilityMessage.contains('🟢')
                          ? Colors.green
                          : _availabilityMessage.contains('🟡')
                          ? Colors.orange
                          : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                TextFormField(
                  controller: _unitsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Units Needed',
                    prefixIcon: Icon(Icons.bloodtype),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Enter units';
                    if (int.tryParse(val) == null) return 'Invalid number';
                    return null;
                  },
                ),
                TextFormField(
                  controller: _hospitalController,
                  decoration: const InputDecoration(
                    labelText: 'Hospital / Clinic',
                    prefixIcon: Icon(Icons.local_hospital),
                  ),
                  validator: (val) =>
                      val == null || val.isEmpty ? 'Enter hospital name' : null,
                ),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Additional Notes',
                    prefixIcon: Icon(Icons.notes),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: Text(
                    _selectedDate == null
                        ? 'Select Required Date'
                        : 'Date: ${DateFormat('yyyy-MM-dd').format(_selectedDate!)}',
                    style: theme.textTheme.bodyLarge,
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () => _selectDate(context),
                ),
                ListTile(
                  title: Text(
                    _currentPosition == null
                        ? 'Get Current Location'
                        : 'Location: ${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}',
                    style: theme.textTheme.bodyLarge,
                  ),
                  trailing: const Icon(Icons.location_on),
                  onTap: _getCurrentLocation,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submitRequest,
                  icon: const Icon(Icons.send),
                  label: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Submit Request'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
