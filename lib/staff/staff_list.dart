import 'package:dentease/widgets/staffWidgets/staff_footer.dart';
import 'package:dentease/widgets/staffWidgets/staff_header.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dentease/widgets/background_cont.dart';

class StaffListPage extends StatefulWidget {
  final String clinicId;

  const StaffListPage({super.key, required this.clinicId});

  @override
  _StaffListPageState createState() => _StaffListPageState();
}

class _StaffListPageState extends State<StaffListPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> staffs = [];
  String? staffId;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStaffId();
    _fetchStaff();
  }

  Future<void> _fetchStaffId() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null || user.email == null) {
        setState(() {
          isLoading = false;
        });
        return;
      }

      final response = await supabase
          .from('staffs')
          .select('staff_id')
          .eq('email', user.email!)
          .maybeSingle();

      if (response != null && response['staff_id'] != null) {
        setState(() {
          staffId = response['staff_id'].toString();
        });
      }
    } catch (e) {
      print("Error fetching staff ID: $e");
    }
  }

  Future<void> _fetchStaff() async {
    try {
      final response = await supabase
          .from('staffs')
          .select('firstname, lastname, email, phone')
          .eq('clinic_id', widget.clinicId);

      setState(() {
        staffs = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching staffs: $e')),
      );
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
        body: Stack(
          children: [
            const StaffHeader(),
            Padding(
              padding: const EdgeInsets.only(top: 150, bottom: 50),
              child: Column(
                children: [
                  Expanded(
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : staffs.isEmpty
                            ? const Center(child: Text("No staffs found."))
                            : ListView.builder(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20),
                                itemCount: staffs.length,
                                itemBuilder: (context, index) {
                                  final staff = staffs[index];
                                  return Card(
                                    margin: const EdgeInsets.all(10),
                                    child: ListTile(
                                      title: Text(
                                        "${staff['firstname'] ?? ''} ${staff['lastname'] ?? ''}"
                                            .trim(),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                              "Email: ${staff['email'] ?? 'N/A'}"),
                                          Text(
                                              "Phone: ${staff['phone'] ?? 'N/A'}"),
                                        ],
                                      ),
                                      leading: const Icon(Icons.person),
                                    ),
                                  );
                                },
                              ),
                  ),
                ],
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
