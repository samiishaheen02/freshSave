import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class OrderPage extends StatefulWidget {
  final List<Map<String, dynamic>> cartItems;
  final Function() onOrderSuccess;
  final String storeId;
  final String storeName;

  const OrderPage({
    Key? key,
    required this.cartItems,
    required this.onOrderSuccess,
    required this.storeId,
    required this.storeName,
  }) : super(key: key);

  @override
  State<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends State<OrderPage> {
  late final String _storeId;
  late final String _storeName;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  DateTime? _pickupTime;
  bool _isSubmitting = false;
  double _calculatedTotal = 0.0;

  @override
  void initState() {
    super.initState();

    // Use the provided store info or derive from the first cart item.
    _storeId =
        widget.storeId.isNotEmpty
            ? widget.storeId
            : (widget.cartItems.isNotEmpty &&
                    widget.cartItems.first.containsKey('storeId')
                ? widget.cartItems.first['storeId'] as String
                : '');
    _storeName =
        widget.storeName.isNotEmpty
            ? widget.storeName
            : (widget.cartItems.isNotEmpty &&
                    widget.cartItems.first.containsKey('storeName')
                ? widget.cartItems.first['storeName'] as String
                : '');
    debugPrint('OrderPage init: _storeId=$_storeId, _storeName=$_storeName');

    _calculatedTotal = _calculateTotal();
    _prefillUserData();
  }

  void _prefillUserData() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      if (user.displayName != null) _nameController.text = user.displayName!;
      if (user.phoneNumber != null) _phoneController.text = user.phoneNumber!;
    }
  }

  double _calculateTotal() {
    return widget.cartItems.fold(0.0, (sum, item) {
      final price = (item['discountedPrice'] as num?)?.toDouble() ?? 0.0;
      final quantity = (item['orderQuantity'] as int?) ?? 1;
      return sum + (price * quantity);
    });
  }

  Future<void> _selectPickupDate(BuildContext context) async {
    final initialDate = _pickupTime ?? DateTime.now();
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (pickedDate != null) {
      setState(() {
        if (_pickupTime != null) {
          _pickupTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            _pickupTime!.hour,
            _pickupTime!.minute,
          );
        } else {
          final now = DateTime.now();
          _pickupTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            now.hour,
            now.minute,
          );
        }
      });
    }
  }

  Future<void> _selectPickupTime(BuildContext context) async {
    final initialTime =
        _pickupTime != null
            ? TimeOfDay.fromDateTime(_pickupTime!)
            : TimeOfDay.now();
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.green.shade700,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (pickedTime != null) {
      setState(() {
        if (_pickupTime != null) {
          _pickupTime = DateTime(
            _pickupTime!.year,
            _pickupTime!.month,
            _pickupTime!.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        } else {
          final now = DateTime.now();
          _pickupTime = DateTime(
            now.year,
            now.month,
            now.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        }
      });
    }
  }

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pickupTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a pickup date and time')),
      );
      return;
    }
    if (_storeId.isEmpty || _storeName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Store information missing. Please try again.'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final orderRef = FirebaseFirestore.instance.collection('orders').doc();

      final orderData = {
        'customerName': _nameController.text.trim(),
        'customerId': user?.uid,
        'customerEmail': user?.email,
        'phoneNumber': _phoneController.text.trim(),
        'pickupTime': _pickupTime,
        'notes': _notesController.text.trim(),
        'items':
            widget.cartItems.map((item) {
              return {
                'itemId': item['id'],
                'itemName': item['itemName'],
                'quantity': item['orderQuantity'],
                'price': item['discountedPrice'],
                'originalPrice': item['originalPrice'],
                'subtotal': (item['discountedPrice'] * item['orderQuantity'])
                    .toStringAsFixed(2),
                // Include original document path for later stock update
                'originalDocPath': item['originalDocRef'].path,
              };
            }).toList(),
        'total': _calculatedTotal,
        'orderDate': FieldValue.serverTimestamp(),
        'status': 'pending',
        'storeId': _storeId,
        'storeName': _storeName,
        'requiresAction': true,
      };

      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderRef.id)
          .set(orderData);
      widget.onOrderSuccess();
      await _showSuccessDialog(orderRef.id);
    } catch (e) {
      debugPrint('Order submission failed: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Order failed: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _showSuccessDialog(String orderId) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: const Text('Order Confirmed'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 60),
                const SizedBox(height: 16),
                const Text('Your order has been placed successfully!'),
                const SizedBox(height: 16),
                Text('Order #${orderId.substring(0, 8).toUpperCase()}'),
                const SizedBox(height: 8),
                Text(
                  'Store: $_storeName',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Total: \$${_calculatedTotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Pickup: ${DateFormat.yMd().format(_pickupTime!)} ${DateFormat.jm().format(_pickupTime!)}',
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed:
                    () => Navigator.popUntil(context, (route) => route.isFirst),
                child: const Text('Back to Home'),
              ),
            ],
          ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      filled: true,
      fillColor: Colors.white.withOpacity(0.9),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Place Order'),
        backgroundColor: Colors.green.shade700,
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('lib/assets/background.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          color: Colors.black.withOpacity(0.3),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  // Store Information
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.store, color: Colors.green),
                      title: Text(
                        _storeName.isNotEmpty ? _storeName : 'Unknown Store',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Order Summary
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Order Summary',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...widget.cartItems.map(
                            (item) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(child: Text(item['itemName'])),
                                      Text(
                                        '\$${(item['discountedPrice'] * item['orderQuantity']).toStringAsFixed(2)}',
                                      ),
                                    ],
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8.0),
                                    child: Text(
                                      '\$${item['discountedPrice'].toStringAsFixed(2)} × ${item['orderQuantity']}',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Divider(height: 24),
                          Row(
                            children: [
                              const Text(
                                'Total:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '\$${_calculatedTotal.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade700,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Customer Information
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Customer Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _nameController,
                            decoration: _inputDecoration(
                              'Full Name',
                              Icons.person,
                            ),
                            validator:
                                (value) =>
                                    value?.trim().isEmpty ?? true
                                        ? 'Please enter your name'
                                        : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _phoneController,
                            decoration: _inputDecoration(
                              'Phone Number',
                              Icons.phone,
                            ),
                            keyboardType: TextInputType.phone,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty)
                                return 'Please enter your phone number';
                              if (!RegExp(r'^[0-9]{10,}$').hasMatch(value))
                                return 'Enter a valid phone number';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _notesController,
                            decoration: _inputDecoration(
                              'Special Instructions (Optional)',
                              Icons.note,
                            ),
                            maxLines: 3,
                          ),
                          const SizedBox(height: 16),
                          // Pickup Date Selection
                          GestureDetector(
                            onTap: () => _selectPickupDate(context),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.white.withOpacity(0.9),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.date_range,
                                    color: Colors.green,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    _pickupTime == null
                                        ? 'Select Pickup Date'
                                        : 'Pickup Date: ${DateFormat.yMd().format(_pickupTime!)}',
                                    style: TextStyle(
                                      color:
                                          _pickupTime == null
                                              ? Colors.grey[600]
                                              : Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Pickup Time Selection
                          GestureDetector(
                            onTap: () => _selectPickupTime(context),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.white.withOpacity(0.9),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.access_time,
                                    color: Colors.green,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    _pickupTime == null
                                        ? 'Select Pickup Time'
                                        : 'Pickup Time: ${DateFormat.jm().format(_pickupTime!)}',
                                    style: TextStyle(
                                      color:
                                          _pickupTime == null
                                              ? Colors.grey[600]
                                              : Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_pickupTime == null)
                            const Padding(
                              padding: EdgeInsets.only(top: 4.0),
                              child: Text(
                                'Please select a pickup date and time',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Submit Order Button
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitOrder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child:
                        _isSubmitting
                            ? const CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            )
                            : const Text(
                              'Place Order',
                              style: TextStyle(fontSize: 18),
                            ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
