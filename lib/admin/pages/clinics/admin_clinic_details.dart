import 'package:dentease/widgets/background_cont.dart';
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
  final TextEditingController _noteController = TextEditingController();

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
              'clinic_name, email, info, license_url, office_url, permit_url, latitude, longitude, address, status, note')
          .eq('clinic_id', widget.clinicId)
          .maybeSingle();

      if (response == null) {
        throw Exception('Clinic details not found');
      }

      setState(() {
        clinicDetails = response;
        selectedStatus = response['status'] ?? 'pending';
        _noteController.text = response['note'] ?? ''; // preload existing note
        isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching clinic details')),
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
        SnackBar(content: Text('Error updating status')),
      );
    }
  }

  Future<void> _updateNote() async {
    final noteText = _noteController.text.trim();
    if (noteText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note cannot be empty')),
      );
      return;
    }

    try {
      await supabase
          .from('clinics')
          .update({'note': noteText}).eq('clinic_id', widget.clinicId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note sent successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending note')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundCont(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
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
                        Text(
                          clinicDetails!['clinic_name'] ?? '',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
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
                                    value: 'rejected',
                                    child: Text('Rejected'),
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
                        const SizedBox(height: 20),
                        const Divider(thickness: 1.5, color: Colors.blueGrey),
                        const SizedBox(height: 20),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.note_alt, color: Colors.indigo),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _noteController,
                                maxLines: null,
                                decoration: const InputDecoration(
                                  hintText: 'Enter note...',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _updateNote,
                              child: const Text('Send Note'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Divider(thickness: 1.5, color: Colors.blueGrey),
                        const SizedBox(height: 20),
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
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info, color: Colors.indigo),
                            const SizedBox(width: 8),
                            Expanded(
                              // allows the text to wrap properly
                              child: Text(
                                clinicDetails!['info'] ?? 'No info provided',
                                style: const TextStyle(fontSize: 16),
                                softWrap: true, // optional, ensures wrapping
                                overflow: TextOverflow
                                    .visible, // makes sure text is fully shown
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Divider(thickness: 1.5, color: Colors.blueGrey),
                        const SizedBox(height: 20),
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
                        const SizedBox(height: 20),
                        const Divider(thickness: 1.5, color: Colors.blueGrey),
                        const SizedBox(height: 20),
                        const Text(
                          'PRC Credentials:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (clinicDetails!['license_url'] != null &&
                            (clinicDetails!['license_url'] as String)
                                .isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => FullScreenImage(
                                        imageUrl: clinicDetails!['license_url'],
                                      ),
                                    ),
                                  );
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(
                                    clinicDetails!['license_url'],
                                    height: 150,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ],
                          )
                        else
                          const Text(
                            "No PRC License image is available.",
                            style: TextStyle(
                              fontSize: 16,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey,
                            ),
                          ),
                        const SizedBox(height: 8),
                        const Text(
                          'DTI Permit:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (clinicDetails!['permit_url'] != null &&
                            (clinicDetails!['permit_url'] as String)
                                .isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => FullScreenImage(
                                        imageUrl: clinicDetails!['permit_url'],
                                      ),
                                    ),
                                  );
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(
                                    clinicDetails!['permit_url'],
                                    height: 150,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ],
                          )
                        else
                          const Text(
                            "No DTI Permit image is available.",
                            style: TextStyle(
                              fontSize: 16,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey,
                            ),
                          ),
                        const SizedBox(height: 8),
                        const Text(
                          'Workplace:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (clinicDetails!['office_url'] != null &&
                            (clinicDetails!['office_url'] as String).isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => FullScreenImage(
                                        imageUrl: clinicDetails!['office_url'],
                                      ),
                                    ),
                                  );
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(
                                    clinicDetails!['office_url'],
                                    height: 150,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ],
                          )
                        else
                          const Text(
                            "No Workplace image is available.",
                            style: TextStyle(
                              fontSize: 16,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey,
                            ),
                          ),
                        const SizedBox(height: 20),
                        const Divider(thickness: 1.5, color: Colors.blueGrey),
                        const SizedBox(height: 50),
                      ],
                    ),
                  ),
      ),
    );
  }
}
class FullScreenImage extends StatelessWidget {
  final String imageUrl;
  const FullScreenImage({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(imageUrl, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
