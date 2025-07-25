import 'package:dentease/clinic/dentease_moreDetails.dart';
import 'package:dentease/widgets/clinicWidgets/forDentStaff_clinicPage.dart';
import 'package:flutter/material.dart';
import 'package:dentease/widgets/background_cont.dart';
import 'package:dentease/widgets/dentistWidgets/dentist_footer.dart';
import 'package:dentease/widgets/dentistWidgets/dentist_header.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DentClinicPage extends StatefulWidget {
  final String clinicId;

  const DentClinicPage({
    super.key,
    required this.clinicId,
  });

  @override
  State<DentClinicPage> createState() => _DentClinicPageState();
}

class _DentClinicPageState extends State<DentClinicPage> {
  final supabase = Supabase.instance.client;
  Map<String, dynamic>? clinicDetails;
  String? dentistId; // Store the fetched dentist_id
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchClinicDetails();
  }

  /// Fetch clinic details and the associated `dentist_id`
  Future<void> _fetchClinicDetails() async {
    try {
      final clinicResponse = await supabase
          .from('clinics')
          .select()
          .eq('clinic_id', widget.clinicId)
          .maybeSingle();

      final dentistResponse = await supabase
          .from('dentists')
          .select('dentist_id')
          .eq('clinic_id', widget.clinicId)
          .maybeSingle();

      setState(() {
        clinicDetails = clinicResponse;
        dentistId = dentistResponse?['dentist_id'];
        isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching clinic details: $e')),
      );
      setState(() {
        isLoading = false;
      });
    }
  }

  Widget _buildDetailRow(String label, String value) {
    final isStatusRow = label.toLowerCase().contains('status');
    final isRejected = value.toLowerCase() == 'rejected';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: isStatusRow && isRejected ? Colors.red : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
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
            const DentistHeader(),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: isLoading
                    ? const CircularProgressIndicator()
                    : clinicDetails == null
                        ? const Text(
                            'No clinic details found.',
                            style: TextStyle(fontSize: 14),
                          )
                        : SingleChildScrollView(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const SizedBox(height: 30),
                                ClinicFrontForDentStaff(
                                    clinicId: widget.clinicId),
                                const SizedBox(height: 30),
                                _buildDetailRow('Status:',
                                    clinicDetails?['status'] ?? 'N/A'),
                                _buildDetailRow(
                                    'Note:', clinicDetails?['note'] ?? 'N/A'),
                                _buildDetailRow('Clinic Name:',
                                    clinicDetails?['clinic_name'] ?? 'N/A'),
                                const SizedBox(height: 20),
                                ElevatedButton(
                                  onPressed: () {
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
                                    backgroundColor: Colors.blue,
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
            if (dentistId != null)
              DentistFooter(
                clinicId: widget.clinicId,
                dentistId: dentistId!,
              ),
          ],
        ),
      ),
    );
  }
}
