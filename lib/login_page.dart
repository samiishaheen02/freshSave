import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:freshsave_app/main.dart';
import 'business/business_homepage.dart';
import 'consumer/consumer_homepage.dart';
import 'foodbank/foodbank_homepage.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Controllers for email and password.
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  Future<void> _login() async {
    try {
      // Sign in using FirebaseAuth.
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text.trim(),
      );
      final user = credential.user;
      if (user == null) {
        throw Exception("Login failed: user is null");
      }
      // Retrieve the user document from Firestore to get the registered role.
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
      if (!userDoc.exists) {
        throw Exception("User record not found");
      }
      final String role = userDoc.get('role');

      // Navigate based on the user's role.
      switch (role) {
        case 'consumer':
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const ConsumerHomepage()),
          );
          break;
        case 'business':
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const BusinessHomepage()),
          );
          break;
        case 'foodbank':
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const FoodBankHomepage()),
          );
          break;
        default:
          throw Exception("Invalid user role");
      }
    } catch (e, stackTrace) {
      debugPrint('🔥 ERROR: $e');
      debugPrint('📍 STACK TRACE:\n$stackTrace');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Login failed: ${e.toString()}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Fresh Save Login'),
        centerTitle: true,
        backgroundColor: Colors.green.shade600,
      ),
      body: Stack(
        children: [
          // Background image.
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('lib/assets/background.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Dark overlay.
          Container(color: Colors.black.withOpacity(0.5)),
          // Content.
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const SizedBox(height: 40),
                // Email text field.
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                  child: TextField(
                    controller: _email,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      labelStyle: TextStyle(color: Colors.white),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(height: 20),
                // Password text field.
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                  child: TextField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      labelStyle: TextStyle(color: Colors.white),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(height: 30),
                // Login button.
                ElevatedButton(
                  onPressed: _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text('Login', style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(height: 16),
                // Registration navigation.
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RegistrationHomePage(),
                      ),
                    );
                  },
                  child: const Text(
                    "Don't have an account? Register here",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
