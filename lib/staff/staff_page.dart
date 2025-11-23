import 'package:dentease/dentist/dentist_clinic_sched.dart';
import 'package:dentease/dentist/dentist_clinic_services.dart';
import 'package:dentease/widgets/background_cont.dart';
import 'package:dentease/widgets/staffWidgets/staff_footer.dart';
import 'package:dentease/widgets/staffWidgets/staff_header.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StaffPage extends StatefulWidget {
  final String clinicId;
  final String staffId;
  const StaffPage({super.key, required this.clinicId, required this.staffId});

  @override
  _StaffPageState createState() => _StaffPageState();
}

class _StaffPageState extends State<StaffPage> {
  String? userEmail;
  String? clinicId;
  String? staffId;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserDetails();
  }

  Future<void> _fetchUserDetails() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null || user.email == null) {
      setState(() => isLoading = false);
      return;
    }

    userEmail = user.email;

    try {
      final response = await supabase
          .from('staffs')
          .select('clinic_id, staff_id')
          .eq('email', userEmail!)
          .maybeSingle();

      if (response != null && response['clinic_id'] != null) {
        setState(() {
          clinicId = response['clinic_id'].toString();
          staffId = response['staff_id'].toString();
        });
      }
    } catch (error) {
      debugPrint("Error fetching clinic ID: $error");
    }

    setState(() => isLoading = false);
  }

  // Same image-based button style as DentistPage
  Widget _buildCustomButton({
    required String title,
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
            fit: BoxFit.cover,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        child: const Center(
          child: Text(
            // Text transparent to match the DentistPage (title baked into image)
            '',
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

  @override
  Widget build(BuildContext context) {
    return BackgroundCont(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            const StaffHeader(),
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
                        backgroundImage:
                            const AssetImage('assets/dentist/services.png'),
                      ),
                      _buildCustomButton(
                        title: "Clinic Schedules",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DentistClinicSchedPage(
                                clinicId: widget.clinicId,
                              ),
                            ),
                          );
                        },
                        backgroundImage:
                            const AssetImage('assets/dentist/calendar.png'),
                      ),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
            if (staffId != null)
              StaffFooter(clinicId: widget.clinicId, staffId: staffId!),
          ],
        ),
      ),
    );
  }
}
