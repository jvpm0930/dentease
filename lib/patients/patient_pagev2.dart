import 'package:dentease/widgets/background_cont.dart';
import 'package:dentease/widgets/clinicWidgets/clinic_slider.dart';
import 'package:dentease/widgets/patientWidgets/patient_footer.dart';
import 'package:dentease/widgets/patientWidgets/patient_header.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PatientPage extends StatefulWidget {
  const PatientPage({super.key});

  @override
  _PatientPageState createState() => _PatientPageState();
}

class _PatientPageState extends State<PatientPage> {
  final supabase = Supabase.instance.client;
  String? userEmail;
  String? clinicId;
  String? patientId;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserDetails();
  }

  Future<void> _fetchUserDetails() async {
    final user = supabase.auth.currentUser;

    if (user == null || user.email == null) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    userEmail = user.email; // Assign userEmail

    try {
      final response = await supabase
          .from('patients')
          .select('clinic_id, patient_id')
          .eq('email', userEmail!) // Ensure userEmail is not null
          .maybeSingle();

      if (response != null) {
        setState(() {
          clinicId = response['clinic_id']?.toString();
          patientId = response['patient_id']?.toString();
        });
      }
    } catch (error) {
      print("Error fetching user details: $error");
    }

    setState(() {
      isLoading = false;
    });
  }


  @override
  Widget build(BuildContext context) {
    return BackgroundCont(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            const PatientHeader(),
            const SizedBox(height: 30),
            Center(child: const ClinicCarousel()), // Centering the carousel
            if (patientId != null)
              PatientFooter(patientId: patientId!),
          ],
        ),
      ),
    );
  }

}