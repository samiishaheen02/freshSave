import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../login_page.dart';
import 'order_page.dart';
import 'order_history_page.dart';

class ConsumerHomepage extends StatefulWidget {
  const ConsumerHomepage({Key? key}) : super(key: key);

  @override
  State<ConsumerHomepage> createState() => _ConsumerHomepageState();
}

class _ConsumerHomepageState extends State<ConsumerHomepage> {
  List<Map<String, dynamic>> _cartItems = [];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  final GlobalKey<ScaffoldMessengerState> _scaffoldKey =
      GlobalKey<ScaffoldMessengerState>();
  final Map<String, String> _businessNames = {};
  bool _isLoadingBusinessNames = false;

  Map<String, int> _desiredQuantities = {};

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

  void _logout(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Logout?'),
            content: const Text('Do you want to sign out?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                    (route) => false,
                  );
                },
                child: const Text('Yes', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );
  }

  Future<void> _addToCart(
    DocumentSnapshot doc,
    Map<String, dynamic> item,
    int desiredQuantity,
  ) async {
    try {
      final freshDoc = await doc.reference.get();
      if (!freshDoc.exists || freshDoc['quantity'] <= 0) {
        _showSnackBar('${item['itemName']} is no longer available');
        return;
      }

      final storeId = item['uploadedBy'] ?? '';
      final storeName = _businessNames[storeId] ?? 'Local Business';

      if (_cartItems.isNotEmpty) {
        final existingStoreId = _cartItems.first['storeId'];
        if (existingStoreId != storeId) {
          _showSnackBar('All items in the cart must be from the same store.');
          return;
        }
      }

      final cartIndex = _cartItems.indexWhere((i) => i['id'] == doc.id);
      int currentCartQuantity = 0;
      if (cartIndex >= 0) {
        currentCartQuantity = _cartItems[cartIndex]['orderQuantity'];
      }

      final availableStock = (item['quantity'] ?? 0) - currentCartQuantity;
      if (desiredQuantity > availableStock) {
        _showSnackBar('Requested quantity exceeds available stock');
        return;
      }

      setState(() {
        if (cartIndex >= 0) {
          _cartItems[cartIndex]['orderQuantity'] += desiredQuantity;
        } else {
          _cartItems.add({
            ...item,
            'id': doc.id,
            'orderQuantity': desiredQuantity,
            'originalDocRef': doc.reference,
            'storeId': storeId,
            'storeName': storeName,
          });
        }
      });

      _showSnackBar('Added $desiredQuantity x ${item['itemName']} to cart');
    } catch (e) {
      _showSnackBar('Failed to add item: $e');
    }
  }

  void _viewOrderHistory(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar('Please login to view order history');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderHistoryPage(userId: user.uid),
      ),
    );
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
                        _isSearching = false;
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
            _isSearching = query.isNotEmpty;
          });
        },
      ),
    );
  }

  Widget _buildItemCard(DocumentSnapshot doc, Map<String, dynamic> item) {
    if (!_desiredQuantities.containsKey(doc.id)) {
      _desiredQuantities[doc.id] = 1;
    }
    int selectedQuantity = _desiredQuantities[doc.id]!;

    final expiryDate =
        item['expiryDate'] != null
            ? DateTime.tryParse(item['expiryDate'])
            : null;
    final isExpired = expiryDate != null && expiryDate.isBefore(DateTime.now());
    final cartItem = _cartItems.firstWhere(
      (i) => i['id'] == doc.id,
      orElse: () => {},
    );
    final cartQuantity = cartItem['orderQuantity'] ?? 0;
    final remainingQuantity = (item['quantity'] ?? 0) - cartQuantity;
    final businessName =
        item['uploadedBy'] != null
            ? _businessNames[item['uploadedBy']] ?? 'Local Business'
            : 'Local Business';

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
                Text(
                  'Original: \$${item['originalPrice']?.toStringAsFixed(2) ?? '0.00'}',
                  style: const TextStyle(
                    decoration: TextDecoration.lineThrough,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Discounted: \$${item['discountedPrice']?.toStringAsFixed(2) ?? '0.00'}',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
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
            if (cartQuantity > 0) ...[
              const SizedBox(height: 4),
              Text(
                'In Cart: $cartQuantity',
                style: TextStyle(color: Colors.green.shade700),
              ),
            ],
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
                          if (_desiredQuantities[doc.id]! > 1) {
                            _desiredQuantities[doc.id] =
                                _desiredQuantities[doc.id]! - 1;
                          }
                        });
                      },
                    ),
                    Text('$selectedQuantity'),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        setState(() {
                          if (selectedQuantity < remainingQuantity) {
                            _desiredQuantities[doc.id] = selectedQuantity + 1;
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
                      remainingQuantity <= 0
                          ? null
                          : () => _addToCart(
                            doc,
                            item,
                            _desiredQuantities[doc.id]!,
                          ),
                  child: Text(
                    remainingQuantity <= 0
                        ? 'Out of Stock'
                        : 'Add ${_desiredQuantities[doc.id]} to Order',
                  ),
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
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          );
        }
        if (snapshot.hasError) {
          debugPrint('Firestore error: ${snapshot.error}');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Error loading items',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Please check your internet connection',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _businessNames.clear();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.storefront, color: Colors.white, size: 48),
                SizedBox(height: 16),
                Text(
                  'No items available',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ],
            ),
          );
        }

        final allItems = snapshot.data!.docs;
        final filteredItems =
            _isSearching
                ? allItems.where((doc) {
                  final item = doc.data() as Map<String, dynamic>;
                  final name = item['itemName']?.toString().toLowerCase() ?? '';
                  return name.contains(_searchQuery.toLowerCase());
                }).toList()
                : allItems;

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

        if (_isSearching && filteredItems.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.search_off, size: 48, color: Colors.white),
                const SizedBox(height: 16),
                Text(
                  'No items found for "$_searchQuery"',
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
              ],
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
          title: const Text('FreshSave'),
          backgroundColor: Colors.green.shade700,
          actions: [
            IconButton(
              icon: const Icon(Icons.history),
              onPressed: () => _viewOrderHistory(context),
              tooltip: 'Order History',
            ),
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_cart),
                  onPressed:
                      _cartItems.isEmpty
                          ? null
                          : () async {
                            final storeId = _cartItems.first['storeId'] ?? '';
                            final storeName =
                                _cartItems.first['storeName'] ?? '';
                            debugPrint(
                              ' OrderPage with storeId=$storeId, storeName=$storeName',
                            );
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => OrderPage(
                                      cartItems: _cartItems,
                                      onOrderSuccess: () {
                                        setState(() {
                                          _cartItems.clear();
                                        });
                                      },
                                      storeId: storeId,
                                      storeName: storeName,
                                    ),
                              ),
                            );
                          },
                ),
                if (_cartItems.isNotEmpty)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        _cartItems
                            .fold<int>(
                              0,
                              (sum, item) =>
                                  sum + (item['orderQuantity'] as int),
                            )
                            .toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => _logout(context),
            ),
          ],
        ),
        body: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('lib/assets/background.jpg'),
              fit: BoxFit.cover,
            ),
          ),
          child: Container(
            color: Colors.black.withOpacity(0.6),
            child: Column(
              children: [_buildSearchBar(), Expanded(child: _buildItemsList())],
            ),
          ),
        ),
      ),
    );
  }
}
