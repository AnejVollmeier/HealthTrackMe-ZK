import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:healthtrackme/main.dart' as app;
import 'package:healthtrackme/screens/dashboard_screen.dart';
import 'package:healthtrackme/screens/login_screen.dart';
import 'package:healthtrackme/services/api_service.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _waitTimeout = Duration(seconds: 20);

Future<void> _waitFor(
  WidgetTester tester,
  bool Function() condition,
  String description,
) async {
  final elapsed = Stopwatch()..start();
  while (!condition()) {
    if (elapsed.elapsed >= _waitTimeout) {
      fail('Timed out waiting for $description.');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'FS-01-TP02 - Reject login with an incorrect password',
    (tester) async {
      const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
      const email = String.fromEnvironment('E2E_EMAIL');
      const password = String.fromEnvironment('E2E_PASSWORD');
      const wrongPassword = String.fromEnvironment('E2E_WRONG_PASSWORD');
      const isolatedDatabase = bool.fromEnvironment('E2E_ISOLATED_DATABASE');

      // No requests or app startup until the isolated environment is configured.
      final uri = Uri.tryParse(apiBaseUrl);
      if (!kIsWeb ||
          !isolatedDatabase ||
          uri == null ||
          uri.scheme != 'http' ||
          !['localhost', '127.0.0.1'].contains(uri.host) ||
          uri.port != 18080 ||
          uri.path != '/api/v1' ||
          uri.userInfo.isNotEmpty ||
          uri.hasQuery ||
          uri.hasFragment) {
        fail('Use the dedicated local E2E API on port 18080, path /api/v1, '
            'and confirm E2E_ISOLATED_DATABASE=true. See integration_test/README.md.');
      }
      if (email.trim().isEmpty ||
          password.isEmpty ||
          wrongPassword.isEmpty ||
          wrongPassword == password) {
        fail('Configure E2E_EMAIL, E2E_PASSWORD and a different, nonempty '
            'E2E_WRONG_PASSWORD in the private configuration file.');
      }

      // Prove the account exists; an unknown email would yield the same 401.
      // Use raw HTTP so this prerequisite never stores a JWT in the app.
      final client = http.Client();
      try {
        final response = await client
            .post(
              Uri.parse('$apiBaseUrl/auth/login'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'email': email, 'password': password}),
            )
            .timeout(_waitTimeout);
        expect(response.statusCode == 200, isTrue,
            reason:
                'The existing E2E account must accept its correct password.');
        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        final data = payload['data'] as Map<String, dynamic>?;
        expect(
          payload['success'] == true &&
              data?['token'] is String &&
              (data!['token'] as String).isNotEmpty &&
              data['user']?['email'] == email,
          isTrue,
          reason: 'The E2E account must return a valid login response.',
        );
      } finally {
        client.close();
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('healthtrackme_active_user_id');
      await prefs.setString('healthtrackme_locale', 'en');

      await app.main().timeout(_waitTimeout);
      final login = find.byType(LoginScreen);
      await _waitFor(tester, () => login.evaluate().length == 1, 'LoginScreen');
      expect(ApiService.instance.baseUrl, apiBaseUrl);

      final fields = find.descendant(
        of: login,
        matching: find.byType(TextFormField),
      );
      expect(fields, findsNWidgets(2));
      // LoginScreen contains email first (emailAddress keyboard), then password.
      final emailField = fields.at(0);
      final passwordField = fields.at(1);
      expect(
          tester
              .widget<TextField>(find.descendant(
                  of: emailField, matching: find.byType(TextField)))
              .decoration
              ?.hintText,
          'you@example.com');
      expect(
          tester
              .widget<TextField>(find.descendant(
                  of: passwordField, matching: find.byType(TextField)))
              .obscureText,
          isTrue);
      await tester.enterText(emailField, email);
      await tester.enterText(passwordField, wrongPassword);

      final submit = find.descendant(
        of: login,
        matching: find.widgetWithText(ElevatedButton, 'Log in'),
      );
      expect(submit, findsOneWidget);
      await tester.ensureVisible(submit);
      await tester.pump();
      await tester.tap(submit);

      final error = find.descendant(
        of: login,
        matching: find.text('Invalid email or password.'),
      );
      await _waitFor(tester, () => error.evaluate().length == 1,
          'the incorrect-password error');
      expect(error, findsOneWidget);
      expect(login, findsOneWidget);
      expect(find.byType(DashboardScreen), findsNothing);
      expect(
          GoRouter.of(tester.element(login))
              .routeInformationProvider
              .value
              .uri
              .path,
          '/auth');
      expect(ApiService.instance.activeUserId, isNull);
      expect(await ApiService.instance.getAuthToken(), isNull);
      expect(prefs.getString('auth_token'), isNull);
      expect(prefs.getInt('healthtrackme_active_user_id'), isNull);
      expect(tester.widget<ElevatedButton>(submit).onPressed, isNotNull);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
