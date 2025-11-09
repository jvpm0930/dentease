import 'dart:ui';
import 'package:dentease/widgets/background_cont.dart';
import 'package:flutter/material.dart';

class PatientBookingSuccess extends StatefulWidget {
  const PatientBookingSuccess({super.key});

  @override
  State<PatientBookingSuccess> createState() => _PatientBookingSuccessState();
}

class _PatientBookingSuccessState extends State<PatientBookingSuccess>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  static const Color kPrimary = Color(0xFF103D7E);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    )..forward();

    _scale = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _backToHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
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
                    ScaleTransition(
                      scale: _scale,
                      child: Container(
                        height: 96,
                        width: 96,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFF2ECC71), Color(0xFF27AE60)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x3327AE60),
                              blurRadius: 18,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.check_rounded,
                            color: Colors.white, size: 56),
                      ),
                    ),
                    const SizedBox(height: 18),
                    FadeTransition(
                      opacity: _fade,
                      child: const Text(
                        'Appointment Confirmed',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FadeTransition(
                      opacity: _fade,
                      child: const Text(
                        'Your appointment has been booked successfully.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14.5,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: _PillButton.filled(
                            label: 'Back to Home',
                            onTap: _backToHome,
                            background: kPrimary,
                            foreground: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _PillButton.ghost(
                            label: 'Done',
                            onTap: _backToHome,
                            borderColor: kPrimary.withOpacity(0.35),
                            textColor: kPrimary,
                          ),
                        ),
                      ],
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
            color: Colors.white.withOpacity(0.90),
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
            border: Border.all(color: Colors.white.withOpacity(0.6), width: 1),
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
  final Color? background;
  final Color? foreground;
  final Color? borderColor;
  final bool filled;

  const _PillButton._internal({
    required this.label,
    required this.onTap,
    this.background,
    this.foreground,
    this.borderColor,
    required this.filled,
  });

  factory _PillButton.filled({
    required String label,
    required VoidCallback onTap,
    required Color background,
    Color foreground = Colors.white,
  }) {
    return _PillButton._internal(
      label: label,
      onTap: onTap,
      background: background,
      foreground: foreground,
      filled: true,
    );
  }

  factory _PillButton.ghost({
    required String label,
    required VoidCallback onTap,
    Color? borderColor,
    Color? textColor,
  }) {
    return _PillButton._internal(
      label: label,
      onTap: onTap,
      borderColor: borderColor ?? Colors.black26,
      foreground: textColor ?? Colors.black87,
      filled: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(28);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Ink(
          decoration: BoxDecoration(
            color: filled ? background : Colors.white.withOpacity(0.85),
            borderRadius: radius,
            border: filled
                ? null
                : Border.all(
                    color: borderColor ?? Colors.black26,
                    width: 1.2,
                  ),
            boxShadow: filled
                ? const [
                    BoxShadow(
                      color: Color(0x26000000),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ]
                : const [],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: foreground ?? Colors.black87,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
