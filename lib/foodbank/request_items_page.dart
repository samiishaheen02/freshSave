import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RequestItemsPage extends StatefulWidget {
  const RequestItemsPage({super.key});

  @override
  State<RequestItemsPage> createState() => _RequestItemsPageState();
}

class _RequestItemsPageState extends State<RequestItemsPage> {
  final Map<String, String> _businessNames = {};
  bool _isLoadingBusinessNames = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey<ScaffoldMessengerState> _scaffoldKey =
      GlobalKey<ScaffoldMessengerState>();
  final Map<String, int> _requestQuantities = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBusinessNames(List<String> userIds) async {
    if (_isLoadingBusinessNames || userIds.isEmpty) return;
    _isLoadingBusinessNames = true;
    try {
      final users =
          await FirebaseFirestore.instance
              .collection('users')
              .where(FieldPath.documentId, whereIn: userIds)
              .get();
      for (final doc in users.docs) {
        if (!_businessNames.containsKey(doc.id)) {
          final data = doc.data() as Map<String, dynamic>;
          final businessName =
              data['businessName'] ??
              data['name'] ??
              data['email']?.split('@').first ??
              'Local Business';
          _businessNames[doc.id] = businessName.toString();
        }
      }
    } catch (e) {
      debugPrint('Error loading business names: $e');
      _showSnackBar('Error loading business information');
    } finally {
      _isLoadingBusinessNames = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _requestItems(
    String businessId,
    String businessName,
    Map<String, dynamic> item,
  ) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        _showSnackBar('Please login to request items');
        return;
      }

      final requestedQuantity = _requestQuantities[item['id']] ?? 1;
      if (requestedQuantity <= 0) {
        _showSnackBar('Please select a valid quantity');
        return;
      }

      if (requestedQuantity > (item['quantity'] ?? 0)) {
        _showSnackBar('Requested quantity exceeds available stock');
        return;
      }

      // Get food bank info
      final foodBankDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .get();
      final foodBankName = foodBankDoc['name'] ?? 'Food Bank';

      await FirebaseFirestore.instance.collection('donated_items').add({
        'itemName': item['itemName'],
        'quantity': requestedQuantity,
        'originalQuantity': item['quantity'],
        'originalPrice': item['originalPrice'],
        'discountedPrice': item['discountedPrice'],
        'expiryDate': item['expiryDate'],
        'donatedBy': businessId,
        'donatedByName': businessName,
        'receivedBy': currentUser.uid,
        'receivedByName': foodBankName,
        'status': 'pending',
        'originalItemId': item['id'],
        'requestedAt': FieldValue.serverTimestamp(),
        'isPartial': requestedQuantity < (item['quantity'] ?? 0),
      });

      _showSnackBar('Request sent to $businessName');
    } catch (e) {
      _showSnackBar('Failed to send request: $e');
    }
  }

  void _showSnackBar(String message) {
    _scaffoldKey.currentState?.showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white.withOpacity(0.9),
          hintText: 'Search for items...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon:
              _searchQuery.isNotEmpty
                  ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                  )
                  : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (query) {
          setState(() {
            _searchQuery = query;
          });
        },
      ),
    );
  }

  Widget _buildItemCard(DocumentSnapshot doc, Map<String, dynamic> item) {
    if (!_requestQuantities.containsKey(doc.id)) {
      _requestQuantities[doc.id] = 1;
    }
    int selectedQuantity = _requestQuantities[doc.id]!;

    final expiryDate =
        item['expiryDate'] != null
            ? DateTime.tryParse(item['expiryDate'])
            : null;
    final isExpired = expiryDate != null && expiryDate.isBefore(DateTime.now());
    final businessName = _businessNames[item['uploadedBy']] ?? 'Business';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              businessName,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade800,
              ),
            ),
            const SizedBox(height: 4),
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
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.scale, size: 20, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text('Quantity: ${item['quantity']}'),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 20,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 8),
                Text(
                  'Expiry: ${expiryDate != null ? DateFormat('MMM dd, yyyy').format(expiryDate) : 'Not specified'}',
                  style: TextStyle(color: isExpired ? Colors.red : Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove),
                      onPressed: () {
                        setState(() {
                          if (_requestQuantities[doc.id]! > 1) {
                            _requestQuantities[doc.id] =
                                _requestQuantities[doc.id]! - 1;
                          }
                        });
                      },
                    ),
                    Text('$selectedQuantity'),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        setState(() {
                          if (selectedQuantity < (item['quantity'] ?? 0)) {
                            _requestQuantities[doc.id] = selectedQuantity + 1;
                          } else {
                            _showSnackBar('Cannot exceed available stock');
                          }
                        });
                      },
                    ),
                  ],
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed:
                      () => _requestItems(item['uploadedBy'], businessName, {
                        'id': doc.id,
                        ...item,
                      }),
                  child: const Text('Request Items'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsList() {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('food_items')
              .where('status', isEqualTo: 'available')
              .where('quantity', isGreaterThan: 0)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No items available'));
        }

        final allItems = snapshot.data!.docs;
        final filteredItems =
            _searchQuery.isEmpty
                ? allItems
                : allItems.where((doc) {
                  final item = doc.data() as Map<String, dynamic>;
                  final name = item['itemName']?.toString().toLowerCase() ?? '';
                  return name.contains(_searchQuery.toLowerCase());
                }).toList();

        final userIds =
            filteredItems
                .map(
                  (doc) =>
                      (doc.data() as Map<String, dynamic>)['uploadedBy']
                          as String?,
                )
                .whereType<String>()
                .where((id) => !_businessNames.containsKey(id))
                .toSet()
                .toList();
        if (userIds.isNotEmpty) {
          _loadBusinessNames(userIds);
        }

        if (_searchQuery.isNotEmpty && filteredItems.isEmpty) {
          return Center(
            child: Text(
              'No items found for "$_searchQuery"',
              style: const TextStyle(fontSize: 18),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredItems.length,
          itemBuilder:
              (context, index) => _buildItemCard(
                filteredItems[index],
                filteredItems[index].data() as Map<String, dynamic>,
              ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _scaffoldKey,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Request Items from Businesses'),
          backgroundColor: Colors.green.shade700,
        ),
        body: Column(
          children: [_buildSearchBar(), Expanded(child: _buildItemsList())],
        ),
      ),
    );
  }
}
