import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class BusinessOrdersPage extends StatefulWidget {
  const BusinessOrdersPage({Key? key}) : super(key: key);

  @override
  State<BusinessOrdersPage> createState() => _BusinessOrdersPageState();
}

class _BusinessOrdersPageState extends State<BusinessOrdersPage> {
  String? _storeId;
  bool _isLoading = true;
  String? _errorMessage;
  bool _indexError = false;

  @override
  void initState() {
    super.initState();
    _initializeStore();
  }

  Future<void> _initializeStore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No user logged in');

      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
      if (!userDoc.exists || userDoc['role'] != 'business') {
        throw Exception('User is not registered as a business');
      }

      setState(() {
        _storeId = user.uid;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Initialization error: $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Stream<QuerySnapshot> _getOrdersStream() {
    if (_storeId == null) return Stream.empty();

    try {
      var query = FirebaseFirestore.instance
          .collection('orders')
          .where('storeId', isEqualTo: _storeId)
          .orderBy('orderDate', descending: true);
      return query.snapshots().handleError((error) {
        if (error.toString().contains('index')) {
          setState(() => _indexError = true);
        }
        throw error;
      });
    } catch (e) {
      debugPrint('Query error: $e');
      return Stream.error(e);
    }
  }

  Future<void> _updateOrderStatus(
    String orderId,
    String newStatus,
    BuildContext context,
  ) async {
    try {
      // Update the order status.
      await FirebaseFirestore.instance.collection('orders').doc(orderId).update(
        {'status': newStatus, 'updatedAt': FieldValue.serverTimestamp()},
      );

      // If business accepts the order, then update the stock for each order item.
      if (newStatus == 'accepted') {
        final orderDoc =
            await FirebaseFirestore.instance
                .collection('orders')
                .doc(orderId)
                .get();
        final orderData = orderDoc.data() as Map<String, dynamic>?;
        if (orderData != null && orderData['items'] != null) {
          final items =
              (orderData['items'] as List).cast<Map<String, dynamic>>();
          for (final item in items) {
            final String? docPath = item['originalDocPath'];
            final int quantity = item['quantity'] as int? ?? 0;
            if (docPath != null) {
              final docRef = FirebaseFirestore.instance.doc(docPath);
              // Subtract the ordered quantity from business stock.
              await docRef.update({
                'quantity': FieldValue.increment(-quantity),
                // Optionally, if remaining quantity becomes zero, update status.
                // You might choose to fetch the document, compute new quantity, and if <=0, set status to "out_of_stock".
              });
            }
          }
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order marked as ${newStatus.toUpperCase()}'),
          backgroundColor: _getStatusColor(newStatus),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update order: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showCancellationDialog(
    String orderId,
    BuildContext context,
  ) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Cancel Order'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Please provide a reason:'),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(hintText: 'Reason'),
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Confirm'),
              ),
            ],
          ),
    );

    if (confirmed == true && reasonController.text.trim().isNotEmpty) {
      await _updateOrderStatus(orderId, 'cancelled', context);
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return Colors.green;
      case 'pickedup':
        return Colors.green.shade700;
      case 'cancelled':
        return Colors.red;
      case 'completed':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  Widget _buildOrderCard(DocumentSnapshot doc) {
    final order = doc.data() as Map<String, dynamic>;
    final items = order['items'] as List? ?? [];
    final total = (order['total'] as num?)?.toDouble() ?? 0.0;
    final date = (order['orderDate'] as Timestamp?)?.toDate() ?? DateTime.now();
    final status = order['status'] as String? ?? 'pending';
    final customerName = order['customerName'] as String? ?? 'Customer';
    final phoneNumber = order['phoneNumber'] as String? ?? 'Not provided';
    final notes = order['notes'] as String? ?? '';
    final pickupTime = order['pickupTime'] as Timestamp?;
    final pickupDateStr =
        pickupTime != null
            ? DateFormat('MMM dd, yyyy - h:mm a').format(pickupTime.toDate())
            : 'Not specified';

    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Order Number and Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order #${doc.id.substring(0, 8)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Chip(
                  label: Text(status.toUpperCase()),
                  backgroundColor: _getStatusColor(status).withOpacity(0.2),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Customer: $customerName'),
            Text('Phone: $phoneNumber'),
            Text(
              'Order Date: ${DateFormat('MMM d, yyyy - h:mm a').format(date)}',
            ),
            Text('Pickup: $pickupDateStr'),
            if (notes.isNotEmpty) Text('Request: $notes'),
            const Divider(height: 16),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('${item['itemName']} (x${item['quantity']})'),
                    ),
                    Text(
                      '\$${(item['price'] * item['quantity']).toStringAsFixed(2)}',
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'TOTAL:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('\$${total.toStringAsFixed(2)}'),
              ],
            ),
            const SizedBox(height: 12),
            // Action buttons based on order status.
            if (status == 'pending') ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          () => _updateOrderStatus(doc.id, 'accepted', context),
                      child: const Text('Accept'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _showCancellationDialog(doc.id, context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (status == 'accepted') ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.check, color: Colors.green),
                  label: const Text('Mark as Picked Up'),
                  onPressed:
                      () => _updateOrderStatus(doc.id, 'pickedup', context),
                ),
              ),
            ] else if (status == 'pickedup') ...[
              Row(
                children: const [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 4),
                  Text(
                    'Picked Up',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_errorMessage!),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _initializeStore,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Business Orders')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getOrdersStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final orders = snapshot.data?.docs ?? [];
          if (orders.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_bag_outlined, size: 48),
                  SizedBox(height: 16),
                  Text('No orders found'),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: orders.length,
            itemBuilder: (context, index) => _buildOrderCard(orders[index]),
          );
        },
      ),
    );
  }
}
