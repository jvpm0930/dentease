import 'package:dentease/logic/safe_navigator.dart';
import 'package:dentease/patients/patient_clinicv2.dart';
import 'package:dentease/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ClinicListPage extends StatefulWidget {
  const ClinicListPage({super.key});

  @override
  State<ClinicListPage> createState() => _ClinicListPageState();
}

class _ClinicListPageState extends State<ClinicListPage> {
  // Use getter to avoid race condition with Supabase initialization
  SupabaseClient get supabase => Supabase.instance.client;
  List<Map<String, dynamic>> clinics = [];
  List<Map<String, dynamic>> filteredClinics = [];
  bool isLoading = true;
  String searchQuery = '';

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchClinics();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchClinics() async {
    try {
      final response = await supabase
          .from('clinics')
          .select('clinic_id, clinic_name, profile_url, address')
          .eq('status', 'approved')
          .order('clinic_name', ascending: true);

      setState(() {
        clinics = List<Map<String, dynamic>>.from(response);
        filteredClinics = clinics;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching clinics: $e');
      setState(() => isLoading = false);
    }
  }

  void _filterClinics(String query) {
    setState(() {
      searchQuery = query;
      if (query.isEmpty) {
        filteredClinics = clinics;
      } else {
        filteredClinics = clinics.where((clinic) {
          final name = clinic['clinic_name']?.toString().toLowerCase() ?? '';
          final address = clinic['address']?.toString().toLowerCase() ?? '';
          return name.contains(query.toLowerCase()) ||
              address.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBlue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'All Clinics',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            color: AppTheme.primaryBlue,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              controller: _searchController,
              onChanged: _filterClinics,
              style: GoogleFonts.poppins(fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Search clinics...',
                hintStyle: GoogleFonts.poppins(color: AppTheme.textGrey),
                prefixIcon:
                    Icon(Icons.search_rounded, color: AppTheme.textGrey),
                filled: true,
                fillColor: AppTheme.cardBackground,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Clinic List
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredClinics.isEmpty
                    ? Center(
                        child: Text(
                          searchQuery.isEmpty
                              ? 'No clinics available'
                              : 'No clinics match your search',
                          style: GoogleFonts.poppins(
                            color: AppTheme.textGrey,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredClinics.length,
                        itemBuilder: (context, index) {
                          return _buildClinicCard(filteredClinics[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildClinicCard(Map<String, dynamic> clinic) {
    final clinicName = clinic['clinic_name'] ?? 'Unknown Clinic';
    final profileUrl = clinic['profile_url'] as String?;
    final address = clinic['address'] as String? ?? '';

    return GestureDetector(
      onTap: () {
        SafeNavigator.push(
          context,
          PatientClinicInfoPage(clinicId: clinic['clinic_id']),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(
          children: [
            // Clinic Image
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: profileUrl ?? '',
                width: 70,
                height: 70,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  width: 70,
                  height: 70,
                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  width: 70,
                  height: 70,
                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  child: Icon(
                    Icons.local_hospital_rounded,
                    size: 32,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 16),

            // Clinic Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    clinicName,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (address.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: AppTheme.textGrey,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            address,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: AppTheme.textGrey,
                              fontWeight: FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Arrow
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 18,
              color: AppTheme.textGrey,
            ),
          ],
        ),
      ),
    );
  }
}
