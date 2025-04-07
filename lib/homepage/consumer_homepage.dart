import 'package:flutter/material.dart';
import '../login_page.dart';
import '../order_page.dart';

class ConsumerHomepage extends StatelessWidget {
  const ConsumerHomepage({super.key});

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FreshSave'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed:
                () =>
                    showSearch(context: context, delegate: SimpleFoodSearch()),
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
        child: Column(
          children: [
            // Store selection dropdown
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButton<String>(
                isExpanded: true,
                hint: const Text(
                  'Select Nearby Store',
                  style: TextStyle(color: Colors.white),
                ),
                items: const [
                  DropdownMenuItem<String>(
                    value: 'Avalon Mall',
                    child: Text(
                      'Avalon Mall',
                      style: TextStyle(color: Colors.black26),
                    ),
                  ),
                  DropdownMenuItem<String>(
                    value: 'Memorial University',
                    child: Text(
                      'Memorial University',
                      style: TextStyle(color: Colors.black26),
                    ),
                  ),
                  DropdownMenuItem<String>(
                    value: 'Water Street',
                    child: Text(
                      'Water Street',
                      style: TextStyle(color: Colors.black26),
                    ),
                  ),
                ],
                onChanged: (value) {},
                underline: Container(),
                icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
              ),
            ),

            // Order button
            Expanded(
              child: Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const OrderPage(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 16,
                    ),
                  ),
                  child: const Text(
                    'Order',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SimpleFoodSearch extends SearchDelegate<String> {
  final foodItems = [
    'Apples',
    'Bread',
    'Milk',
    'Vegetables',
    'Rice',
    'Pasta',
    'Canned Goods',
  ];

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, ''),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildMatchingItems();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildMatchingItems();
  }

  Widget _buildMatchingItems() {
    final matches =
        foodItems
            .where((item) => item.toLowerCase().contains(query.toLowerCase()))
            .toList();

    return ListView.builder(
      itemCount: matches.length,
      itemBuilder: (context, index) {
        final item = matches[index];
        return ListTile(title: Text(item), onTap: () => close(context, item));
      },
    );
  }
}
