import 'package:dentease/admin/pages/dentists/admin_dentist_details.dart';
import 'package:dentease/widgets/background_cont.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdmClinicDentistsPage extends StatefulWidget {
  final String clinicId;

  const AdmClinicDentistsPage({super.key, required this.clinicId});

  @override
  State<AdmClinicDentistsPage> createState() => _AdmClinicDentistsPageState();
}

class _AdmClinicDentistsPageState extends State<AdmClinicDentistsPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> dentists = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    debugPrint('📋 [AdminClinicDentists] Initializing for clinicId: ${widget.clinicId}');
    _fetchDentists();
  }

  Future<void> _fetchDentists() async {
    debugPrint('🔄 [AdminClinicDentists] Starting to fetch dentists for clinicId: ${widget.clinicId}');
    
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    
    try {
      // Get current user info for debugging
      final currentUser = supabase.auth.currentUser;
      debugPrint('👤 [AdminClinicDentists] Current user ID: ${currentUser?.id}');
      debugPrint('👤 [AdminClinicDentists] Current user email: ${currentUser?.email}');
      
      // Fetching data including dentist_id
      debugPrint('📡 [AdminClinicDentists] Executing query: SELECT dentist_id, firstname, lastname, email FROM dentists WHERE clinic_id = ${widget.clinicId}');
      
      final response = await supabase
          .from('dentists')
          .select('dentist_id, firstname, lastname, email, status, specialization')
          .eq('clinic_id', widget.clinicId);

      debugPrint('✅ [AdminClinicDentists] Query completed successfully');
      debugPrint('📊 [AdminClinicDentists] Raw response: $response');
      debugPrint('📊 [AdminClinicDentists] Number of dentists found: ${response.length}');

      final dentistList = List<Map<String, dynamic>>.from(response);
      
      // Log each dentist found
      for (int i = 0; i < dentistList.length; i++) {
        debugPrint('👨‍⚕️ [AdminClinicDentists] Dentist $i: ${dentistList[i]}');
      }

      if (mounted) {
        setState(() {
          dentists = dentistList;
          isLoading = false;
        });
      }
      
      debugPrint('🎯 [AdminClinicDentists] State updated with ${dentists.length} dentists');
      
    } catch (e, stackTrace) {
      debugPrint('❌ [AdminClinicDentists] Error fetching dentists: $e');
      debugPrint('📚 [AdminClinicDentists] Stack trace: $stackTrace');
      
      if (mounted) {
        setState(() {
          errorMessage = 'Error fetching dentists: $e';
          isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching dentists: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🏗️ [AdminClinicDentists] Building UI - isLoading: $isLoading, dentists count: ${dentists.length}, error: $errorMessage');
    
    return BackgroundCont(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: const BackButton(color: Colors.black),
          foregroundColor: Colors.white,
          title: const Text(
            'Dentists List',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          actions: [
            // Refresh button
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: () {
                debugPrint('🔄 [AdminClinicDentists] Manual refresh triggered');
                _fetchDentists();
              },
            ),
          ],
        ),
        body: isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Loading dentists...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              )
            : errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          'Error Loading Dentists',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _fetchDentists,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : dentists.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.person_off,
                              size: 64,
                              color: Colors.white54,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No Dentists Found',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Clinic ID: ${widget.clinicId}',
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'No dentists are registered for this clinic yet.',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchDentists,
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 20),
                          itemCount: dentists.length,
                          itemBuilder: (context, index) {
                            final dentist = dentists[index];
                            final String fullName =
                                'DR. ${dentist['firstname'] ?? ''} ${dentist['lastname'] ?? ''} M.D.';
                            final String status = dentist['status'] ?? 'unknown';
                            final String specialization = dentist['specialization'] ?? '';

                            debugPrint('🎨 [AdminClinicDentists] Rendering dentist card $index: $fullName');

                            return GestureDetector(
                              onTap: () {
                                debugPrint('👆 [AdminClinicDentists] Tapped on dentist: ${dentist['dentist_id']}');
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AdmDentistDetailsPage(
                                      dentistId: dentist['dentist_id'],
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                    vertical: 6, horizontal: 16),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: Colors.purple.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            fullName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: Colors.black,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            dentist['email'] ?? 'No email available',
                                            style: const TextStyle(
                                                fontSize: 14, color: Colors.grey),
                                          ),
                                          if (specialization.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              specialization,
                                              style: TextStyle(
                                                fontSize: 12, 
                                                color: Colors.purple.shade400,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    Column(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8, 
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: status == 'approved' 
                                                ? Colors.green.shade100 
                                                : status == 'pending'
                                                    ? Colors.orange.shade100
                                                    : Colors.red.shade100,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            status.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: status == 'approved' 
                                                  ? Colors.green.shade700 
                                                  : status == 'pending'
                                                      ? Colors.orange.shade700
                                                      : Colors.red.shade700,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        const Icon(Icons.chevron_right, color: Colors.grey),
                                      ],
                                    ),
                                  ],
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
