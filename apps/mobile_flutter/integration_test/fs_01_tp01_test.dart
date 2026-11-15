import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthtrackme/screens/edit_profile_screen.dart';
import 'package:healthtrackme/screens/login_screen.dart';
import 'package:healthtrackme/screens/profile_screen.dart';
import 'package:healthtrackme/screens/register_screen.dart';
import 'package:integration_test/integration_test.dart';

import 'support/e2e.dart';

Future<void> verifyProfile(WidgetTester tester, String email) async {
  await navigate(tester, '/profile');
  await waitFor(
      tester, () => find.text(email).evaluate().length == 1, 'profile email');
  expect(find.text('ZK Registration'), findsOneWidget);
  await tap(tester, find.text('Personal details'));
  await waitFor(
      tester,
      () => find.byType(EditProfileScreen).evaluate().length == 1,
      'personal details');
  expect(tester.widget<TextField>(field('First name')).controller!.text, 'ZK');
  expect(tester.widget<TextField>(field('Last name')).controller!.text,
      'Registration');
  expect(tester.widget<TextField>(field('Date of birth')).controller!.text,
      '2000-05-15');
  Navigator.of(tester.element(find.byType(EditProfileScreen))).pop();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('FS-01-TP01 - Registration, logout and login', (tester) async {
    checkEnvironment();
    final email = uniqueEmail('registration');
    await startApp(tester);
    await tap(tester, find.widgetWithText(TextButton, 'Register'));
    await waitFor(
        tester,
        () => find.byType(RegisterScreen).evaluate().length == 1,
        'registration form');
    await enter(tester, field('First name'), 'ZK');
    await enter(tester, field('Last name'), 'Registration');
    await enter(tester, field('you@example.com'), email);
    await tap(tester, field('Select date'));
    await waitFor(
        tester,
        () => find.byType(CalendarDatePicker).evaluate().length == 1,
        'date picker');
    // Real calendar interaction: picker starts in January 2000.
    for (var month = 0; month < 4; month++) {
      await tap(tester, find.byTooltip('Next month'));
    }
    await tap(
        tester,
        find
            .descendant(
                of: find.byType(CalendarDatePicker), matching: find.text('15'))
            .hitTestable());
    expect(tester.widget<TextField>(field('Select date')).controller!.text,
        '15.05.2000');
    await enter(tester, field('Create a password'), testPassword);
    await enter(tester, field('Confirm your password'), testPassword);
    await tap(tester, find.widgetWithText(ElevatedButton, 'Create account'));
    await waitFor(
        tester,
        () => router(tester).routeInformationProvider.value.uri.path == '/home',
        'successful registration');
    final account = await authenticate(email);
    await verifyProfile(tester, email);
    await logout(tester);
    router(tester).go('/profile');
    await tester.pump(const Duration(milliseconds: 400));
    await waitFor(
        tester,
        () => router(tester).routeInformationProvider.value.uri.path == '/auth',
        'profile access rejected after logout');
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(ProfileScreen), findsNothing);
    await login(tester, email);
    await verifyProfile(tester, email);
    final data =
        await request('GET', '/users/${account.id}', token: account.token);
    expect(data['email'], email);
    expect(data['dateOfBirth'], '2000-05-15');
  }, timeout: caseTimeout);
}
