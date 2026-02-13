import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'widgets/slide_to_confirm.dart';
import '../utils/phone_utils.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> orderData;

  const OrderDetailScreen({
    super.key,
    required this.orderId,
    required this.orderData,
  });

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  Map<String, dynamic>? userData;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadUserData();
  }

  Future<void> loadUserData() async {
    try {
      final userUid = widget.orderData['uid'] ?? widget.orderData['userId'];
      if (userUid != null) {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('uid', isEqualTo: userUid)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          setState(() {
            userData = querySnapshot.docs.first.data();
            loading = false;
          });
        } else {
          final doc = await FirebaseFirestore.instance.collection('users').doc(userUid).get();
          if (doc.exists) {
            setState(() {
              userData = doc.data();
              loading = false;
            });
          } else {
            setState(() => loading = false);
          }
        }
      } else {
        setState(() => loading = false);
      }
    } catch (e) {
      debugPrint("Error loading user data: $e");
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.orderData;
    final String status = d['status'] ?? d['orderStatus'] ?? 'pending';
    final String address = d['address'] ?? 'No address';
    final String area = d['area'] ?? '';
    final String phone = d['phone'] ?? '';
    final String displayUserName = d['userName'] ?? userData?['name'] ?? 'Customer';
    final String deliverySlot = d['deliverySlot'] ?? 'Not specified';
    final String deliveryType = d['deliveryType'] ?? 'Normal';
    final String paymentMethod = d['paymentMethod'] ?? 'N/A';
    final String gstNumber = d['gstNumber'] ?? 'N/A';
    final double totalAmount = (d['totalAmount'] ?? d['price'] ?? 0).toDouble();
    final List<dynamic> items = d['items'] ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          "Order Details",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A237E)),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1A237E)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildOrderHeader(status, d['productName'] ?? (items.isNotEmpty ? 'Multiple Items' : 'Order')),
                      if (items.isNotEmpty)
                        _buildInfoSection(
                          title: "Items",
                          icon: Icons.shopping_basket_rounded,
                          child: Column(
                            children: [
                              ...items.map((item) => _buildItemTile(item)).toList(),
                              const Divider(height: 32),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text("Total Amount", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                                  Text("₹${totalAmount.toStringAsFixed(0)}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFFFF6F00))),
                                ],
                              ),
                            ],
                          ),
                        )
                      else
                        _buildInfoSection(
                          title: "Product Info",
                          icon: Icons.propane_tank_rounded,
                          child: Column(
                            children: [
                              _buildItemTile({
                                'name': d['productName'] ?? 'LPG Cylinder',
                                'weight': d['weight'] ?? 'N/A',
                                'price': d['price'] ?? 0,
                                'quantity': d['quantity'] ?? 1,
                              }),
                              const Divider(height: 32),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text("Total Amount", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                                  Text("₹${totalAmount.toStringAsFixed(0)}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFFFF6F00))),
                                ],
                              ),
                            ],
                          ),
                        ),
                      _buildInfoSection(
                        title: "Customer Details",
                        icon: Icons.person_rounded,
                        child: Column(
                          children: [
                            _buildDetailRow("Name", displayUserName),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(child: _buildDetailRow("Phone", phone)),
                                if (phone.isNotEmpty)
                                  IconButton(
                                    onPressed: () => PhoneUtils.callCustomer(phone, context),
                                    icon: const Icon(Icons.call, color: Colors.white, size: 20),
                                    style: IconButton.styleFrom(
                                      backgroundColor: const Color(0xFF4CAF50),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      _buildInfoSection(
                        title: "Delivery Location",
                        icon: Icons.location_on_rounded,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDetailRow("Area", area),
                            const SizedBox(height: 12),
                            Text(
                              "Address",
                              style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Text(
                                address,
                                style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (status == 'assigned' || status == 'pending')
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5)),
                        ],
                      ),
                      child: SlideToConfirm(
                        onConfirm: () async {
                          final agentId = FirebaseAuth.instance.currentUser?.uid;
                          final batch = FirebaseFirestore.instance.batch();
                          
                          batch.update(
                            FirebaseFirestore.instance.collection('orders').doc(widget.orderId),
                            {'orderStatus': 'completed', 'status': 'completed', 'completedAt': FieldValue.serverTimestamp()},
                          );
                          
                          if (agentId != null) {
                            batch.update(
                              FirebaseFirestore.instance.collection('delivery_agents').doc(agentId),
                              {
                                'orderIDs': FieldValue.arrayRemove([widget.orderId]),
                                'completed_orders': FieldValue.arrayUnion([widget.orderId]),
                                'cylindersDeliveredToday': FieldValue.increment(1),
                              },
                            );
                          }
                          await batch.commit();
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Order marked as completed'), backgroundColor: Color(0xFFC62828)),
                            );
                          }
                        },
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildOrderHeader(String status, String title) {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                ),
                const SizedBox(height: 4),
                Text(
                  "Order ID: #${widget.orderId.substring(widget.orderId.length > 8 ? widget.orderId.length - 8 : 0).toUpperCase()}",
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500, letterSpacing: 1),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: status == 'completed' ? Colors.green.shade50 : const Color(0xFF1A237E).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: status == 'completed' ? Colors.green.shade700 : const Color(0xFF1A237E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection({required String title, required IconData icon, required Widget child}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: const Color(0xFF1A237E)),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildItemTile(Map<String, dynamic> item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              image: item['imageUrl'] != null && item['imageUrl'].toString().isNotEmpty
                  ? DecorationImage(image: NetworkImage(item['imageUrl']), fit: BoxFit.cover)
                  : null,
            ),
            child: (item['imageUrl'] == null || item['imageUrl'].toString().isEmpty) 
                ? const Icon(Icons.propane_tank_rounded, color: Color(0xFF1A237E)) 
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'] ?? 'Item',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                ),
                Text(
                  "Weight: ${item['weight'] ?? 'N/A'}",
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "₹${item['price']}",
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFFFF6F00)),
              ),
              Text(
                "Qty: ${item['quantity']}",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(label, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
          ),
        ),
      ],
    );
  }
}

// Extension for string title case
extension StringExtension on String {
  String toTitleCase() {
    if (isEmpty) return this;
    return split(' ')
        .map((word) => word.isNotEmpty
            ? word[0].toUpperCase() + word.substring(1).toLowerCase()
            : word)
        .join(' ');
  }
}