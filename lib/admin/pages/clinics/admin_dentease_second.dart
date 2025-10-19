import 'package:dentease/admin/pages/clinics/admin_clinic_reviews.dart';
import 'package:dentease/clinic/models/adminChat_supportList.dart';
import 'package:dentease/widgets/background_cont.dart';
import 'package:flutter/material.dart';
import '../dentists/admin_clinic_dentist.dart';
import 'admin_clinic_details.dart';
import '../patients/admin_clinic_patient.dart';
import '../staffs/admin_clinic_staff.dart';

class AdmClinicDashboardPage extends StatelessWidget {
  final String clinicId;
  final String clinicName;

  const AdmClinicDashboardPage({
    super.key,
    required this.clinicId,
    required this.clinicName,
  });

  Widget _buildCardButton({
    required String title,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundCont(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text(clinicName),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildCardButton(
                title: 'Dentists',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          AdmClinicDentistsPage(clinicId: clinicId),
                    ),
                  );
                },
              ),
              _buildCardButton(
                title: 'Staff',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AdmClinicStaffsPage(clinicId: clinicId),
                    ),
                  );
                },
              ),
              _buildCardButton(
                title: 'Patients',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          AdmClinicPatientsPage(clinicId: clinicId),
                    ),
                  );
                },
              ),
              _buildCardButton(
                title: 'Details',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AdmClinicDetailsPage(clinicId: clinicId),
                    ),
                  );
                },
              ),
              _buildCardButton(
                title: 'Reviews',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          AdmClinicReviews(clinicId: clinicId),
                    ),
                  );
                },
              ),
              _buildCardButton(
                title: 'Chat Support',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          AdminSupportChatforClinic(clinicId: clinicId, adminId: '',
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
