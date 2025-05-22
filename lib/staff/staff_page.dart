import 'package:dentease/staff/staff_clinic_services.dart';
import 'package:dentease/staff/staff_clinics_sched.dart';
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
      setState(() {
        isLoading = false;
      });
      return;
    }

    userEmail = user.email; // Ensure userEmail is assigned

    try {
      final response = await supabase
          .from('staffs')
          .select('clinic_id, staff_id')
          .eq('email', userEmail!) // Ensure userEmail is not null
          .maybeSingle();

      if (response != null && response['clinic_id'] != null) {
        setState(() {
          clinicId = response['clinic_id'].toString();
          staffId = response['staff_id'].toString();
        });
      }
    } catch (error) {
      print("Error fetching clinic ID: $error");
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
            const StaffHeader(),
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
                      title: "Clinic Services",
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                StaffServListPage(clinicId: clinicId!),
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
                            builder: (context) =>
                                StaffClinicSchedPage(
                              clinicId: widget.clinicId,
                              staffId: widget.staffId,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
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
