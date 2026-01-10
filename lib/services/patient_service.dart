import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Enhanced Patient Service for managing patient records and appointment relationships
/// Provides pending/completed patient tracking, history retrieval, and real-time updates
class PatientService {
  static final PatientService _instance = PatientService._internal();
  factory PatientService() => _instance;
  PatientService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  // Stream controllers for real-time updates
  final Map<String, StreamController<List<PatientRecord>>> _pendingStreams = {};
  final Map<String, StreamController<List<PatientRecord>>> _completedStreams =
      {};

  // Real-time subscriptions
  RealtimeChannel? _patientChannel;

  /// Initialize real-time subscriptions for patient changes
  void initializeRealTimeSubscriptions() {
    _patientChannel = _supabase
        .channel('patient_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'bookings',
          callback: (payload) {
            _handlePatientChange(payload);
          },
        )
        .subscribe();
  }

  /// Handle real-time patient changes
  void _handlePatientChange(PostgresChangePayload payload) {
    try {
      final data = payload.newRecord;
      final clinicId = data['clinic_id'] as String?;

      if (clinicId != null) {
        // Refresh streams for the affected clinic
        _refreshStreamsForClinic(clinicId);
      }
    } catch (e) {
      debugPrint('Error handling patient change: $e');
    }
  }

  /// Refresh all streams for a specific clinic
  void _refreshStreamsForClinic(String clinicId) {
    // Refresh pending patients
    if (_pendingStreams.containsKey(clinicId)) {
      _fetchPendingPatients(clinicId).then((patients) {
        if (!_pendingStreams[clinicId]!.isClosed) {
          _pendingStreams[clinicId]!.add(patients);
        }
      });
    }

    // Refresh completed patients
    if (_completedStreams.containsKey(clinicId)) {
      _fetchCompletedPatients(clinicId).then((patients) {
        if (!_completedStreams[clinicId]!.isClosed) {
          _completedStreams[clinicId]!.add(patients);
        }
      });
    }
  }

  /// Get stream of pending patients (patients with approved appointments)
  Stream<List<PatientRecord>> getPendingPatients(String clinicId) {
    if (!_pendingStreams.containsKey(clinicId)) {
      _pendingStreams[clinicId] =
          StreamController<List<PatientRecord>>.broadcast();

      // Initial fetch
      _fetchPendingPatients(clinicId).then((patients) {
        if (!_pendingStreams[clinicId]!.isClosed) {
          _pendingStreams[clinicId]!.add(patients);
        }
      });
    }

    return _pendingStreams[clinicId]!.stream;
  }

  /// Get stream of completed patients (patients with completed appointment history)
  Stream<List<PatientRecord>> getCompletedPatients(String clinicId) {
    if (!_completedStreams.containsKey(clinicId)) {
      _completedStreams[clinicId] =
          StreamController<List<PatientRecord>>.broadcast();

      // Initial fetch
      _fetchCompletedPatients(clinicId).then((patients) {
        if (!_completedStreams[clinicId]!.isClosed) {
          _completedStreams[clinicId]!.add(patients);
        }
      });
    }

    return _completedStreams[clinicId]!.stream;
  }

  /// Get detailed patient information including appointment history
  Future<PatientDetails?> getPatientDetails(String patientId) async {
    try {
      // Fetch patient basic information
      final patientResponse = await _supabase
          .from('patients')
          .select('*')
          .eq('patient_id', patientId)
          .maybeSingle();

      if (patientResponse == null) {
        return null;
      }

      // Fetch patient's appointment history
      final appointmentsResponse = await _supabase.from('bookings').select('''
            booking_id, service_id, clinic_id, date, status,
            completed_at, completion_notes, rejection_reason,
            services(service_name, service_detail),
            clinics(clinic_name)
          ''').eq('patient_id', patientId).order('date', ascending: false);

      final appointments = appointmentsResponse
          .map((data) => PatientAppointment.fromJson(data))
          .toList();

      return PatientDetails(
        patientId: patientResponse['patient_id'] as String,
        firstName: patientResponse['firstname'] as String? ?? 'Unknown',
        lastName: patientResponse['lastname'] as String? ?? '',
        email: patientResponse['email'] as String?,
        phone: patientResponse['phone'] as String?,
        profileUrl: patientResponse['profile_url'] as String?,
        dateOfBirth: patientResponse['date_of_birth'] != null
            ? DateTime.parse(patientResponse['date_of_birth'] as String)
            : null,
        address: patientResponse['address'] as String?,
        medicalHistory: patientResponse['medical_history'] as String?,
        appointments: appointments,
      );
    } catch (e) {
      debugPrint('Error fetching patient details: $e');
      return null;
    }
  }

  /// Get patient appointment history for a specific clinic
  Future<List<PatientAppointment>> getPatientHistory(
      String patientId, String clinicId) async {
    try {
      final response = await _supabase
          .from('bookings')
          .select('''
            booking_id, service_id, clinic_id, date, status,
            completed_at, completion_notes, rejection_reason,
            services(service_name, service_detail),
            clinics(clinic_name)
          ''')
          .eq('patient_id', patientId)
          .eq('clinic_id', clinicId)
          .order('date', ascending: false);

      return response.map((data) => PatientAppointment.fromJson(data)).toList();
    } catch (e) {
      debugPrint('Error fetching patient history: $e');
      return [];
    }
  }

