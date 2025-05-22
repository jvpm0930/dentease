import 'package:dentease/admin/pages/patients/admin_dentist_details.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdmClinicPatientsPage extends StatefulWidget {
  final String clinicId;

  const AdmClinicPatientsPage({super.key, required this.clinicId});

  @override
  State<AdmClinicPatientsPage> createState() => _AdmClinicPatientsPageState();
}

class _AdmClinicPatientsPageState extends State<AdmClinicPatientsPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> patients = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPatients();
  }

  Future<void> _fetchPatients() async {
    try {
      // Fetching data including patient_id
      final response = await supabase
          .from('patients')
          .select(
              'patient_id, firstname, lastname, email') // Include dentist_id
          .eq('clinic_id', widget.clinicId);

      setState(() {
        patients = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching patients: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patients List'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : patients.isEmpty
              ? const Center(child: Text('No patients found.'))
              : ListView.builder(
                  itemCount: patients.length,
                  itemBuilder: (context, index) {
                    final patient = patients[index];
                    final String fullName =
                        '${patient['firstname'] ?? ''} ${patient['lastname'] ?? ''} ';

                    return GestureDetector(
                      onTap: () {
                        // Navigate to DentistDetailsPage with dentist_id
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AdmPatientDetailsPage(
                              patientId: patient['patient_id'],
                            ),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            vertical: 6, horizontal: 16),
                        padding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 16),
                        decoration: BoxDecoration(
                          color:
                              Colors.purple.shade50, // Light purple background
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  fullName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  patient['email'] ?? 'No email available',
                                  style: const TextStyle(
                                      fontSize: 14, color: Colors.grey),
                                ),
                              ],
                            ),
                            const Icon(Icons.chevron_right, color: Colors.grey),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
