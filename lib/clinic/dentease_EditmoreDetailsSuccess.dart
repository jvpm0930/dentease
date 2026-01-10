import 'dart:ui';
import 'package:dentease/clinic/dentease_moreDetails.dart';
import 'package:dentease/widgets/background_cont.dart';
import 'package:dentease/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ------------------------------------------
//  SUCCESS PAGE WITH NOTIFY TRIGGER INCLUDED
// ------------------------------------------
class EditDetailsSuccess extends StatefulWidget {
  final String clinicId; // Required so notify targets correct clinic

  const EditDetailsSuccess({
    super.key,
    required this.clinicId,
  });

  @override
  State<EditDetailsSuccess> createState() => _EditDetailsSuccessState();
}

class _EditDetailsSuccessState extends State<EditDetailsSuccess>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  final supabase = Supabase.instance.client; // <<< FIXED

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // -----------------------------------------------------------
  //  Sends a notify signal to Admin (Resubmit event trigger)
  // -----------------------------------------------------------
  Future<void> _sendNotifySignal() async {
    try {
      await supabase.from('clinics').update({
        'notify':
            DateTime.now().millisecondsSinceEpoch.toString(), // unique ping
      }).eq('clinic_id', widget.clinicId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Request Sent for Review")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Notify failed → $e")),
      );
    }
  }

  // -----------------------------------------------------------
  //  BACK NAVIGATION (Redirect Anywhere You Want)
  // -----------------------------------------------------------
  void _backToHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
          builder: (_) => ClinicDetails(clinicId: widget.clinicId)),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundCont(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: _GlassCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 22),
                    _PillButton(
                      label: "Notify Admin (Resubmit)",
                      onTap: _sendNotifySignal,
                      color: Colors.red.shade600,
                    ),
                    const SizedBox(height: 16),
                    _PillButton(
                      label: "Done",
                      onTap: _backToHome,
                      color: AppTheme.primaryBlue,
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

//// Glass card + Buttons remain unchanged ↓ -------------------------
class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.90),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.6), width: 1),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 16,
                offset: Offset(0, 8),
              )
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _PillButton({
    required this.label,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity, // full stretch
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}
