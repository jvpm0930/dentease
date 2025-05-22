import 'package:dentease/clinic/models/clinic_patientchat_list.dart';
import 'package:dentease/staff/staff_bookings_pend.dart';
import 'package:dentease/staff/staff_profile.dart';
import 'package:dentease/staff/staff_page.dart';
import 'package:flutter/material.dart';

class StaffFooter extends StatelessWidget {
  final String staffId;
  final String clinicId;
  const StaffFooter({super.key, required this.staffId, required this.clinicId});

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
                _buildNavImage('assets/icons/home.png', context, StaffPage(clinicId: clinicId, staffId: staffId)),
                _buildNavImage(
                    'assets/icons/calendar.png', context,  StaffBookingPendPage(clinicId: clinicId, staffId: staffId)),
                _buildNavImage('assets/icons/chat.png', context,  ClinicPatientChatList(clinicId: clinicId)),
                _buildNavImage(
                    'assets/icons/profile.png', context,  StaffProfile(staffId: staffId)),
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
