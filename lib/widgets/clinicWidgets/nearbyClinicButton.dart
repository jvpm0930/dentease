import 'package:flutter/material.dart';

class NearbyClinicsButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String imagePath;

  const NearbyClinicsButton({
    super.key,
    required this.onPressed,
    this.imagePath = 'assets/nearby.png', // your custom image
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(imagePath),
            fit: BoxFit.cover, // or BoxFit.contain, depending on your image
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        child: const Center(
          child: Text(
            'Nearby Clinics',
            style: TextStyle(
              color: Colors.transparent,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
