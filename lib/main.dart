import 'package:flutter/material.dart';
import 'registration/consumer_registration.dart';
import 'registration/business_registration.dart';
import 'registration/foodbank_registration.dart';
import 'package:firebase_core/firebase_core.dart';
import 'login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const FreshSaveApp());
}

class FreshSaveApp extends StatelessWidget {
  const FreshSaveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FreshSave',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.green),
      home: const LoginPage(),
    );
  }
}

class RegistrationHomePage extends StatelessWidget {
  const RegistrationHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const FreshSaveApp()),
            );
          },
        ),
        title: const Text('Registration'),
        backgroundColor: Colors.green,
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              // App Name.
              const Center(
                child: Text(
                  'Fresh Save',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
              const SizedBox(height: 60),
              const Text(
                'Register as:',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),
              // Role selection dropdown.
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Choose account type',
                ),
                items: const [
                  DropdownMenuItem(value: 'consumer', child: Text('Consumer')),
                  DropdownMenuItem(value: 'business', child: Text('Business')),
                  DropdownMenuItem(value: 'foodbank', child: Text('Food Bank')),
                ],
                onChanged: (value) {
                  if (value == 'consumer') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ConsumerRegistrationPage(),
                      ),
                    );
                  } else if (value == 'business') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const BusinessRegistrationPage(),
                      ),
                    );
                  } else if (value == 'foodbank') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FoodBankRegistrationPage(),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
