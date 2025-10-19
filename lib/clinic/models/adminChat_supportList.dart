import 'package:dentease/clinic/models/admin_supportChatpage.dart';
import 'package:dentease/widgets/background_cont.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminSupportChatforClinic extends StatefulWidget {
  final String adminId;
  final String clinicId;

  const AdminSupportChatforClinic({
    super.key,
    required this.adminId,
    required this.clinicId,
  });

  @override
  _AdminSupportChatforClinicState createState() =>
      _AdminSupportChatforClinicState();
}

class _AdminSupportChatforClinicState extends State<AdminSupportChatforClinic> {
  final supabase = Supabase.instance.client;

  Map<String, dynamic>? clinic;
  bool hasNewMessage = false;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchClinicData();
  }

  Future<void> fetchClinicData() async {
    try {
      // Fetch only the specific clinic
      final response = await supabase
          .from('clinics')
          .select('clinic_id, clinic_name, email')
          .eq('clinic_id', widget.clinicId)
          .maybeSingle();

      if (response == null) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Clinic not found')),
        );
        return;
      }

      // Check if this clinic sent any unread messages to admin
      final newMsgResponse = await supabase
          .from('supports')
          .select()
          .eq('sender_id', widget.clinicId)
          .eq('receiver_id', widget.adminId);

      setState(() {
        clinic = response;
        hasNewMessage = newMsgResponse.isNotEmpty;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching clinic: $e')),
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
            "Clinic Support Chat",
            style: TextStyle(color: Colors.white),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : clinic == null
                ? const Center(
                    child: Text(
                      "Clinic not found",
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      color: Colors.white.withOpacity(0.9),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        title: Text(
                          clinic!['clinic_name'] ?? 'Unknown',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        subtitle: Text(
                          clinic!['email'] ?? '',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                        /*
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.chat_bubble, color: Colors.blue),
                            if (hasNewMessage)
                              const Text(
                                'New message',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),*/
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AdminSupportChatPage(
                                clinicId: widget.clinicId,
                                clinicName: clinic!['clinic_name'],
                                adminId: widget.adminId,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
      ),
    );
  }
}
