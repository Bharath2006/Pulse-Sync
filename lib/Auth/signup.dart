import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

import 'Login.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  String _selectedRole = 'donor';
  String? _selectedBloodGroup;
  String? _phoneNumber;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

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

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordController.text != _confirmPasswordController.text) {
      _showSnackBar('❌ Passwords do not match');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(credential.user!.uid)
          .set({
            'name': _nameController.text.trim(),
            'email': _emailController.text.trim(),
            'phone': _phoneNumber,
            'role': _selectedRole,
            'bloodGroup': _selectedBloodGroup,
            'createdAt': FieldValue.serverTimestamp(),
            'lastDonation': null,
            'isAvailable': true,
            'location': null,
          });

      _showSnackBar('✅ Registration successful! Please login');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } on FirebaseAuthException catch (e) {
      String msg = switch (e.code) {
        'weak-password' => '❗ Password is too weak',
        'email-already-in-use' => '❗ Email already in use',
        'invalid-email' => '❗ Invalid email address',
        _ => '❌ Registration failed',
      };
      _showSnackBar(msg);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = Colors.red.shade600;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: accentColor,
        title: const Text(
          'Create Account',
          style: TextStyle(color: Colors.white),
        ),
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 15),
              _buildTextField(
                controller: _nameController,
                label: 'Full Name',
                icon: Icons.person,
                validator: (val) => val == null || val.isEmpty
                    ? 'Enter name'
                    : (val.length < 3 ? 'Too short' : null),
              ),
              const SizedBox(height: 15),
              _buildTextField(
                controller: _emailController,
                label: 'Email',
                icon: Icons.email,
                keyboardType: TextInputType.emailAddress,
                validator: (val) =>
                    val == null ||
                        !RegExp(
                          r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                        ).hasMatch(val)
                    ? 'Enter valid email'
                    : null,
              ),
              const SizedBox(height: 15),
              IntlPhoneField(
                decoration: _inputDecoration('Phone Number'),
                initialCountryCode: 'IN',
                onChanged: (phone) => _phoneNumber = phone.completeNumber,
                validator: (phone) => (phone?.number.isEmpty ?? true)
                    ? 'Enter phone number'
                    : null,
              ),
              const SizedBox(height: 15),
              _buildPasswordField(
                controller: _passwordController,
                label: 'Password',
                obscure: _obscurePassword,
                toggle: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              const SizedBox(height: 15),
              _buildPasswordField(
                controller: _confirmPasswordController,
                label: 'Confirm Password',
                obscure: _obscureConfirmPassword,
                toggle: () => setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword,
                ),
              ),
              const SizedBox(height: 15),
              _buildDropdown(
                value: _selectedRole,
                items: ['donor', 'recipient'],
                label: 'Role',
                onChanged: (val) => setState(() => _selectedRole = val!),
              ),
              const SizedBox(height: 15),
              _buildDropdown(
                value: _selectedBloodGroup,
                items: _bloodGroups,
                label: 'Blood Group',
                onChanged: (val) => setState(() => _selectedBloodGroup = val),
                validator: (val) => val == null ? 'Select blood group' : null,
              ),
              const SizedBox(height: 25),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _register,
                icon: const Icon(Icons.person_add),
                label: Text(_isLoading ? 'Registering...' : 'Register'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 30,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
                child: const Text('Already have an account? Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon, color: Colors.red.shade400) : null,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: Colors.white,
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      decoration: _inputDecoration(label, icon: icon),
      validator: validator,
      keyboardType: keyboardType,
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback toggle,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      decoration: _inputDecoration(label, icon: Icons.lock).copyWith(
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
          onPressed: toggle,
        ),
      ),
      validator: (val) => val == null || val.isEmpty
          ? 'Enter password'
          : (val.length < 8 ? 'Minimum 8 characters' : null),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required List<String> items,
    required String label,
    void Function(String?)? onChanged,
    String? Function(String?)? validator,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: onChanged,
      validator: validator,
      decoration: _inputDecoration(label),
    );
  }
}
