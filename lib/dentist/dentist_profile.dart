import 'package:dentease/dentist/dentist_profile_update.dart';
import 'package:dentease/login/login_screen.dart';
import 'package:dentease/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DentistProfile extends StatefulWidget {
  final String dentistId;

  const DentistProfile({super.key, required this.dentistId});

  @override
  State<DentistProfile> createState() => _DentistProfileState();
}

class _DentistProfileState extends State<DentistProfile> {
  final supabase = Supabase.instance.client;
  Map<String, dynamic>? dentistDetails;
  Map<String, dynamic>? clinicDetails;
  bool isLoading = true;
  String? profileUrl;

  @override
  void initState() {
    super.initState();
    _fetchDentistDetails();
  }

  Future<void> _fetchDentistDetails() async {
    try {
      final response = await supabase
          .from('dentists')
          .select(
              'firstname, lastname, phone, role, profile_url, fcm_token, clinic_id')
          .eq('dentist_id', widget.dentistId)
          .single();

      final clinicId = response['clinic_id'];
      Map<String, dynamic>? fetchedClinic;
      if (clinicId != null) {
        fetchedClinic = await supabase
            .from('clinics')
            .select(
                'clinic_name, email, address, license_url, permit_url, office_url, profile_url, info')
            .eq('clinic_id', clinicId)
            .maybeSingle();
      }

      if (mounted) {
        setState(() {
          dentistDetails = response;
          clinicDetails = fetchedClinic;
          final url = response['profile_url'];
          if (url != null && url.isNotEmpty) {
            // Cache-buster
            profileUrl =
                '$url?timestamp=${DateTime.now().millisecondsSinceEpoch}';
          } else {
            profileUrl = null;
          }
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching dentist details: $e')),
        );
      }
      setState(() => isLoading = false);
    }
  }

  Future<void> _logout(BuildContext context) async {
    try {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          content: const Text('Are you sure you want to log out?'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(context, false),
            ),
            ElevatedButton(
              child: const Text('Logout'),
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await Supabase.instance.client.auth.signOut();

        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logout failed: $e')),
        );
      }
    }
  }

  Widget _buildProfilePicture() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowMedium,
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: CircleAvatar(
        radius: 80,
        backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
        backgroundImage: profileUrl != null && profileUrl!.isNotEmpty
            ? NetworkImage(profileUrl!)
            : const AssetImage('assets/profile.png') as ImageProvider,
        child: profileUrl == null || profileUrl!.isEmpty
            ? Icon(
                Icons.person_rounded,
                size: 80,
                color: AppTheme.primaryBlue,
              )
            : null,
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.softBlue,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: AppTheme.primaryBlue,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppTheme.textGrey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isNotEmpty ? value : 'N/A',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppTheme.textDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          "My Profile",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppTheme.primaryBlue,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        automaticallyImplyLeading: false,
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryBlue))
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: ListView(
                children: [
                  const SizedBox(height: 10),
                  Center(child: _buildProfilePicture()),
                  const SizedBox(height: 24),

                  // Personal Information Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.cardBackground,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Personal Information',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textDark,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildInfoTile(Icons.person, "Firstname",
                            dentistDetails?['firstname'] ?? ''),
                        _buildInfoTile(Icons.person_outline, "Lastname",
                            dentistDetails?['lastname'] ?? ''),
                        _buildInfoTile(Icons.phone, "Phone Number",
                            dentistDetails?['phone'] ?? ''),
                        _buildInfoTile(
                            Icons.badge, "Role", dentistDetails?['role'] ?? ''),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Clinic Info Section (Separate Card)
                  if (clinicDetails != null) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBackground,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: AppTheme.cardShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Clinic Details",
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textDark,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildInfoTile(Icons.business, "Clinic Name",
                              clinicDetails?['clinic_name'] ?? ''),
                          _buildInfoTile(Icons.location_on, "Address",
                              clinicDetails?['address'] ?? ''),
                          _buildInfoTile(Icons.email, "Clinic Email",
                              clinicDetails?['email'] ?? ''),
                          _buildInfoTile(Icons.info_outline, "Description",
                              clinicDetails?['info'] ?? ''),
                          
                          const SizedBox(height: 16),
                          Text(
                            "Clinic Images",
                             style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textDark,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _buildDocumentTile(
                              "Clinic Logo", clinicDetails?['profile_url']),
                          _buildDocumentTile("Clinic Banner/Frontal",
                              clinicDetails?['office_url']),
                          
                          const SizedBox(height: 16),
                          Text(
                            "Clinic Documents",
                             style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textDark,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _buildDocumentTile("Business License",
                              clinicDetails?['license_url']),
                          _buildDocumentTile(
                              "Permit", clinicDetails?['permit_url']),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Action Buttons
                  ElevatedButton.icon(
                    onPressed: () async {
                      final updated = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              DentistProfUpdate(dentistId: widget.dentistId),
                        ),
                      );
                      if (updated == true) {
                        _fetchDentistDetails();
                      }
                    },
                    icon: const Icon(Icons.edit_rounded, color: Colors.white),
                    label: Text(
                      'Edit Profile',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.logout_rounded, color: Colors.white),
                    label: Text(
                      'Logout',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.errorColor,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    onPressed: () async => await _logout(context),
                  ),

                  const SizedBox(height: 50),
                ],
              ),
            ),
    );
  }

  Widget _buildDocumentTile(String title, String? url) {
    final hasImage = url != null && url.isNotEmpty;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.softBlue,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600, color: AppTheme.textDark)),
          const SizedBox(height: 8),
          if (hasImage)
            GestureDetector(
              onTap: () {
                if (url.isNotEmpty) {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              FullScreenImageViewer(imageUrl: url)));
                }
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    url,
                    fit: BoxFit.cover,
                    loadingBuilder: (ctx, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                          color: Colors.grey.shade200,
                          child: const Center(
                              child: Icon(Icons.image, color: Colors.grey)));
                    },
                    errorBuilder: (ctx, err, stack) => Container(
                        color: Colors.grey.shade200,
                        child: const Center(
                            child:
                                Icon(Icons.broken_image, color: Colors.grey))),
                  ),
                ),
              ),
            )
          else
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Text("No document upload.",
                    style: GoogleFonts.poppins(
                        color: AppTheme.textGrey, fontSize: 13)),
              ],
            )
        ],
      ),
    );
  }
}

class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  const FullScreenImageViewer({super.key, required this.imageUrl});

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
          child: Image.network(imageUrl),
        ),
      ),
    );
  }
}
