import 'package:dentease/patients/patient_clinicv2.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ClinicCarousel extends StatefulWidget {
  const ClinicCarousel({super.key});

  @override
  _ClinicCarouselState createState() => _ClinicCarouselState();
}

class _ClinicCarouselState extends State<ClinicCarousel> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> clinics = [];
  final TextEditingController searchController = TextEditingController();
  String searchQuery = '';
  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchClinics();
  }

  /// **🔹 Fetch only clinics where `status = 'approved'`**
  Future<void> _fetchClinics() async {
    try {
      final List<dynamic> response = await supabase
          .from('clinics')
          .select('clinic_id, clinic_name, profile_url')
          .eq('status', 'approved'); // Only approved clinics

      setState(() {
        clinics = List<Map<String, dynamic>>.from(response);
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

    final filteredClinics = clinics.where((clinic) {
      final name = clinic['clinic_name']?.toString().toLowerCase() ?? '';
      return name.contains(searchQuery.toLowerCase());
    }).toList();

    return SafeArea(
      child: SingleChildScrollView(
        // Add scroll view
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            //const SizedBox(height: 10), // 🔹 Extra top padding
            /*
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: searchController,
                decoration: const InputDecoration(
                  labelText: 'Search Clinics',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() {
                    searchQuery = value;
                  });
                },
              ),
            ),
            */
            const SizedBox(height: 10),
            SizedBox(
              height: 250,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: filteredClinics.length,
                itemBuilder: (context, index) {
                  final clinic = filteredClinics[index];
                  final clinicName = clinic['clinic_name'] ?? 'Unknown Clinic';
                  final profileUrl = clinic['profile_url'] as String?;

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PatientClinicInfoPage(
                              clinicId: clinic['clinic_id']),
                        ),
                      );
                    },
                    child: _buildClinicCard(context, clinicName, profileUrl),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }


  /// Creates a Clickable Clinic Card
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
            child: profileUrl != null && profileUrl.isNotEmpty
                ? ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    child: Image.network(
                      profileUrl,
                      width: 200,
                      height: 200,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.broken_image,
                            size: 100, color: Colors.grey);
                      },
                    ),
                  )
                : const Icon(Icons.image, size: 100, color: Colors.grey),
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
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
