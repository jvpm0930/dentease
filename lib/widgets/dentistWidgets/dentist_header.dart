import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DentistHeader extends StatefulWidget {
  const DentistHeader({super.key});

  @override
  _DentistHeaderState createState() => _DentistHeaderState();
}

class _DentistHeaderState extends State<DentistHeader> {
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
          .from('dentists')
          .select('profile_url, firstname, lastname, fcm_token')
          .eq('dentist_id', user.id)
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
      debugPrint('Error fetching dentist profile data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName =
        ((firstname ?? '').isNotEmpty || (lastname ?? '').isNotEmpty)
            ? '${firstname ?? ''} ${lastname ?? ''}'.trim()
            : (userEmail ?? 'Loading...');

    return Padding(
      padding: const EdgeInsets.only(top: 50, left: 20, right: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.grey[300],
                backgroundImage: profileUrl != null
                    ? NetworkImage(profileUrl!)
                    : const AssetImage('assets/profile.png') as ImageProvider,
                child: (profileUrl == null)
                    ? const Icon(Icons.person, size: 30, color: Colors.grey)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Hello dentist,',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70,
                      ),
                    ),
                    Text(
                      displayName,
                      style: const TextStyle(
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
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
