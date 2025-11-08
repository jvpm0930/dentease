import 'package:dentease/clinic/models/patientchatpage.dart';
import 'package:dentease/widgets/background_cont.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

class PatientClinicChatList extends StatefulWidget {
  final String patientId;

  const PatientClinicChatList({super.key, required this.patientId});

  @override
  _PatientClinicChatListState createState() => _PatientClinicChatListState();
}

class _PatientClinicChatListState extends State<PatientClinicChatList> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> clinics = [];
  Map<String, bool> hasNewMessages = {};
  bool isLoading = true;
  Timer? refreshTimer;

  @override
  void initState() {
    super.initState();
    fetchClinics();
    startAutoRefresh();
  }

  void startAutoRefresh() {
    refreshTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      fetchClinics();
    });
  }

  /// Fetches clinics based on `clinic_id` from `bookings` table,
  /// retrieves clinic details, and checks for unread messages.
  Future<void> fetchClinics() async {
    try {
      // Get all bookings for this patient
      final bookingResponse = await supabase
          .from('bookings')
          .select('clinic_id')
          .eq('patient_id', widget.patientId);

      final clinicIds =
          bookingResponse.map((b) => b['clinic_id'] as String).toList();

      if (clinicIds.isEmpty) {
        setState(() {
          clinics = [];
          hasNewMessages = {};
          isLoading = false;
        });
        return;
      }

      // Get clinic details
      final clinicResponse = await supabase
          .from('clinics')
          .select('clinic_id, clinic_name, email')
          .inFilter('clinic_id', clinicIds);

      // Get all unread messages (clinic → patient)
      final unreadMessages = await supabase
          .from('messages')
          .select('sender_id')
          .eq('receiver_id', widget.patientId)
          .or('is_read.eq.false,is_read.eq.FALSE,is_read.is.null');

      final unreadClinicIds =
          unreadMessages.map((m) => m['sender_id'] as String).toSet();

      // Create a map for quick lookup
      final Map<String, bool> newMessagesMap = {
        for (var id in clinicIds) id: unreadClinicIds.contains(id)
      };

      // Update UI
      setState(() {
        clinics = List<Map<String, dynamic>>.from(clinicResponse);
        hasNewMessages = newMessagesMap;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching clinics')),
      );
    }
  }

  @override
  void dispose() {
    stopAutoRefresh(); 
    super.dispose();
  }

  void stopAutoRefresh() {
    refreshTimer?.cancel();
    refreshTimer = null;
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
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
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
                        elevation: 4,
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
                            style: const TextStyle(color: Colors.black54),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              hasNewMessages[clinicId] == true
                                  ? const Icon(Icons.mark_chat_unread,
                                      color: Colors.red)
                                  : const Icon(Icons.chat_bubble_outline,
                                      color: Colors.blue),
                              if (hasNewMessages[clinicId] == true)
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
                            if (clinicId != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PatientChatPage(
                                    patientId: widget.patientId,
                                    clinicName: clinicName,
                                    clinicId: clinicId,
                                  ),
                                ),
                              ).then((_) {
                                // Refresh when returning from chat page
                                fetchClinics();
                              });
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
