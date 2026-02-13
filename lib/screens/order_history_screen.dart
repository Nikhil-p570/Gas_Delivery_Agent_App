import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'order_detail_screen.dart';

class OrderHistoryScreen extends StatelessWidget {
  const OrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final agentId = FirebaseAuth.instance.currentUser?.uid;

    if (agentId == null) {
      return const Scaffold(
        body: Center(child: Text("User not logged in")),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          "Order History",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A237E),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1A237E)),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('delivery_agents')
            .doc(agentId)
            .snapshots(),
        builder: (context, agentSnap) {
          if (!agentSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final agentData = agentSnap.data!.data() as Map<String, dynamic>?;
          final List<dynamic> completedOrderIds =
              agentData?['completed_orders'] ?? [];

          if (completedOrderIds.isEmpty) {
            return _buildEmptyState();
          }

          // Fetch only the last 20-30 orders or use a better strategy for large histories
          // For now, we fetch what's in the array
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('orders')
                .where(FieldPath.documentId, whereIn: completedOrderIds.take(10).toList()) // Firestore whereIn limit is 10 (30 in some SDKs)
                .snapshots(),
            builder: (context, ordersSnap) {
              if (ordersSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!ordersSnap.hasData || ordersSnap.data!.docs.isEmpty) {
                return _buildEmptyState();
              }

              final orders = ordersSnap.data!.docs;
              
              // Sort by completion time (most recent first)
              final sortedOrders = orders.toList()
                ..sort((a, b) {
                  final aTime = (a.data() as Map)['completedAt'] as Timestamp?;
                  final bTime = (b.data() as Map)['completedAt'] as Timestamp?;
                  if (aTime == null) return 1;
                  if (bTime == null) return -1;
                  return bTime.compareTo(aTime);
                });

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: sortedOrders.length,
                itemBuilder: (context, index) {
                  final doc = sortedOrders[index];
                  final d = doc.data() as Map<String, dynamic>;
                  final productName = d['productName'] ?? 'LPG Cylinder';
                  final qty = d['quantity'] ?? 1;
                  final completedAt = d['completedAt'] as Timestamp?;
                  final dateStr = completedAt != null
                      ? DateFormat('dd MMM yyyy, hh:mm a').format(completedAt.toDate())
                      : 'N/A';

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
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.check_circle_rounded,
                                color: Colors.green.shade700,
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
                                  Text(
                                    "Qty: $qty",
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    dateStr,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: Color(0xFF1A237E),
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
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A237E).withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.history_rounded,
              size: 48,
              color: Color(0xFF1A237E),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "No Completed Orders",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Delivered orders will appear here",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
