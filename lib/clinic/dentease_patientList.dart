import 'package:dentease/clinic/dentease_patientListV2.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dentease/widgets/background_cont.dart';

class ClinicPatientListPage extends StatefulWidget {
  final String clinicId;

  const ClinicPatientListPage({super.key, required this.clinicId});

  @override
  _ClinicPatientListPageState createState() => _ClinicPatientListPageState();
}

class _ClinicPatientListPageState extends State<ClinicPatientListPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> patients = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPatient();
  }


  Future<void> _fetchPatient() async {
    try {
      final response = await supabase
          .from('bookings')
          .select('patients:patient_id (patient_id, firstname, lastname, email, phone)')
          .eq('clinic_id', widget.clinicId);

      // Extract patient details properly
      List<Map<String, dynamic>> patientList = response
          .where((record) => record['patients'] != null)
          .map<Map<String, dynamic>>((record) => record['patients'])
          .toList();

      // ** Remove duplicates by `id` (patient_id) to ensure uniqueness**
      final uniquePatients = <String, Map<String, dynamic>>{};
      for (var patient in patientList) {
        final id =
            patient['patient_id'].toString(); // Use `id` or `email` as unique key
        uniquePatients[id] = patient;
      }

      setState(() {
        patients = uniquePatients.values.toList();
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
    return BackgroundCont(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            "Patient List",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent, // Transparent AppBar
          elevation: 0, // Remove shadow
          iconTheme: const IconThemeData(color: Colors.white), // White icons
        ),
        body: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 30, bottom: 50),
              child: Column(
                children: [
                  /*
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                DentAddPatient(clinicId: widget.clinicId),
                          ),
                        );
                      },
                      child: const Text(
                        "Add New Patient",
                        style: TextStyle(color: Colors.blue),
                      ),
                    ),
                  ),
                  */
                  Expanded(
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : patients.isEmpty
                            ? const Center(child: Text("No patients found."))
                            : ListView.builder(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20),
                                itemCount: patients.length,
                                itemBuilder: (context, index) {
                                  final patient = patients[index];
                                  return Card(
                                    margin: const EdgeInsets.all(10),
                                    child: ListTile(
                                      title: Text(
                                        "${patient['firstname'] ?? ''} ${patient['lastname'] ?? ''}"
                                            .trim(),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                              "Email: ${patient['email'] ?? 'N/A'}"),
                                          Text(
                                              "Phone: ${patient['phone'] ?? 'N/A'}"),
                                        ], 
                                      ),
                                      leading: const Icon(Icons.person, 
                                          color: Color(0xFF103D7E),
                                          ),
                                      trailing: GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  DentistBookingPatientPage(
                                                patientId: patient[
                                                    'patient_id'],
                                                clinicId: widget.clinicId,
                                              ),
                                            ),
                                          );
                                        },
                                        child: const Padding(
                                          padding: EdgeInsets.only(right: 10),
                                          child: Icon(Icons.info,
                                              color: const Color(0xFF103D7E)),
                                        ),
                                      ),

                                    ),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
