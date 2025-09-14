import 'dart:async';
import 'package:dentease/clinic/dentease_EditmoreDetails.dart';
import 'package:flutter/material.dart';
import 'package:dentease/widgets/background_cont.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class ClinicDetails extends StatefulWidget {
  final String clinicId;

  const ClinicDetails({
    super.key,
    required this.clinicId,
  });

  @override
  State<ClinicDetails> createState() => _ClinicDetailsState();
}

class FullScreenImage extends StatelessWidget {
  final String imageUrl;

  const FullScreenImage({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          boundaryMargin: const EdgeInsets.all(20),
          minScale: 0.5,
          maxScale: 3.0,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

class _ClinicDetailsState extends State<ClinicDetails> {
  final supabase = Supabase.instance.client;
  Map<String, dynamic>? clinicDetails;
  bool isLoading = true;
  String? profileUrl;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchClinicDetails();
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _fetchClinicDetails(); // Call your refresh function
    });
  }

  @override
  void dispose() {
    //  Dispose of the timer to avoid memory leaks
    _timer?.cancel();
    super.dispose();
  }

  /// Fetch clinic details from Supabase
  Future<void> _fetchClinicDetails() async {
    try {
      final response = await supabase
          .from('clinics')
          .select()
          .eq('clinic_id', widget.clinicId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          clinicDetails = response;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching clinic details: $e')),
        );
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  /// Build each row of clinic info
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.black,
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundCont(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            "Clinic Details",
            style: TextStyle(color: Colors.white),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: isLoading
                    ? const CircularProgressIndicator()
                    : clinicDetails == null
                        ? const Text(
                            'No clinic details found.',
                            style: TextStyle(fontSize: 14, color: Colors.white),
                          )
                        : RefreshIndicator(
                            onRefresh: _fetchClinicDetails,
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  _buildDetailRow('Status:',
                                      clinicDetails?['status'] ?? 'N/A'),
                                  _buildDetailRow('Clinic Name:',
                                      clinicDetails?['clinic_name'] ?? 'N/A'),
                                  _buildDetailRow('Clinic Contact #:',
                                      clinicDetails?['phone'] ?? 'N/A'),
                                  _buildDetailRow('Email:',
                                      clinicDetails?['email'] ?? 'N/A'),
                                  _buildDetailRow('Address:',
                                      clinicDetails?['address'] ?? 'N/A'),

                                  // Map Widget (if lat/lng exists)
                                  if (clinicDetails?['latitude'] != null &&
                                      clinicDetails?['longitude'] != null)
                                    const SizedBox(height: 8),
                                  if (clinicDetails?['latitude'] != null &&
                                      clinicDetails?['longitude'] != null)
                                    SizedBox(
                                      height: 150,
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
                                            markerId: const MarkerId(
                                                'clinicLocation'),
                                            position: LatLng(
                                              clinicDetails!['latitude'],
                                              clinicDetails!['longitude'],
                                            ),
                                          ),
                                        },
                                      ),
                                    ),
                                  const SizedBox(height: 8),

                                  // License Image
                                  if (clinicDetails?['license_url'] != null)
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'License Image:',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        GestureDetector(
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    FullScreenImage(
                                                  imageUrl: clinicDetails![
                                                      'license_url'],
                                                ),
                                              ),
                                            );
                                          },
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            child: Image.network(
                                              clinicDetails!['license_url'],
                                              height: 150,
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                     const SizedBox(height: 8),

                                  // Permit Image
                                  if (clinicDetails?['permit_url'] != null)
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Permit Image:',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        GestureDetector(
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    FullScreenImage(
                                                  imageUrl: clinicDetails![
                                                      'permit_url'],
                                                ),
                                              ),
                                            );
                                          },
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            child: Image.network(
                                              clinicDetails!['permit_url'],
                                              height: 150,
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                     const SizedBox(height: 8),

                                  // Office Image
                                  if (clinicDetails?['office_url'] != null)
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Office Image:',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        GestureDetector(
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    FullScreenImage(
                                                  imageUrl: clinicDetails![
                                                      'office_url'],
                                                ),
                                              ),
                                            );
                                          },
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            child: Image.network(
                                              clinicDetails!['office_url'],
                                              height: 150,
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  const SizedBox(height: 20),

                                  // Clinic Info
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Clinic Info:',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                      Text(
                                        clinicDetails?['info'] ?? 'N/A',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),

                                  // Edit Button to navigate to EditClinicDetails
                                  ElevatedButton.icon(
                                    onPressed: () async {
                                      final result = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              EditClinicDetails(
                                            clinicDetails: clinicDetails!,
                                            clinicId: widget.clinicId,
                                          ),
                                        ),
                                      );

                                      // Manually refresh after edit
                                      if (result == true) {
                                        _fetchClinicDetails();
                                      }
                                    },
                                    icon: const Icon(Icons.edit),
                                    label: const Text(
                                      'Edit Clinic Details',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 24, vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
              ),
            ),
          ],
        ),

      ),
    );
  }
}
