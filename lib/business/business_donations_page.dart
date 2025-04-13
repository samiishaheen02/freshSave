import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class BusinessDonationsPage extends StatefulWidget {
  const BusinessDonationsPage({super.key});

  @override
  State<BusinessDonationsPage> createState() => _BusinessDonationsPageState();
}

class _BusinessDonationsPageState extends State<BusinessDonationsPage> {
  final List<String> _statusFilters = [
    'All',
    'Pending',
    'Accepted',
    'Rejected',
    'Donated to Charity',
  ];
  String _selectedFilter = 'All';

  String _formatTimestamp(dynamic ts) {
    if (ts == null) return 'Not specified';
    try {
      DateTime dt;
      if (ts is Timestamp) {
        dt = ts.toDate();
      } else if (ts is DateTime) {
        dt = ts;
      } else if (ts is String) {
        dt = DateTime.parse(ts);
      } else {
        return 'Not specified';
      }
      return DateFormat('MMM dd, yyyy - h:mm a').format(dt);
    } catch (e) {
      return 'Invalid date';
    }
  }

  Widget _buildFoodBankInfo(String receivedBy, String? receivedByName) {
    if (receivedByName != null && receivedByName.trim().isNotEmpty) {
      return Text(
        'Food Bank: $receivedByName',
        style: const TextStyle(color: Colors.grey),
        overflow: TextOverflow.ellipsis,
      );
    } else if (receivedBy.isNotEmpty) {
      return FutureBuilder<DocumentSnapshot>(
        future:
            FirebaseFirestore.instance
                .collection('users')
                .doc(receivedBy)
                .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Text(
              'Food Bank: Loading...',
              style: TextStyle(color: Colors.grey),
              overflow: TextOverflow.ellipsis,
            );
          }
          if (snapshot.hasData &&
              snapshot.data != null &&
              snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            final foodBankName =
                data['name'] ?? data['orgName'] ?? 'Unknown Food Bank';
            return Text(
              'Food Bank: $foodBankName',
              style: const TextStyle(color: Colors.grey),
              overflow: TextOverflow.ellipsis,
            );
          }
          return const Text(
            'Food Bank: Unknown',
            style: TextStyle(color: Colors.grey),
            overflow: TextOverflow.ellipsis,
          );
        },
      );
    }
    return const SizedBox();
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.green;
      case 'donated_to_charity':
      case 'donated':
        return Colors.blue;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildStatusChip(String status) {
    return Chip(
      label: Text(
        status.toUpperCase(),
        style: const TextStyle(fontSize: 12, color: Colors.white),
      ),
      backgroundColor: _getStatusColor(status),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    );
  }

  Future<void> _updateDonationStatus(
    DocumentReference docRef,
    String newStatus, {
    String? originalItemId,
    int? donatedQuantity,
  }) async {
    try {
      await docRef.update({
        'status': newStatus,
        if (newStatus == 'accepted') 'receivedAt': FieldValue.serverTimestamp(),
      });

      if (newStatus == 'accepted' &&
          originalItemId != null &&
          donatedQuantity != null) {
        DocumentReference foodItemRef = FirebaseFirestore.instance
            .collection('food_items')
            .doc(originalItemId);
        DocumentSnapshot foodSnap = await foodItemRef.get();
        if (foodSnap.exists) {
          final foodData = foodSnap.data() as Map<String, dynamic>;
          int availableQty = foodData['quantity'] ?? 0;
          if (donatedQuantity > availableQty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Donation quantity exceeds available stock.'),
              ),
            );
          } else {
            int remainingQty = availableQty - donatedQuantity;
            await foodItemRef.update({'quantity': remainingQty});
          }
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Donation status updated to ${newStatus.replaceAll('_', ' ')}',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating status: $e'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildDonationCard(
    Map<String, dynamic> donation,
    DocumentReference docRef,
  ) {
    final expiryDate =
        donation['expiryDate'] != null
            ? DateTime.tryParse(donation['expiryDate'])
            : null;
    final isExpired = expiryDate != null && expiryDate.isBefore(DateTime.now());
    final donationTimestamp = donation['donatedAt'] ?? donation['requestedAt'];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 3,
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
                    donation['itemName'] ?? 'Unnamed Item',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _buildStatusChip(donation['status'] ?? 'unknown'),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Icon(Icons.scale, size: 20, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Quantity: ${donation['quantity']}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 20,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Expiry: ${expiryDate != null ? DateFormat('MMM dd, yyyy').format(expiryDate) : 'Not specified'}',
                    style: TextStyle(
                      color: isExpired ? Colors.red : Colors.grey,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Icon(Icons.access_time, size: 20, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Requested: ${_formatTimestamp(donationTimestamp)}',
                    style: const TextStyle(color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildFoodBankInfo(
              donation['receivedBy'] ?? '',
              donation['receivedByName'],
            ),
            if (donation['status'] == 'accepted') ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 20,
                    color: Colors.green.shade600,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Accepted: ${_formatTimestamp(donation['receivedAt'])}',
                      style: const TextStyle(color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (donation['status'] == 'donated_to_charity') ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.volunteer_activism,
                    size: 20,
                    color: Colors.blue.shade600,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Donated to Charity: ${_formatTimestamp(donation['donatedToCharityAt'])}',
                      style: const TextStyle(color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],

            if (donation['status'] == 'pending') ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isExpired ? Colors.grey : Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed:
                          isExpired
                              ? null
                              : () {
                                _updateDonationStatus(
                                  docRef,
                                  'accepted',
                                  originalItemId: donation['originalItemId'],
                                  donatedQuantity: donation['quantity'],
                                );
                              },
                      child: const Text('Accept'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        _updateDonationStatus(docRef, 'rejected');
                      },
                      child: const Text('Decline'),
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

  Widget _buildFilterDropdown() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: DropdownButtonFormField<String>(
        value: _selectedFilter,
        decoration: InputDecoration(
          labelText: 'Filter by Status',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        items:
            _statusFilters
                .map(
                  (String value) => DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  ),
                )
                .toList(),
        onChanged: (String? newValue) {
          if (newValue != null) {
            setState(() {
              _selectedFilter = newValue;
            });
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Center(child: Text('Please sign in to view donations'));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Donations'),
        backgroundColor: Colors.green.shade700,
      ),
      body: Column(
        children: [
          _buildFilterDropdown(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection('donated_items')
                      .where('donatedBy', isEqualTo: currentUser.uid)
                      .orderBy('requestedAt', descending: true)
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.handshake,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No donation records found',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Apply filtering based on selected status.
                final filteredDocs =
                    snapshot.data!.docs.where((doc) {
                      final donation = doc.data() as Map<String, dynamic>;
                      if (_selectedFilter == 'All') return true;
                      if (_selectedFilter == 'Pending')
                        return donation['status'] == 'pending';
                      if (_selectedFilter == 'Accepted')
                        return donation['status'] == 'accepted';
                      if (_selectedFilter == 'Rejected')
                        return donation['status'] == 'rejected';
                      if (_selectedFilter == 'Donated to Charity')
                        return donation['status'] == 'donated_to_charity';
                      return true;
                    }).toList();

                if (filteredDocs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.filter_alt_off,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No donations match the filter',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final docSnapshot = filteredDocs[index];
                    final donation = docSnapshot.data() as Map<String, dynamic>;
                    return _buildDonationCard(donation, docSnapshot.reference);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
