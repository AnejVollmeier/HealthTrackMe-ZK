import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:healthtrackme/main.dart' as app;
import 'package:healthtrackme/screens/dashboard_screen.dart';
import 'package:healthtrackme/screens/friends_screen.dart';
import 'package:healthtrackme/screens/login_screen.dart';
import 'package:healthtrackme/screens/medicines_screen.dart';
import 'package:healthtrackme/services/api_service.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const waitTimeout = Duration(seconds: 20);
const caseTimeout = Timeout(Duration(minutes: 2));
const apiUrl = String.fromEnvironment('API_BASE_URL');
const testPassword = 'ZK-E2e!2026-Only';

void checkEnvironment() {
  final uri = Uri.tryParse(apiUrl);
  expect(
      kIsWeb &&
          const bool.fromEnvironment('E2E_ISOLATED_DATABASE') &&
          uri != null &&
          uri.scheme == 'http' &&
          ['localhost', '127.0.0.1'].contains(uri.host) &&
          uri.port == 18080 &&
          uri.path == '/api/v1' &&
          uri.userInfo.isEmpty &&
          !uri.hasQuery &&
          !uri.hasFragment,
      isTrue,
      reason: 'Use local port 18080 /api/v1 with healthtrackme_e2e; '
          'set E2E_ISOLATED_DATABASE=true before any requests.');
}

String uniqueEmail(String role) =>
    'zk-e2e-$role-${DateTime.now().microsecondsSinceEpoch}-'
    '${Random.secure().nextInt(0x100000000).toRadixString(16)}@example.com';

