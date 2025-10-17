import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../Donor/donation_history_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String userRole;

  const ProfileScreen({super.key, required this.userRole});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _bloodGroupController;
  late TextEditingController _phoneController;
  DateTime? _lastDonationDate;
  bool _isAvailable = true;
  bool _isLoading = false;
  bool _isEditing = false;
  Map<String, dynamic>? _userData;
  final user = FirebaseAuth.instance.currentUser;

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
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _bloodGroupController = TextEditingController();
    _phoneController = TextEditingController();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        setState(() {
          _userData = doc.data();
          _nameController.text = _userData?['name'] ?? '';
          _emailController.text = _userData?['email'] ?? '';
          _bloodGroupController.text = _userData?['bloodGroup'] ?? '';
          _phoneController.text = _userData?['phone'] ?? '';
          _isAvailable = _userData?['isAvailable'] ?? false;
          if (_userData?['lastDonation'] != null) {
            _lastDonationDate = (_userData?['lastDonation'] as Timestamp)
                .toDate();
          }
        });
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
            'name': _nameController.text.trim(),
            'bloodGroup': _bloodGroupController.text,
            'phone': _phoneController.text.trim(),
            'isAvailable': _isAvailable,
            'lastDonation': _lastDonationDate != null
                ? Timestamp.fromDate(_lastDonationDate!)
                : null,
          });

      setState(() {
        _isEditing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _lastDonationDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _userData == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (!_isEditing && widget.userRole == 'donor')
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Center(
                child: CircleAvatar(
                  radius: 50,
                  child: Text(
                    _nameController.text.isNotEmpty
                        ? _nameController.text[0].toUpperCase()
                        : '?',
                    style: const TextStyle(fontSize: 40),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                readOnly: !_isEditing,
                validator: (value) {
                  if (value == null || value.isEmpty)
                    return 'Please enter name';
                  return null;
                },
              ),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                readOnly: true,
              ),
              const SizedBox(height: 16),
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
                onChanged: _isEditing
                    ? (value) => _bloodGroupController.text = value!
                    : null,
                decoration: const InputDecoration(labelText: 'Blood Group'),
                validator: (value) {
                  if (value == null || value.isEmpty)
                    return 'Please select blood group';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone Number'),
                keyboardType: TextInputType.phone,
                readOnly: !_isEditing,
                validator: (value) {
                  if (value == null || value.isEmpty)
                    return 'Please enter phone number';
                  return null;
                },
              ),
              if (widget.userRole == 'donor') ...[
                const SizedBox(height: 16),
                ListTile(
                  title: Text(
                    _lastDonationDate == null
                        ? 'Last Donation: Never'
                        : 'Last Donation: ${DateFormat('yyyy-MM-dd').format(_lastDonationDate!)}',
                  ),
                  trailing: _isEditing
                      ? IconButton(
                          icon: const Icon(Icons.calendar_today),
                          onPressed: () => _selectDate(context),
                        )
                      : null,
                ),
                SwitchListTile(
                  title: const Text('Available to Donate'),
                  value: _isAvailable,
                  onChanged: _isEditing
                      ? (value) => setState(() => _isAvailable = value)
                      : null,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            CompletedDonationsScreen(userId: user!.uid),
                      ),
                    );
                  },
                  child: const Text('View Donation History'),
                ),
              ],
              if (_isEditing) ...[
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isLoading ? null : _updateProfile,
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Save Profile'),
                ),
                TextButton(
                  onPressed: () => setState(() => _isEditing = false),
                  child: const Text('Cancel'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
