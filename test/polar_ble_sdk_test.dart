import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polar_ble_sdk/polar_ble_sdk.dart';

void main() {
  const MethodChannel channel = MethodChannel('polar_ble_sdk');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      return '42';
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

}
