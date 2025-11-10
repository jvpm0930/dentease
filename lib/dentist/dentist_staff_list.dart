import 'package:dentease/dentist/dentist_add_staff.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dentease/widgets/background_cont.dart';
import 'package:dentease/widgets/dentistWidgets/dentist_footer.dart';
import 'package:dentease/widgets/dentistWidgets/dentist_header.dart';

class DentStaffListPage extends StatefulWidget {
  final String clinicId;

  const DentStaffListPage({super.key, required this.clinicId});

  @override
  _DentStaffListPageState createState() => _DentStaffListPageState();
}

class _DentStaffListPageState extends State<DentStaffListPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> staffs = [];
  String? dentistId;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDentistId();
    _fetchStaff();
  }

  /// 🔹 Fetch the `dentist_id` based on the logged-in user's email
  Future<void> _fetchDentistId() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null || user.email == null) {
        setState(() {
          isLoading = false;
        });
        return;
      }

      final response = await supabase
          .from('dentists')
          .select('dentist_id')
          .eq('email', user.email!)
          .maybeSingle();

      if (response != null && response['dentist_id'] != null) {
        setState(() {
          dentistId = response['dentist_id'].toString();
        });
      }
    } catch (e) {
      print("Error fetching dentist ID: $e");
    }
  }

  /// Fetch staff members from `staffs` table
  Future<void> _fetchStaff() async {
    try {
      final response = await supabase
          .from('staffs')
          .select('firstname, lastname, email, phone')
          .eq('clinic_id', widget.clinicId);

      setState(() {
        staffs = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching staff: $e')),
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
        body: Stack(
          children: [
            const DentistHeader(),
            Padding(
              padding: const EdgeInsets.only(top: 150, bottom: 50),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                DentAddStaff(clinicId: widget.clinicId),
                          ),
                        );
                      },
                      child: const Text(
                        "Add New Staff",
                        style: TextStyle(color: const Color(0xFF103D7E)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : staffs.isEmpty
                            ? const Center(child: Text("No staff found."))
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
                                      leading: const Icon(Icons.person, color: const Color(0xFF103D7E),),
                                    ),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
            if (dentistId != null) DentistFooter(clinicId: widget.clinicId, dentistId: dentistId!),
          ],
        ),
      ),
    );
  }
}
