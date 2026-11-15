import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';
import 'package:integration_test/common.dart';

// A browser refresh destroys the pending in-page integration_test request.
// Finish phase one first, refresh through WebDriver, then collect phase two.
Future<void> main() async {
  FlutterDriver? driver;
  try {
    driver = await FlutterDriver.connect().timeout(const Duration(seconds: 45));
    final before = Response.fromJson(
        await driver.requestData(null, timeout: const Duration(minutes: 3)));
    if (!before.allTestsPassed || before.data?['phase'] != 'before-reload') {
      throw StateError('FAIL FS-02-TP01 before reload: '
          '${before.formattedFailureDetails}');
    }
    final web = driver.webDriver;
    final originBefore = await web.execute('return performance.timeOrigin;',
        []).timeout(const Duration(seconds: 5));
    await web.refresh().timeout(const Duration(seconds: 30));
    final watch = Stopwatch()..start();
    while (true) {
      final ready = await web.execute(
          'return typeof window.\$flutterDriver === "function";',
          []).timeout(const Duration(seconds: 5));
      if (ready == true) break;
      if (watch.elapsed > const Duration(seconds: 45)) {
        throw StateError(
            'FAIL: integration_test did not restart after refresh.');
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    final originAfter = await web.execute('return performance.timeOrigin;',
        []).timeout(const Duration(seconds: 5));
    if (originBefore == originAfter) {
      throw StateError('FAIL: Chrome document did not reload.');
    }
    final after = Response.fromJson(
        await driver.requestData(null, timeout: const Duration(minutes: 3)));
    if (!after.allTestsPassed || after.data?['phase'] != 'after-reload') {
      throw StateError('FAIL FS-02-TP01 after reload: '
          '${after.formattedFailureDetails}');
    }
    for (final key in ['email', 'userId', 'medicineId', 'date']) {
      if (before.data?[key] == null || before.data?[key] != after.data?[key]) {
        throw StateError('FAIL: $key changed across page reload.');
      }
    }
    if (before.data?['bootId'] == after.data?['bootId']) {
      throw StateError('FAIL: Dart entrypoint did not restart.');
    }
    stdout.writeln(
        'PASS FS-02-TP01: real browser reload; same user and medicine; TAKEN persisted.');
    stdout.writeln('All tests passed.');
  } catch (error, stack) {
    stderr.writeln('$error\n$stack');
    exitCode = 1;
  } finally {
    await driver?.close().timeout(const Duration(seconds: 15));
  }
}
