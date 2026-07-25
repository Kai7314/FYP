import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';

class AppErrorDialog {
  static Future<void> show(
    BuildContext context, {
    required String title,
    required Object error,
  }) {
    final message = friendlyMessage(error);
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.error_outline, color: AppColors.danger),
        title: Text(title),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  static String friendlyMessage(Object error) {
    final text = error.toString();
    final lowered = text.toLowerCase();

    if (lowered.contains('you can add up to')) {
      return 'You can add up to 5 emergency contacts only.';
    }
    if (lowered.contains('contacts_one_primary_per_user')) {
      return 'The primary contact was changed on the server. Refresh the contacts list and try again if it does not update.';
    }
    if (lowered.contains('already an emergency contact') ||
        lowered.contains('duplicate key')) {
      return 'This phone number is already saved as an emergency contact.';
    }
    if (lowered.contains('verify your phone number') ||
        lowered.contains('verify this contact phone number')) {
      return 'Please send and enter the SMS verification code before saving this phone number.';
    }
    if (lowered.contains('complete the reward goal')) {
      return 'Keep checking in until this reward goal is completed, then try again.';
    }
    if (lowered.contains('reward has already been requested')) {
      return 'This reward already has a fulfillment request. Check its status on the Rewards page.';
    }
    if (lowered.contains('reward administrator access is required')) {
      return 'This page is available only to an approved reward administrator.';
    }
    if (lowered.contains('reward_requests') ||
        lowered.contains('request_current_user_reward') ||
        lowered.contains('sync_current_user_rewards')) {
      return 'Reward delivery requests are not configured on the server yet. Apply the reward fulfillment migration and try again.';
    }
    if (lowered.contains('contact address is required')) {
      return 'Please enter the contact address. If you already entered it, run the contacts validation SQL in Supabase and hot restart the app.';
    }
    if (lowered.contains('contact address must not exceed') ||
        lowered.contains('address must not exceed')) {
      return 'Contact address must be 200 characters or fewer.';
    }
    final missingSchemaColumn =
        lowered.contains('pgrst204') || lowered.contains('schema cache');
    final documentsSchemaError =
        missingSchemaColumn &&
        (lowered.contains('documents') ||
            lowered.contains('storage_path') ||
            lowered.contains('uploaded_at'));
    if (documentsSchemaError) {
      return 'Secure document storage is not fully configured. Apply the Legacy Documents database setup, wait a few seconds, then try again.';
    }
    final contactsSchemaError =
        lowered.contains('contacts table is missing') ||
        lowered.contains('is_primary') ||
        (missingSchemaColumn && lowered.contains('contacts'));
    if (contactsSchemaError) {
      return 'The contacts database is not fully updated yet. Run the contacts quick-fix SQL in Supabase, wait a few seconds, then try again.';
    }
    final profileSchemaError =
        missingSchemaColumn &&
        (lowered.contains('users') ||
            lowered.contains('address_state') ||
            lowered.contains('address_region') ||
            lowered.contains('emergency_escalation_target'));
    if (profileSchemaError) {
      return 'Your profile database is missing a required field. Run supabase/quick_fix_users_profile_columns.sql in the Supabase SQL Editor, wait a few seconds, then try again.';
    }
    if (missingSchemaColumn) {
      return 'The database schema is still updating. Wait a few seconds and try again.';
    }
    if (lowered.contains('document must not exceed 10 mb') ||
        lowered.contains('selected document is empty') ||
        lowered.contains('choose a pdf') ||
        lowered.contains('file content does not match') ||
        lowered.contains('could not read the selected document') ||
        lowered.contains('rename the file using')) {
      return text.replaceFirst(RegExp(r'^Bad state:\s*'), '');
    }
    if (lowered.contains('legacy-documents') ||
        lowered.contains('bucket not found') ||
        lowered.contains('storage.objects') ||
        lowered.contains('storageexception')) {
      return 'Secure document storage is not fully configured. Run supabase/legacy_documents_upload.sql in the Supabase SQL Editor, then try again.';
    }
    if (lowered.contains('could not create a secure link') ||
        lowered.contains('could not open the selected document')) {
      return 'The document could not be opened securely. Check your connection and try again.';
    }
    if (lowered.contains('legacy_access_enabled') ||
        lowered.contains('legacy_access_test_enabled') ||
        lowered.contains('legacy_access_started_at') ||
        lowered.contains('legacy_access_otps') ||
        lowered.contains('set_legacy_access_enabled') ||
        lowered.contains('set_legacy_access_test_enabled')) {
      return 'Legacy Checking is not configured yet. Run supabase/legacy_access_setup.sql in the Supabase SQL Editor, then try again.';
    }
    if (lowered.contains('primary trusted contact before enabling') ||
        lowered.contains('verify the primary contact phone')) {
      return text.replaceFirst(RegExp(r'^Bad state:\s*'), '');
    }
    if (lowered.contains('delete policy') ||
        lowered.contains('row-level security') ||
        lowered.contains('permission denied')) {
      return 'Supabase does not allow deleting contacts yet. Run the contacts delete policy quick-fix SQL, then try again.';
    }
    if (lowered.contains('signed in')) {
      return 'Please sign in again before changing your contacts.';
    }
    if (lowered.contains('failed host lookup') ||
        lowered.contains('failed to fetch') ||
        lowered.contains('socketexception')) {
      return 'Cannot connect to Supabase. Check your internet connection and try again.';
    }
    if (lowered.contains('contact could not be deleted')) {
      return 'The contact could not be deleted. Refresh the contacts list and try again.';
    }
    if (lowered.contains('legacy_notes')) {
      return 'Legacy notes are not set up in Supabase yet. Run supabase/legacy_notes_crud.sql in the Supabase SQL Editor, then try again.';
    }

    if (kDebugMode) {
      final details = text.length > 240 ? '${text.substring(0, 240)}...' : text;
      return 'Something went wrong. Please try again.\n\nTechnical detail: $details';
    }

    return 'Something went wrong. Please try again.';
  }
}