  /// Fetch pending patients from database
  Future<List<PatientRecord>> _fetchPendingPatients(String clinicId) async {
    try {
      // Get patients with approved appointments (pending treatment)
      final response = await _supabase
          .from('bookings')
          .select('''
            patient_id, date, status,
            patients(firstname, lastname, profile_url, phone, email),
            services(service_name)
          ''')
          .eq('clinic_id', clinicId)
          .eq('status', 'approved')
          .gte('date', DateTime.now().toIso8601String())
          .order('date', ascending: true);

      // Group by patient and get the latest appointment for each
      final Map<String, Map<String, dynamic>> patientMap = {};

      for (final booking in response) {
        final patientId = booking['patient_id'] as String;
        final appointmentDate = DateTime.parse(booking['date'] as String);

        if (!patientMap.containsKey(patientId) ||
            appointmentDate.isAfter(
                DateTime.parse(patientMap[patientId]!['date'] as String))) {
          patientMap[patientId] = booking;
        }
      }

      // Convert to PatientRecord objects
      final List<PatientRecord> patients = [];
      for (final booking in patientMap.values) {
        final patientData = booking['patients'] as Map<String, dynamic>? ?? {};
        final serviceData = booking['services'] as Map<String, dynamic>? ?? {};

        // Get total appointments count for this patient at this clinic
        final totalAppointments = await _getPatientAppointmentCount(
            booking['patient_id'] as String, clinicId);
        final completedAppointments = await _getPatientCompletedCount(
            booking['patient_id'] as String, clinicId);

        patients.add(PatientRecord(
          patientId: booking['patient_id'] as String,
          firstName: patientData['firstname'] as String? ?? 'Unknown',
          lastName: patientData['lastname'] as String? ?? '',
          profileUrl: patientData['profile_url'] as String?,
          phone: patientData['phone'] as String?,
          email: patientData['email'] as String?,
          latestAppointment: PatientAppointment(
            bookingId: '', // Not needed for this context
            serviceId: '',
            clinicId: clinicId,
            appointmentDate: DateTime.parse(booking['date'] as String),
            status: PatientAppointmentStatus.approved,
            serviceName: serviceData['service_name'] as String? ?? 'Service',
            clinicName: '', // Not needed for this context
          ),
          totalAppointments: totalAppointments,
          completedAppointments: completedAppointments,
        ));
      }

      return patients;
    } catch (e) {
      debugPrint('Error fetching pending patients: $e');
      return [];
    }
  }

  /// Fetch completed patients from database
  Future<List<PatientRecord>> _fetchCompletedPatients(String clinicId) async {
    try {
      // Get patients with completed appointments
      final response = await _supabase
          .from('bookings')
          .select('''
            patient_id, date, status, completed_at,
            patients(firstname, lastname, profile_url, phone, email),
            services(service_name)
          ''')
          .eq('clinic_id', clinicId)
          .eq('status', 'completed')
          .order('completed_at', ascending: false);

      // Group by patient and get the latest completed appointment for each
      final Map<String, Map<String, dynamic>> patientMap = {};

      for (final booking in response) {
        final patientId = booking['patient_id'] as String;
        final completedAt = booking['completed_at'] != null
            ? DateTime.parse(booking['completed_at'] as String)
            : DateTime.parse(booking['date'] as String);

        if (!patientMap.containsKey(patientId) ||
            completedAt.isAfter(DateTime.parse(
                patientMap[patientId]!['completed_at'] as String? ??
                    patientMap[patientId]!['date'] as String))) {
          patientMap[patientId] = booking;
        }
      }

      // Convert to PatientRecord objects
      final List<PatientRecord> patients = [];
      for (final booking in patientMap.values) {
        final patientData = booking['patients'] as Map<String, dynamic>? ?? {};
        final serviceData = booking['services'] as Map<String, dynamic>? ?? {};

        // Get total appointments count for this patient at this clinic
        final totalAppointments = await _getPatientAppointmentCount(
            booking['patient_id'] as String, clinicId);
        final completedAppointments = await _getPatientCompletedCount(
            booking['patient_id'] as String, clinicId);

        patients.add(PatientRecord(
          patientId: booking['patient_id'] as String,
          firstName: patientData['firstname'] as String? ?? 'Unknown',
          lastName: patientData['lastname'] as String? ?? '',
          profileUrl: patientData['profile_url'] as String?,
          phone: patientData['phone'] as String?,
          email: patientData['email'] as String?,
          latestAppointment: PatientAppointment(
            bookingId: '', // Not needed for this context
            serviceId: '',
            clinicId: clinicId,
            appointmentDate: DateTime.parse(booking['date'] as String),
            status: PatientAppointmentStatus.completed,
            serviceName: serviceData['service_name'] as String? ?? 'Service',
            clinicName: '', // Not needed for this context
            completedAt: booking['completed_at'] != null
                ? DateTime.parse(booking['completed_at'] as String)
                : null,
          ),
          totalAppointments: totalAppointments,
          completedAppointments: completedAppointments,
        ));
      }

      return patients;
    } catch (e) {
      debugPrint('Error fetching completed patients: $e');
      return [];
    }
  }

