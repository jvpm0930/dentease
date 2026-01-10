import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Helper class to debug and fix authentication issues
class AuthDebugHelper {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Debug staff login issues
  static Future<void> debugStaffLogin(String email) async {
    try {
      debugPrint('=== DEBUGGING STAFF LOGIN FOR: $email ===');

      // 1. Check if staff exists in staffs table
      final staffRecord = await _supabase
          .from('staffs')
          .select('staff_id, email, firstname, lastname, clinic_id, password')
          .eq('email', email)
          .maybeSingle();

      if (staffRecord == null) {
        debugPrint('❌ Staff record not found in staffs table');
        return;
      }

      debugPrint('✅ Staff record found:');
      debugPrint('   Staff ID: ${staffRecord['staff_id']}');
      debugPrint('   Email: ${staffRecord['email']}');
      debugPrint(
          '   Name: ${staffRecord['firstname']} ${staffRecord['lastname']}');
      debugPrint('   Clinic ID: ${staffRecord['clinic_id']}');

      // 2. Try to authenticate with Supabase Auth
      try {
        final authResponse = await _supabase.auth.signInWithPassword(
          email: email,
          password: staffRecord['password'] ?? '123456', // Use stored password
        );

        if (authResponse.user != null) {
          debugPrint('✅ Auth successful! User ID: ${authResponse.user!.id}');

          // Check if staff_id matches auth user id
          if (authResponse.user!.id == staffRecord['staff_id']) {
            debugPrint('✅ Staff ID matches Auth User ID');
          } else {
            debugPrint('❌ Staff ID mismatch!');
            debugPrint('   Auth User ID: ${authResponse.user!.id}');
            debugPrint('   Staff ID: ${staffRecord['staff_id']}');
          }

          // Sign out after test
          await _supabase.auth.signOut();
        } else {
          debugPrint('❌ Auth failed - no user returned');
        }
      } catch (authError) {
        debugPrint('❌ Auth failed with error: $authError');
      }

      debugPrint('=== DEBUG COMPLETE ===');
    } catch (e) {
      debugPrint('❌ Debug failed: $e');
    }
  }

  /// Fix staff authentication by recreating the auth user
  static Future<bool> fixStaffAuth(String email, String password) async {
    try {
      debugPrint('=== FIXING STAFF AUTH FOR: $email ===');

      // Get staff record
      final staffRecord = await _supabase
          .from('staffs')
          .select('staff_id, email, firstname, lastname, clinic_id')
          .eq('email', email)
          .maybeSingle();

      if (staffRecord == null) {
        debugPrint('❌ Staff record not found');
        return false;
      }

      // Call create_user function to recreate the auth user
      final response = await _supabase.functions.invoke(
        'create_user',
        body: {
          'email': email,
          'password': password,
          'role': 'staff',
          'clinic_id': staffRecord['clinic_id'],
          'profile_data': {
            'firstname': staffRecord['firstname'],
            'lastname': staffRecord['lastname'],
          },
        },
      );

      if (response.status == 200) {
        final data = response.data as Map<String, dynamic>;
        if (data['success'] == true) {
          debugPrint('✅ Staff auth fixed successfully!');
          return true;
        } else {
          debugPrint('❌ Fix failed: ${data['error']}');
          return false;
        }
      } else {
        debugPrint('❌ Fix failed with status: ${response.status}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Fix failed: $e');
      return false;
    }
  }

  /// Test FCM token saving
  static Future<void> testFCMTokenSaving(
      String userId, String tableName, String idColumn) async {
    try {
      debugPrint('=== TESTING FCM TOKEN SAVING ===');
      debugPrint('User ID: $userId');
      debugPrint('Table: $tableName');
      debugPrint('ID Column: $idColumn');

      // Simulate FCM token
      const testToken = 'test_fcm_token_' + '123456789';

      // Try to save token
      final result = await _supabase
          .from(tableName)
          .update({'fcm_token': testToken}).eq(idColumn, userId);

      debugPrint('✅ FCM token save test completed');
      debugPrint('Result: $result');

      // Verify the save
      final verification = await _supabase
          .from(tableName)
          .select('fcm_token')
          .eq(idColumn, userId)
          .maybeSingle();

      if (verification != null && verification['fcm_token'] == testToken) {
        debugPrint('✅ FCM token verified successfully');
      } else {
        debugPrint('❌ FCM token verification failed');
      }
    } catch (e) {
      debugPrint('❌ FCM token test failed: $e');
    }
  }
}
