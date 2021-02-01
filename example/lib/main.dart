import 'dart:io';

import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:polar_ble_sdk/polar_ble_sdk.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  TextEditingController deviceIdCtrl = TextEditingController(text: '370C0628');
  PolarBleSdk polarBleSdk = PolarBleSdk();
  PermissionStatus _locationPermissionStatus = PermissionStatus.unknown;
  int _lastHr;
  AccelerometerData _lastAccData;
  HrData _lastHrData;

  @override
  void initState() {
    _checkPermissions();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('PolarBleSdk example app'),
        ),
        body: Platform.isIOS || _locationPermissionStatus == PermissionStatus.granted ? Center(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 16, 32, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text('Device ID: '),
                    SizedBox(width: 8),
                    Expanded(child: TextField(controller: deviceIdCtrl)),
                  ],
                ),
                RaisedButton(onPressed: connect, child: Text('Connect'),),
                RaisedButton(onPressed: disconnect, child: Text('Disconnect'),),
                RaisedButton(onPressed: autoconnect, child: Text('Autoconnect'),),
                //RaisedButton(onPressed: hrBroadcast, child: Text('HR broadcast'),),
                RaisedButton(onPressed: acc, child: Text('ACC'),),
                RaisedButton(onPressed: hr, child: Text('HR'),),
                SizedBox(height: 32),
                _lastAccData != null ? Text('ACC: ${_lastAccData.toString()}'): Container(),
                 _lastHrData != null ? Text('$_lastHrData'): Container(),
              ],
            ),
          ),
        ) : Center(child: Text('Location permission needed')),
      ),
    );
  }

  Future<void> _checkPermissions() async {
    if (Platform.isAndroid) {
      var permissionStatus = await PermissionHandler()
          .requestPermissions([PermissionGroup.location]);

      setState(() {
        _locationPermissionStatus = permissionStatus[PermissionGroup.location];
      });

      if (_locationPermissionStatus != PermissionStatus.granted) {
        return Future.error(Exception("Location permission not granted"));
      }
    }
  }

  void connect() async {
    try {
      await polarBleSdk.connect(deviceIdCtrl.text);
    }catch (e,stack){
      print(stack.toString());
    }
  }

  void disconnect() async {
    try {
      await polarBleSdk.disconnect(deviceIdCtrl.text);
    }catch (e,stack){
      print(stack.toString());
    }
  }

  void autoconnect() async {
    try {
      await polarBleSdk.autoconnect();
    }catch (e,stack){
      print(stack.toString());
    }
  }

  void hrBroadcast() {
    try {
      polarBleSdk.hrBroadcast().listen((hr) {
        print(hr);
        setState(() {
          _lastHr = hr;
        });
      }, onError: (e)  {
        print(e);
        }, onDone: ()=>print('done'), cancelOnError: true,);
    }catch (e,stack){
      print(stack.toString());
    }
  }

  void acc() {
    try {
      polarBleSdk.acc(deviceIdCtrl.text).listen((accData) {
        print(accData.toString());
        setState(() {
          _lastAccData = accData;
        });
      }, onError: (e) => print(e), onDone: ()=>print('done'), cancelOnError: true,);
    }catch (e,stack){
      print(stack.toString());
    }
  }

    void hr() {
    try {
      polarBleSdk.hr(deviceIdCtrl.text).listen((hrData) {
        print(hrData.toString());
        setState(() {
          _lastHrData = hrData;
        });
      }, onError: (e) {
        print(e);
        }, onDone: ()=>print('done'), cancelOnError: true,);
    }catch (e,stack){
      print(stack.toString());
    }
  }
}
