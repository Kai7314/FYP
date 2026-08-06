import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  test('check-ins and emergency outbox writes are server-authoritative', () {
    final checkins = source(
      'lib/dataAccessLayer/repositories/checkin_repository.dart',
    );
    final emergencies = source(
      'lib/dataAccessLayer/repositories/emergency_repository.dart',
    );
    final migration = source(
      'supabase/migrations/202608050004_server_authoritative_feature_logic.sql',
    );

    expect(checkins, contains("client.rpc('record_threshold_checkin')"));
    expect(checkins, isNot(contains("from('checkins').insert")));
    expect(
      emergencies,
      contains("client.rpc(\n      'queue_current_user_emergency_sms'"),
    );
    expect(
      emergencies,
      isNot(contains("from('emergency_delivery_outbox').insert")),
    );
    expect(migration, contains('drop policy if exists "checkins_insert_own"'));
    expect(migration, contains('drop policy if exists "outbox_insert_own"'));
  });

  test('Oren progression uses authenticated server actions in production', () {
    final service = source('lib/services/oren_care_service.dart');
    final home = source('lib/presentation/screen/home/home_screen.dart');
    final migration = source(
      'supabase/migrations/202608050004_server_authoritative_feature_logic.sql',
    );

    expect(service, contains("_performServerAction('daily_login')"));
    expect(service, contains("_performServerAction('buy_toy'"));
    expect(home, contains('final orenCareService = OrenCareService();'));
    expect(migration, contains('perform_current_user_oren_action'));
    expect(migration, contains('migrate_current_user_oren_state'));
    expect(migration, contains('legacy_imported_at'));
  });

  test('production SOS explicitly disables direct device SMS', () {
    final home = source('lib/presentation/screen/home/home_screen.dart');
    final edgeFunction = source(
      'supabase/functions/send-emergency-sms/index.ts',
    );

    expect(home, contains('allowDirectSms: false'));
    expect(edgeFunction, contains('recipientIsApproved'));
    expect(edgeFunction, contains('test-user-sms:'));
  });

  test('Legacy Document metadata requires server byte validation', () {
    final repository = source(
      'lib/dataAccessLayer/repositories/document_repository.dart',
    );
    final finalizer = source(
      'supabase/functions/finalize-legacy-document/index.ts',
    );
    final migration = source(
      'supabase/migrations/202608050005_server_document_finalization.sql',
    );

    expect(repository, contains(".invoke(\n            'finalize-legacy-document'"));
    expect(repository, isNot(contains("from('documents').insert")));
    expect(finalizer, contains('matchesSignature'));
    expect(finalizer, contains('blob.size > maxBytes'));
    expect(migration, contains('revoke insert, update on public.documents'));
  });
}
