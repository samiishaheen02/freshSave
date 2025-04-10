import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class StockPage extends StatefulWidget {
  const StockPage({super.key});

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  List<DocumentSnapshot> _items = [];

  @override
  void initState() {
    super.initState();
    _loadStockItems();
  }

  Future<void> _loadStockItems() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final query =
        await FirebaseFirestore.instance
            .collection('food_items')
            .where('uploadedBy', isEqualTo: user.uid)
            .get();

    setState(() {
      _items = query.docs;
    });
  }

  String _formatDate(dynamic date) {
    if (date == null) return '-';

    if (date is Timestamp) {
      return DateFormat('yyyy-MM-dd').format(date.toDate());
    } else if (date is DateTime) {
      return DateFormat('yyyy-MM-dd').format(date);
    } else if (date is String) {
      final parsed = DateTime.tryParse(date);
      return parsed != null ? DateFormat('yyyy-MM-dd').format(parsed) : '-';
    }

    return '-';
  }

  void _sendToDonationPool(List<DocumentSnapshot> items) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    for (var doc in items) {
      final data = doc.data() as Map<String, dynamic>;

      await FirebaseFirestore.instance.collection('donated_items').add({
        'itemName': data['itemName'] ?? '',
        'quantity': data['quantity'] ?? 0,
        'originalPrice': data['originalPrice'],
        'discountedPrice': data['discountedPrice'],
        'expiryDate': data['expiryDate'],
        'accessibleFrom': data['accessibleFrom'],
        'donatedBy': user.uid,
        'donatedAt': FieldValue.serverTimestamp(),
      });

      await doc.reference.delete();
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Remaining items donated.')));

    _loadStockItems();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Stock'),
        backgroundColor: Colors.green.shade600,
        elevation: 4,
      ),
      body:
          _items.isEmpty
              ? const Center(
                child: Text(
                  'No items uploaded yet.',
                  style: TextStyle(fontSize: 16),
                ),
              )
              : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final item = _items[index].data() as Map<String, dynamic>;
                  final expiry = _formatDate(item['selectedDate']);
                  final access = _formatDate(item['accessDate']);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['itemName'] ?? '',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text("Quantity: ${item['quantity']}"),
                        Text("Expiry: $expiry"),
                        Text("Access Date: $access"),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              "\$${item['originalPrice']?.toStringAsFixed(2) ?? '-'}",
                              style: const TextStyle(
                                decoration: TextDecoration.lineThrough,
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "\$${item['discountedPrice']?.toStringAsFixed(2) ?? '-'}",
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
      backgroundColor: Colors.grey.shade100,
    );
  }
}
