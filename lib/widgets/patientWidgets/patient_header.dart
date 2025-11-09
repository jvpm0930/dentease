import 'package:dentease/widgets/clinicWidgets/nearbyClinic.dart';
import 'package:dentease/widgets/clinicWidgets/nearbyClinicButton.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PatientHeader extends StatefulWidget {
  const PatientHeader({super.key});

  @override
  _PatientHeaderState createState() => _PatientHeaderState();
}

class _PatientHeaderState extends State<PatientHeader> {
  String? userEmail;
  String? profileUrl;
  String? firstname; 
  String? lastname;

  @override
  void initState() {
    super.initState();
    _fetchUserEmail();
  }

  Future<void> _fetchUserEmail() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      setState(() {
        userEmail = user.email;
      });

      await _fetchProfileData(user.id); // 👈 renamed for clarity
    }
  }

  /// Fetch patient's profile (first name, last name, profile URL)
  Future<void> _fetchProfileData(String userId) async {
    try {
      final response = await Supabase.instance.client
          .from('patients')
          .select('profile_url, firstname, lastname')
          .eq('patient_id', userId)
          .maybeSingle();

      if (response != null) {
        setState(() {
          firstname = response['firstname'];
          lastname = response['lastname'];
          final url = response['profile_url'];
          profileUrl = url != null && url.isNotEmpty
              ? '$url?timestamp=${DateTime.now().millisecondsSinceEpoch}'
              : null;
        });
      }
    } catch (e) {
      debugPrint('Error fetching profile data');
    }
  }

  @override
  Widget build(BuildContext context) {
    final fullName = (firstname != null && firstname!.isNotEmpty) ||
            (lastname != null && lastname!.isNotEmpty)
        ? '${firstname ?? ''} ${lastname ?? ''}'.trim()
        : "Loading...";

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
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize
                      .min, // Prevents unnecessary vertical expansion
                  children: [
                    const Text(
                      'Hello patient,',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70,
                      ),
                    ),
                    Text(
                      fullName,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow:
                          TextOverflow.ellipsis, // Ellipsis only for the name
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 30),
          const Text(
            "Explore Services Today",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          NearbyClinicsButton(
            imagePath: 'assets/nearby.png',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ClinicMapPage(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
