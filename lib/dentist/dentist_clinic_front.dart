import 'package:dentease/clinic/dentease_moreDetails.dart';
import 'package:dentease/widgets/clinicWidgets/forDentStaff_clinicPage.dart';
import 'package:flutter/material.dart';
import 'package:dentease/widgets/background_cont.dart';
import 'package:dentease/widgets/dentistWidgets/dentist_footer.dart';
import 'package:dentease/widgets/dentistWidgets/dentist_header.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DentClinicPage extends StatefulWidget {
  final String clinicId;

  const DentClinicPage({
    super.key,
    required this.clinicId,
  });

  @override
  State<DentClinicPage> createState() => _DentClinicPageState();
}

class _DentClinicPageState extends State<DentClinicPage> {
  final supabase = Supabase.instance.client;
  final Color kPrimary = const Color(0xFF103D7E);

  Map<String, dynamic>? clinicDetails;
  String? dentistId; // Store the fetched dentist_id
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchClinicDetails();
  }

  /// Fetch clinic details and the associated `dentist_id`
  Future<void> _fetchClinicDetails() async {
    try {
      final clinicResponse = await supabase
          .from('clinics')
          .select()
          .eq('clinic_id', widget.clinicId)
          .maybeSingle();

      final dentistResponse = await supabase
          .from('dentists')
          .select('dentist_id')
          .eq('clinic_id', widget.clinicId)
          .maybeSingle();

      setState(() {
        clinicDetails = clinicResponse;
        dentistId = dentistResponse?['dentist_id'];
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching clinic details: $e')),
      );
      setState(() {
        isLoading = false;
      });
    }
  }

  // Keeps original function (unused in new layout) for compatibility
  Widget _buildDetailRow(String label, String value) {
    final isStatusRow = label.toLowerCase().contains('status');
    final isRejected = value.toLowerCase() == 'rejected';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: isStatusRow && isRejected ? Colors.red : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    final s = status.toLowerCase();
    Color bg;
    Color fg;
    if (s == 'approved' || s == 'active') {
      bg = Colors.green.withOpacity(0.12);
      fg = Colors.green.shade800;
    } else if (s == 'pending' || s == 'in-review') {
      bg = Colors.orange.withOpacity(0.12);
      fg = Colors.orange.shade800;
    } else if (s == 'rejected' || s == 'inactive') {
      bg = Colors.red.withOpacity(0.12);
      fg = Colors.red.shade800;
    } else {
      bg = Colors.grey.withOpacity(0.12);
      fg = Colors.black87;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flag_rounded, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(status,
              style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = clinicDetails?['clinic_name']?.toString() ?? 'N/A';
    final status = clinicDetails?['status']?.toString() ?? 'N/A';
    final note = clinicDetails?['note']?.toString() ?? 'N/A';

    return BackgroundCont(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            const DentistHeader(),

            // Main content area
            Positioned.fill(
              top: 140,
              bottom: 100,
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : clinicDetails == null
                      ? const Center(
                          child: _EmptyCard(
                            message: 'No clinic details found.',
                          ),
                        )
                      : SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          child: Column(
                            children: [
                              // Cover / Front section
                              _SectionCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _SectionTitle(
                                      icon: Icons.local_hospital_rounded,
                                      title: "Clinic Front",
                                      color: kPrimary,
                                    ),
                                    const SizedBox(height: 10),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        color: const Color.fromARGB(0, 0, 0, 0),
                                        child: ClinicFrontForDentStaff(
                                            clinicId: widget.clinicId),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Details section
                              _SectionCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _SectionTitle(
                                      icon: Icons.info_rounded,
                                      title: "Clinic Overview",
                                      color: kPrimary,
                                    ),
                                    const SizedBox(height: 12),

                                    // Name
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: CircleAvatar(
                                        backgroundColor:
                                            kPrimary.withOpacity(0.1),
                                        foregroundColor: kPrimary,
                                        child: const Icon(Icons.apartment),
                                      ),
                                      title: const Text(
                                        "Clinic Name",
                                        style: TextStyle(
                                          color: Colors.black54,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      subtitle: Text(
                                        name,
                                        style: const TextStyle(
                                          color: Colors.black87,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 8),

                                    // Status
                                    Row(
                                      children: [
                                        const Icon(Icons.verified_user,
                                            color: Colors.black54),
                                        const SizedBox(width: 10),
                                        const Text(
                                          "Status:",
                                          style: TextStyle(
                                            color: Colors.black54,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        _statusChip(status),
                                      ],
                                    ),

                                    const SizedBox(height: 14),

                                    // Note
                                    const Text(
                                      "Note",
                                      style: TextStyle(
                                        color: Colors.black54,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                            color: Colors.grey.shade300),
                                      ),
                                      child: Text(
                                        note.isNotEmpty ? note : 'N/A',
                                        style: const TextStyle(
                                            color: Colors.black87),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 14),

                              // More details button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ClinicDetails(
                                          clinicId: widget.clinicId,
                                        ),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: kPrimary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  icon: const Icon(Icons.info_outline),
                                  label: const Text(
                                    'More Details',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
            ),

            if (dentistId != null)
              DentistFooter(
                clinicId: widget.clinicId,
                dentistId: dentistId!,
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  const _SectionTitle({
    required this.icon,
    required this.title,
    this.color = const Color(0xFF103D7E),
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String message;
  const _EmptyCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.black54),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
