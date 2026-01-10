import 'package:dentease/widgets/background_cont.dart';
import 'package:dentease/widgets/clinicWidgets/clinic_slider.dart';
import 'package:dentease/widgets/patientWidgets/patient_footer.dart';
import 'package:dentease/widgets/patientWidgets/patient_header.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PatientPage extends StatefulWidget {
  const PatientPage({super.key});

  @override
  _PatientPageState createState() => _PatientPageState();
}

class _PatientPageState extends State<PatientPage> {
  // Use getter to avoid race condition with Supabase initialization
  SupabaseClient get supabase => Supabase.instance.client;
  String? patientId;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserDetails();
  }

  Future<void> _fetchUserDetails() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      setState(() => isLoading = false);
      return;
    }

    try {
      final response = await supabase
          .from('patients')
          .select('patient_id')
          .eq('patient_id', user.id)
          .maybeSingle();

      if (response != null) {
        setState(() {
          patientId = response['patient_id']?.toString();
        });
      }
    } catch (error) {
      debugPrint("Error fetching user details: $error");
    }

    setState(() => isLoading = false);
  }

  Future<bool> _showExitDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit App?'),
        content: const Text('Are you sure you want to exit?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Exit'),
          ),
        ],
      ),
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await _showExitDialog();
        if (shouldExit && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: BackgroundCont(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Section
                      const PatientHeader(),

                      const SizedBox(height: 20),

                      // Featured Clinics Section
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          'Featured Clinics',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Clinic Carousel
                      const SizedBox(
                        height: 280,
                        child: ClinicCarousel(),
                      ),

                      // Bottom padding for navbar
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
          // Floating Bottom Navbar
          bottomNavigationBar: patientId != null
              ? PatientFooter(patientId: patientId!)
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}