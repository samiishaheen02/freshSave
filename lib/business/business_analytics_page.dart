import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BusinessAnalyticsPage extends StatefulWidget {
  const BusinessAnalyticsPage({super.key});

  @override
  State<BusinessAnalyticsPage> createState() => _BusinessAnalyticsPageState();
}

class _BusinessAnalyticsPageState extends State<BusinessAnalyticsPage> {
  int _totalOrders = 0;
  double _totalRevenue = 0.0;
  int _remainingStock = 0;
  int _totalItemsSold = 0;
  Map<String, int> _itemSales = {};

  @override
  void initState() {
    super.initState();
    _loadAnalyticsData();
  }

  Future<void> _loadAnalyticsData() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final ordersQuery =
          await FirebaseFirestore.instance
              .collection('orders')
              .where('storeId', isEqualTo: currentUser.uid)
              .where('status', isEqualTo: 'pickedup')
              .get();

      final inventoryQuery =
          await FirebaseFirestore.instance
              .collection('food_items')
              .where('uploadedBy', isEqualTo: currentUser.uid)
              .where('status', isEqualTo: 'available')
              .get();

      int ordersCount = ordersQuery.size;
      double revenue = ordersQuery.docs.fold(0.0, (sum, doc) {
        return sum + (doc['total'] as num).toDouble();
      });
      int stockCount = inventoryQuery.docs.fold(0, (sum, doc) {
        return sum + (doc['quantity'] as num).toInt();
      });

      final itemSales = <String, int>{};
      for (final order in ordersQuery.docs) {
        final items = order['items'] as List<dynamic>;
        for (final item in items) {
          final itemName = item['itemName'] as String;
          final quantity = item['quantity'] as int;
          itemSales.update(
            itemName,
            (value) => value + quantity,
            ifAbsent: () => quantity,
          );
        }
      }
      int totalItemsSold =
          itemSales.isEmpty ? 0 : itemSales.values.reduce((a, b) => a + b);

      setState(() {
        _totalOrders = ordersCount;
        _totalRevenue = revenue;
        _remainingStock = stockCount;
        _itemSales = itemSales;
        _totalItemsSold = totalItemsSold;
      });
    } catch (e) {
      debugPrint('Error loading analytics: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Analytics'),
        backgroundColor: Colors.green.shade600,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalyticsData,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatsSection(),
            const SizedBox(height: 24),
            const Text(
              'Sales Summary',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildSalesItemList(),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            const Text(
              'Current Stock Breakdown',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildStockBreakdown(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _buildStatItem(
          Icons.shopping_cart,
          'Total Orders',
          _totalOrders.toString(),
        ),
        _buildStatItem(
          Icons.attach_money,
          'Total Revenue',
          '\$${_totalRevenue.toStringAsFixed(2)}',
        ),
        _buildStatItem(
          Icons.inventory,
          'Remaining Stock',
          _remainingStock.toString(),
        ),
        _buildStatItem(
          Icons.production_quantity_limits,
          'Items Sold',
          _totalItemsSold.toString(),
        ),
      ],
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: Colors.green.shade600),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesItemList() {
    if (_itemSales.isEmpty) {
      return const Center(
        child: Text('No sales data available', style: TextStyle(fontSize: 16)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Items Sold:',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ..._itemSales.entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(entry.key, style: const TextStyle(fontSize: 16)),
                ),
                Text(
                  '${entry.value} sold',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStockBreakdown() {
    final currentUser = FirebaseAuth.instance.currentUser;
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('food_items')
              .where('uploadedBy', isEqualTo: currentUser?.uid)
              .where('status', isEqualTo: 'available')
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text('No items in stock', style: TextStyle(fontSize: 16)),
          );
        }

        final docs = snapshot.data!.docs;
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final itemName = data['itemName'] ?? 'Unnamed Item';
            final quantity = data['quantity'] ?? 0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(itemName, style: const TextStyle(fontSize: 16)),
                  Text(
                    "Stock: $quantity",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