  /// Get total appointment count for a patient at a specific clinic
  Future<int> _getPatientAppointmentCount(
      String patientId, String clinicId) async {
    try {
      final response = await _supabase
          .from('bookings')
          .select('booking_id')
          .eq('patient_id', patientId)
          .eq('clinic_id', clinicId);

      return response.length;
    } catch (e) {
      debugPrint('Error getting patient appointment count: $e');
      return 0;
    }
  }

  /// Get completed appointment count for a patient at a specific clinic
  Future<int> _getPatientCompletedCount(
      String patientId, String clinicId) async {
    try {
      final response = await _supabase
          .from('bookings')
          .select('booking_id')
          .eq('patient_id', patientId)
          .eq('clinic_id', clinicId)
          .eq('status', 'completed');

      return response.length;
    } catch (e) {
      debugPrint('Error getting patient completed count: $e');
      return 0;
    }
  }

  /// Dispose of resources
  void dispose() {
    _patientChannel?.unsubscribe();

    for (final controller in _pendingStreams.values) {
      controller.close();
    }
    for (final controller in _completedStreams.values) {
      controller.close();
    }

    _pendingStreams.clear();
    _completedStreams.clear();
  }
}

/// Patient record model for list views
class PatientRecord {
  final String patientId;
  final String firstName;
  final String lastName;
  final String? profileUrl;
  final String? phone;
  final String? email;
  final PatientAppointment latestAppointment;
  final int totalAppointments;
  final int completedAppointments;

  PatientRecord({
    required this.patientId,
    required this.firstName,
    required this.lastName,
    this.profileUrl,
    this.phone,
    this.email,
    required this.latestAppointment,
    required this.totalAppointments,
    required this.completedAppointments,
  });

  String get fullName => '$firstName $lastName'.trim();
}

/// Detailed patient information model
class PatientDetails {
  final String patientId;
  final String firstName;
  final String lastName;
  final String? email;
  final String? phone;
  final String? profileUrl;
  final DateTime? dateOfBirth;
  final String? address;
  final String? medicalHistory;
  final List<PatientAppointment> appointments;

  PatientDetails({
    required this.patientId,
    required this.firstName,
    required this.lastName,
    this.email,
    this.phone,
    this.profileUrl,
    this.dateOfBirth,
    this.address,
    this.medicalHistory,
    required this.appointments,
  });

  String get fullName => '$firstName $lastName'.trim();

  int get totalAppointments => appointments.length;

  int get completedAppointments => appointments
      .where((a) => a.status == PatientAppointmentStatus.completed)
      .length;

  int get pendingAppointments => appointments
      .where((a) => a.status == PatientAppointmentStatus.approved)
      .length;
}

/// Patient appointment model
class PatientAppointment {
  final String bookingId;
  final String serviceId;
  final String clinicId;
  final DateTime appointmentDate;
  final PatientAppointmentStatus status;
  final DateTime? completedAt;
  final String? completionNotes;
  final String? rejectionReason;
  final String serviceName;
  final String? serviceDetail;
  final String clinicName;

  PatientAppointment({
    required this.bookingId,
    required this.serviceId,
    required this.clinicId,
    required this.appointmentDate,
    required this.status,
    this.completedAt,
    this.completionNotes,
    this.rejectionReason,
    required this.serviceName,
    this.serviceDetail,
    required this.clinicName,
  });

  factory PatientAppointment.fromJson(Map<String, dynamic> json) {
    final serviceData = json['services'] as Map<String, dynamic>? ?? {};
    final clinicData = json['clinics'] as Map<String, dynamic>? ?? {};

    return PatientAppointment(
      bookingId: json['booking_id'] as String,
      serviceId: json['service_id'] as String,
      clinicId: json['clinic_id'] as String,
      appointmentDate: DateTime.parse(json['date'] as String),
      status: PatientAppointmentStatus.fromString(json['status'] as String),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      completionNotes: json['completion_notes'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
      serviceName: serviceData['service_name'] as String? ?? 'Service',
      serviceDetail: serviceData['service_detail'] as String?,
      clinicName: clinicData['clinic_name'] as String? ?? 'Clinic',
    );
  }
}

/// Patient appointment status enumeration
enum PatientAppointmentStatus {
  pending,
  approved,
  completed,
  rejected,
  cancelled;

  static PatientAppointmentStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return PatientAppointmentStatus.pending;
      case 'approved':
        return PatientAppointmentStatus.approved;
      case 'completed':
        return PatientAppointmentStatus.completed;
      case 'rejected':
        return PatientAppointmentStatus.rejected;
      case 'cancelled':
        return PatientAppointmentStatus.cancelled;
      default:
        return PatientAppointmentStatus.pending;
    }
  }
}
