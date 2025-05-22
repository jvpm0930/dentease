import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdmClinicDetailsPage extends StatefulWidget {
  final String clinicId;

  const AdmClinicDetailsPage({super.key, required this.clinicId});

  @override
  State<AdmClinicDetailsPage> createState() => _AdmClinicDetailsPageState();
}

class _AdmClinicDetailsPageState extends State<AdmClinicDetailsPage> {
  final supabase = Supabase.instance.client;
  Map<String, dynamic>? clinicDetails;
  bool isLoading = true;
  String selectedStatus = 'pending'; // Default value

  @override
  void initState() {
    super.initState();
    _fetchClinicDetails();
  }

  Future<void> _fetchClinicDetails() async {
    try {
      final response = await supabase
          .from('clinics')
          .select(
              'clinic_name, email, license_url, latitude, longitude, address, status')
          .eq('clinic_id', widget.clinicId)
          .maybeSingle();

      if (response == null) {
        throw Exception('Clinic details not found');
      }

      setState(() {
        clinicDetails = response;
        selectedStatus = response['status'] ?? 'pending'; // Set status
        isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching clinic details: $e')),
      );
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _updateStatus() async {
    try {
      await supabase
          .from('clinics')
          .update({'status': selectedStatus}).eq('clinic_id', widget.clinicId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Status updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating status: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clinic Details'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : clinicDetails == null
              ? const Center(child: Text('No details found'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Clinic Name
                      Text(
                        clinicDetails!['clinic_name'] ?? '',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Clinic Status (Dropdown + Update Button)
                      Row(
                        children: [
                          const Icon(Icons.approval, color: Colors.indigo),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButton<String>(
                              value: selectedStatus,
                              onChanged: (newValue) {
                                setState(() {
                                  selectedStatus = newValue!;
                                });
                              },
                              items: const [
                                DropdownMenuItem(
                                  value: 'pending',
                                  child: Text('Pending'),
                                ),
                                DropdownMenuItem(
                                  value: 'approved',
                                  child: Text('Approved'),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: _updateStatus,
                            child: const Text('Update Status'),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Clinic Email
                      Row(
                        children: [
                          const Icon(Icons.email, color: Colors.indigo),
                          const SizedBox(width: 8),
                          Text(
                            clinicDetails!['email'] ?? 'No email provided',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Clinic Address
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.location_on, color: Colors.indigo),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              clinicDetails!['address'] ??
                                  'No address provided',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Map View
                      if (clinicDetails!['latitude'] != null &&
                          clinicDetails!['longitude'] != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 200,
                              child: GoogleMap(
                                initialCameraPosition: CameraPosition(
                                  target: LatLng(
                                    clinicDetails!['latitude'],
                                    clinicDetails!['longitude'],
                                  ),
                                  zoom: 15,
                                ),
                                markers: {
                                  Marker(
                                    markerId: const MarkerId('clinicLocation'),
                                    position: LatLng(
                                      clinicDetails!['latitude'],
                                      clinicDetails!['longitude'],
                                    ),
                                  ),
                                },
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 16),

                      // Clinic License Image
                      if (clinicDetails!['license_url'] != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'License:',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                clinicDetails!['license_url'],
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
    );
  }
}
