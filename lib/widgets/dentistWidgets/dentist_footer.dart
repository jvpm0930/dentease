import 'package:dentease/clinic/models/clinicChat_support.dart';
import 'package:dentease/dentist/dentist_bookings_pend.dart';
import 'package:dentease/dentist/dentist_profile.dart';
import 'package:dentease/dentist/dentist_page.dart';
import 'package:dentease/clinic/models/clinic_patientchat_list.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DentistFooter extends StatefulWidget {
  final String dentistId;
  final String clinicId;

  const DentistFooter(
      {super.key, required this.dentistId, required this.clinicId});

  @override
  _DentistFooterState createState() => _DentistFooterState();
}

class _DentistFooterState extends State<DentistFooter> {
  final supabase = Supabase.instance.client;
  String? patientId;

  @override
  void initState() {
    super.initState();
    fetchPatientId();
  }

  /// Fetch patientId from bookings where clinicId matches
  Future<void> fetchPatientId() async {
    final response = await supabase
        .from('bookings')
        .select('patient_id')
        .eq('clinic_id', widget.clinicId)
        .maybeSingle(); // Fetch a single patient (modify as needed)

    if (response != null && response['patient_id'] != null) {
      setState(() {
        patientId = response['patient_id'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 20,
      right: 20,
      bottom: 30,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.blue,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavImage(
                'assets/icons/home.png',
                context,
                DentistPage(
                    clinicId: widget.clinicId, dentistId: widget.dentistId)),
            _buildNavImage('assets/icons/calendar.png', context,
                DentistBookingPendPage(clinicId: widget.clinicId, dentistId: widget.dentistId)),
            _buildNavImage(
                'assets/icons/chat.png', context, ClinicPatientChatList(clinicId: widget.clinicId)),
            _buildNavImage(
                'assets/icons/customer-service.png', context, ClinicChatPageforAdmin(clinicId: widget.clinicId, adminId: 'eee5f574-903b-4575-a9d9-2f69e58f1801')),
            _buildNavImage('assets/icons/profile.png', context,
                DentistProfile(dentistId: widget.dentistId)),
          ],
        ),
      ),
    );
  }

  /// Builds a navigation button with an image
  Widget _buildNavImage(String imagePath, BuildContext context, Widget? page) {
    return IconButton(
      icon: Image.asset(
        imagePath,
        width: 30,
        height: 30,
        color: Colors.white,
      ),
      onPressed: page != null
          ? () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => page),
              );
            }
          : null, // Disable button if page is null
    );
  }

}
