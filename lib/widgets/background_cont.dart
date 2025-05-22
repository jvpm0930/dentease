import 'package:flutter/material.dart';

class BackgroundCont extends StatelessWidget {
  final Widget child;

  const BackgroundCont({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/background1.png'), //  Correct path
          fit: BoxFit.cover, // Makes the image cover the full screen
        ),
      ),
      child: child, // Pass the page content inside this container
    );
  }
}