import 'package:dentease/clinic/dentease_moreDetails.dart';
import 'package:dentease/widgets/clinicWidgets/forDentStaff_clinicPage.dart';
import 'package:dentease/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:dentease/widgets/background_cont.dart';
import 'package:dentease/widgets/dentistWidgets/dentist_footer.dart';
import 'package:dentease/widgets/dentistWidgets/dentist_header.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// IMPORT NEW SEPARATED LOGIC FILES
import 'package:dentease/clinic/logic/note_update_listener.dart';
import 'package:dentease/clinic/logic/status_update_listener.dart';

class DentClinicPage extends StatefulWidget {
  final String clinicId;

  const DentClinicPage({super.key, required this.clinicId});

  @override
  State<DentClinicPage> createState() => _DentClinicPageState();
}

class _DentClinicPageState extends State<DentClinicPage> {
  // Use getter to avoid race condition with Supabase initialization
  SupabaseClient get supabase => Supabase.instance.client;

  Map<String, dynamic>? clinicDetails;
  String? dentistId;
  bool isLoading = true;

  /// Notification core
  static final FlutterLocalNotificationsPlugin _localNotifs =
      FlutterLocalNotificationsPlugin();

  /// Separated listeners
  late NoteUpdateListener noteListener;
  late StatusUpdateListener statusListener;

  /// ─────────────────────────────────────────────────────────────
  /// INIT
  /// ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _initNotifications();

    _fetchClinicDetails().then((_) async {
      /// Initialize listener handlers
      noteListener =
          NoteUpdateListener(clinicId: widget.clinicId, notifier: _localNotifs);
      statusListener = StatusUpdateListener(
          clinicId: widget.clinicId, notifier: _localNotifs);

      /// Load last saved notifications
      await noteListener.init();
      await statusListener.init();

      /// Subscribe NOTE + push to UI
      noteListener.subscribe((note) {
        if (mounted) setState(() => clinicDetails?['note'] = note);
      });

      /// Subscribe STATUS + push to UI
      statusListener.subscribe((status) {
        if (mounted) setState(() => clinicDetails?['status'] = status);
      });
    });
  }

  /// Clean realtime channels
  @override
  void dispose() {
    supabase.removeAllChannels(); // easy flush!
    super.dispose();
  }

  /// ─────────────────────────────────────────────────────────────
  ///  Notification Permission Init
  /// ─────────────────────────────────────────────────────────────
  Future<void> _initNotifications() async {
    const androidSetup = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _localNotifs
        .initialize(const InitializationSettings(android: androidSetup));
  }

  /// ─────────────────────────────────────────────────────────────
  ///  Fetch Data
  /// ─────────────────────────────────────────────────────────────
  Future<void> _fetchClinicDetails() async {
    try {
      final c = await supabase
          .from('clinics')
          .select()
          .eq('clinic_id', widget.clinicId)
          .maybeSingle();
      final d = await supabase
          .from('dentists')
          .select('dentist_id')
          .eq('clinic_id', widget.clinicId)
          .maybeSingle();

      setState(() {
        clinicDetails = c;
        dentistId = d?['dentist_id'];
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
      setState(() => isLoading = false);
    }
  }

  /// ─────────────────────────────────────────────────────────────
  /// UI BUILD STARTS HERE
  /// ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final name = clinicDetails?['clinic_name'] ?? 'N/A';
    final status = clinicDetails?['status'] ?? 'N/A';
    final note = clinicDetails?['note'] ?? 'N/A';

    return BackgroundCont(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            const DentistHeader(),
            Positioned.fill(
              top: 140,
              bottom: 100,
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : clinicDetails == null
                      ? const Center(
                          child:
                              _EmptyCard(message: 'No clinic details found.'))
                      : SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          physics: const BouncingScrollPhysics(),
                          child: Column(children: [
                            /// CLINIC IMAGES
                            _SectionCard(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _SectionTitle(
                                        icon: Icons.local_hospital_rounded,
                                        title: "Clinic Front"),
                                    const SizedBox(height: 10),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: ClinicFrontForDentStaff(
                                          clinicId: widget.clinicId),
                                    ),
                                  ]),
                            ),
                            const SizedBox(height: 12),

                            /// INFO BLOCK
                            _SectionCard(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _SectionTitle(
                                        icon: Icons.info,
                                        title: "Clinic Overview"),
                                    const SizedBox(height: 12),

                                    /// NAME
                                    _infoBox("Clinic Name:", name),

                                    const SizedBox(height: 8),

                                    /// STATUS
                                    Row(children: [
                                      const Icon(Icons.verified_user,
                                          color: AppTheme.primaryBlue),
                                      const SizedBox(width: 10),
                                      const Text("Status:",
                                          style: TextStyle(
                                              color: Colors.black54,
                                              fontWeight: FontWeight.bold)),
                                      const Spacer(),
                                      _statusChip(status),
                                    ]),

                                    const SizedBox(height: 14),

                                    /// NOTE
                                    Text("Note:",
                                        style: TextStyle(
                                            color: Colors.black54,
                                            fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 6),
                                    _noteBox(note),
                                    const SizedBox(height: 30),
                                  ]),
                            ),

                            const SizedBox(height: 14),

                            /// MORE DETAILS
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => ClinicDetails(
                                            clinicId: widget.clinicId))),
                                icon: const Icon(Icons.info_outline),
                                label: const Text("More Details",
                                    style:
                                        TextStyle(fontWeight: FontWeight.w700)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryBlue,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ]),
                        ),
            ),
            if (dentistId != null)
              DentistFooter(clinicId: widget.clinicId, dentistId: dentistId!),
          ],
        ),
      ),
    );
  }

  //──────────────────── UI Sub Widgets ────────────────────//

  Widget _infoBox(String label, String value) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.apartment, color: AppTheme.primaryBlue),
          const SizedBox(width: 10),
          Text(label,
              style: const TextStyle(
                  color: Colors.black54, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300)),
          child: Text(value,
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        ),
      ]);

  Widget _noteBox(String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300)),
        child: Text(text.isNotEmpty ? text : "N/A"),
      );

  Widget _statusChip(String status) {
    final s = status.toLowerCase();
    Color col = s == "approved"
        ? Colors.green
        : s == "pending"
            ? Colors.orange
            : s == "rejected"
                ? Colors.red
                : Colors.grey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: col.withValues(alpha: .15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: col)),
      child: Text(status,
          style: TextStyle(color: col, fontWeight: FontWeight.bold)),
    );
  }
}

//──────────────────── SMALL CARDS ────────────────────//

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.dividerColor),
          boxShadow: AppTheme.cardShadow,
        ),
        child: child,
      );
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, color: AppTheme.primaryBlue),
          const SizedBox(width: 8),
          Text(title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      );
}

class _EmptyCard extends StatelessWidget {
  final String message;
  const _EmptyCard({required this.message});

  @override
  Widget build(BuildContext context) => _SectionCard(
        child: Row(children: [
          const Icon(Icons.info_outline, color: Colors.black54),
          const SizedBox(width: 10),
          Expanded(
              child:
                  Text(message, style: const TextStyle(color: Colors.black87))),
        ]),
      );
}
