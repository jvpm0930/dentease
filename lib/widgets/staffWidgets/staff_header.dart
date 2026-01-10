import 'package:dentease/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StaffHeader extends StatefulWidget {
  const StaffHeader({super.key});

  @override
  State<StaffHeader> createState() => _StaffHeaderState();
}

class _StaffHeaderState extends State<StaffHeader> {
  String? userEmail;
  String? profileUrl;
  String? firstname;
  String? lastname;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    setState(() => userEmail = user.email);

    try {
      final data = await Supabase.instance.client
          .from('staffs')
          .select('profile_url, firstname, lastname, fcm_token')
          .eq('staff_id', user.id)
          .maybeSingle();

      if (data != null) {
        final url = data['profile_url'];
        setState(() {
          firstname = data['firstname'];
          lastname = data['lastname'];
          profileUrl = (url != null && url.toString().isNotEmpty)
              ? '$url?timestamp=${DateTime.now().millisecondsSinceEpoch}'
              : null;
        });
      }
    } catch (e) {
      debugPrint('Error fetching staff profile data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName =
        ((firstname ?? '').isNotEmpty || (lastname ?? '').isNotEmpty)
            ? '${firstname ?? ''} ${lastname ?? ''}'.trim()
            : (userEmail ?? 'Loading...');

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryBlue,
            AppTheme.primaryBlue.withValues(alpha: 0.8),
          ],
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            backgroundImage: profileUrl != null
                ? NetworkImage(profileUrl!)
                : const AssetImage('assets/profile.png') as ImageProvider,
            child: (profileUrl == null)
                ? const Icon(Icons.person_rounded,
                    size: 30, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Hello staff,',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                Text(
                  displayName,
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
