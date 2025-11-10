import 'package:dentease/clinic/deantease_analytics.dart';
import 'package:dentease/clinic/dentease_patientList.dart';
import 'package:dentease/dentist/dentist_clinic_front.dart';
import 'package:dentease/dentist/dentist_clinic_sched.dart';
import 'package:dentease/dentist/dentist_clinic_services.dart';
import 'package:dentease/dentist/dentist_list.dart';
import 'package:dentease/dentist/dentist_staff_list.dart';
import 'package:dentease/widgets/background_cont.dart';
import 'package:dentease/widgets/dentistWidgets/dentist_footer.dart';
import 'package:dentease/widgets/dentistWidgets/dentist_header.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DentistPage extends StatefulWidget {
  final String clinicId;
  final String dentistId;
  const DentistPage(
      {super.key, required this.clinicId, required this.dentistId});

  @override
  _DentistPageState createState() => _DentistPageState();
}

class _DentistPageState extends State<DentistPage> {
  final supabase = Supabase.instance.client;
  String? userEmail;
  String? clinicId;
  String? dentistId;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserDetails();
  }

  Future<void> _fetchUserDetails() async {
    final user = supabase.auth.currentUser;

    if (user == null || user.email == null) {
      setState(() => isLoading = false);
      return;
    }

    userEmail = user.email;

    try {
      final response = await supabase
          .from('dentists')
          .select('clinic_id, dentist_id')
          .eq('email', userEmail!)
          .maybeSingle();

      if (response != null) {
        setState(() {
          clinicId = response['clinic_id']?.toString();
          dentistId = response['dentist_id']?.toString();
        });
      }
    } catch (error) {
      print("Error fetching user details: $error");
    }

    setState(() => isLoading = false);
  }

  Widget _buildCustomButton({
    required String title, // kept for semantics/accessibility
    required VoidCallback onTap,
    required ImageProvider backgroundImage,
    EdgeInsetsGeometry margin = const EdgeInsets.only(bottom: 12),
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: margin,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: backgroundImage,
            fit: BoxFit.cover, // same as NearbyClinicsButton
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        child: Center(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.transparent, // same as NearbyClinicsButton
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundCont(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            const DentistHeader(),
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else if (clinicId != null)
              Positioned.fill(
                top: 140,
                bottom: 90,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      _buildCustomButton(
                        title: "Clinic Patients",
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  ClinicPatientListPage(clinicId: clinicId!)),
                        ),
                        backgroundImage:
                            const AssetImage('assets/dentist/patient.png'),
                      ),
                      _buildCustomButton(
                        title: "Clinic Dentists",
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  DentistListPage(clinicId: clinicId!)),
                        ),
                        backgroundImage:
                            const AssetImage('assets/dentist/dentist.png'),
                      ),
                      _buildCustomButton(
                        title: "Clinic Staffs",
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  DentStaffListPage(clinicId: clinicId!)),
                        ),
                        backgroundImage:
                            const AssetImage('assets/dentist/staff.png'),
                      ),
                      _buildCustomButton(
                        title: "Clinic Services",
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  DentistServListPage(clinicId: clinicId!)),
                        ),
                        backgroundImage:
                            const AssetImage('assets/dentist/services.png'),
                      ),
                      _buildCustomButton(
                        title: "Clinic Schedules",
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DentistClinicSchedPage(
                              clinicId: widget.clinicId,
                              dentistId: widget.dentistId,
                            ),
                          ),
                        ),
                        backgroundImage:
                            const AssetImage('assets/dentist/calendar.png'),
                      ),
                      _buildCustomButton(
                        title: "Clinic Details",
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  DentClinicPage(clinicId: clinicId!)),
                        ),
                        backgroundImage:
                            const AssetImage('assets/dentist/details.png'),
                      ),
                      _buildCustomButton(
                        title: "Clinic Analytics",
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  ClinicAnalytics(clinicId: clinicId!)),
                        ),
                        backgroundImage:
                            const AssetImage('assets/dentist/analysis.png'),
                      ),
                      const SizedBox(height: 120), 
                    ],
                  ),
                ),
              ),
            if (dentistId != null)
              DentistFooter(clinicId: widget.clinicId, dentistId: dentistId!),
          ],
        ),
      ),
    );
  }
} 
