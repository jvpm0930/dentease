import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Enhanced Appointment Service for managing appointment lifecycle
/// Provides state transitions, real-time updates, and error handling
class AppointmentService {
  static final AppointmentService _instance = AppointmentService._internal();
  factory AppointmentService() => _instance;
  AppointmentService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  // Stream controllers for real-time updates
  final Map<String, StreamController<List<Appointment>>> _pendingStreams = {};
  final Map<String, StreamController<List<Appointment>>> _upcomingStreams = {};
  final Map<String, StreamController<List<Appointment>>> _completedStreams = {};
  final Map<String, StreamController<AppointmentCounts>> _countsStreams = {};

  // Real-time subscriptions
  RealtimeChannel? _appointmentChannel;

  /// Initialize real-time subscriptions for appointment changes
  void initializeRealTimeSubscriptions() {
    _appointmentChannel = _supabase
        .channel('appointment_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'bookings',
          callback: (payload) {
            _handleAppointmentChange(payload);
          },
        )
        .subscribe();
  }

  /// Handle real-time appointment changes
  void _handleAppointmentChange(PostgresChangePayload payload) {
    try {
      final data = payload.newRecord;
      final clinicId = data['clinic_id'] as String?;

      if (clinicId != null) {
        // Refresh streams for the affected clinic
        _refreshStreamsForClinic(clinicId);
      }
    } catch (e) {
      debugPrint('Error handling appointment change: $e');
    }
  }

  /// Refresh all streams for a specific clinic
  void _refreshStreamsForClinic(String clinicId) {
    // Refresh pending appointments
    if (_pendingStreams.containsKey(clinicId)) {
      _fetchPendingAppointments(clinicId).then((appointments) {
        if (!_pendingStreams[clinicId]!.isClosed) {
          _pendingStreams[clinicId]!.add(appointments);
        }
      });
    }

    // Refresh upcoming appointments
    if (_upcomingStreams.containsKey(clinicId)) {
      _fetchUpcomingAppointments(clinicId).then((appointments) {
        if (!_upcomingStreams[clinicId]!.isClosed) {
          _upcomingStreams[clinicId]!.add(appointments);
        }
      });
    }

    // Refresh completed appointments
    if (_completedStreams.containsKey(clinicId)) {
      _fetchCompletedAppointments(clinicId).then((appointments) {
        if (!_completedStreams[clinicId]!.isClosed) {
          _completedStreams[clinicId]!.add(appointments);
        }
      });
    }

    // Refresh appointment counts
    if (_countsStreams.containsKey(clinicId)) {
      _fetchAppointmentCounts(clinicId).then((counts) {
        if (!_countsStreams[clinicId]!.isClosed) {
          _countsStreams[clinicId]!.add(counts);
        }
      });
    }
  }

  /// Approve an appointment request
  Future<ServiceResult> approveAppointment(String bookingId) async {
    try {
      final response = await _supabase.rpc('approve_appointment', params: {
        'p_booking_id': bookingId,
      });

      if (response['success'] == true) {
        return ServiceResult.success(
          message: 'Appointment approved successfully',
          data: response,
        );
      } else {
        return ServiceResult.error(
          message: response['error'] ?? 'Failed to approve appointment',
          error: response['error'],
        );
      }
    } catch (e) {
      debugPrint('Error approving appointment: $e');
      return ServiceResult.error(
        message: 'Network error occurred while approving appointment',
        error: e.toString(),
      );
    }
  }

  /// Reject an appointment request
  Future<ServiceResult> rejectAppointment(
      String bookingId, String reason) async {
    try {
      // Update booking status to rejected with reason
      final updateData = <String, dynamic>{
        'status': 'rejected',
      };

      // Add rejection reason if supported
      try {
        updateData['rejection_reason'] = reason;
      } catch (e) {
        debugPrint('rejection_reason column may not exist: $e');
      }

      await _supabase
          .from('bookings')
          .update(updateData)
          .eq('booking_id', bookingId);

      return ServiceResult.success(
        message: 'Appointment rejected successfully',
        data: {'booking_id': bookingId, 'reason': reason},
      );
    } catch (e) {
      debugPrint('Error rejecting appointment: $e');
      return ServiceResult.error(
        message: 'Failed to reject appointment',
        error: e.toString(),
      );
    }
  }

