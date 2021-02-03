
import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:polar_ble_sdk/constants.dart';
import 'package:polar_ble_sdk/hr_data.dart';

import 'accelerometer_data.dart';

export 'accelerometer_data.dart';
export 'hr_data.dart';

const String POLAR_H10 = 'Polar H10';

class PolarBleSdk {
  final _channel = MethodChannel('polar_ble_sdk');
  final _hrBroadcastEventChannel = EventChannel(EventName.hrBroadcast);
  final _accEventChannel = EventChannel(EventName.acc);
  final _hrEventChannel = EventChannel(EventName.hr);

  Future<void> connect(String deviceId) async {
    await _channel.invokeMethod(MethodName.connect, {"deviceId":deviceId});
  }

  Future<void> disconnect(String deviceId) async {
    await _channel.invokeMethod(MethodName.disconnect, {"deviceId":deviceId});
 }

  Future<void> autoconnect() async {
    await _channel.invokeMethod(MethodName.autoconnect);
  }

  Stream<dynamic> hrBroadcast() {
     return _hrBroadcastEventChannel.receiveBroadcastStream();
  }

  Stream<AccelerometerData> acc(String deviceId) {
    return _accEventChannel.receiveBroadcastStream(deviceId).map((data) => AccelerometerData.fromJson(jsonDecode(data)));
  }

    Stream<HrData> hr(String deviceId) {
    return _hrEventChannel.receiveBroadcastStream(deviceId).map((data) => HrData.fromJson(jsonDecode(data)));
  }

}
