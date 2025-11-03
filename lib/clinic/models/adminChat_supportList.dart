import 'package:dentease/clinic/models/admin_supportChatpage.dart';
import 'package:dentease/widgets/background_cont.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminSupportChatforClinic extends StatefulWidget {
  final String adminId;

  const AdminSupportChatforClinic({
    super.key,
    required this.adminId,
  });

  @override
  _AdminSupportChatforClinicState createState() =>
      _AdminSupportChatforClinicState();
}

class _AdminSupportChatforClinicState extends State<AdminSupportChatforClinic> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> clinics = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchClinicData();
  }

  Future<void> fetchClinicData() async {
    try {
      final response = await supabase
          .from('clinics')
          .select('clinic_id, clinic_name');

      setState(() {
        clinics = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
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
            : clinics.isEmpty
                ? const Center(
                    child: Text(
                      "No clinics found",
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: clinics.length,
                    itemBuilder: (context, index) {
                      final clinic = clinics[index];

                      return Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        color: Colors.white.withOpacity(0.9),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          title: Text(
                            clinic['clinic_name'] ?? 'Unknown',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.chat_bubble_outline,
                            color: Colors.blue,
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AdminSupportChatPage(
                                  clinicId: clinic['clinic_id'],
                                  clinicName: clinic['clinic_name'],
                                  adminId: widget.adminId,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
