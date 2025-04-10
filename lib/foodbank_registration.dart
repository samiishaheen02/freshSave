import 'package:flutter/material.dart';

class FoodBankRegistrationPage extends StatefulWidget {
  const FoodBankRegistrationPage({super.key});

  @override
  State<FoodBankRegistrationPage> createState() => _FoodBankRegistrationPageState();
}

class _FoodBankRegistrationPageState extends State<FoodBankRegistrationPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _orgNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _orgNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _register() {
    if (_formKey.currentState!.validate()) {
      String org = _orgNameController.text.trim();
      String email = _emailController.text.trim();
      String password = _passwordController.text;

      print('Registering Food Bank: $org with email $email');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Food Bank Registered Successfully!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Food Bank Registration')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _orgNameController,
                decoration: const InputDecoration(labelText: 'Organization Name'),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Enter organization name' : null,
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Contact Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Enter contact email';
                  if (!value.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (value) =>
                    value != null && value.length >= 6 ? null : 'Minimum 6 characters',
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _confirmPasswordController,
                decoration: const InputDecoration(labelText: 'Confirm Password'),
                obscureText: true,
                validator: (value) {
                  if (value != _passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: _register,
                child: const Text('Register'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
