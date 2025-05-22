import 'package:dentease/clinic/dentease_moreDetails.dart';
import 'package:dentease/widgets/clinicWidgets/forDentStaff_clinicPage.dart';
import 'package:dentease/widgets/staffWidgets/staff_footer.dart';
import 'package:dentease/widgets/staffWidgets/staff_header.dart';
import 'package:flutter/material.dart';
import 'package:dentease/widgets/background_cont.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StaffClinicPage extends StatefulWidget {
  final String clinicId;

  const StaffClinicPage({super.key, required this.clinicId});

  @override
  State<StaffClinicPage> createState() => _StaffClinicPageState();
}

class _StaffClinicPageState extends State<StaffClinicPage> {
  final supabase = Supabase.instance.client;
  Map<String, dynamic>? clinicDetails;
  String? staffId;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchClinicDetails();
  }

  Future<void> _fetchClinicDetails() async {
    try {
      final clinicResponse = await supabase
          .from('clinics')
          .select()
          .eq('clinic_id', widget.clinicId)
          .maybeSingle();

      final staffResponse = await supabase
          .from('staffs')
          .select('staff_id')
          .eq('clinic_id', widget.clinicId)
          .maybeSingle();

      if (!mounted) return; // Prevent state updates if widget is disposed

      setState(() {
        clinicDetails = clinicResponse;
        staffId = staffResponse?['staff_id'];
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching clinic details: $e')),
      );
      setState(() {
        isLoading = false;
      });
    }
  }

  Widget _buildDetailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Expanded(
            child: Text(value ?? 'N/A',
                textAlign: TextAlign.right,
                style: const TextStyle(color: Colors.white, fontSize: 14)),
          ),
        ],
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
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: isLoading
                    ? const CircularProgressIndicator()
                    : clinicDetails == null
                        ? const Text('No clinic details found.',
                            style: TextStyle(fontSize: 14))
                        : SingleChildScrollView(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const SizedBox(height: 30),
                                ClinicFrontForDentStaff(
                                    clinicId: widget.clinicId),
                                const SizedBox(height: 30),
                                const Text(
                                    "Above is Clinics Front Card In Patients Page"),
                                const SizedBox(height: 10),
                                _buildDetailRow(
                                    'Status:', clinicDetails?['status']),
                                _buildDetailRow('Clinic Name:',
                                    clinicDetails?['clinic_name']),
                                ElevatedButton(
                                  onPressed: () {
                                    // Navigate to DentClinicMore page
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ClinicDetails(
                                          clinicId: widget.clinicId,
                                        ),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        Colors.blue, // Button color
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 30, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'More Details',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
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
