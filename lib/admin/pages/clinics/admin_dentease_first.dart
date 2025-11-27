import 'package:dentease/admin/pages/clinics/admin_dentease_pending.dart';
import 'package:dentease/admin/pages/clinics/admin_dentease_rejected.dart';
import 'package:dentease/widgets/adminWidgets/admin_footer.dart';
import 'package:dentease/widgets/adminWidgets/admin_header.dart';
import 'package:dentease/widgets/background_cont.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin_dentease_second.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> clinics = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchClinics();
  }

  Future<void> _fetchClinics() async {
    try {
      final response = await supabase
          .from('clinics')
          .select('clinic_id, clinic_name, status')
          .eq('status', 'approved');

      setState(() {
        clinics = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      _showSnackbar('Error fetching clinics');
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundCont(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          foregroundColor: Colors.white,
          backgroundColor: Colors.transparent,
          title: const AdminHeader(),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF103D7E),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text("Approved"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AdminPagev2(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF103D7E),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text("Pending"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AdminPagev3(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF103D7E),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text("Rejected"),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: clinics.length,
                      itemBuilder: (context, index) {
                        final clinic = clinics[index];
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AdmClinicDashboardPage(
                                  clinicId: clinic['clinic_id'],
                                  clinicName: clinic['clinic_name'],
                                ),
                              ),
                            );
                          },
                          child: Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: ListTile(
                              title: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    clinic['clinic_name'],
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    clinic['status'],
                                    style: const TextStyle(
                                        fontSize: 14, color: Colors.grey),
                                  ),
                                ],
                              ),
                              trailing: const Icon(Icons.chevron_right),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
        bottomNavigationBar: const AdminFooter(),
      ),
    );
  }
}