Future<void> waitFor(
    WidgetTester tester, bool Function() condition, String description) async {
  final watch = Stopwatch()..start();
  while (!condition()) {
    if (watch.elapsed >= waitTimeout) fail('FAIL: timeout: $description');
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> visible(WidgetTester tester, Finder finder) async {
  await waitFor(tester, () => finder.evaluate().isNotEmpty, '$finder');
  expect(finder, findsOneWidget);
  await tester.ensureVisible(finder).timeout(waitTimeout);
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> tap(WidgetTester tester, Finder finder) async {
  await visible(tester, finder);
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 300));
}

Finder field(String label) => find.byWidgetPredicate((w) =>
    w is TextField &&
    (w.decoration?.labelText == label || w.decoration?.hintText == label));

Future<void> enter(WidgetTester tester, Finder finder, String value) async {
  await visible(tester, finder);
  await tester.enterText(finder, value);
  await tester.pump();
}

GoRouter router(WidgetTester tester) => tester
    .widget<app.HealthTrackMeApp>(find.byType(app.HealthTrackMeApp))
    .router;

Future<void> navigate(WidgetTester tester, String path) async {
  router(tester).go(path);
  await tester.pump(const Duration(milliseconds: 400));
  await waitFor(
      tester,
      () => router(tester).routeInformationProvider.value.uri.path == path,
      'route $path');
}

Future<void> startApp(WidgetTester tester,
    {bool preserveSession = false}) async {
  checkEnvironment();
  final prefs = await SharedPreferences.getInstance();
  if (!preserveSession) {
    await prefs.remove('auth_token');
    await prefs.remove('healthtrackme_active_user_id');
  }
  await prefs.setString('healthtrackme_locale', 'en');
  await app.main().timeout(waitTimeout);
  await tester.pump();
  await GoogleFonts.pendingFonts().timeout(waitTimeout);
  await tester.pump();
  expect(ApiService.instance.baseUrl, apiUrl);
  if (!preserveSession) {
    await waitFor(tester, () => find.byType(LoginScreen).evaluate().length == 1,
        'LoginScreen');
  }
}

// Raw HTTP assertions must fail on HTTP errors, unlike UI API methods which
// intentionally return an empty list on a network failure.
Future<dynamic> request(String method, String path,
    {String? token, Map<String, dynamic>? body, int status = 200}) async {
  checkEnvironment();
  final client = http.Client();
  try {
    final req = http.Request(method, Uri.parse('$apiUrl$path'));
    req.headers['Content-Type'] = 'application/json';
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    if (body != null) req.body = jsonEncode(body);
    final response = await http.Response.fromStream(
            await client.send(req).timeout(waitTimeout))
        .timeout(waitTimeout);
    expect(response.statusCode, status, reason: '$method $path HTTP status');
    if (response.body.isEmpty) return null;
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    expect(payload['success'], true, reason: '$method $path success');
    return payload['data'];
  } finally {
    client.close();
  }
}

class Account {
  final String email;
  final int id;
  final String token;
  Account(this.email, this.id, this.token);
}

Future<Account> authenticate(String email) async {
  final data = await request('POST', '/auth/login', body: {
    'email': email,
    'password': testPassword,
  }) as Map<String, dynamic>;
  expect(data['user']['email'], email);
  expect(data['token'],
      isA<String>().having((s) => s.isNotEmpty, 'nonempty', true));
  return Account(email, data['user']['id'] as int, data['token'] as String);
}

Future<Account> createAccount(String role) async {
  final email = uniqueEmail(role);
  await request('POST', '/users', status: 201, body: {
    'email': email,
    'password': testPassword,
    'firstName': 'ZK',
    'lastName': role,
    'dateOfBirth': '2000-05-15',
    'userType': 'PATIENT',
  });
  return authenticate(email);
}

Future<void> login(WidgetTester tester, String email) async {
  await waitFor(tester, () => find.byType(LoginScreen).evaluate().length == 1,
      'login form');
  final fields = find.descendant(
      of: find.byType(LoginScreen), matching: find.byType(TextFormField));
  expect(fields, findsNWidgets(2));
  await enter(tester, fields.at(0), email);
  await enter(tester, fields.at(1), testPassword);
  await tap(tester, find.widgetWithText(ElevatedButton, 'Log in'));
  await waitFor(tester,
      () => find.byType(DashboardScreen).evaluate().length == 1, 'dashboard');
  expect(ApiService.instance.activeUserId, isNotNull);
  expect(await ApiService.instance.getAuthToken(), isNotEmpty);
}

Future<void> logout(WidgetTester tester) async {
  await navigate(tester, '/home');
  await tap(tester, find.byTooltip('Account'));
  await tap(tester, find.text('Sign out'));
  await waitFor(tester, () => find.byType(LoginScreen).evaluate().length == 1,
      'logout -> LoginScreen');
  expect(ApiService.instance.activeUserId, isNull);
  expect(await ApiService.instance.getAuthToken(), isNull);
  final prefs = await SharedPreferences.getInstance();
  expect(prefs.getString('auth_token'), isNull);
  expect(prefs.getInt('healthtrackme_active_user_id'), isNull);
}

Future<void> openMedicineForm(WidgetTester tester) async {
  await navigate(tester, '/meds');
  await tap(tester, find.widgetWithText(FloatingActionButton, 'Add medicine'));
  await waitFor(
      tester,
      () => find.byType(MedicineEditSheet).evaluate().length == 1,
      'medicine form');
}

Future<List<dynamic>> medicines(Account a) async =>
    (await request('GET', '/medicines/users/${a.id}', token: a.token)) as List;

Future<void> openFriends(WidgetTester tester) async {
  await navigate(tester, '/profile');
  await tap(tester, find.text('Friends & leaderboard'));
  await waitFor(tester, () => find.byType(FriendsScreen).evaluate().length == 1,
      'FriendsScreen');
  await tap(tester, find.text('Friends').last);
  await waitFor(tester, () => find.text('YOUR FRIENDS').evaluate().isNotEmpty,
      'loaded friends tab');
}

Future<void> sendRequest(WidgetTester tester, String email) async {
  await tap(tester, find.byTooltip('Add friend'));
  final dialog = find.byType(AlertDialog);
  await enter(tester,
      find.descendant(of: dialog, matching: find.byType(TextField)), email);
  await tap(tester, find.widgetWithText(FilledButton, 'Send request'));
}

Future<List<dynamic>> friendsData(Account a, [String suffix = '']) async =>
    (await request('GET', '/friends/users/${a.id}$suffix', token: a.token))
        as List;
