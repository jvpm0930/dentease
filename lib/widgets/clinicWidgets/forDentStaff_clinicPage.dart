import 'package:dentease/clinic/dentease_profUpdate.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ClinicFrontForDentStaff extends StatefulWidget {
  final String clinicId;
  const ClinicFrontForDentStaff({super.key, required this.clinicId});

  @override
  _ClinicFrontForDentStaffState createState() =>
      _ClinicFrontForDentStaffState();
}

class _ClinicFrontForDentStaffState extends State<ClinicFrontForDentStaff> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> clinics = [];
  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchClinics();
  }

  // Fetch clinic details
  Future<void> _fetchClinics() async {
    try {
      // Fetch single clinic record
      final Map<String, dynamic> response = await supabase
          .from('clinics')
          .select('clinic_name, profile_url')
          .eq('clinic_id', widget.clinicId)
          .single();

      setState(() {
        clinics = [response]; // Store as a list with one element
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Error fetching clinics: $e';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage.isNotEmpty) {
      return Center(
          child: Text(errorMessage, style: const TextStyle(color: Colors.red)));
    }

    if (clinics.isEmpty) {
      return const Center(
          child: Text('No approved clinics available',
              style: TextStyle(color: Colors.grey)));
    }

    return SizedBox(
      height: 250, // Adjust height as needed
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: clinics.length,
        itemBuilder: (context, index) {
          final clinic = clinics[index];
          final clinicName = clinic['clinic_name'] ?? 'Unknown Clinic';
          final profileUrl = clinic['profile_url'] as String?;

          // Build clinic card (clickable to edit)
          return GestureDetector(
            onTap: () async {
              final updated = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UpdateProfileImage(
                    clinicId: widget.clinicId,
                    profileUrl: profileUrl,
                  ),
                ),
              );

              // Refresh data after updating
              if (updated == true) {
                _fetchClinics();
              }
            },
            child: _buildClinicCard(context, clinicName, profileUrl),
          );
        },
      ),
    );
  }

  Widget _buildClinicCard(
      BuildContext context, String title, String? profileUrl) {
    return Container(
      width: 200, // Card width
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 5, spreadRadius: 1)
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              child: profileUrl != null && profileUrl.isNotEmpty
                  ? Image.network(
                      profileUrl,
                      width: 200,
                      height: 200,
                      fit: BoxFit
                          .cover, // Use BoxFit.cover for filling without distortion
                      errorBuilder: (context, error, stackTrace) {
                        return Image.asset(
                          'assets/clinic3.png',
                          width: 200,
                          height: 200,
                          fit: BoxFit.cover, // Same fit for fallback
                        );
                      },
                    )
                  : Image.asset(
                      'assets/clinic3.png',
                      width: 200,
                      height: 200,
                      fit:
                          BoxFit.cover, // Ensures fallback image fits correctly
                    ),

            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Center(
              child: Text(
                title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
