import 'package:dentease/clinic/models/clinicChat_support.dart';
import 'package:dentease/clinic/models/clinic_patientchat_list.dart';
import 'package:dentease/staff/staff_bookings_pend.dart';
import 'package:dentease/staff/staff_profile.dart';
import 'package:dentease/staff/staff_page.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StaffFooter extends StatefulWidget {
  final String staffId;
  final String clinicId;

  const StaffFooter({
    super.key,
    required this.staffId,
    required this.clinicId,
  });

  @override
  _StaffFooterState createState() => _StaffFooterState();
}

class _StaffFooterState extends State<StaffFooter> {
  final supabase = Supabase.instance.client;
  String? patientId;

  @override
  void initState() {
    super.initState();
    fetchPatientId();
  }

  Future<void> fetchPatientId() async {
    try {
      final response = await supabase
          .from('bookings')
          .select('patient_id')
          .eq('clinic_id', widget.clinicId)
          .maybeSingle();

      if (response != null && response['patient_id'] != null) {
        setState(() {
          patientId = response['patient_id'];
        });
      }
    } catch (e) {
      debugPrint('Error fetching patient ID: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 20,
          right: 20,
          bottom: 30,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(30),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  spreadRadius: 2,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildNavImage(
                  'assets/icons/home.png',
                  context,
                  StaffPage(
                    clinicId: widget.clinicId,
                    staffId: widget.staffId,
                  ),
                ),
                _buildNavImage(
                  'assets/icons/calendar.png',
                  context,
                  StaffBookingPendPage(
                    clinicId: widget.clinicId,
                    staffId: widget.staffId,
                  ),
                ),
                _buildNavImage(
                  'assets/icons/chat.png',
                  context,
                  ClinicPatientChatList(
                    clinicId: widget.clinicId,
                  ),
                ),
                _buildNavImage(
                  'assets/icons/customer-service.png',
                  context,
                  ClinicChatPageforAdmin(
                    clinicId: widget.clinicId,
                    adminId: 'eee5f574-903b-4575-a9d9-2f69e58f1801',
                  ),
                ),
                _buildNavImage(
                  'assets/icons/profile.png',
                  context,
                  StaffProfile(staffId: widget.staffId),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNavImage(String imagePath, BuildContext context, Widget page) {
    return IconButton(
      icon: Image.asset(
        imagePath,
        width: 30,
        height: 30,
        color: Colors.white,
      ),
      onPressed: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => page));
      },
    );
  }
}
