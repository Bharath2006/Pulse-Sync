import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final List<String> _timePeriods = ['Last Week', 'Last Month', 'Last Year'];
  String _selectedPeriod = 'Last Month';
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Reports',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.redAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedPeriod,
                  items: _timePeriods
                      .map(
                        (period) => DropdownMenuItem(
                          value: period,
                          child: Text(
                            period,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedPeriod = value);
                    }
                  },
                  underline: SizedBox(),
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    children: [
                      _buildBloodGroupChart(),
                      const SizedBox(height: 24),
                      _buildRequestStatusChart(),
                      const SizedBox(height: 24),
                      _buildDonationStats(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBloodGroupChart() {
    return FutureBuilder<QuerySnapshot>(
      future: _getRequestsForPeriod(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final requests = snapshot.data!.docs;
        final bloodGroupCounts = <String, int>{};

        for (var request in requests) {
          final data = request.data() as Map<String, dynamic>;
          final bloodGroup = data['bloodGroup'] as String;
          bloodGroupCounts[bloodGroup] =
              (bloodGroupCounts[bloodGroup] ?? 0) + 1;
        }

        final barGroups = bloodGroupCounts.entries.toList().asMap().entries.map(
          (entry) {
            final index = entry.key;
            final e = entry.value;
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: e.value.toDouble(),
                  color: Colors.redAccent,
                ),
              ],
              showingTooltipIndicators: [0],
            );
          },
        ).toList();

        final titles = bloodGroupCounts.keys.toList();

        return Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.all(8),
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Requests by Blood Group',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 250,
                  child: BarChart(
                    BarChartData(
                      barGroups: barGroups,
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= titles.length)
                                return Container();
                              return Text(
                                titles[index],
                                style: const TextStyle(fontSize: 12),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: true),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRequestStatusChart() {
    return FutureBuilder<QuerySnapshot>(
      future: _getRequestsForPeriod(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final requests = snapshot.data!.docs;
        final statusCounts = <String, int>{};

        for (var request in requests) {
          final status = request['status'] as String;
          statusCounts[status] = (statusCounts[status] ?? 0) + 1;
        }

        final colors = [Colors.green, Colors.red, Colors.orange, Colors.blue];

        final sections = statusCounts.entries.toList().asMap().entries.map((
          entry,
        ) {
          final index = entry.key;
          final e = entry.value;
          return PieChartSectionData(
            color: colors[index % colors.length],
            value: e.value.toDouble(),
            title: '${e.key}: ${e.value}',
            radius: 60,
            titleStyle: const TextStyle(fontSize: 12, color: Colors.white),
          );
        }).toList();

        return Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.all(8),
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Request Status Distribution',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 250,
                  child: PieChart(
                    PieChartData(
                      sections: sections,
                      centerSpaceRadius: 30,
                      sectionsSpace: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDonationStats() {
    return FutureBuilder<QuerySnapshot>(
      future: _getDonationsForPeriod(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final donations = snapshot.data!.docs;
        final totalUnits = donations.fold<int>(
          0,
          (sum, doc) => sum + (doc['units'] as int),
        );

        return Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.all(8),
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Donation Statistics',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatCard(
                      'Total Donations',
                      donations.length.toString(),
                    ),
                    _buildStatCard('Total Units', totalUnits.toString()),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Future<QuerySnapshot> _getRequestsForPeriod() async {
    DateTime startDate;
    final now = DateTime.now();

    switch (_selectedPeriod) {
      case 'Last Week':
        startDate = now.subtract(const Duration(days: 7));
        break;
      case 'Last Year':
        startDate = DateTime(now.year - 1, now.month, now.day);
        break;
      case 'Last Month':
      default:
        startDate = DateTime(now.year, now.month - 1, now.day);
        break;
    }

    return FirebaseFirestore.instance
        .collection('requests')
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        )
        .get();
  }

  Future<QuerySnapshot> _getDonationsForPeriod() async {
    DateTime startDate;
    final now = DateTime.now();

    switch (_selectedPeriod) {
      case 'Last Week':
        startDate = now.subtract(const Duration(days: 7));
        break;
      case 'Last Year':
        startDate = DateTime(now.year - 1, now.month, now.day);
        break;
      case 'Last Month':
      default:
        startDate = DateTime(now.year, now.month - 1, now.day);
        break;
    }

    return FirebaseFirestore.instance
        .collection('donations')
        .where(
          'donationDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        )
        .get();
  }
}

class _ChartData {
  final String label;
  final int value;

  _ChartData(this.label, this.value);
}
