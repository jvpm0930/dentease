import 'package:dentease/admin/pages/staffs/admin_staff_details.dart';
import 'package:dentease/widgets/background_cont.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdmClinicStaffsPage extends StatefulWidget {
  final String clinicId;

  const AdmClinicStaffsPage({super.key, required this.clinicId});

  @override
  State<AdmClinicStaffsPage> createState() => _AdmClinicStaffsPageState();
}

class _AdmClinicStaffsPageState extends State<AdmClinicStaffsPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> staffs = [];
  bool isLoading = true;
  String? errorMessage;
  bool? clinicHasStaff; // null = unknown, true = has staff enabled, false = no staff

  @override
  void initState() {
    super.initState();
    debugPrint('📋 [AdminClinicStaff] Initializing for clinicId: ${widget.clinicId}');
    _fetchStaffs();
  }

  Future<void> _fetchStaffs() async {
    debugPrint('🔄 [AdminClinicStaff] Starting to fetch staffs for clinicId: ${widget.clinicId}');
    
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    
    try {
      // Get current user info for debugging
      final currentUser = supabase.auth.currentUser;
      debugPrint('👤 [AdminClinicStaff] Current user ID: ${currentUser?.id}');
      debugPrint('👤 [AdminClinicStaff] Current user email: ${currentUser?.email}');
      
      // First, check if the clinic has staff enabled (has_staff column)
      debugPrint('📡 [AdminClinicStaff] Checking clinic has_staff setting...');
      try {
        final clinicResponse = await supabase
            .from('clinics')
            .select('has_staff')
            .eq('clinic_id', widget.clinicId)
            .maybeSingle();
        
        debugPrint('🏥 [AdminClinicStaff] Clinic response: $clinicResponse');
        
        if (clinicResponse != null) {
          clinicHasStaff = clinicResponse['has_staff'] as bool?;
          debugPrint('🏥 [AdminClinicStaff] Clinic has_staff: $clinicHasStaff');
        } else {
          debugPrint('⚠️ [AdminClinicStaff] Clinic not found or has_staff column missing');
          clinicHasStaff = true; // Default to true (assume they have staff)
        }
      } catch (e) {
        debugPrint('⚠️ [AdminClinicStaff] Error checking has_staff: $e (column may not exist)');
        clinicHasStaff = true; // Default to true if column doesn't exist
      }

      // Fetch staff data
      debugPrint('📡 [AdminClinicStaff] Executing query: SELECT staff_id, firstname, lastname, email FROM staffs WHERE clinic_id = ${widget.clinicId}');
      
      final response = await supabase
          .from('staffs')
          .select('staff_id, firstname, lastname, email')
          .eq('clinic_id', widget.clinicId);

      debugPrint('✅ [AdminClinicStaff] Query completed successfully');
      debugPrint('📊 [AdminClinicStaff] Raw response: $response');
      debugPrint('📊 [AdminClinicStaff] Number of staffs found: ${response.length}');

      final staffList = List<Map<String, dynamic>>.from(response);
      
      // Log each staff found
      for (int i = 0; i < staffList.length; i++) {
        debugPrint('👩‍💼 [AdminClinicStaff] Staff $i: ${staffList[i]}');
      }

      if (mounted) {
        setState(() {
          staffs = staffList;
          isLoading = false;
        });
      }
      
      debugPrint('🎯 [AdminClinicStaff] State updated with ${staffs.length} staffs, clinicHasStaff: $clinicHasStaff');
      
    } catch (e, stackTrace) {
      debugPrint('❌ [AdminClinicStaff] Error fetching staffs: $e');
      debugPrint('📚 [AdminClinicStaff] Stack trace: $stackTrace');
      
      if (mounted) {
        setState(() {
          errorMessage = 'Error fetching staffs: $e';
          isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching staffs: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Get the appropriate empty state message based on clinic settings
  Widget _buildEmptyState() {
    debugPrint('🎨 [AdminClinicStaff] Building empty state - clinicHasStaff: $clinicHasStaff');
    
    // If clinicHasStaff is explicitly false, the dentist said they don't have staff
    if (clinicHasStaff == false) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.group_off,
              size: 64,
              color: Colors.white54,
            ),
            const SizedBox(height: 16),
            const Text(
              'No Staff Currently',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This clinic operates without staff members.',
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            const Text(
              'The dentist indicated they do not have staff.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    
    // If clinicHasStaff is true (or null/unknown), they should have staff but none found
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.person_search,
            size: 64,
            color: Colors.white54,
          ),
          const SizedBox(height: 16),
          const Text(
            'No Staff Found',
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
            'No staff members have been registered for this clinic yet.',
            style: TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🏗️ [AdminClinicStaff] Building UI - isLoading: $isLoading, staffs count: ${staffs.length}, error: $errorMessage');
    
    return BackgroundCont(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: const BackButton(color: Colors.black),
          foregroundColor: Colors.white,
          backgroundColor: Colors.transparent,
          title: const Text(
            'Staff List',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          actions: [
            // Refresh button
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: () {
                debugPrint('🔄 [AdminClinicStaff] Manual refresh triggered');
                _fetchStaffs();
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
                      'Loading staff members...',
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
                        const Text(
                          'Error Loading Staff',
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
                          onPressed: _fetchStaffs,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : staffs.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _fetchStaffs,
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 20),
                          itemCount: staffs.length,
                          itemBuilder: (context, index) {
                            final staff = staffs[index];
                            final String fullName =
                                'Sec. ${staff['firstname'] ?? ''} ${staff['lastname'] ?? ''}';
                            final String role = staff['role'] ?? 'staff';

                            debugPrint('🎨 [AdminClinicStaff] Rendering staff card $index: $fullName');

                            return GestureDetector(
                              onTap: () {
                                debugPrint('👆 [AdminClinicStaff] Tapped on staff: ${staff['staff_id']}');
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AdmStaffDetailsPage(
                                      staffId: staff['staff_id'],
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
                                            staff['email'] ?? 'No email available',
                                            style: const TextStyle(
                                                fontSize: 14, color: Colors.grey),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            role.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.purple.shade400,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right, color: Colors.grey),
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
