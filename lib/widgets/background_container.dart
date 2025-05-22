import 'package:flutter/material.dart';

class BackgroundContainer extends StatelessWidget {
  final Widget child;

  const BackgroundContainer({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/background2.png'), //  Correct path
          fit: BoxFit.cover, // Makes the image cover the full screen
        ),
      ),
      child: child, // Pass the page content inside this container
    );
  }
}
