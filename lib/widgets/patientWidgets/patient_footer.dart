import 'package:dentease/clinic/models/patient_clinicchat_list.dart';
import 'package:dentease/clinic/scanner/camera.dart';
import 'package:dentease/patients/patient_booking_pend.dart';
import 'package:dentease/patients/patient_pagev2.dart';
import 'package:dentease/patients/patient_profile.dart';
import 'package:flutter/material.dart';

class PatientFooter extends StatelessWidget {
  final patientId;
  const PatientFooter({super.key, required this.patientId});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 20, // Side margins for better alignment
          right: 20,
          bottom: 30, // Controls how high it appears from the bottom
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.blue, // Background color
              borderRadius: BorderRadius.circular(30), // Rounded shape
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  spreadRadius: 2,
                  offset: Offset(0, 4), // Drop shadow effect
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildNavImage('assets/icons/home.png', context, PatientPage()),
                _buildNavImage('assets/icons/calendar.png', context,
                    PatientBookingPend(patientId: patientId)),
                _buildNavImage('assets/icons/scan.png', context, ToothScannerPage()),
                _buildNavImage('assets/icons/chat.png', context, PatientClinicChatList(patientId: patientId)),
                _buildNavImage(
                    'assets/icons/profile.png', context, PatientProfile(patientId: patientId)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Builds a navigation item using a custom image icon
  Widget _buildNavImage(String imagePath, BuildContext context, Widget page) {
    return IconButton(
      icon: Image.asset(
        imagePath,
        width: 30, // Adjust size
        height: 30,
        color: Colors.white, // Optional: make it match other icons
      ),
      onPressed: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => page));
      },
    );
  }
}
