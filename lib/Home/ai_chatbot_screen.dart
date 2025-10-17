import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

import '../blood_donation_utils.dart';

class AIChatbotScreen extends StatefulWidget {
  const AIChatbotScreen({super.key});
  @override
  State createState() => _AIChatbotScreenState();
}

class _AIChatbotScreenState extends State<AIChatbotScreen> {
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  final List<String> _catalog = [
    "Who can donate blood?",
    "When can I donate next?",
    "Predict demand for A+",
    "Predict demand for B+",
    "Predict demand for O+",
    "Predict demand for AB+",
    "Predict demand for A-",
    "Predict demand for B-",
    "Predict demand for O-",
    "Predict demand for AB-",
    "Find best donors for A+",
    "Find best donors for B+",
    "Find best donors for O+",
    "Find best donors for AB+",
    "Find best donors for A-",
    "Find best donors for B-",
    "Find best donors for O-",
    "Find best donors for AB-",
    "Which blood groups are in high demand?",
    "How often can I donate blood?",
    "What are the health benefits of donating blood?",
    "Is blood donation safe?",
    "What to eat before donating blood?",
    "What to do after blood donation?",
    "Can I donate blood if I have a tattoo?",
    "Can women donate blood during periods?",
    "Who should not donate blood?",
    "Minimum weight to donate blood?",
    "Can I donate if I take medications?",
    "Age limit for blood donation?",
    "Can diabetic patients donate blood?",
    "Can blood donation cause weakness?",
    "How long does donation take?",
    "Can smokers donate blood?",
    "What tests are done on donated blood?",
    "Can I donate plasma separately?",
    "Can I donate blood if I had COVID-19?",
    "Benefits of regular donation?",
    "What are rare blood groups?",
    "Why is O- called universal donor?",
    "Check current blood inventory levels",
    "Which blood groups are critically low?",
  ];

