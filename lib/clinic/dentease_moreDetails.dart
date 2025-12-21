import 'dart:async';
import 'package:dentease/clinic/dentease_EditmoreDetails.dart';
import 'package:dentease/clinic/dentease_EditmoreDetailsSuccess.dart';
import 'package:flutter/material.dart';
import 'package:dentease/widgets/background_cont.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; 
import 'package:dentease/clinic/logic/resubmit_notify_listener.dart'; 

class ClinicDetails extends StatefulWidget {
  final String clinicId;

  const ClinicDetails({
    super.key,
    required this.clinicId,
  });

  @override
  State<ClinicDetails> createState() => _ClinicDetailsState();
}
ResubmitNotifyListener? _notifyListener;

class FullScreenImage extends StatelessWidget {
  final String imageUrl;

  const FullScreenImage({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          boundaryMargin: const EdgeInsets.all(20),
          minScale: 0.5,
          maxScale: 3.0,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

class _ClinicDetailsState extends State<ClinicDetails> {
  final supabase = Supabase.instance.client;
  final Color kPrimary = const Color(0xFF103D7E);

  Map<String, dynamic>? clinicDetails;
  bool isLoading = true;
  String? profileUrl;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchClinicDetails();
    _startAutoRefresh();

    // NEW — Start listener
    _notifyListener = ResubmitNotifyListener(
      clinicId: widget.clinicId,
      notifier: FlutterLocalNotificationsPlugin(), // uses same channel
    );

    _notifyListener!.subscribe(); // start listening to notify column
  }


  void _startAutoRefresh() {
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _fetchClinicDetails();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }


  Future<void> _fetchClinicDetails() async {
    try {
      final response = await supabase
          .from('clinics')
          .select()
          .eq('clinic_id', widget.clinicId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          clinicDetails = response;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching clinic details: $e')),
        );
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // Old row kept for compatibility (unused in new layout)
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white,
              )),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    final s = status.toString().toLowerCase();
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
          Text(
            status,
            style: TextStyle(color: fg, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = clinicDetails?['clinic_name']?.toString() ?? 'N/A';
    final status = clinicDetails?['status']?.toString() ?? 'N/A';
    final phone = clinicDetails?['phone']?.toString() ?? 'N/A';
    final email = clinicDetails?['email']?.toString() ?? 'N/A';
    final address = clinicDetails?['address']?.toString() ?? 'N/A';
    final info = clinicDetails?['info']?.toString() ?? 'N/A';

    final lat = (clinicDetails?['latitude'] as num?)?.toDouble();
    final lng = (clinicDetails?['longitude'] as num?)?.toDouble();

    final licenseUrl = clinicDetails?['license_url']?.toString();
    final permitUrl = clinicDetails?['permit_url']?.toString();
    final officeUrl = clinicDetails?['office_url']?.toString();

    return BackgroundCont(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent, // <-- VISIBLE
          elevation: 0,
          centerTitle: true,
          title: const Text(
            "Clinic Details",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),

        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : clinicDetails == null
                ? const Center(
                    child: Text(
                      'No clinic details found.',
                      style: TextStyle(fontSize: 14, color: Colors.white),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _fetchClinicDetails,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Column(
                        children: [
                          // Basic Info
                          _SectionCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _SectionTitle(
                                    icon: Icons.info_rounded,
                                    title: 'Basic Info',
                                    color: kPrimary),
                                const SizedBox(height: 10),
                                _InfoRow(
                                  label: 'Status',
                                  trailing: _statusChip(status),
                                ),
                                const SizedBox(height: 8),
                                _InfoRow(
                                  label: 'Clinic Name',
                                  value: name,
                                ),
                                const SizedBox(height: 8),
                                _InfoRow(
                                  label: 'Clinic Contact #',
                                  value: phone,
                                ),
                                const SizedBox(height: 8),
                                _InfoRow(
                                  label: 'Email',
                                  value: email,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Address + Map
                          _SectionCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _SectionTitle(
                                    icon: Icons.location_on_rounded,
                                    title: 'Address',
                                    color: kPrimary),
                                const SizedBox(height: 10),
                                Text(
                                  address,
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                if (lat != null && lng != null)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: SizedBox(
                                      height: 180,
                                      child: GoogleMap(
                                        initialCameraPosition: CameraPosition(
                                          target: LatLng(lat, lng),
                                          zoom: 15,
                                        ),
                                        markers: {
                                          Marker(
                                            markerId:
                                                const MarkerId('clinicLocation'),
                                            position: LatLng(lat, lng),
                                          ),
                                        },
                                        myLocationButtonEnabled: false,
                                        zoomControlsEnabled: false,
                                        liteModeEnabled: true,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Documents
                          _SectionCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _SectionTitle(
                                    icon: Icons.assignment_turned_in_rounded,
                                    title: 'Credentials & Permits',
                                    color: kPrimary),
                                const SizedBox(height: 12),

                                // PRC
                                const Text(
                                  'PRC Credentials:',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black87),
                                ),
                                const SizedBox(height: 8),
                                if (licenseUrl != null && licenseUrl.isNotEmpty)
                                  _DocImageTile(
                                    url: licenseUrl,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              FullScreenImage(imageUrl: licenseUrl),
                                        ),
                                      );
                                    },
                                  )
                                else
                                  const _DocEmpty(text: "No PRC license image available."),
                                const SizedBox(height: 16),

                                // DTI
                                const Text(
                                  'DTI Permit:',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black87),
                                ),
                                const SizedBox(height: 8),
                                if (permitUrl != null && permitUrl.isNotEmpty)
                                  _DocImageTile(
                                    url: permitUrl,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              FullScreenImage(imageUrl: permitUrl),
                                        ),
                                      );
                                    },
                                  )
                                else
                                  const _DocEmpty(text: "No DTI Permit image available."),
                                const SizedBox(height: 16),

                                // Workplace
                                const Text(
                                  'Workplace:',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black87),
                                ),
                                const SizedBox(height: 8),
                                if (officeUrl != null && officeUrl.isNotEmpty)
                                  _DocImageTile(
                                    url: officeUrl,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              FullScreenImage(imageUrl: officeUrl),
                                        ),
                                      );
                                    },
                                  )
                                else
                                  const _DocEmpty(text: "No Workplace image available."),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Clinic Info
                          _SectionCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _SectionTitle(
                                  icon: Icons.notes_rounded,
                                  title: 'Clinic Info',
                                  color: kPrimary,
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(10),
                                    border:
                                        Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Text(
                                    (info.isNotEmpty) ? info : 'N/A',
                                    style: const TextStyle(color: Colors.black87),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EditDetailsSuccess(
                                      clinicId: widget.clinicId,
                                    ),
                                  ),
                                );
                                if (result == true) {
                                  _fetchClinicDetails();
                                }
                              }, 
                              icon: const Icon(Icons.loop, color: Colors.white),
                              label: const Text(
                                "Resubmit Application",
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Edit button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EditClinicDetails(
                                      clinicDetails: clinicDetails!,
                                      clinicId: widget.clinicId,
                                    ),
                                  ),
                                );
                                if (result == true) {
                                  _fetchClinicDetails();
                                }
                              },
                              icon: const Icon(Icons.edit),
                              label: const Text(
                                'Edit Clinic Details',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kPrimary,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 54),
                        ],
                      ),
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
        color: Colors.white.withOpacity(0.98),
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

class _InfoRow extends StatelessWidget {
  final String label;
  final String? value;
  final Widget? trailing;

  const _InfoRow({
    required this.label,
    this.value,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final right = trailing ??
        Text(
          value ?? 'N/A',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
          textAlign: TextAlign.right,
        );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 12),
        right,
      ],
    );
  }
}

class _DocImageTile extends StatelessWidget {
  final String url;
  final VoidCallback onTap;

  const _DocImageTile({
    required this.url,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 150,
          width: double.infinity,
          color: Colors.grey.shade200,
          child: Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return const Center(
                child: Icon(Icons.broken_image, color: Colors.black45, size: 32),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DocEmpty extends StatelessWidget {
  final String text;
  const _DocEmpty({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontStyle: FontStyle.italic,
          color: Colors.black54,
        ),
      ),
    );
  }
}