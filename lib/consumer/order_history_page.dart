import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

class OrderHistoryPage extends StatefulWidget {
  final String userId;
  const OrderHistoryPage({super.key, required this.userId});

  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> {
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();
  final List<String> _deletingOrderIds = [];

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: scaffoldMessengerKey,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Your Orders'),
          backgroundColor: Colors.green.shade700,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refreshOrders,
            ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('lib/assets/background.jpg'),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        color: Colors.black.withOpacity(0.4),
        child: StreamBuilder<QuerySnapshot>(
          stream:
              FirebaseFirestore.instance
                  .collection('orders')
                  .where('customerId', isEqualTo: widget.userId)
                  .orderBy('orderDate', descending: true)
                  .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              );
            }

            if (snapshot.hasError) {
              return _buildErrorWidget(snapshot.error!);
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(
                child: Text(
                  'You have no orders yet',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              );
            }

            return _buildOrderList(snapshot.data!.docs);
          },
        ),
      ),
    );
  }

  Widget _buildErrorWidget(dynamic error) {
    final isIndexError = error.toString().contains('index');

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 16),
          Text(
            isIndexError
                ? 'Database configuration needed'
                : 'Error loading orders',
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 16),
          if (isIndexError)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
              ),
              onPressed: _handleIndexError,
              child: const Text('Fix Database Configuration'),
            ),
        ],
      ),
    );
  }

  Widget _buildOrderList(List<DocumentSnapshot> orders) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index].data() as Map<String, dynamic>;
        final orderId = orders[index].id;
        return _buildOrderCard(order, orderId);
      },
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order, String orderId) {
    final items = order['items'] as List<dynamic>;
    final total = order['total'] ?? 0.0;
    final date = order['orderDate']?.toDate() ?? DateTime.now();
    final status = order['status'] ?? 'pending';
    final storeName = order['storeName'] ?? 'Store';
    final isDeleting = _deletingOrderIds.contains(orderId);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Order #${orderId.substring(0, 8).toUpperCase()}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.content_copy, size: 18),
                      onPressed:
                          isDeleting ? null : () => _copyOrderId(orderId),
                    ),
                    if (status == 'pending')
                      IconButton(
                        icon:
                            isDeleting
                                ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Icon(
                                  Icons.delete,
                                  size: 18,
                                  color: Colors.red,
                                ),
                        onPressed:
                            isDeleting
                                ? null
                                : () => _confirmDeleteOrder(orderId),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Store: $storeName'),
            const SizedBox(height: 4),
            Text('Date: ${DateFormat('MMM dd, yyyy - hh:mm a').format(date)}'),
            const SizedBox(height: 4),
            Text(
              'Status: ${status.toUpperCase()}',
              style: TextStyle(
                color: _getStatusColor(status),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
            ...items.map((item) => _buildOrderItem(item)).toList(),
            const Divider(height: 16),
            _buildOrderTotal(total),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderItem(dynamic item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text('${item['itemName']} (x${item['quantity']})')),
          Text('\$${(item['price'] * item['quantity']).toStringAsFixed(2)}'),
        ],
      ),
    );
  }

  Widget _buildOrderTotal(double total) {
    return Row(
      children: [
        const Text('Total:', style: TextStyle(fontWeight: FontWeight.bold)),
        const Spacer(),
        Text(
          '\$${total.toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.green.shade700,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'processing':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  void _copyOrderId(String orderId) {
    Clipboard.setData(ClipboardData(text: orderId));
    _showSnackBar('Order ID copied to clipboard');
  }

  void _refreshOrders() {
    setState(() {});
    _showSnackBar('Orders refreshed');
  }

  void _handleIndexError() {
    _showSnackBar('Please create the required index in Firebase Console');
  }

  Future<void> _confirmDeleteOrder(String orderId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Cancel Order'),
            content: const Text('Are you sure you want to cancel this order?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Yes', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      await _deleteOrder(orderId);
    }
  }

  Future<void> _deleteOrder(String orderId) async {
    try {
      setState(() => _deletingOrderIds.add(orderId));

      final doc =
          await FirebaseFirestore.instance
              .collection('orders')
              .doc(orderId)
              .get();

      if (!doc.exists || doc['status'] != 'pending') {
        throw Exception('Only pending orders can be cancelled');
      }

      await FirebaseFirestore.instance.collection('orders').doc(orderId).update(
        {'status': 'cancelled', 'updatedAt': FieldValue.serverTimestamp()},
      );

      _showSnackBar('Order cancelled successfully');
    } catch (e) {
      _showSnackBar('Failed to cancel order: ${e.toString()}');
    } finally {
      setState(() => _deletingOrderIds.remove(orderId));
    }
  }

  void _showSnackBar(String message) {
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }
}
