import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prepnotes/core/config/firebase_config.dart';

void main() {
  test('emulators are off unless USE_EMULATORS=true is passed', () {
    expect(EmulatorConfig.enabled, isFalse);
  });

  test('emulator ports match firebase.json', () {
    final json = jsonDecode(
      File('firebase.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final emulators = json['emulators'] as Map<String, dynamic>;
    int port(String name) =>
        (emulators[name] as Map<String, dynamic>)['port'] as int;

    expect(EmulatorConfig.authPort, port('auth'));
    expect(EmulatorConfig.firestorePort, port('firestore'));
    expect(EmulatorConfig.storagePort, port('storage'));
    expect(EmulatorConfig.functionsPort, port('functions'));
  });

  test('functions run in Mumbai', () {
    expect(FirebaseConfig.functionsRegion, 'asia-south1');
  });
}
