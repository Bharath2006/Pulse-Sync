import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../Donor/pending_donations_screen.dart';
import '../Home/ai_chatbot_screen.dart';
import '../Donor/donation_history_screen.dart';
import '../Donor/donor_matching_screen.dart';
import '../Home/map_screen.dart';
import '../Request/RequestHistoryScreen.dart';
import '../Request/create_request_screen.dart';
import '../Request/request_list_screen.dart';
import '../admin/admin_dashboard.dart';
import '../profile/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _userRole = 'donor';
  String _userName = '';
  String _userId = '';
  int _currentIndex = 0;
  bool _isLoading = true;
  int _pendingRequestsCount = 0;
  int _donationHistoryCount = 0;
  final user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        setState(() {
          _userRole = doc.data()?['role'] ?? 'donor';
          _userName = doc.data()?['name'] ?? '';
          _userId = user.uid;
        });
        _loadPendingRequestsCount();
        _loadDonationHistoryCount();
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPendingRequestsCount() async {
    if (_userRole == 'recipient') {
      final snapshot = await FirebaseFirestore.instance
          .collection('requests')
          .where('userId', isEqualTo: _userId)
          .where('status', isEqualTo: 'pending')
          .get();

      setState(() => _pendingRequestsCount = snapshot.size);
    }
  }

  Future<void> _loadDonationHistoryCount() async {
    if (_userRole == 'donor') {
      final snapshot = await FirebaseFirestore.instance
          .collection('donations')
          .where('donorId', isEqualTo: _userId)
          .get();

      setState(() => _donationHistoryCount = snapshot.size);
    }
  }

  Widget _getRoleBasedHomeScreen() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    switch (_userRole) {
      case 'admin':
        return const AdminDashboard();
      case 'recipient':
        return RequestHistoryScreen(userId: _userId);
      case 'donor':
      default:
        return const RequestListScreen();
    }
  }

  Widget _getCurrentScreen() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    switch (_currentIndex) {
      case 0:
        return _getRoleBasedHomeScreen();
      case 1:
        return const MapScreen();
      case 2:
        return const AIChatbotScreen();
      case 3:
        return ProfileScreen(userRole: _userRole);
      default:
        return _getRoleBasedHomeScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, $_userName'),
        backgroundColor: Colors.red[700],
        foregroundColor: Colors.white,
        actions: [
          if (_userRole == 'donor')
            Badge(
              label: Text('$_donationHistoryCount'),
              child: IconButton(
                icon: const Icon(Icons.history),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          CompletedDonationsScreen(userId: _userId),
                    ),
                  ).then((_) => _loadDonationHistoryCount());
                },
                tooltip: 'Donation History',
              ),
            ),
          if (_userRole == 'recipient' && _pendingRequestsCount > 0)
            Badge(
              label: Text('$_pendingRequestsCount'),
              child: IconButton(
                icon: const Icon(Icons.notifications),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          RequestHistoryScreen(userId: _userId),
                    ),
                  ).then((_) => _loadPendingRequestsCount());
                },
                tooltip: 'Pending Requests',
              ),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacementNamed(context, '/login');
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _getCurrentScreen(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.red[700],
        unselectedItemColor: Colors.grey,
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          const BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
          const BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'AI Chat',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person),
            label: _userRole == 'admin' ? 'Admin' : 'Profile',
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? _userRole == 'recipient'
                ? FloatingActionButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CreateRequestScreen(),
                        ),
                      ).then((_) => _loadPendingRequestsCount());
                    },
                    backgroundColor: Colors.red[700],
                    child: const Icon(Icons.add, color: Colors.white),
                  )
                : FloatingActionButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              PendingDonationsScreen(userId: user!.uid),
                        ),
                      );
                    },
                    backgroundColor: Colors.red[700],
                    child: const Icon(Icons.bloodtype, color: Colors.white),
                  )
          : null,
    );
  }
}
