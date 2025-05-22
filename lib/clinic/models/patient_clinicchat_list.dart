import 'package:dentease/clinic/models/patientchatpage.dart';
import 'package:dentease/widgets/background_cont.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PatientClinicChatList extends StatefulWidget {
  final String patientId;

  const PatientClinicChatList({super.key, required this.patientId});

  @override
  _PatientClinicChatListState createState() => _PatientClinicChatListState();
}

class _PatientClinicChatListState extends State<PatientClinicChatList> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> clinics = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchClinics();
  }

  /// Fetches clinics based on `clinic_id` from `bookings`, retrieving clinic details from `clinics` table
  Future<void> fetchClinics() async {
    try {
      final bookingResponse = await supabase
          .from('bookings')
          .select('clinic_id')
          .eq('patient_id', widget.patientId);

      final clinicIds =
          bookingResponse.map((booking) => booking['clinic_id']).toList();

      if (clinicIds.isEmpty) {
        setState(() {
          clinics = [];
          isLoading = false;
        });
        return;
      }

      // Fetch clinic data based on `clinic_id`
      final clinicResponse = await supabase
          .from('clinics')
          .select('clinic_id, clinic_name, email')
          .inFilter('clinic_id', clinicIds); // Corrected filter

      setState(() {
        clinics = List<Map<String, dynamic>>.from(clinicResponse);
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching clinics: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundCont(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            "Clinic Chat List",
            style: TextStyle(color: Colors.white),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent, // Transparent AppBar
          elevation: 0, // Remove shadow
          iconTheme: const IconThemeData(color: Colors.white), // White icons
        ),
        body: isLoading
            ? const Center(
                child: CircularProgressIndicator()) // Show loading indicator
            : clinics.isEmpty
                ? const Center(
                    child: Text(
                      "No Clinic Messages",
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: clinics.length,
                    itemBuilder: (context, index) {
                      final clinic = clinics[index];
                      final clinicId = clinic['clinic_id'] as String?;
                      final clinicName =
                          clinic['clinic_name'] as String? ?? 'Unknown';
                      final clinicEmail = clinic['email'] as String? ?? '';

                      return Card(
                        elevation: 4, // Shadow effect
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          title: Text(
                            clinicName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          subtitle: Text(
                            clinicEmail,
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                          trailing: const Icon(Icons.chat, color: Colors.blue),
                          onTap: () {
                            if (clinicId != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PatientChatpage(
                                    patientId: widget.patientId,
                                    clinicName: clinicName,
                                    clinicId: clinicId,
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
