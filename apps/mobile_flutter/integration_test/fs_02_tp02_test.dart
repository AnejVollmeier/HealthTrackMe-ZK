import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthtrackme/screens/medicines_screen.dart';
import 'package:integration_test/integration_test.dart';

import 'support/e2e.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('FS-02-TP02 - Reject medicine without a name', (tester) async {
    checkEnvironment();
    final account = await createAccount('empty-medicine');
    await startApp(tester);
    await login(tester, account.email);
    expect(await medicines(account), isEmpty);
    await openMedicineForm(tester);
    await enter(tester, field('Dosage'), '1 tableta');
    await tap(tester, find.byType(DropdownButtonFormField<String>));
    await tap(tester, find.text('Once daily').last);
    await tap(tester, find.widgetWithText(FilledButton, 'Save'));
    await waitFor(tester, () => find.text('Required').evaluate().length == 1,
        'required name validation');
    expect(find.byType(MedicineEditSheet), findsOneWidget);
    expect(tester.widget<TextField>(field('Medicine name')).controller!.text,
        isEmpty);
    expect(find.text('Medicine added'), findsNothing);
    expect(await medicines(account), isEmpty,
        reason: 'No medicine may be persisted after rejected submission.');
    // A correction must still be possible after the validation failure.
    expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
            .onPressed,
        isNotNull);
  }, timeout: caseTimeout);
}
