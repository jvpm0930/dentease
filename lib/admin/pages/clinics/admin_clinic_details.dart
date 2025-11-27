import 'package:dentease/widgets/background_cont.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdmClinicDetailsPage extends StatefulWidget {
  final String clinicId;

  const AdmClinicDetailsPage({super.key, required this.clinicId});

  @override
  State<AdmClinicDetailsPage> createState() => _AdmClinicDetailsPageState();
}

class _AdmClinicDetailsPageState extends State<AdmClinicDetailsPage> {
  final supabase = Supabase.instance.client;
  final TextEditingController _noteController = TextEditingController();

  Map<String, dynamic>? clinicDetails;
  bool isLoading = true;
  String selectedStatus = 'pending';

  static const kPrimary = Color(0xFF103D7E);

  @override
  void initState() {
    super.initState();
    _fetchClinicDetails();
  }

  Future<void> _fetchClinicDetails() async {
    try {
      final response = await supabase
          .from('clinics')
          .select(
            'clinic_name, email, info, license_url, office_url, permit_url, latitude, longitude, address, status, note',
          )
          .eq('clinic_id', widget.clinicId)
          .maybeSingle();

      if (response == null) {
        throw Exception('Clinic details not found');
      }

      setState(() {
        clinicDetails = response;
        selectedStatus = response['status'] ?? 'pending';
        _noteController.text = response['note'] ?? '';
        isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error fetching clinic details')),
        );
      }
      setState(() => isLoading = false);
    }
  }

  Future<void> _updateStatus() async {
    try {
      await supabase
          .from('clinics')
          .update({'status': selectedStatus}).eq('clinic_id', widget.clinicId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error updating status')),
        );
      }
    }
  }

  Future<void> _updateNote() async {
    final noteText = _noteController.text.trim();
    if (noteText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note cannot be empty')),
      );
      return;
    }

    try {
      await supabase
          .from('clinics')
          .update({'note': noteText}).eq('clinic_id', widget.clinicId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note sent successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error sending note')),
        );
      }
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green.shade600;
      case 'rejected':
        return Colors.red.shade600;
      default:
        return Colors.orange.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundCont(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          foregroundColor: Colors.white,
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            'Clinic Details',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : clinicDetails == null
                ? const Center(child: Text('No details found'))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header: Name + Status chip
                        _SectionCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                clinicDetails!['clinic_name'] ?? '',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Chip(
                                    label: Text(
                                      (clinicDetails!['status'] ?? 'pending')
                                          .toString()
                                          .toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    backgroundColor: _statusColor(
                                        clinicDetails!['status'] ?? 'pending'),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Current Status',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Status update area
                        _SectionCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _SectionTitle(
                                icon: Icons.approval,
                                title: 'Update Status',
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      value: selectedStatus,
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'pending',
                                          child: Text('Pending'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'rejected',
                                          child: Text('Rejected'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'approved',
                                          child: Text('Approved'),
                                        ),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() => selectedStatus = val);
                                        }
                                      },
                                      decoration: InputDecoration(
                                        labelText: 'Select new status',
                                        prefixIcon: const Icon(Icons.flag),
                                        filled: true,
                                        fillColor: Colors.white,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 12),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                            color: Colors.grey.shade300,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  ElevatedButton.icon(
                                    onPressed: _updateStatus,
                                    icon: const Icon(Icons.save),
                                    label: const Text('Update'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: kPrimary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14, horizontal: 18),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Notes
                        _SectionCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _SectionTitle(
                                icon: Icons.note_alt,
                                title: 'Admin Note to Clinic',
                              ),
                              const SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _noteController,
                                      minLines: 3,
                                      maxLines: 6,
                                      decoration: InputDecoration(
                                        hintText:
                                            'Write a note or reason for status changes...',
                                        filled: true,
                                        fillColor: Colors.white,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 12),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                              color: Colors.grey.shade300),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  ElevatedButton.icon(
                                    onPressed: _updateNote,
                                    icon: const Icon(Icons.send),
                                    label: const Text('Send'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: kPrimary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14, horizontal: 18),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Contact + Info
                        _SectionCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _SectionTitle(
                                icon: Icons.info_outline,
                                title: 'Clinic Information',
                              ),
                              const SizedBox(height: 12),
                              _InfoRow(
                                icon: Icons.email,
                                label: 'Email',
                                value: clinicDetails!['email'] ??
                                    'No email provided',
                              ),
                              const SizedBox(height: 10),
                              _InfoRow(
                                icon: Icons.location_on,
                                label: 'Address',
                                value: clinicDetails!['address'] ??
                                    'No address provided',
                                multiLine: true,
                              ),
                              const SizedBox(height: 10),
                              _InfoRow(
                                icon: Icons.description,
                                label: 'Info',
                                value: clinicDetails!['info'] ??
                                    'No info provided',
                                multiLine: true,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Map
                        if (clinicDetails!['latitude'] != null &&
                            clinicDetails!['longitude'] != null)
                          _SectionCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _SectionTitle(
                                  icon: Icons.map,
                                  title: 'Location',
                                ),
                                const SizedBox(height: 12),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: SizedBox(
                                    height: 200,
                                    child: GoogleMap(
                                      initialCameraPosition: CameraPosition(
                                        target: LatLng(
                                          (clinicDetails!['latitude'] as num)
                                              .toDouble(),
                                          (clinicDetails!['longitude'] as num)
                                              .toDouble(),
                                        ),
                                        zoom: 15,
                                      ),
                                      markers: {
                                        Marker(
                                          markerId:
                                              const MarkerId('clinicLocation'),
                                          position: LatLng(
                                            (clinicDetails!['latitude'] as num)
                                                .toDouble(),
                                            (clinicDetails!['longitude'] as num)
                                                .toDouble(),
                                          ),
                                        ),
                                      },
                                      myLocationButtonEnabled: false,
                                      zoomControlsEnabled: false,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 12),

                        // Credentials
                        _SectionCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _SectionTitle(
                                icon: Icons.verified_user,
                                title: 'Credentials',
                              ),
                              const SizedBox(height: 12),
                              _ImageTile(
                                title: 'PRC Credentials',
                                url: clinicDetails!['license_url'],
                              ),
                              const SizedBox(height: 12),
                              _ImageTile(
                                title: 'DTI Permit',
                                url: clinicDetails!['permit_url'],
                              ),
                              const SizedBox(height: 12),
                              _ImageTile(
                                title: 'Workplace',
                                url: clinicDetails!['office_url'],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 40),
                      ],
                    ),
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
  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF103D7E);
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool multiLine;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.multiLine = false,
  });

  @override
  Widget build(BuildContext context) {
    const kPrimary = Color(0xFF103D7E);
    return Row(
      crossAxisAlignment:
          multiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Icon(icon, color: kPrimary),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 15, color: Colors.black87),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ImageTile extends StatelessWidget {
  final String title;
  final String? url;

  const _ImageTile({required this.title, required this.url});

  @override
  Widget build(BuildContext context) {
    const placeholderStyle = TextStyle(
      fontSize: 14,
      fontStyle: FontStyle.italic,
      color: Colors.grey,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            )),
        const SizedBox(height: 8),
        if (url != null && (url as String).isNotEmpty)
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FullScreenImage(imageUrl: url!),
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  url!,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: const [
                Icon(Icons.image_not_supported, color: Colors.grey),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No image available.',
                    style: placeholderStyle,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class FullScreenImage extends StatelessWidget {
  final String imageUrl;
  const FullScreenImage({super.key, required this.imageUrl});

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
          child: Image.network(imageUrl, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
