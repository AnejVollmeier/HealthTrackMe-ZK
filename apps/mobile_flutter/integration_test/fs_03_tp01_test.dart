import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/e2e.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('FS-03-TP01 - Send and accept a friend request', (tester) async {
    checkEnvironment();
    final a = await createAccount('friend-a');
    final b = await createAccount('friend-b');
    expect(await friendsData(a), isEmpty);
    expect(await friendsData(b), isEmpty);
    await startApp(tester);
    await login(tester, a.email);
    await openFriends(tester);
    await sendRequest(tester, b.email);
    await waitFor(tester, () => find.text(b.email).evaluate().length == 1,
        'outgoing friend card');
    expect(find.text('PENDING'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    final outgoing = await friendsData(a, '/requests/outgoing');
    expect(outgoing, hasLength(1));
    expect(outgoing.single['email'], b.email);
    expect(outgoing.single['status'], 'PENDING');
    final friendshipId = outgoing.single['friendshipId'];
    final incoming = await friendsData(b, '/requests/incoming');
    expect(incoming, hasLength(1));
    expect(incoming.single['friendshipId'], friendshipId);
    expect(incoming.single['email'], a.email);
    await logout(tester);
    await login(tester, b.email);
    await openFriends(tester);
    expect(find.text(a.email), findsOneWidget);
    expect(find.text('REQUESTS'), findsOneWidget);
    await tap(tester, find.byIcon(Icons.check_rounded));
    await waitFor(
        tester,
        () =>
            find.byIcon(Icons.person_remove_alt_1_outlined).evaluate().length ==
            1,
        'accepted friend card for B');
    expect(find.text(a.email), findsOneWidget);
    expect(find.text('REQUESTS'), findsNothing);
    final bFriends = await friendsData(b);
    expect(bFriends, hasLength(1));
    expect(bFriends.single['email'], a.email);
    expect(bFriends.single['status'], 'ACCEPTED');
    expect(bFriends.single['friendshipId'], friendshipId);
    await logout(tester);
    await login(tester, a.email);
    await openFriends(tester);
    expect(find.text(b.email), findsOneWidget);
    expect(find.byIcon(Icons.person_remove_alt_1_outlined), findsOneWidget);
    expect(find.text('PENDING'), findsNothing);
    expect(find.text('Pending'), findsNothing);
    final aFriends = await friendsData(a);
    expect(aFriends, hasLength(1));
    expect(aFriends.single['email'], b.email);
    expect(aFriends.single['status'], 'ACCEPTED');
    expect(aFriends.single['friendshipId'], friendshipId);
    for (final account in [a, b]) {
      expect(await friendsData(account, '/requests/incoming'), isEmpty);
      expect(await friendsData(account, '/requests/outgoing'), isEmpty);
    }
  }, timeout: caseTimeout);
}
