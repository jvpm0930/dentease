import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dentease/widgets/background_cont.dart';
import 'package:dentease/widgets/dentistWidgets/dentist_footer.dart';
import 'package:dentease/widgets/dentistWidgets/dentist_header.dart';

class DentistListPage extends StatefulWidget {
  final String clinicId;

  const DentistListPage({super.key, required this.clinicId});

  @override
  _DentistListPageState createState() => _DentistListPageState();
}

class _DentistListPageState extends State<DentistListPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> dentists = [];
  String? dentistId;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDentistId();
    _fetchDentists();
  }

  /// 🔹 Fetch `dentist_id` for the logged-in user
  Future<void> _fetchDentistId() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null || user.email == null) {
        setState(() => isLoading = false);
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

  /// 🔹 Fetch the list of dentists from `dentists` table
  Future<void> _fetchDentists() async {
    try {
      final response = await supabase
          .from('dentists')
          .select('dentist_id, firstname, lastname, email, phone')
          .eq('clinic_id', widget.clinicId);

      setState(() {
        dentists = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching dentists: $e')),
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
                  Expanded(
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : dentists.isEmpty
                            ? const Center(child: Text("No dentists found."))
                            : ListView.builder(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20),
                                itemCount: dentists.length,
                                itemBuilder: (context, index) {
                                  final dentist = dentists[index];
                                  return Card(
                                    margin: const EdgeInsets.all(10),
                                    child: ListTile(
                                      title: Text(
                                        "${dentist['firstname'] ?? ''} ${dentist['lastname'] ?? ''}"
                                            .trim(),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                              "Email: ${dentist['email'] ?? 'N/A'}"),
                                          Text(
                                              "Phone: ${dentist['phone'] ?? 'N/A'}"),
                                        ],
                                      ),
                                      leading: const Icon(Icons.person, color: const Color(0xFF103D7E) ,),
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