  /// Complete an appointment
  Future<ServiceResult> completeAppointment(
      String bookingId, String? notes) async {
    try {
      final response = await _supabase.rpc('complete_appointment', params: {
        'p_booking_id': bookingId,
        'p_completion_notes': notes,
      });

      if (response['success'] == true) {
        return ServiceResult.success(
          message: 'Appointment completed successfully',
          data: response,
        );
      } else {
        return ServiceResult.error(
          message: response['error'] ?? 'Failed to complete appointment',
          error: response['error'],
        );
      }
    } catch (e) {
      debugPrint('Error completing appointment: $e');
      return ServiceResult.error(
        message: 'Network error occurred while completing appointment',
        error: e.toString(),
      );
    }
  }

  /// Get stream of pending appointment requests
  Stream<List<Appointment>> getPendingRequests(String clinicId) {
    if (!_pendingStreams.containsKey(clinicId)) {
      _pendingStreams[clinicId] =
          StreamController<List<Appointment>>.broadcast();

      // Initial fetch
      _fetchPendingAppointments(clinicId).then((appointments) {
        if (!_pendingStreams[clinicId]!.isClosed) {
          _pendingStreams[clinicId]!.add(appointments);
        }
      });
    }

    return _pendingStreams[clinicId]!.stream;
  }

  /// Get stream of upcoming appointments
  Stream<List<Appointment>> getUpcomingAppointments(String clinicId) {
    if (!_upcomingStreams.containsKey(clinicId)) {
      _upcomingStreams[clinicId] =
          StreamController<List<Appointment>>.broadcast();

      // Initial fetch
      _fetchUpcomingAppointments(clinicId).then((appointments) {
        if (!_upcomingStreams[clinicId]!.isClosed) {
          _upcomingStreams[clinicId]!.add(appointments);
        }
      });
    }

    return _upcomingStreams[clinicId]!.stream;
  }

  /// Get stream of completed appointments
  Stream<List<Appointment>> getCompletedAppointments(String clinicId) {
    if (!_completedStreams.containsKey(clinicId)) {
      _completedStreams[clinicId] =
          StreamController<List<Appointment>>.broadcast();

      // Initial fetch
      _fetchCompletedAppointments(clinicId).then((appointments) {
        if (!_completedStreams[clinicId]!.isClosed) {
          _completedStreams[clinicId]!.add(appointments);
        }
      });
    }

    return _completedStreams[clinicId]!.stream;
  }

  /// Get stream of appointment counts for analytics
  Stream<AppointmentCounts> getAppointmentCounts(String clinicId) {
    if (!_countsStreams.containsKey(clinicId)) {
      _countsStreams[clinicId] =
          StreamController<AppointmentCounts>.broadcast();

      // Initial fetch
      _fetchAppointmentCounts(clinicId).then((counts) {
        if (!_countsStreams[clinicId]!.isClosed) {
          _countsStreams[clinicId]!.add(counts);
        }
      });
    }

    return _countsStreams[clinicId]!.stream;
  }

  /// Fetch pending appointments from database
  Future<List<Appointment>> _fetchPendingAppointments(String clinicId) async {
    try {
      final response = await _supabase
          .from('bookings')
          .select('''
            booking_id, patient_id, service_id, clinic_id, date, status,
            completed_at, completion_notes, rejection_reason,
            patients(firstname, lastname, profile_url, phone, email),
            services(service_name)
          ''')
          .eq('clinic_id', clinicId)
          .eq('status', 'pending')
          .order('date', ascending: true);

      return response.map((data) => Appointment.fromJson(data)).toList();
    } catch (e) {
      debugPrint('Error fetching pending appointments: $e');
      return [];
    }
  }

