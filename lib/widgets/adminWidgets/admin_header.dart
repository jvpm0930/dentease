import 'package:dentease/login/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminHeader extends StatefulWidget {
  const AdminHeader({super.key});

  @override
  _AdminHeaderState createState() => _AdminHeaderState();
}

class _AdminHeaderState extends State<AdminHeader> {
  String? userEmail; // Stores logged-in user email

  @override
  void initState() {
    super.initState();
    _fetchUserEmail();
  }

  // Fetches the currently logged-in user's email
  Future<void> _fetchUserEmail() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      setState(() {
        userEmail = user.email; // Retrieve the email
      });
    }
  }

  Future<void> _logout(BuildContext context) async {
    try {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          content: const Text('Are you sure you want to log out?'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(context, false),
            ),
            ElevatedButton(
              child: const Text('Logout'),
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await Supabase.instance.client.auth.signOut();

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 30, left: 20, right: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(height: 30),
              // Profile Image and Email Column
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Display Email if Available
                  Text(
                    userEmail ?? "Loading...",
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              // Logout Button
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white, size: 28),
                onPressed: () async => await _logout(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
