import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ReceivedPage extends StatefulWidget {
  const ReceivedPage({Key? key}) : super(key: key);

  @override
  State<ReceivedPage> createState() => _ReceivedPageState();
}

class _ReceivedPageState extends State<ReceivedPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Not specified';
    return DateFormat('MMM dd, yyyy - hh:mm a').format(timestamp.toDate());
  }

  String _formatExpiryDate(String? isoDate) {
    if (isoDate == null) return 'Not specified';
    final parsedDate = DateTime.tryParse(isoDate);
    if (parsedDate == null) return 'Invalid date';
    return DateFormat('MMM dd, yyyy').format(parsedDate);
  }

  bool _isExpired(String? expiryDate) {
    if (expiryDate == null) return false;
    final parsedDate = DateTime.tryParse(expiryDate);
    if (parsedDate == null) return false;
    return parsedDate.isBefore(DateTime.now());
  }

  Future<void> _updateDonationStatus({
    required DocumentReference docRef,
    required String status,
    String? originalItemId,
    int? donatedQuantity,
  }) async {
    try {
      await docRef.update({
        'status': status,
        if (status == 'accepted') 'receivedAt': FieldValue.serverTimestamp(),
        if (status == 'donated_to_charity')
          'donatedToCharityAt': FieldValue.serverTimestamp(),
      });

      if (status == 'accepted' &&
          originalItemId != null &&
          donatedQuantity != null) {
        DocumentReference foodItemRef = FirebaseFirestore.instance
            .collection('food_items')
            .doc(originalItemId);
        DocumentSnapshot foodSnap = await foodItemRef.get();
        if (foodSnap.exists) {
          Map<String, dynamic> foodData =
              foodSnap.data() as Map<String, dynamic>;
          int availableQty = foodData['quantity'] ?? 0;
          if (donatedQuantity > availableQty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Donation quantity exceeds available stock.'),
              ),
            );
          } else {
            int remainingQty = availableQty - donatedQuantity;

            if (remainingQty == 0) {
              await foodItemRef.update({'quantity': 0, 'status': 'pending'});
            } else {
              await foodItemRef.update({'quantity': remainingQty});
            }
          }
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status updated to ${status.replaceAll('_', ' ')}'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Widget _buildDonationCard({
    required Map<String, dynamic> donation,
    required DocumentReference docRef,
    bool showAcceptReject = false,
    bool showDonateToCharity = false,
  }) {
    final isExpired = _isExpired(donation['expiryDate']);
    final isPartial = donation['isPartial'] ?? false;
    final originalQty =
        (donation['originalQuantity'] as int?) ??
        (donation['quantity'] as int? ?? 0);
    final currentQty = (donation['quantity'] as int?) ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
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
                    donation['itemName']?.toString() ?? 'Unnamed Item',
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
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'EXPIRED',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'From: ${donation['donatedByName']?.toString() ?? 'Unknown Business'}',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 8),
            Text(
              'Quantity: $currentQty${isPartial ? ' (of $originalQty)' : ''}',
            ),
            const SizedBox(height: 8),
            Text(
              'Expiry: ${_formatExpiryDate(donation['expiryDate']?.toString())}',
              style: TextStyle(
                color: isExpired ? Colors.red : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            if (donation['status'] == 'pending')
              Text(
                'Requested: ${_formatDate(donation['donatedAt'] as Timestamp?)}',
              ),
            if (donation['status'] == 'accepted')
              Text(
                'Received: ${_formatDate(donation['receivedAt'] as Timestamp?)}',
              ),
            if (donation['status'] == 'donated_to_charity')
              Text(
                'Donated to charity: ${_formatDate(donation['donatedToCharityAt'] as Timestamp?)}',
              ),

            if (showAcceptReject) ...[
              const SizedBox(height: 16),
              _buildAcceptRejectButtons(docRef, donation, isExpired),
            ],

            if (showDonateToCharity) ...[
              const SizedBox(height: 16),
              _buildDonateToCharityButton(docRef),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAcceptRejectButtons(
    DocumentReference docRef,
    Map<String, dynamic> donation,
    bool isExpired,
  ) {
    return Column(
      children: [
        if (isExpired)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'This item has expired and cannot be accepted',
              style: TextStyle(color: Colors.red),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isExpired ? Colors.grey : Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed:
                    isExpired
                        ? null
                        : () async {
                          await _updateDonationStatus(
                            docRef: docRef,
                            status: 'accepted',
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
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () async {
                  await _updateDonationStatus(
                    docRef: docRef,
                    status: 'rejected',
                  );
                },
                child: const Text('Reject'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDonateToCharityButton(DocumentReference docRef) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: () async {
        await _updateDonationStatus(
          docRef: docRef,
          status: 'donated_to_charity',
        );
      },
      child: const Text('Donate to Charity'),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      return const Center(child: Text('Please sign in to view donations'));
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Received Donations'),
          backgroundColor: Colors.green.shade600,
          bottom: TabBar(
            tabs: [
              const Tab(text: 'Pending'),
              const Tab(text: 'Accepted'),
              Tab(
                child: StreamBuilder<QuerySnapshot>(
                  stream:
                      FirebaseFirestore.instance
                          .collection('donated_items')
                          .where('receivedBy', isEqualTo: currentUserId)
                          .where('status', isEqualTo: 'donated_to_charity')
                          .snapshots(),
                  builder: (context, snapshot) {
                    final count = snapshot.data?.docs.length ?? 0;
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Charity'),
                        if (count > 0) ...[
                          const SizedBox(width: 4),
                          CircleAvatar(
                            radius: 10,
                            backgroundColor: Colors.red,
                            child: Text(
                              count.toString(),
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, Color(0xFFE8F5E9)],
            ),
          ),
          child: TabBarView(
            children: [
              _buildDonationsList(
                status: 'pending',
                showAcceptReject: true,
                emptyMessage: 'No pending donations',
                userId: currentUserId,
              ),
              _buildDonationsList(
                status: 'accepted',
                showDonateToCharity: true,
                emptyMessage: 'No accepted donations',
                userId: currentUserId,
              ),
              _buildDonationsList(
                status: 'donated_to_charity',
                emptyMessage: 'No charity donations',
                userId: currentUserId,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDonationsList({
    required String status,
    bool showAcceptReject = false,
    bool showDonateToCharity = false,
    required String emptyMessage,
    required String userId,
  }) {
    Query query = FirebaseFirestore.instance
        .collection('donated_items')
        .where('receivedBy', isEqualTo: userId)
        .where('status', isEqualTo: status);

    if (status == 'pending') {
      query = query.orderBy('donatedAt', descending: true);
    } else if (status == 'accepted') {
      query = query.orderBy('receivedAt', descending: true);
    } else if (status == 'donated_to_charity') {
      query = query.orderBy('donatedToCharityAt', descending: true);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Error loading donations',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Please try again later',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inbox_outlined,
                  size: 48,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  emptyMessage,
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final donation = doc.data() as Map<String, dynamic>;
            return _buildDonationCard(
              donation: donation,
              docRef: doc.reference,
              showAcceptReject: showAcceptReject,
              showDonateToCharity: showDonateToCharity,
            );
          },
        );
      },
    );
  }
}
