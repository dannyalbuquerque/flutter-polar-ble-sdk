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
  EcgData _lastEcgData;
   PpgData _lastPpgData;

  StreamSubscription accSubscription;
  StreamSubscription hrSubscription;
  StreamSubscription ecgSubscription;
  StreamSubscription ppgSubscription;

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
                Row(
                  children: [
                    RaisedButton(onPressed: (){
                     setState(() {
                       deviceIdCtrl.text = '7F01D527';
                     });
                    }, child: Text('OH1'),),
                                        RaisedButton(onPressed: (){
                     setState(() {
                       deviceIdCtrl.text = '370C0628';
                     });
                    }, child: Text('H10'),),
                  ],
                ),
                RaisedButton(onPressed: connect, child: Text('Connect'),),
                RaisedButton(onPressed: disconnect, child: Text('Disconnect'),),
                RaisedButton(onPressed: autoconnect, child: Text('Autoconnect'),),
                //RaisedButton(onPressed: hrBroadcast, child: Text('HR broadcast'),),
                RaisedButton(onPressed: acc, child: Text('ACC'),),
                RaisedButton(onPressed: hr, child: Text('HR'),),
                RaisedButton(onPressed: ecg, child: Text('ECG'),),
                RaisedButton(onPressed: ppg, child: Text('PPG'),),
                SizedBox(height: 32),
                _lastAccData != null ? Text('ACC: ${_lastAccData.toString()}'): Container(),
                _lastHrData != null ? Text('$_lastHrData'): Container(),
                _lastEcgData != null ? Text('$_lastEcgData'): Container(),
                _lastPpgData != null ? Text('$_lastPpgData'): Container(),
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
      print('connected');
    }catch (e,stack){
      print(stack.toString());
    }
  }

  void disconnect() async {
    try {
      await polarBleSdk.disconnect(deviceIdCtrl.text);
      print('disconnected');
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
    if(accSubscription != null){
      accSubscription.cancel();
      accSubscription = null;
              setState(() {
          _lastAccData = null;
        });
    }else{
    try {
      accSubscription = polarBleSdk.acc(deviceIdCtrl.text).listen((accData) {
        print(accData.toString());
        setState(() {
          _lastAccData = accData;
        });
      }, onError: (e) => print(e), onDone: ()=>print('done'), cancelOnError: true,);
    }catch (e,stack){
      print(stack.toString());
    }
    }

  }

    void hr() {
          if(hrSubscription != null){
      hrSubscription.cancel();
      hrSubscription = null;
              setState(() {
          _lastHrData = null;
        });
    }else{
    try {
      hrSubscription =  polarBleSdk.hr(deviceIdCtrl.text).listen((hrData) {
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

      void ecg() {
                  if(ecgSubscription != null){
      ecgSubscription.cancel();
      ecgSubscription = null;
              setState(() {
          _lastEcgData = null;
        });
    }else{
    try {
      ecgSubscription =  polarBleSdk.ecg(deviceIdCtrl.text).listen((ecgData) {
        print(ecgData.toString());
        setState(() {
          _lastEcgData = ecgData;
        });
      }, onError: (e) {
        print(e);
        }, onDone: ()=>print('done'), cancelOnError: true,);
    }catch (e,stack){
      print(stack.toString());
    }
  }
      }

            void ppg() {
                  if(ppgSubscription != null){
      ppgSubscription.cancel();
      ppgSubscription = null;
              setState(() {
          _lastPpgData = null;
        });
    }else{
    try {
      ppgSubscription =  polarBleSdk.ppg(deviceIdCtrl.text).listen((ppgData) {
        print(ppgData.toString());
        setState(() {
          _lastPpgData = ppgData;
        });
      }, onError: (e) {
        print(e);
        }, onDone: ()=>print('done'), cancelOnError: true,);
    }catch (e,stack){
      print(stack.toString());
    }
  }
      }
}
