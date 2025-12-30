import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';
import 'order_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool isOnline = false;
  Timer? timer;
  final agentId = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    loadOnlineStatus();
  }

  Future<void> loadOnlineStatus() async {
    final doc = await FirebaseFirestore.instance
        .collection('delivery_agents')
        .doc(agentId)
        .get();
    if (doc.exists && mounted) {
      setState(() {
        isOnline = doc.data()?['isOnline'] ?? false;
      });
    }
  }

  Future<void> toggleOnline(bool val) async {
    setState(() => isOnline = val);
    FirebaseFirestore.instance
        .collection('delivery_agents')
        .doc(agentId)
        .update({'isOnline': val});
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          "Delivery Agent",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.logout_rounded, color: Colors.grey.shade700),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isOnline ? "You are online" : "You are offline",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isOnline ? "Ready to deliver" : "Not accepting orders",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: isOnline ? Colors.red.shade50 : Colors.grey.shade50,
                  ),
                  child: Switch(
                    value: isOnline,
                    onChanged: toggleOnline,
                    activeColor: Colors.red.shade700,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: IncomingOrders(agentId: agentId))
        ],
      ),
    );
  }
}

class IncomingOrders extends StatelessWidget {
  final String agentId;
  const IncomingOrders({super.key, required this.agentId});

  // Helper to format order type display
  String _formatOrderType(String? orderType) {
    if (orderType == null) return 'New Cylinder';
    if (orderType == 'new_cylinder') return 'New Cylinder';
    if (orderType == 'refill') return 'Refill';
    return orderType.replaceAll('_', ' ');
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('assignedAgentId', isEqualTo: agentId)
          .where('orderStatus', isEqualTo: 'assigned')
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }
        if (snap.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.local_shipping_rounded,
                    size: 48,
                    color: Colors.red.shade700,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "No Orders Assigned",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Waiting for orders to be assigned",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snap.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snap.data!.docs[index];
            final d = doc.data() as Map<String, dynamic>;
            final productName = d['productName'] ?? 'LPG Cylinder';
            final qty = d['quantity'] ?? 1;
            final area = d['area'] ?? _extractArea(d['address'] ?? '');
            final orderType = d['orderType'] ?? 'new_cylinder';
            final formattedOrderType = _formatOrderType(orderType);

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OrderDetailScreen(
                        orderId: doc.id,
                        orderData: d,
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.propane_tank_rounded,
                          color: Colors.red.shade700,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              productName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // First row: Qty, Weight and Order Type
                                Row(
                                  children: [
                                    // Quantity badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        "Qty: $qty",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.blue.shade700,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    
                                    // Weight badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        d['weight'] ?? '19.5 kg',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.green.shade700,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    
                                    // Order Type badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: orderType == 'new_cylinder' 
                                          ? Colors.orange.shade50 
                                          : Colors.purple.shade50,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        formattedOrderType,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: orderType == 'new_cylinder'
                                            ? Colors.orange.shade700
                                            : Colors.purple.shade700,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                
                                // Second row: Area
                                Text(
                                  "Area: $area",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.grey.shade400,
                        size: 28,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _extractArea(String address) {
    if (address.isEmpty) return 'No area';
    final parts = address.split(',');
    if (parts.length > 1) {
      return parts[parts.length - 2].trim();
    }
    return address.split(' ').take(3).join(' ');
  }
}