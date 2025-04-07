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

  String _formatDate(String? isoDate) {
    if (isoDate == null) return '-';
    final parsedDate = DateTime.tryParse(isoDate);
    if (parsedDate == null) return isoDate;
    return DateFormat('yyyy-MM-dd').format(parsedDate);
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
      body: Stack(
        children: [
          // Background image
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('lib/assets/background.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Dark overlay with same opacity (0.5)
          Container(color: Colors.black.withOpacity(0.5)),
          // Content
          _items.isEmpty
              ? const Center(
                child: Text(
                  'No items uploaded yet.',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              )
              : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final item = _items[index].data() as Map<String, dynamic>;
                  final originalPrice =
                      item['originalPrice']?.toStringAsFixed(2) ?? '-';
                  final discountedPrice =
                      item['discountedPrice']?.toStringAsFixed(2) ?? '-';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(
                        0.85,
                      ), // Slightly transparent white
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
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
                        Text("Expiry: ${_formatDate(item['expiryDate'])}"),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              "\$$originalPrice",
                              style: const TextStyle(
                                decoration: TextDecoration.lineThrough,
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "\$$discountedPrice",
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
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.volunteer_activism),
            label: const Text("Donate Remaining Food"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(fontSize: 18),
            ),
            onPressed: () {
              final remaining =
                  _items.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return (data['quantity'] ?? 0) > 0;
                  }).toList();

              if (remaining.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('No remaining items to donate.'),
                  ),
                );
              } else {
                _sendToDonationPool(remaining);
              }
            },
          ),
        ),
      ),
    );
  }
}
