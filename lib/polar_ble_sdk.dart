import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:polar_ble_sdk/constants.dart';
import 'package:polar_ble_sdk/device_info.dart';
import 'package:polar_ble_sdk/ecg_data.dart';
import 'package:polar_ble_sdk/hr_data.dart';
import 'package:polar_ble_sdk/ppg_data.dart';
import 'package:streams_channel/streams_channel.dart';

import 'accelerometer_data.dart';

export 'accelerometer_data.dart';
export 'hr_data.dart';
export 'ecg_data.dart';
export 'ppg_data.dart';
export 'device_info.dart';

const String POLAR_H10 = 'Polar H10';
const String POLAR_OH1 = 'Polar OH1';
const Duration DEFAULT_TIMEOUT = Duration(seconds: 10);

class PolarBleSdk {
  final _channel = MethodChannel('polar_ble_sdk');
  //final _hrBroadcastEventChannel = EventChannel(EventName.hrBroadcast);
  final _accStreamsChannel = StreamsChannel(EventName.acc);
  final _hrStreamsChannel = StreamsChannel(EventName.hr);
  final _ecgsearchStreamsChannel = StreamsChannel(EventName.ecg);
  final _ppgsearchStreamsChannel = StreamsChannel(EventName.ppg);
  final _searchEventChannel = EventChannel(EventName.search);

  Future<void> connect(String deviceId) async {
    await _channel.invokeMethod(
        MethodName.connect, {"deviceId": deviceId}).timeout(DEFAULT_TIMEOUT);
    return;
  }

  Future<void> disconnect(String deviceId) async {
    await _channel.invokeMethod(
        MethodName.disconnect, {"deviceId": deviceId}).timeout(DEFAULT_TIMEOUT);
    return;
  }

  // Future<void> autoconnect() async {
  //   await _channel
  //       .invokeMethod(MethodName.autoconnect)
  //       .timeout(DEFAULT_TIMEOUT);
  //   return;
  // }

  // Stream<dynamic> hrBroadcast() {
  //   return _hrBroadcastEventChannel.receiveBroadcastStream();
  // }

  Stream<AccelerometerData> acc(String deviceId) {
    return _accStreamsChannel
        .receiveBroadcastStream(deviceId)
        .map((data) => AccelerometerData.fromJson(jsonDecode(data)));
  }

  Stream<HrData> hr(String deviceId) {
    return _hrStreamsChannel
        .receiveBroadcastStream(deviceId)
        .map((data) => HrData.fromJson(jsonDecode(data)));
  }

  Stream<EcgData> ecg(String deviceId) {
    return _ecgsearchStreamsChannel
        .receiveBroadcastStream(deviceId)
        .map((data) => EcgData.fromJson(jsonDecode(data)));
  }

  Stream<PpgData> ppg(String deviceId) {
    return _ppgsearchStreamsChannel
        .receiveBroadcastStream(deviceId)
        .map((data) => PpgData.fromJson(jsonDecode(data)));
  }

  Stream<DeviceInfo> searchForDevice() {
    return _searchEventChannel
        .receiveBroadcastStream()
        .map((data) => DeviceInfo.fromJson(jsonDecode(data)));
  }
}
