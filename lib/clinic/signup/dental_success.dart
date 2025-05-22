import 'package:dentease/login/login_screen.dart';
import 'package:dentease/widgets/background_container.dart';
import 'package:flutter/material.dart';

class DentalSuccess extends StatelessWidget {
  const DentalSuccess({super.key});

  @override
  Widget build(BuildContext context) {
    return BackgroundContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                  Image.asset('assets/logo2.png', width: 500),
                  SizedBox(height: 20),
                  Text(
                    'You can now Login, Wait for admin verification for your Clinic application',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 20),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => LoginScreen()),
                    ),
                    child: Text(
                      'Login',
                      style: TextStyle(
                        color: Colors.white, // Dark blue text
                      ),
                    ),
                  ),
                ],
            )
          )
        ),
      )
    );
  }
}