  /// Fetch upcoming appointments from database
  Future<List<Appointment>> _fetchUpcomingAppointments(String clinicId) async {
    try {
      final now = DateTime.now();
      final response = await _supabase
          .from('bookings')
          .select('''
            booking_id, patient_id, service_id, clinic_id, date, status,
            completed_at, completion_notes, rejection_reason,
            patients(firstname, lastname, profile_url, phone, email),
            services(service_name)
          ''')
          .eq('clinic_id', clinicId)
          .eq('status', 'approved')
          .gte('date', now.toIso8601String())
          .order('date', ascending: true);

      return response.map((data) => Appointment.fromJson(data)).toList();
    } catch (e) {
      debugPrint('Error fetching upcoming appointments: $e');
      return [];
    }
  }

  /// Fetch completed appointments from database
  Future<List<Appointment>> _fetchCompletedAppointments(String clinicId) async {
    try {
      final response = await _supabase
          .from('bookings')
          .select('''
            booking_id, patient_id, service_id, clinic_id, date, status,
            completed_at, completion_notes, rejection_reason,
            patients(firstname, lastname, profile_url, phone, email),
            services(service_name)
          ''')
          .eq('clinic_id', clinicId)
          .inFilter('status', ['completed', 'cancelled', 'rejected'])
          .order('date', ascending: false)
          .limit(50);

      return response.map((data) => Appointment.fromJson(data)).toList();
    } catch (e) {
      debugPrint('Error fetching completed appointments: $e');
      return [];
    }
  }

  /// Fetch appointment counts from database
  Future<AppointmentCounts> _fetchAppointmentCounts(String clinicId) async {
    try {
      final response = await _supabase
          .from('clinic_appointment_stats')
          .select('*')
          .eq('clinic_id', clinicId)
          .maybeSingle();

      if (response != null) {
        return AppointmentCounts.fromJson(response);
      } else {
        return AppointmentCounts.empty();
      }
    } catch (e) {
      debugPrint('Error fetching appointment counts: $e');
      return AppointmentCounts.empty();
    }
  }

  /// Dispose of resources
  void dispose() {
    _appointmentChannel?.unsubscribe();

    for (final controller in _pendingStreams.values) {
      controller.close();
    }
    for (final controller in _upcomingStreams.values) {
      controller.close();
    }
    for (final controller in _completedStreams.values) {
      controller.close();
    }
    for (final controller in _countsStreams.values) {
      controller.close();
    }

    _pendingStreams.clear();
    _upcomingStreams.clear();
    _completedStreams.clear();
    _countsStreams.clear();
  }
}

/// Service result wrapper for error handling
class ServiceResult {
  final bool isSuccess;
  final String message;
  final dynamic data;
  final String? error;

  ServiceResult._({
    required this.isSuccess,
    required this.message,
    this.data,
    this.error,
  });

  factory ServiceResult.success({
    required String message,
    dynamic data,
  }) {
    return ServiceResult._(
      isSuccess: true,
      message: message,
      data: data,
    );
  }

  factory ServiceResult.error({
    required String message,
    String? error,
  }) {
    return ServiceResult._(
      isSuccess: false,
      message: message,
      error: error,
    );
  }
}

/// Appointment data model
class Appointment {
  final String bookingId;
  final String patientId;
  final String serviceId;
  final String clinicId;
  final DateTime appointmentDate;
  final AppointmentStatus status;
  final DateTime? completedAt;
  final String? completionNotes;
  final String? rejectionReason;
  final PatientInfo patient;
  final ServiceInfo service;

  Appointment({
    required this.bookingId,
    required this.patientId,
    required this.serviceId,
    required this.clinicId,
    required this.appointmentDate,
    required this.status,
    this.completedAt,
    this.completionNotes,
    this.rejectionReason,
    required this.patient,
    required this.service,
  });

