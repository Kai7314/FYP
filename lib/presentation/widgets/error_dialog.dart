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
    if (lowered.contains('contact address is required')) {
      return 'Please enter the contact address. If you already entered it, run the contacts validation SQL in Supabase and hot restart the app.';
    }
    if (lowered.contains('contact address must not exceed') ||
        lowered.contains('address must not exceed')) {
      return 'Contact address must be 200 characters or fewer.';
    }
    if (lowered.contains('contacts table is missing') ||
        lowered.contains('is_primary') ||
        lowered.contains('pgrst204') ||
        lowered.contains('schema cache')) {
      return 'The contacts database is not fully updated yet. Run the contacts quick-fix SQL in Supabase, wait a few seconds, then try again.';
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
    if (lowered.contains('documents.uploaded_at') ||
        (lowered.contains('uploaded_at') && lowered.contains('documents'))) {
      return 'The documents table is missing uploaded_at. Run supabase/quick_fix_documents_uploaded_at.sql in the Supabase SQL Editor, wait a few seconds, then open Legacy Planning again.';
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
