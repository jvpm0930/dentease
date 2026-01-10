import 'package:dentease/dentist/dentist_add_dentist.dart';
import 'package:dentease/widgets/background_cont.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DentistListPage extends StatefulWidget {
  final String clinicId;

  const DentistListPage({super.key, required this.clinicId});

  @override
  _DentistListPageState createState() => _DentistListPageState();
}

class _DentistListPageState extends State<DentistListPage> {
  // Use getter to avoid race condition with Supabase initialization
  SupabaseClient get supabase => Supabase.instance.client;
  List<Map<String, dynamic>> dentists = [];
  bool isLoading = true;

  // Theme Colors
  static const kPrimaryBlue = Color(0xFF0D2A7A);

  @override
  void initState() {
    super.initState();
    _fetchDentists();
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching dentists: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _navigateToAddDentist() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DentistAddDentist(clinicId: widget.clinicId),
      ),
    );

    // Refresh list if dentist was added successfully
    if (result == true) {
      _fetchDentists();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundCont(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            'Dentists',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              icon: const Icon(Icons.add, color: Colors.white),
              onPressed: _navigateToAddDentist,
              tooltip: 'Add Dentist',
            ),
          ],
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : dentists.isEmpty
                ? const Center(child: Text("No dentists found.", style: TextStyle(color: Colors.white70)))
                : RefreshIndicator(
                    onRefresh: _fetchDentists,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: dentists.length,
                      separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final dentist = dentists[index];
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              )
                            ],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: kPrimaryBlue.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.person, color: kPrimaryBlue),
                            ),
                            title: Text(
                              "${dentist['firstname'] ?? ''} ${dentist['lastname'] ?? ''}"
                                  .trim(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (dentist['email'] != null)
                                    Row(
                                      children: [
                                        const Icon(Icons.email_outlined,
                                            size: 14, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            dentist['email'],
                                            style: const TextStyle(
                                                color: Colors.grey, fontSize: 13),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  const SizedBox(height: 4),
                                  if (dentist['phone'] != null)
                                    Row(
                                      children: [
                                        const Icon(Icons.phone_outlined,
                                            size: 14, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Text(
                                          dentist['phone'],
                                          style: const TextStyle(
                                              color: Colors.grey, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}
