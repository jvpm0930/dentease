
import 'package:dentease/dentist/dentist_add_service.dart';
import 'package:dentease/dentist/dentist_service_details.dart';
import 'package:dentease/widgets/dentistWidgets/dentist_footer.dart';
import 'package:dentease/widgets/dentistWidgets/dentist_header.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dentease/widgets/background_cont.dart';

class DentistServListPage extends StatefulWidget {
  final String clinicId;

  const DentistServListPage({super.key, required this.clinicId});

  @override
  _DentistServListPageState createState() => _DentistServListPageState();
}

class _DentistServListPageState extends State<DentistServListPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> services = [];
  String? dentistId;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDentistId();
    _fetchServices();
  }

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

  Future<void> _fetchServices() async {
    try {
      final response = await supabase
          .from('services')
          .select('service_id, service_name, service_price, status')
          .eq('clinic_id', widget.clinicId);

      setState(() {
        services = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching services: $e')),
      );
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _deleteService(String id) async {
    try {
      // Step 1: Check if the service is linked to any bills
      final billResponse =
          await supabase.from('bills').select('bill_id').eq('service_id', id);

      if (billResponse.isNotEmpty) {
        // If linked, show an error message and stop
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Cannot delete: This service is linked to existing bills.',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Step 2: If not linked, delete the service
      await supabase.from('services').delete().eq('service_id', id);

      // Step 3: Update the local list
      setState(() {
        services.removeWhere((service) => service['service_id'] == id);
      });

      // Step 4: Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Service deleted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Handle unexpected errors
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting service: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
              padding: const EdgeInsets.only(top: 150, bottom: 100),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: ElevatedButton(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  DentistAddService(clinicId: widget.clinicId),
                            ),
                          );
                          _fetchServices();
                        },
                        child: const Text(
                          "Add New Services",
                          style: TextStyle(
                              color: Colors.blue),
                        ),
                      ),
                    ),
                    ListView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: services.length,
                      itemBuilder: (context, index) {
                        final service = services[index];
                        return Card(
                          margin: const EdgeInsets.all(10),
                          child: ListTile(
                            title: Text(
                              "Name: ${service['service_name'] ?? 'N/A'}"
                                  .trim(),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    "Price: ${service['service_price'] ?? 'N/A'}"
                                        .trim()
                              ),
                                Text(
                                  "Status: ${service['status']}",
                                  style: TextStyle(
                                    color: service['status'] == 'inactive'
                                        ? Colors.red
                                        : Colors.blue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            leading: const Icon(Icons.medical_services),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () =>
                                  _deleteService(service['service_id']),
                            ),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      DentistServiceDetailsPage(
                                    serviceId: service['service_id'].toString(),
                                  ),
                                ),
                              );
                              _fetchServices();
                            },
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            if (dentistId != null) DentistFooter(clinicId: widget.clinicId, dentistId: dentistId!),
          ],
        ),
      ),
    );
  }
}
