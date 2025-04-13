import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class StockPage extends StatefulWidget {
  final String businessId;
  final String businessName;

  const StockPage({
    Key? key,
    required this.businessId,
    required this.businessName,
  }) : super(key: key);

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  List<DocumentSnapshot> _items = [];
  bool _isLoading = true;

  Map<String, int> _donationQuantities = {};

  @override
  void initState() {
    super.initState();
    _loadStockItems();
  }

  Future<void> _loadStockItems() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      setState(() => _isLoading = true);

      final query =
          await FirebaseFirestore.instance
              .collection('food_items')
              .where('uploadedBy', isEqualTo: user.uid)
              .where('status', isEqualTo: 'available')
              .orderBy('expiryDate')
              .get();

      setState(() {
        _items = query.docs;
        for (var doc in _items) {
          if (!_donationQuantities.containsKey(doc.id)) {
            _donationQuantities[doc.id] = 1;
          }
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error loading items: $e');
    }
  }

  String _formatDate(String? isoDate) {
    if (isoDate == null) return 'Not specified';
    final parsedDate = DateTime.tryParse(isoDate);
    if (parsedDate == null) return 'Invalid date';
    return DateFormat('MMM dd, yyyy').format(parsedDate);
  }

  Future<void> _donateItem(DocumentSnapshot doc, int donationQuantity) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showSnackBar('You must be logged in to donate');
        return;
      }

      final foodBanks =
          await FirebaseFirestore.instance
              .collection('users')
              .where('role', isEqualTo: 'foodbank')
              .get();

      if (foodBanks.docs.isEmpty) {
        _showSnackBar('No registered food banks found');
        return;
      }

      final selectedBank = await showDialog<String>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Select Food Bank'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: foodBanks.docs.length,
                  itemBuilder: (context, index) {
                    final bank = foodBanks.docs[index];
                    return ListTile(
                      title: Text(bank['name'] ?? 'Unnamed Food Bank'),
                      onTap: () => Navigator.pop(context, bank.id),
                    );
                  },
                ),
              ),
            ),
      );

      if (selectedBank == null) return;

      final data = doc.data() as Map<String, dynamic>;
      int availableQty = data['quantity'] ?? 0;

      if (donationQuantity > availableQty) {
        _showSnackBar('Donation quantity exceeds available stock');
        return;
      }

      final businessDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      await FirebaseFirestore.instance.collection('donated_items').add({
        'itemName': data['itemName'],
        'quantity': donationQuantity,
        'originalPrice': data['originalPrice'],
        'discountedPrice': data['discountedPrice'],
        'expiryDate': data['expiryDate'],
        'accessibleFrom': data['accessibleFrom'],
        'donatedBy': user.uid,
        'donatedByName': businessDoc['name'],
        'receivedBy': selectedBank,
        'status': 'pending',
        'originalItemId': doc.id,
        'donatedAt': FieldValue.serverTimestamp(),
      });

      _showSnackBar('Donation request sent successfully!');

      setState(() {
        _donationQuantities[doc.id] = 1;
      });

      _loadStockItems();
    } catch (e) {
      _showSnackBar('Failed to donate item: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item, DocumentSnapshot doc) {
    int availableQty = item['quantity'] ?? 0;
    int donationQuantity = _donationQuantities[doc.id] ?? 1;
    final isExpired =
        item['expiryDate'] != null &&
        DateTime.tryParse(item['expiryDate'])?.isBefore(DateTime.now()) == true;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item['itemName'] ?? 'Unnamed Item',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (isExpired)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'EXPIRED',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _buildDetailRow(Icons.scale, 'Quantity: $availableQty'),
              _buildDetailRow(
                Icons.calendar_today,
                'Expiry: ${_formatDate(item['expiryDate'])}',
              ),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Quantity selector
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove),
                        onPressed: () {
                          setState(() {
                            if (_donationQuantities[doc.id]! > 1) {
                              _donationQuantities[doc.id] =
                                  _donationQuantities[doc.id]! - 1;
                            }
                          });
                        },
                      ),
                      Text('$donationQuantity'),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () {
                          setState(() {
                            if (donationQuantity < availableQty) {
                              _donationQuantities[doc.id] =
                                  donationQuantity + 1;
                            } else {
                              _showSnackBar('Cannot exceed available stock');
                            }
                          });
                        },
                      ),
                    ],
                  ),
                  // Donate button.
                  SizedBox(
                    width: 150,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.volunteer_activism),
                      label: const Text('Donate Item'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        _donateItem(doc, donationQuantity);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Stock'),
        backgroundColor: Colors.green.shade600,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStockItems,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.green.shade100, Colors.white],
          ),
        ),
        child:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No available items in stock',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                )
                : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index].data() as Map<String, dynamic>;
                    return _buildItemCard(item, _items[index]);
                  },
                ),
      ),
    );
  }
}
