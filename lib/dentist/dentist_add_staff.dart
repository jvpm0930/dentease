import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DentAddStaff extends StatefulWidget {
  final String clinicId;

  const DentAddStaff({super.key, required this.clinicId});

  @override
  State<DentAddStaff> createState() => _DentAddStaffState();
}

class _DentAddStaffState extends State<DentAddStaff> {
  // Use getter to avoid race condition with Supabase initialization
  SupabaseClient get supabase => Supabase.instance.client;

  final firstnameController = TextEditingController();
  final lastnameController = TextEditingController();
  final passwordController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();

  bool isLoading = false;
  bool canManageSchedule = false; // Permissions toggle
  String? clinicNameSlug; // For email validation

  @override
  void dispose() {
    firstnameController.dispose();
    lastnameController.dispose();
    passwordController.dispose();
    phoneController.dispose();
    emailController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchClinicSlug();
  }

  /// Fetch clinic name and convert to slug for email validation
  Future<void> _fetchClinicSlug() async {
    try {
      final clinic = await supabase
          .from('clinics')
          .select('clinic_name')
          .eq('clinic_id', widget.clinicId)
          .maybeSingle();

      if (clinic != null && mounted) {
        setState(() {
          clinicNameSlug = clinic['clinic_name']
              .toString()
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-z0-9]'), '');
        });
      }
    } catch (e) {
      debugPrint('Error fetching clinic name: $e');
    }
  }

  Future<void> createStaff() async {
    try {
      final firstname = firstnameController.text.trim();
      final lastname = lastnameController.text.trim();
      final phone = phoneController.text.trim();
      final email = emailController.text.trim();
      final password = passwordController.text.trim();

      // Validation
      if (firstname.isEmpty ||
          lastname.isEmpty ||
          email.isEmpty ||
          password.isEmpty) {
        _showSnackbar('Please fill in all required fields.');
        return;
      }

      if (!RegExp(r"^[a-zA-Z0-9+_.-]+@[a-zA-Z0-9.-]+$").hasMatch(email)) {
        _showSnackbar('Please enter a valid email.');
        return;
      }

      if (password.length < 6) {
        _showSnackbar('Password must be at least 6 characters long.');
        return;
      }

      // Basic email validation is already done above
      // Removed domain restriction to allow any valid email address

      setState(() => isLoading = true);

      // Check if email already exists in staffs table
      final existingStaff = await supabase
          .from('staffs')
          .select('email')
          .eq('email', email)
          .maybeSingle();

      if (existingStaff != null) {
        _showSnackbar(
            'Email already exists. Please use a different email address.');
        setState(() => isLoading = false);
        return;
      }

      // Call Edge Function for server-side user creation
      final response = await supabase.functions.invoke(
        'create_user',
        body: {
          'email': email,
          'password': password,
          'role': 'staff',
          'clinic_id': widget.clinicId,
          'profile_data': {
            'firstname': firstname,
            'lastname': lastname,
            'phone': phone,
            // Remove permissions for now since it's not in the schema
          },
        },
      );

      if (response.status == 200) {
        final data = response.data as Map<String, dynamic>;

        if (data['success'] == true) {
          _showSnackbar('Staff member added successfully!');

          // Navigate back to staff list (dentist stays logged in)
          if (mounted) {
            Navigator.pop(context, true); // Return true to indicate success
          }
        } else {
          _showSnackbar('Error: ${data['error'] ?? 'Failed to create staff'}');
        }
      } else {
        _showSnackbar('Server error: ${response.status}');
      }
    } catch (e) {
      debugPrint('Error creating staff: $e');
      String errorMessage = 'Error: ${e.toString()}';

      // Provide more specific error messages
      if (e.toString().contains('FunctionsException')) {
        errorMessage =
            'Server function error. Please check if the create_user function is deployed.';
      } else if (e.toString().contains('network')) {
        errorMessage = 'Network error. Please check your internet connection.';
      } else if (e.toString().contains('email') ||
          e.toString().contains('already exist')) {
        errorMessage =
            'Email already exists. Please use a different email address.';
      }

      _showSnackbar(errorMessage);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: message.contains('successfully')
            ? const Color(0xFF00BFA5)
            : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0D2A7A),
          foregroundColor: Colors.white,
          elevation: 0,
          leading: const BackButton(color: Colors.white),
          title: Text(
            'Add Staff Member',
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D2A7A).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_add_rounded,
                        size: 48,
                        color: Color(0xFF0D2A7A),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Add New Staff Member',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Fill in the details below to add a new staff member to your clinic',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.roboto(
                        fontSize: 14,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Form Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Personal Information',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0D2A7A),
                      ),
                    ),
                    const SizedBox(height: 20),

                    _buildModernTextField(
                      controller: firstnameController,
                      label: 'First Name',
                      icon: Icons.person_outline,
                      hint: 'Enter first name',
                    ),
                    const SizedBox(height: 16),

                    _buildModernTextField(
                      controller: lastnameController,
                      label: 'Last Name',
                      icon: Icons.person_outline,
                      hint: 'Enter last name',
                    ),
                    const SizedBox(height: 16),

                    _buildModernTextField(
                      controller: phoneController,
                      label: 'Phone Number',
                      icon: Icons.phone_outlined,
                      hint: 'Enter phone number',
                      keyboardType: TextInputType.phone,
                    ),

                    const SizedBox(height: 24),

                    Text(
                      'Account Information',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0D2A7A),
                      ),
                    ),
                    const SizedBox(height: 20),

                    _buildModernTextField(
                      controller: emailController,
                      label: 'Email Address',
                      icon: Icons.email_outlined,
                      hint: 'Enter email address',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),

                    _buildModernTextField(
                      controller: passwordController,
                      label: 'Password',
                      icon: Icons.lock_outline,
                      hint: 'Enter password (min 6 characters)',
                      isPassword: true,
                    ),

                    const SizedBox(height: 24),

                    // Permissions Section (commented out for now)
                    /*
                    Text(
                      'Permissions',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0D2A7A),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D2A7A).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.schedule_outlined,
                              color: Color(0xFF0D2A7A),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Schedule Management',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF1E293B),
                                  ),
                                ),
                                Text(
                                  'Allow this staff member to edit clinic schedule',
                                  style: GoogleFonts.roboto(
                                    fontSize: 12,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: canManageSchedule,
                            onChanged: (value) {
                              setState(() => canManageSchedule = value);
                            },
                            activeColor: const Color(0xFF0D2A7A),
                          ),
                        ],
                      ),
                    ),
                    */

                    const SizedBox(height: 32),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed:
                                isLoading ? null : () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: const BorderSide(color: Color(0xFF0D2A7A)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF0D2A7A),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isLoading ? null : createStaff,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0D2A7A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    'Add Staff Member',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: isPassword,
          style: GoogleFonts.roboto(
            fontSize: 16,
            color: const Color(0xFF1E293B),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.roboto(
              color: const Color(0xFF64748B),
            ),
            prefixIcon: Icon(
              icon,
              color: const Color(0xFF0D2A7A),
              size: 20,
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF0D2A7A), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }
}
