import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManageInventoryScreen extends StatefulWidget {
  const ManageInventoryScreen({super.key});

  @override
  State<ManageInventoryScreen> createState() => _ManageInventoryScreenState();
}

class _ManageInventoryScreenState extends State<ManageInventoryScreen> {
  final List<String> _bloodGroups = [
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Blood Inventory')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('inventory').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final inventory = snapshot.data!.docs;
          final inventoryMap = {
            for (var item in inventory) 
              item.id: item['units'] as int
          };

          return ListView.builder(
            itemCount: _bloodGroups.length,
            itemBuilder: (context, index) {
              final bloodGroup = _bloodGroups[index];
              final units = inventoryMap[bloodGroup] ?? 0;

              return Card(
                child: ListTile(
                  title: Text(bloodGroup),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove),
                        onPressed: () => _updateInventory(bloodGroup, -1),
                      ),
                      Text('$units'),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () => _updateInventory(bloodGroup, 1),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _updateInventory(String bloodGroup, int change) async {
    await FirebaseFirestore.instance
        .collection('inventory')
        .doc(bloodGroup)
        .set({
          'units': FieldValue.increment(change),
        }, SetOptions(merge: true));
  }
}