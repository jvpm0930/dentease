import 'package:dentease/admin/pages/clinics/admin_dentease_first.dart';
import 'package:dentease/clinic/models/adminChat_supportList.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminFooter extends StatefulWidget {
  const AdminFooter({super.key});

  @override
  _AdminFooterState createState() => _AdminFooterState();
}

class _AdminFooterState extends State<AdminFooter> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> clinics = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchClinics();
  }

  Future<void> _fetchClinics() async {
    try {
      final response =
          await supabase.from('clinics').select('clinic_id, clinic_name');

      setState(() {
        clinics = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      _showSnackbar('Error fetching clinics: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final hasClinics = clinics.isNotEmpty;
    final clinicId = hasClinics ? clinics.first['clinic_id'] : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFF103D7E),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavImage('assets/icons/home.png', context, const AdminPage()),
          _buildNavImage(
            'assets/icons/customer-service.png',
            context,
            clinicId != null
                ? AdminSupportChatforClinic(
                    adminId: 'eee5f574-903b-4575-a9d9-2f69e58f1801',
                  )
                : null, // disable if no approved clinic found
          ),
        ],
      ),
    );
  }

  /// Builds a navigation button with an image
  Widget _buildNavImage(String imagePath, BuildContext context, Widget? page) {
    return IconButton(
      icon: Image.asset(
        imagePath,
        width: 30,
        height: 30,
        color: Colors.white,
      ),
      onPressed: page != null
          ? () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => page),
              );
            }
          : null,
    );
  }
}