  factory Appointment.fromJson(Map<String, dynamic> json) {
    final patientData = json['patients'] as Map<String, dynamic>? ?? {};
    final serviceData = json['services'] as Map<String, dynamic>? ?? {};

    return Appointment(
      bookingId: json['booking_id'] as String,
      patientId: json['patient_id'] as String,
      serviceId: json['service_id'] as String,
      clinicId: json['clinic_id'] as String,
      appointmentDate: DateTime.parse(json['date'] as String),
      status: AppointmentStatus.fromString(json['status'] as String),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      completionNotes: json['completion_notes'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
      patient: PatientInfo.fromJson(patientData),
      service: ServiceInfo.fromJson(serviceData),
    );
  }
}

/// Appointment status enumeration
enum AppointmentStatus {
  pending,
  approved,
  completed,
  rejected,
  cancelled;

  static AppointmentStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppointmentStatus.pending;
      case 'approved':
        return AppointmentStatus.approved;
      case 'completed':
        return AppointmentStatus.completed;
      case 'rejected':
        return AppointmentStatus.rejected;
      case 'cancelled':
        return AppointmentStatus.cancelled;
      default:
        return AppointmentStatus.pending;
    }
  }
}

/// Patient information model
class PatientInfo {
  final String firstName;
  final String lastName;
  final String? profileUrl;
  final String? phone;
  final String? email;

  PatientInfo({
    required this.firstName,
    required this.lastName,
    this.profileUrl,
    this.phone,
    this.email,
  });

  factory PatientInfo.fromJson(Map<String, dynamic> json) {
    return PatientInfo(
      firstName: json['firstname'] as String? ?? 'Unknown',
      lastName: json['lastname'] as String? ?? '',
      profileUrl: json['profile_url'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
    );
  }

  String get fullName => '$firstName $lastName'.trim();
}

/// Service information model
class ServiceInfo {
  final String serviceName;

  ServiceInfo({
    required this.serviceName,
  });

  factory ServiceInfo.fromJson(Map<String, dynamic> json) {
    return ServiceInfo(
      serviceName: json['service_name'] as String? ?? 'Service',
    );
  }
}

/// Appointment counts for analytics
class AppointmentCounts {
  final int pendingRequests;
  final int approvedCount;
  final int completedCount;
  final int rejectedCount;
  final int cancelledCount;
  final int todaysPatients;
  final int todaysCompleted;
  final int weeklyCompleted;
  final int monthlyCompleted;

  AppointmentCounts({
    required this.pendingRequests,
    required this.approvedCount,
    required this.completedCount,
    required this.rejectedCount,
    required this.cancelledCount,
    required this.todaysPatients,
    required this.todaysCompleted,
    required this.weeklyCompleted,
    required this.monthlyCompleted,
  });

  factory AppointmentCounts.fromJson(Map<String, dynamic> json) {
    return AppointmentCounts(
      pendingRequests: json['pending_count'] as int? ?? 0,
      approvedCount: json['approved_count'] as int? ?? 0,
      completedCount: json['completed_count'] as int? ?? 0,
      rejectedCount: json['rejected_count'] as int? ?? 0,
      cancelledCount: json['cancelled_count'] as int? ?? 0,
      todaysPatients: json['todays_appointments'] as int? ?? 0,
      todaysCompleted: json['todays_completed'] as int? ?? 0,
      weeklyCompleted: json['week_completed'] as int? ?? 0,
      monthlyCompleted: json['month_completed'] as int? ?? 0,
    );
  }

  factory AppointmentCounts.empty() {
    return AppointmentCounts(
      pendingRequests: 0,
      approvedCount: 0,
      completedCount: 0,
      rejectedCount: 0,
      cancelledCount: 0,
      todaysPatients: 0,
      todaysCompleted: 0,
      weeklyCompleted: 0,
      monthlyCompleted: 0,
    );
  }
}
