import 'dart:ui';
import 'package:dentease/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PatientFeedbackpage extends StatefulWidget {
  final String clinicId;

  const PatientFeedbackpage({super.key, required this.clinicId});

  @override
  State<PatientFeedbackpage> createState() => _PatientFeedbackpageState();
}

class _PatientFeedbackpageState extends State<PatientFeedbackpage> {
  // Use getter to avoid race condition with Supabase initialization
  SupabaseClient get supabase => Supabase.instance.client;

  int selectedRating = 0;
  final TextEditingController feedbackController = TextEditingController();
  bool isSubmitting = false;
  String? errorMessage;

  Future<void> submitFeedback() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      setState(
          () => errorMessage = "You must be logged in to submit feedback.");
      return;
    }

    if (selectedRating == 0 || feedbackController.text.trim().isEmpty) {
      setState(
          () => errorMessage = "Please select a rating and enter feedback.");
      return;
    }

    setState(() {
      isSubmitting = true;
      errorMessage = null;
    });

    try {
      final existing = await supabase
          .from('feedbacks')
          .select()
          .eq('patient_id', user.id)
          .eq('clinic_id', widget.clinicId)
          .maybeSingle();

      if (existing != null) {
        setState(() {
          errorMessage = "You have already submitted feedback for this clinic.";
        });
        return;
      }

      await supabase.from('feedbacks').insert({
        'rating': selectedRating,
        'feedback': feedbackController.text.trim(),
        'patient_id': user.id,
        'clinic_id': widget.clinicId,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Feedback submitted successfully!")),
      );

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      setState(() => errorMessage = "Error submitting feedback: $e");
    } finally {
      setState(() => isSubmitting = false);
    }
  }

  Widget buildStar(int index) {
    final isFilled = index <= selectedRating;
    return IconButton(
      icon: Icon(isFilled ? Icons.star : Icons.star_border,
          color: Colors.amber, size: 34),
      onPressed: () => setState(() => selectedRating = index),
      splashRadius: 22,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          "Rate Clinic",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
      ),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: _GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "How was your experience?",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 2,
                      children: List.generate(5, (i) => buildStar(i + 1)),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Leave a feedback:",
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    _InputCard(
                      child: TextField(
                        controller: feedbackController,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          hintText: "Write your feedback here...",
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (errorMessage != null)
                      Text(
                        errorMessage!,
                        style: const TextStyle(
                            color: AppTheme.errorColor, fontSize: 14),
                      ),
                    const SizedBox(height: 12),

                    // Submit (filled capsule)
                    isSubmitting
                        ? const Center(
                            child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: CircularProgressIndicator(),
                          ))
                        : _CapsuleButton.filled(
                            label: 'Submit Feedback',
                            onTap: submitFeedback,
                            background: AppTheme.primaryBlue,
                            foreground: Colors.white,
                            minWidth: double.infinity,
                          ),

                    const SizedBox(height: 10),

                    // Not Now (translucent capsule)
                    _CapsuleButton.translucent(
                      label: 'Not now',
                      onTap: () {
                        Navigator.pop(context);
                      },
                      background: AppTheme.primaryBlue.withValues(alpha: 0.18),
                      textColor: AppTheme.textDark.withValues(alpha: 0.75),
                      borderColor:
                          AppTheme.cardBackground.withValues(alpha: 0.15),
                      minWidth: double.infinity,
                    ),
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

// Frosted/white panel
class _GlassPanel extends StatelessWidget {
  final Widget child;
  const _GlassPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          decoration: BoxDecoration(
            color: AppTheme.cardBackground.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
            border: Border.all(
                color: AppTheme.cardBackground.withValues(alpha: 0.60)),
          ),
          child: child,
        ),
      ),
    );
  }
}

// Inner input card for the TextField
class _InputCard extends StatelessWidget {
  final Widget child;
  const _InputCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground.withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.black12.withValues(alpha: 0.08)),
      ),
      child: child,
    );
  }
}

// Capsule button variants
class _CapsuleButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color background;
  final Color? foreground;
  final Color? borderColor;
  final double minWidth;
  final bool translucent;

  const _CapsuleButton._({
    required this.label,
    required this.onTap,
    required this.background,
    this.foreground,
    this.borderColor,
    required this.minWidth,
    required this.translucent,
  });

  factory _CapsuleButton.filled({
    required String label,
    required VoidCallback onTap,
    required Color background,
    Color foreground = Colors.white,
    double minWidth = double.infinity,
  }) {
    return _CapsuleButton._(
      label: label,
      onTap: onTap,
      background: background,
      foreground: foreground,
      minWidth: minWidth,
      translucent: false,
    );
  }

  factory _CapsuleButton.translucent({
    required String label,
    required VoidCallback onTap,
    required Color background, // e.g., kPrimary.withValues(alpha: 0.18)
    Color? textColor,
    Color? borderColor,
    double minWidth = double.infinity,
  }) {
    return _CapsuleButton._(
      label: label,
      onTap: onTap,
      background: background,
      foreground: textColor,
      borderColor: borderColor,
      minWidth: minWidth,
      translucent: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(28);
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: minWidth),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Ink(
            decoration: BoxDecoration(
              color: background,
              borderRadius: radius,
              border: translucent
                  ? Border.all(
                      color:
                          borderColor ?? Colors.white.withValues(alpha: 0.15),
                      width: 1,
                    )
                  : null,
              boxShadow: translucent
                  ? const []
                  : const [
                      BoxShadow(
                        color: Color(0x26000000),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: foreground ?? Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
