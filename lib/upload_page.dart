import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UploadPage extends StatefulWidget {
  const UploadPage({super.key});

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _originalPriceController = TextEditingController();
  final TextEditingController _discountedPriceController = TextEditingController();

  DateTime? _selectedDate;

  // Date picker function
  Future<void> _pickDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Item'),
        centerTitle: true,
        backgroundColor: Colors.green.shade600,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Item Name
            const Text("Name of Item"),
            const SizedBox(height: 8),
            TextField(
              controller: _itemNameController,
              decoration: const InputDecoration(
                hintText: 'e.g. Apples',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            // Quantity
            const Text("Quantity"),
            const SizedBox(height: 8),
            TextField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'e.g. 10',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            // Expiry Date
            const Text("Expiry Date"),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _pickDate(context),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _selectedDate == null
                      ? 'Select date'
                      : DateFormat('yyyy-MM-dd').format(_selectedDate!),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Price Section
            const Text("Price"),
            const SizedBox(height: 8),
            Row(
              children: [
                // Original Price
                Expanded(
                  child: TextField(
                    controller: _originalPriceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Original Price',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Discounted Price
                Expanded(
                  child: TextField(
                    controller: _discountedPriceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Discounted Price',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 40),

            // Submit Button
            Center(
              child: 
              ElevatedButton(
              onPressed: () async {
                final user = FirebaseAuth.instance.currentUser;

                if (user == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('User not logged in')),
                  );
                  return;
                }

                try {
                  await FirebaseFirestore.instance.collection('food_items').add({
                    'itemName': _itemNameController.text.trim(),
                    'quantity': int.parse(_quantityController.text.trim()),
                    'expiryDate': _selectedDate?.toIso8601String(),
                    'originalPrice': double.parse(_originalPriceController.text.trim()),
                    'discountedPrice': double.parse(_discountedPriceController.text.trim()),
                    'uploadedBy': user.uid,
                    'timestamp': FieldValue.serverTimestamp(),
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Item uploaded successfully!')),
                  );

                  // Optionally clear form
                  _itemNameController.clear();
                  _quantityController.clear();
                  _originalPriceController.clear();
                  _discountedPriceController.clear();
                  setState(() => _selectedDate = null);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Upload failed: $e')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                backgroundColor: Colors.green.shade600,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Submit',
                style: TextStyle(fontSize: 18),
              ),
            ),
            )
          ],
        ),
      ),
    );
  }
}
