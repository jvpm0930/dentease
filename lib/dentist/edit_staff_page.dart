import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditStaffPage extends StatefulWidget {
  final String staffId;
  final String clinicId;
  final Map<String, dynamic> staffData;

  const EditStaffPage({
    super.key,
    required this.staffId,
    required this.clinicId,
    required this.staffData,
  });

  @override
  State<EditStaffPage> createState() => _EditStaffPageState();
}

class _EditStaffPageState extends State<EditStaffPage> {
  final supabase = Supabase.instance.client;

  late TextEditingController firstnameController;
  late TextEditingController lastnameController;
  late TextEditingController phoneController;
  late TextEditingController emailController; // Read-only

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize controllers with existing data
    firstnameController = TextEditingController(
      text: widget.staffData['firstname'] ?? '',
    );
    lastnameController = TextEditingController(
      text: widget.staffData['lastname'] ?? '',
    );
    phoneController = TextEditingController(
      text: widget.staffData['phone'] ?? '',
    );
    emailController = TextEditingController(
      text: widget.staffData['email'] ?? '',
    );
  }

  @override
  void dispose() {
    firstnameController.dispose();
    lastnameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    super.dispose();
  }

  Future<void> _updateStaff() async {
    try {
      final firstname = firstnameController.text.trim();
      final lastname = lastnameController.text.trim();
      final phone = phoneController.text.trim();

      // Validation
      if (firstname.isEmpty || lastname.isEmpty) {
        _showSnackbar('First name and last name are required');
        return;
      }

      setState(() => isLoading = true);

      // Update staff record in Supabase
      await supabase.from('staffs').update({
        'firstname': firstname,
        'lastname': lastname,
        'phone': phone,
      }).eq('staff_id', widget.staffId);

      _showSnackbar('Staff updated successfully!');

      // Navigate back with updated flag
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Error updating staff: $e');
      _showSnackbar('Error updating staff: ${e.toString()}');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA), // Modern admin background
        appBar: AppBar(
          backgroundColor: const Color(0xFF0D2A7A),
          foregroundColor: Colors.white,
          elevation: 0,
          leading: const BackButton(color: Colors.white),
          title: Text(
            'Edit Staff',
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Container(
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
                      Icons.person_outline,
                      size: 48,
                      color: Color(0xFF0D2A7A),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Update Staff Information',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF1E293B),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Email (read-only)
                  _buildTextField(
                    emailController,
                    'Email',
                    Icons.mail,
                    readOnly: true,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Email cannot be changed',
                    style: GoogleFonts.roboto(
                      color: const Color(0xFF64748B),
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Editable fields
                  _buildTextField(
                      firstnameController, 'First Name', Icons.person),
                  const SizedBox(height: 12),
                  _buildTextField(
                      lastnameController, 'Last Name', Icons.person),
                  const SizedBox(height: 12),
                  _buildTextField(phoneController, 'Phone Number', Icons.phone),
                  const SizedBox(height: 24),

                  // Update button
                  isLoading
                      ? const CircularProgressIndicator(
                          color: Color(0xFF0D2A7A))
                      : _buildUpdateButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool readOnly = false,
  }) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      style: TextStyle(
        color: readOnly ? Colors.black54 : Colors.black87,
      ),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: readOnly ? const Color(0xFFF8FAFC) : Colors.white,
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
        prefixIcon: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Icon(
            icon,
            color: readOnly ? Colors.grey : const Color(0xFF0D2A7A),
          ),
        ),
      ),
    );
  }

  Widget _buildUpdateButton() {
    return ElevatedButton.icon(
      onPressed: _updateStaff,
      icon: const Icon(Icons.save),
      label: Text(
        'Update Staff',
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF0D2A7A),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
        elevation: 2,
      ),
    );
  }
}
