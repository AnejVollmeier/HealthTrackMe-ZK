// Browser sessionStorage carries only test identity between two page loads.
// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthtrackme/services/api_service.dart';
import 'package:integration_test/integration_test.dart';

import 'support/e2e.dart';

const reloadKey = 'zk_e2e_fs02tp01_reload';
final bootId = uniqueEmail('page-load');

Finder scheduleTile() =>
    find.ancestor(of: find.text('ZK-Test-01'), matching: find.byType(ListTile));

Future<void> verifyTaken(
    WidgetTester tester, Account account, int medicineId, String date) async {
  final rows = await medicines(account);
  expect(rows, hasLength(1));
  expect(rows.single['id'], medicineId);
  expect(rows.single['name'], 'ZK-Test-01');
  expect(rows.single['dosage'], '1 tableta');
  expect(rows.single['frequency'], 'Once daily');
  final adherence = await request(
      'GET', '/medicines/$medicineId/adherence?days=1',
      token: account.token);
  expect(adherence['takenCount'], 1);
  expect(
      adherence['dailyBreakdown'], contains(containsPair('status', 'TAKEN')));
  expect(adherence['dailyBreakdown'], contains(containsPair('date', date)));
  final taken =
      find.descendant(of: scheduleTile(), matching: find.text('Taken'));
  await waitFor(tester, () => taken.evaluate().length == 1,
      'persisted Taken badge in the medicine schedule');
  expect(taken, findsOneWidget);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('FS-02-TP01 - Medicine TAKEN survives browser reload',
      (tester) async {
    checkEnvironment();
    final saved = html.window.sessionStorage[reloadKey];
    if (saved == null) {
      final account = await createAccount('dose');
      await startApp(tester);
      await login(tester, account.email);
      expect(await medicines(account), isEmpty);
      await openMedicineForm(tester);
      await enter(tester, field('Medicine name'), 'ZK-Test-01');
      await enter(tester, field('Dosage'), '1 tableta');
      await tap(tester, find.byType(DropdownButtonFormField<String>));
      await tap(tester, find.text('Once daily').last);
      await tap(tester, find.widgetWithText(FilledButton, 'Save'));
      await waitFor(tester, () => scheduleTile().evaluate().length == 1,
          'created medicine in the schedule');
      final rows = await medicines(account);
      expect(rows, hasLength(1));
      final medicineId = rows.single['id'] as int;
      final before = await request(
          'GET', '/medicines/$medicineId/adherence?days=1',
          token: account.token);
      expect(before['takenCount'], 0);
      final date = DateTime.now().toIso8601String().split('T').first;
      final tile = tester.widget<ListTile>(scheduleTile());
      await tap(tester, find.byWidget(tile.trailing!));
      await verifyTaken(tester, account, medicineId, date);
      final metadata = {
        'email': account.email,
        'userId': account.id,
        'medicineId': medicineId,
        'date': date,
        'bootId': bootId,
      };
      // Do not clear session/auth or re-create the medicine in phase two.
      html.window.sessionStorage[reloadKey] = jsonEncode(metadata);
      binding.reportData = {'phase': 'before-reload', ...metadata};
    } else {
      final metadata = jsonDecode(saved) as Map<String, dynamic>;
      expect(bootId, isNot(metadata['bootId']),
          reason: 'Dart entrypoint must execute in a fresh page.');
      expect(
          DateTime.now().toIso8601String().split('T').first, metadata['date'],
          reason: 'Run away from midnight: the scenario checks today.');
      await startApp(tester, preserveSession: true);
      expect(ApiService.instance.activeUserId, metadata['userId']);
      final token = await ApiService.instance.getAuthToken();
      expect(token, isNotEmpty, reason: 'JWT must survive real page reload.');
      final account = Account(
          metadata['email'] as String, metadata['userId'] as int, token!);
      final me = await request('GET', '/auth/me', token: token);
      expect(me['id'], account.id);
      expect(me['email'], account.email);
      await navigate(tester, '/meds');
      await verifyTaken(tester, account, metadata['medicineId'] as int,
          metadata['date'] as String);
      html.window.sessionStorage.remove(reloadKey);
      binding.reportData = {
        ...metadata,
        'phase': 'after-reload',
        'bootId': bootId,
      };
    }
  }, timeout: caseTimeout);
}
