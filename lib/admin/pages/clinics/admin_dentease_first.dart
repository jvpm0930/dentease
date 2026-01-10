import 'package:dentease/admin/pages/clinics/admin_clinic_details.dart';
import 'package:dentease/admin/pages/clinics/admin_dentease_second.dart';
import 'package:dentease/widgets/adminWidgets/admin_clinic_card.dart';
import 'package:dentease/widgets/background_cont.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminClinicListPage extends StatefulWidget {
  final bool showFeaturedOnly;
  const AdminClinicListPage({super.key, this.showFeaturedOnly = false});

  @override
  State<AdminClinicListPage> createState() => _AdminClinicListPageState();
}

class _AdminClinicListPageState extends State<AdminClinicListPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> clinics = [];
  bool isLoading = true;

  static const kPrimaryBlue = Color(0xFF1134A6);
  static const kBackground = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _fetchClinics();
  }

  Future<void> _fetchClinics() async {
    try {
      var query = supabase
          .from('clinics')
          .select(
              'clinic_id, clinic_name, status, email, created_at, is_featured')
          .eq('status', 'approved');

      if (widget.showFeaturedOnly) {
        query = query.eq('is_featured', true);
      }

      final response = await query.order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          clinics = List<Map<String, dynamic>>.from(response);
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar('Error fetching clinics');
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _showSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundCont(
      child: Scaffold(
        backgroundColor: kBackground,
        appBar: AppBar(
          foregroundColor: const Color(0xFF102A43),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: widget.showFeaturedOnly
              ? BackButton(color: const Color(0xFF102A43))
              : null,
          automaticallyImplyLeading: !widget.showFeaturedOnly,
          centerTitle: true,
          title: Text(
            widget.showFeaturedOnly ? "Featured Clinics" : "Approved Clinics",
            style: GoogleFonts.poppins(
              color: const Color(0xFF102A43),
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),
        body: isLoading
            ? const Center(
                child: CircularProgressIndicator(color: kPrimaryBlue))
            : clinics.isEmpty
                ? Center(
                    child: Text(
                      'No approved clinics found',
                      style: GoogleFonts.poppins(color: Colors.grey),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _fetchClinics,
                    color: kPrimaryBlue,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 80, top: 10),
                      itemCount: clinics.length,
                      itemBuilder: (context, index) {
                        final clinic = clinics[index];
                        return AdminClinicCard(
                          clinicName: clinic['clinic_name'] ?? 'Unknown Clinic',
                          email: clinic['email'] ?? 'No Email',
                          status: 'approved',
                          submittedDate: _formatDate(clinic['created_at']),
                          showQuickActions:
                              false, // No quick actions for approved list
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AdmClinicDetailsPage(
                                  clinicId: clinic['clinic_id'],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}
