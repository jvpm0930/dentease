import 'package:dentease/widgets/background_cont.dart';
import 'package:flutter/material.dart';

class PatientBookingSuccess extends StatelessWidget {
  const PatientBookingSuccess({super.key});

  @override
  Widget build(BuildContext context) {
    return BackgroundCont(
      child: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 80),
                const SizedBox(height: 24),
                const Text(
                  'Your appointment has been booked successfully!',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  child: const Text('Back to Home'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}