  Future<void> _handlePreText(String text) async {
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isLoading = true;
    });

    String botReply = "Processing...";

    try {
      final lowerText = text.toLowerCase();

      if (lowerText.contains("predict demand for")) {
        final bloodGroup = text.split("for").last.trim().toUpperCase();
        final demand = await BloodDonationUtils.predictDemand(bloodGroup);
        final inventory = await _getInventoryLevel(bloodGroup);

        String inventoryStatus = "🟢 Normal";
        if (inventory < demand * 0.3) {
          inventoryStatus = "🔴 Critical";
        } else if (inventory < demand * 0.6) {
          inventoryStatus = "🟡 Low";
        }

        botReply =
            """
📊 **$bloodGroup Blood Demand Prediction**
        
- **Weekly demand estimate:** $demand units
- **Current inventory:** $inventory units
- **Inventory status:** $inventoryStatus

${_getInventoryAdvice(inventory, demand, bloodGroup)}
""";
      } else if (lowerText.contains("high demand") ||
          lowerText.contains("critically low")) {
        botReply = await _getHighDemandGroups();
      } else if (lowerText.contains("find best donors for")) {
        final bloodGroup = text.split("for").last.trim().toUpperCase();
        const dummyLocation = GeoPoint(12.9716, 77.5946);
        final donors = await BloodDonationUtils.findBestDonors(
          bloodGroup,
          dummyLocation,
          DateTime.now().add(const Duration(days: 2)),
        );
        botReply = donors.isEmpty
            ? "❌ No donors found nearby for $bloodGroup."
            : "✅ Found **${donors.length}** eligible donors for $bloodGroup within 50km radius.";
      } else if (lowerText.contains("inventory level")) {
        botReply = await _getAllInventoryLevels();
      } else {
        botReply = _staticReply(lowerText);
      }

      setState(() {
        _messages.add(ChatMessage(text: botReply, isUser: false));
      });
    } catch (e) {
      setState(() {
        _messages.add(
          ChatMessage(text: "⚠️ Error: ${e.toString()}", isUser: false),
        );
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<int> _getInventoryLevel(String bloodGroup) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('inventory')
          .doc(bloodGroup)
          .get();
      return snapshot.exists ? (snapshot.data()?['units'] ?? 0) : 0;
    } catch (e) {
      return 0;
    }
  }

  Future<String> _getAllInventoryLevels() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('inventory')
          .get();

      if (snapshot.docs.isEmpty) {
        return "No inventory data available";
      }

      String result = "🩸 **Current Blood Inventory Levels**\n\n";
      final groups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

      for (final group in groups) {
        final doc = snapshot.docs.firstWhere(
          (doc) => doc.id == group,
          orElse: () => snapshot.docs.first,
        );
        final units = doc.data()['units'] ?? 0;
        final demand = await BloodDonationUtils.predictDemand(group);

        String status = "🟢";
        if (units < demand * 0.3) {
          status = "🔴";
        } else if (units < demand * 0.6) {
          status = "🟡";
        }

        result += "- $group: $units units $status\n";
      }

      return result;
    } catch (e) {
      return "Error fetching inventory levels";
    }
  }

  Future<String> _getHighDemandGroups() async {
    try {
      final groups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
      final List<Map<String, dynamic>> groupData = [];

      for (final group in groups) {
        final demand = await BloodDonationUtils.predictDemand(group);
        final inventory = await _getInventoryLevel(group);
        final ratio = inventory / demand;
        groupData.add({
          'group': group,
          'demand': demand,
          'inventory': inventory,
          'ratio': ratio,
        });
      }

      // Sort by inventory/demand ratio (lowest first)
      groupData.sort((a, b) => a['ratio'].compareTo(b['ratio']));

      String result = "🆘 **High Demand Blood Groups**\n\n";
      result += "Groups with lowest inventory relative to demand:\n\n";

      for (int i = 0; i < 3 && i < groupData.length; i++) {
        final data = groupData[i];
        result += "🔸 **${data['group']}**:\n";
        result += "   - Weekly demand: ${data['demand']} units\n";
        result += "   - Current inventory: ${data['inventory']} units\n";
        result +=
            "   - Coverage: ${(data['ratio'] * 100).toStringAsFixed(1)}%\n\n";
      }

      return result;
    } catch (e) {
      return "Error determining high demand groups";
    }
  }

  String _getInventoryAdvice(int inventory, int demand, String bloodGroup) {
    if (inventory < demand * 0.3) {
      return "🚨 **Urgent Need**: $bloodGroup blood is critically low! Please encourage donations immediately.";
    } else if (inventory < demand * 0.6) {
      return "⚠️ **Attention Needed**: $bloodGroup inventory is below recommended levels. Consider organizing a donation drive.";
    } else if (inventory > demand * 1.5) {
      return "✅ **Good Supply**: $bloodGroup inventory is at healthy levels. Maintain regular donation schedule.";
    } else {
      return "🟢 **Stable**: $bloodGroup inventory is adequate for current demand. Continue normal operations.";
    }
  }

  String _staticReply(String query) {
    if (query.contains("who can donate")) {
      return "👤 Healthy individuals aged 18–65, 50kg+, not recently ill or tattooed.";
    } else if (query.contains("when can i donate")) {
      return "📅 Donate every 3 months if healthy.";
    } else if (query.contains("how often")) {
      return "🕒 You can donate whole blood every 3 months, platelets every 2 weeks.";
    } else if (query.contains("health benefits")) {
      return "💪 Regular donation improves heart health and reduces iron overload.";
    } else if (query.contains("is blood donation safe")) {
      return "✅ Absolutely. It's a safe and sterile process monitored by professionals.";
    } else if (query.contains("eat before")) {
      return "🍎 Eat iron-rich food like spinach, avoid fatty meals before donating.";
    } else if (query.contains("after blood donation")) {
      return "💤 Rest, drink fluids, and avoid heavy work for 24 hours.";
    } else if (query.contains("tattoo")) {
      return "🖋️ You should wait 6 months after a tattoo to donate.";
    } else if (query.contains("women") && query.contains("period")) {
      return "🚺 Women can donate during periods if they feel healthy.";
    } else if (query.contains("should not donate")) {
      return "❌ People with infections, low weight, or chronic conditions should not donate.";
    } else if (query.contains("weight")) {
      return "⚖️ Minimum weight to donate is 50kg.";
    } else if (query.contains("medication")) {
      return "💊 Depends on the medication. Some are allowed, some are not.";
    } else if (query.contains("age limit")) {
      return "🔞 Must be 18–65 years old to donate blood.";
    } else if (query.contains("diabetic")) {
      return "🩺 Type 2 diabetics (controlled) can donate. Type 1 often can't.";
    } else if (query.contains("weakness")) {
      return "😴 Slight weakness is normal. Rest and hydrate well.";
    } else if (query.contains("how long")) {
      return "⏱️ The process takes 20–30 minutes, including rest.";
    } else if (query.contains("smokers")) {
      return "🚬 Smokers can donate if they are otherwise healthy.";
    } else if (query.contains("tests")) {
      return "🔬 Blood is tested for HIV, Hepatitis, Syphilis and more.";
    } else if (query.contains("plasma")) {
      return "🧪 Yes, plasma donation is possible every 2 weeks.";
    } else if (query.contains("covid")) {
      return "😷 Wait 14 days after recovery to donate blood.";
    } else if (query.contains("benefits")) {
      return "❤️ Regular donation reduces cholesterol and helps save lives.";
    } else if (query.contains("rare blood")) {
      return "🩸 AB negative and Bombay blood group are very rare.";
    } else if (query.contains("universal donor")) {
      return "🩺 O- is universal donor, safe for all blood types in emergencies.";
    } else if (query.contains("inventory") || query.contains("stock")) {
      return "Use the 'Check current blood inventory levels' button to see real-time data.";
    }
    return "ℹ️ Sorry, I don't have info on that. Try another question.";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pulse Sync Assistant'),
        backgroundColor: Colors.red[700],
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Catalog of pretexts
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(8),
            child: Row(
              children: _catalog.map((pretext) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ActionChip(
                    label: Text(pretext),
                    onPressed: () => _handlePreText(pretext),
                    backgroundColor: Colors.red[100],
                    avatar: const Icon(Icons.bloodtype, color: Colors.red),
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.all(8),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[_messages.length - 1 - index];
                return ChatBubble(message: message);
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  ChatMessage({required this.text, required this.isUser});
}

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        mainAxisAlignment: message.isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: message.isUser ? Colors.red[700] : Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  fontSize: 15,
                  color: message.isUser ? Colors.white : Colors.black87,
                  fontFamily: 'Roboto',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
