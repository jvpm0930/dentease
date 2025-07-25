import 'package:dentease/clinic/models/clinicchatpage.dart';
import 'package:dentease/widgets/background_cont.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ClinicPatientChatList extends StatefulWidget {
  final String clinicId;

  const ClinicPatientChatList({super.key, required this.clinicId});

  @override
  _ClinicPatientChatListState createState() => _ClinicPatientChatListState();
}

class _ClinicPatientChatListState extends State<ClinicPatientChatList> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> patients = [];
  Map<String, bool> hasNewMessages = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchPatients();
  }

  Future<void> fetchPatients() async {
    try {
      final bookingResponse = await supabase
          .from('bookings')
          .select('patient_id')
          .eq('clinic_id', widget.clinicId);

      final patientIds = bookingResponse
          .map((booking) => booking['patient_id'] as String)
          .toList();

      if (patientIds.isEmpty) {
        setState(() {
          patients = [];
          hasNewMessages = {}; // Ensure this is reset
          isLoading = false;
        });
        return;
      }

      final patientResponse = await supabase
          .from('patients')
          .select('patient_id, firstname, email')
          .inFilter('patient_id', patientIds);

      final Map<String, bool> newMessagesMap = {};

      for (var patientId in patientIds) {
        final newMessageResponse = await supabase
            .from('messages')
            .select()
            .eq('sender_id', patientId)
            .eq('receiver_id', widget.clinicId)
            .eq('read', false);

        newMessagesMap[patientId] = newMessageResponse.isNotEmpty;
      }

      setState(() {
        patients = List<Map<String, dynamic>>.from(patientResponse);
        hasNewMessages = newMessagesMap; 
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching patients: $e')),
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
            "Patient Chat List",
            style: TextStyle(color: Colors.white),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator()) // Loading state
            : patients.isEmpty
                ? const Center(
                    child: Text(
                      "No Patient Messages",
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: patients.length,
                    itemBuilder: (context, index) {
                      final patient = patients[index];
                      final patientId = patient['patient_id'] as String?;
                      final patientName =
                          patient['firstname'] as String? ?? 'Unknown';
                      final patientEmail = patient['email'] as String? ?? '';

                      return Card(
                        elevation: 4, // Shadow effect
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(12), // Rounded corners
                        ),
                        color:
                            Colors.white.withOpacity(0.9), // Light background
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          title: Text(
                            patientName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          subtitle: Text(
                            patientEmail,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.chat_bubble, color: Colors.blue),
                              if (hasNewMessages[patientId] == true)
                                const Text(
                                  'New message',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                          onTap: () {
                            if (patientId != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ClinicChatPage(
                                    patientId: patientId,
                                    patientName: patientName,
                                    clinicId: widget.clinicId,
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
