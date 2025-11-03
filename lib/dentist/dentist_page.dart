import 'package:dentease/clinic/deantease_analytics.dart';
import 'package:dentease/clinic/dentease_patientList.dart';
import 'package:dentease/dentist/dentist_clinic_front.dart'; // Import new page
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
  const DentistPage({super.key, required this.clinicId, required this.dentistId});

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
      setState(() {
        isLoading = false;
      });
      return;
    }

    userEmail = user.email; // Assign userEmail

    try {
      final response = await supabase
          .from('dentists')
          .select('clinic_id, dentist_id')
          .eq('email', userEmail!) // Ensure userEmail is not null
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

    setState(() {
      isLoading = false;
    });
  }

  /// 🔹 **Reusable Custom Button**
  Widget _buildCustomButton(
      {required String title, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.grey[100], // Light background
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.black54),
          ],
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
              Positioned(
                top: 180,
                left: 20,
                right: 20,
                child: Column(
                  children: [
                    _buildCustomButton(
                      title: "Clinic Patients",
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ClinicPatientListPage(
                                clinicId: clinicId!),
                          ),
                        );
                      },
                    ),
                    _buildCustomButton(
                      title: "Clinic Dentists",
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                DentistListPage(clinicId: clinicId!),
                          ),
                        );
                      },
                    ),
                    _buildCustomButton(
                      title: "Clinic Staffs",
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                DentStaffListPage(clinicId: clinicId!),
                          ),
                        );
                      },
                    ),
                    _buildCustomButton(
                      title: "Clinic Services",
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                DentistServListPage(clinicId: clinicId!),
                          ),
                        );
                      },
                    ),
                    _buildCustomButton(
                      title: "Clinic Schedules",
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DentistClinicSchedPage(
                              clinicId: widget.clinicId,
                              dentistId: widget.dentistId,
                            ),
                          ),
                        );
                      },
                    ),
                    _buildCustomButton(
                      title: "Clinic Details",
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                DentClinicPage(clinicId: clinicId!),
                          ),
                        );
                      },
                    ),
                    _buildCustomButton(
                      title: "Clinic Analytics",
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ClinicAnalytics(clinicId: clinicId!),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            if (dentistId != null) DentistFooter(clinicId: widget.clinicId, dentistId: dentistId!),
          ],
        ),
      ),
    );
  }
}
