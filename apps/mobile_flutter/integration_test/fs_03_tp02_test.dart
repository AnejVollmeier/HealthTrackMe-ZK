import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/e2e.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('FS-03-TP02 - Reject adding yourself', (tester) async {
    checkEnvironment();
    final account = await createAccount('self-friend');
    await startApp(tester);
    await login(tester, account.email);
    await openFriends(tester);
    await sendRequest(tester, account.email);
    await waitFor(
        tester,
        () => find.text("You can't add yourself").evaluate().length == 1,
        'self-friend rejection message');
    expect(find.text("You can't add yourself"), findsOneWidget);
    expect(find.text('No friends yet'), findsOneWidget);
    expect(find.text('PENDING'), findsNothing);
    expect(await friendsData(account), isEmpty);
    expect(await friendsData(account, '/requests/incoming'), isEmpty);
    expect(await friendsData(account, '/requests/outgoing'), isEmpty);
  }, timeout: caseTimeout);
}
