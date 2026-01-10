import 'package:dentease/clinic/models/admin_supportChatpage.dart';
import 'package:dentease/widgets/background_cont.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

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

  //  which clinics have unread support messages
  Set<String> clinicsWithUnreadSupport = {};
  // timer for auto refresh
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    fetchClinicData();
    fetchUnreadSupport(); // initial load

    //  Auto update badge every 3 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      fetchUnreadSupport();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> fetchUnreadSupport() async {
    try {
      final response = await supabase
          .from('supports')
          .select('support_id, sender_id, is_read')
          .eq('receiver_id', widget.adminId)
          .or('is_read.eq.false,is_read.eq.FALSE,is_read.is.null');

      final Set<String> unreadClinics = {};

      for (var row in response) {
        final cid = row['sender_id']?.toString(); //  correct field
        if (cid != null) unreadClinics.add(cid);
      }

      if (!mounted) return;
      setState(() => clinicsWithUnreadSupport = unreadClinics);
    } catch (e) {
      debugPrint("Unread support fetch error: $e");
    }
  }

  Future<void> fetchClinicData() async {
    try {
      final response =
          await supabase.from('clinics')
          .select('clinic_id, clinic_name');

      setState(() {
        clinics = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching clinics')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    final sortedClinics = [...clinics];

    sortedClinics.sort((a, b) {
      final aHasNew =
          clinicsWithUnreadSupport.contains(a['clinic_id'].toString());
      final bHasNew =
          clinicsWithUnreadSupport.contains(b['clinic_id'].toString());

      if (aHasNew && !bHasNew) return -1; // a first
      if (!aHasNew && bHasNew) return 1; // b first
      return 0; // equal -> no change
    });
    return BackgroundCont(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            "Clinic Support Chat",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                    itemCount: sortedClinics.length,
                    itemBuilder: (context, index) {
                      final clinic = sortedClinics[index];

                      return Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        color: Colors.white.withValues(alpha: 0.95),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(10),

                          title: Text(
                            clinic['clinic_name'] ?? 'Unknown',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),

                          // ✨ Optional email-style secondary text for consistency
                          subtitle: Text(
                            "Support Inquiry",
                            style: const TextStyle(
                                color: Colors.black54, fontSize: 13),
                          ),

                          // RIGHT SIDE ICON — SAME STYLE AS PATIENT UI
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              clinicsWithUnreadSupport
                                      .contains(clinic['clinic_id'].toString())
                                  ? const Icon(Icons.mark_chat_unread,
                                      color: Colors.red, size: 26)
                                  : const Icon(Icons.chat_bubble_outline,
                                      color: Color(0xFF103D7E), size: 26),
                              if (clinicsWithUnreadSupport
                                  .contains(clinic['clinic_id'].toString()))
                                const Text(
                                  "New message",
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                            ],
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
