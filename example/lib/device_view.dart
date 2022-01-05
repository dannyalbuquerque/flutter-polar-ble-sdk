import 'dart:async';

import 'package:flutter/material.dart';
import 'package:polar_ble_sdk/polar_ble_sdk.dart';

class DeviceView extends StatefulWidget {
  final PolarDeviceInfo device;
  final PolarBleSdk polarBleSdk;

  DeviceView({
    Key key,
    @required this.device,
    @required this.polarBleSdk,
  }) : super(key: key);

  @override
  _DeviceViewState createState() => _DeviceViewState();
}

class _DeviceViewState extends State<DeviceView>
    with AutomaticKeepAliveClientMixin<DeviceView> {
  PolarBleSdk polarBleSdk;
  AccelerometerData _lastAccData;
  HrData _lastHrData;
  EcgData _lastEcgData;
  PpgData _lastPpgData;
  bool connected = false;
  int _lastBatteryLevel;
  String _lastFwVersion;

  StreamSubscription accSubscription;
  StreamSubscription hrSubscription;
  StreamSubscription ecgSubscription;
  StreamSubscription ppgSubscription;

  @override
  void initState() {
    polarBleSdk = widget.polarBleSdk;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    String deviceId = widget.device.deviceId;
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 16, 32, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Device name: ${widget.device.name}'),
            SizedBox(height: 16),
            RaisedButton(
              onPressed: !connected ? () => connect(deviceId) : null,
              child: Text('Connect'),
            ),
            RaisedButton(
              onPressed: connected
                  ? () => disconnect(deviceId)
                  : () => disconnect(deviceId),
              child: Text('Disconnect'),
            ),
            // RaisedButton(devi
            //   onPressed: autoconnect,
            //   child: Text('Autoconnect'),
            // ),
            //RaisedButton(onPressed: hrBroadcast, child: Text('HR broadcast'),),
            SizedBox(height: 16),
            RaisedButton(
              onPressed: connected ? () => hr(deviceId) : null,
              child: Text('HR'),
            ),
            RaisedButton(
              onPressed: connected ? () => acc(deviceId) : null,
              child: Text('ACC'),
            ),
            RaisedButton(
              onPressed: connected ? () => ecg(deviceId) : null,
              child: Text('ECG'),
            ),
            RaisedButton(
              onPressed: connected ? () => ppg(deviceId) : null,
              child: Text('PPG'),
            ),
            RaisedButton(
              onPressed: connected ? () => batteryLevel(deviceId) : null,
              child: Text('BATTERY LEVEL'),
            ),
            RaisedButton(
              onPressed: connected ? () => fwVersion(deviceId) : null,
              child: Text('FIRMWARE VERSION'),
            ),
            SizedBox(height: 32),
            _lastAccData != null
                ? Text('$deviceId: ${_lastAccData.toString()}')
                : Container(),
            _lastHrData != null
                ? Text('$deviceId: ${_lastHrData.toString()}')
                : Container(),
            _lastEcgData != null
                ? Text('$deviceId: ${_lastEcgData.toString()}')
                : Container(),
            _lastPpgData != null
                ? Text('$deviceId: ${_lastPpgData.toString()}')
                : Container(),
            _lastBatteryLevel != null
                ? Text('$deviceId: ${_lastBatteryLevel.toString()}')
                : Container(),
            _lastFwVersion != null
                ? Text('$deviceId: $_lastFwVersion')
                : Container(),
          ],
        ),
      ),
    );
  }

  void connect(String deviceId) async {
    try {
      await polarBleSdk.connect(deviceId);
      setState(() {
        connected = true;
      });
      print('connected to $deviceId');
    } catch (e, stack) {
      print(stack.toString());
    }
  }

  void disconnect(String deviceId) async {
    try {
      hrSubscription?.cancel();
      accSubscription?.cancel();
      ecgSubscription?.cancel();
      ppgSubscription?.cancel();
      hrSubscription = null;
      accSubscription = null;
      ecgSubscription = null;
      ppgSubscription = null;
      setState(() {
        _lastHrData = null;
        _lastAccData = null;
        _lastEcgData = null;
        _lastPpgData = null;
      });
      await polarBleSdk.disconnect(deviceId);
      print('disconnected of $deviceId');
      setState(() {
        connected = false;
      });
    } catch (e, stack) {
      print(stack.toString());
    }
  }

  void batteryLevel(String deviceId) async {
    try {
      int batteryLevel = await polarBleSdk.batteryLevel(deviceId);
      setState(() {
        _lastBatteryLevel = batteryLevel;
      });
    } catch (e, stack) {
      print(stack.toString());
    }
  }

  void fwVersion(String deviceId) async {
    try {
      String fwVersion = await polarBleSdk.fwVersion(deviceId);
      setState(() async {
        _lastFwVersion = fwVersion;
      });
    } catch (e, stack) {
      print(stack.toString());
    }
  }

  // void autoconnect() async {
  //   try {
  //     await polarBleSdk.autoconnect();
  //   } catch (e, stack) {
  //     print(stack.toString());
  //   }
  // }

  // void hrBroadcast() {
  //   try {
  //     polarBleSdk.hrBroadcast().listen(
  //       (hr) {
  //         print(hr);
  //         setState(() {
  //           _lastHr = hr;
  //         });
  //       },
  //       onError: (e) {
  //         print(e);
  //       },
  //       onDone: () => print('done'),
  //       cancelOnError: true,
  //     );
  //   } catch (e, stack) {
  //     print(stack.toString());
  //   }
  // }

  void acc(String deviceId) {
    if (accSubscription != null) {
      accSubscription.cancel();
      accSubscription = null;
      setState(() {
        _lastAccData = null;
      });
    } else {
      try {
        accSubscription = polarBleSdk.acc(deviceId, 100).listen(
          (accData) {
            //print(accData.toString());
            setState(() {
              _lastAccData = accData;
            });
          },
          onError: (e) => print(e),
          onDone: () => print('done'),
          cancelOnError: true,
        );
      } catch (e, stack) {
        print(stack.toString());
      }
    }
  }

  void hr(String deviceId) {
    if (hrSubscription != null) {
      hrSubscription.cancel();
      hrSubscription = null;
      setState(() {
        _lastHrData = null;
      });
    } else {
      try {
        hrSubscription = polarBleSdk.hr(deviceId).listen(
          (hrData) {
            //print(hrData.toString());
            setState(() {
              _lastHrData = hrData;
            });
          },
          onError: (e) {
            print(e);
          },
          onDone: () => print('done'),
          cancelOnError: true,
        );
      } catch (e, stack) {
        print(stack.toString());
      }
    }
  }

  void ecg(String deviceId) {
    if (ecgSubscription != null) {
      ecgSubscription.cancel();
      ecgSubscription = null;
      setState(() {
        _lastEcgData = null;
      });
    } else {
      try {
        ecgSubscription = polarBleSdk.ecg(deviceId).listen(
          (ecgData) {
            //print(ecgData.toString());
            setState(() {
              _lastEcgData = ecgData;
            });
          },
          onError: (e) {
            print(e);
          },
          onDone: () => print('done'),
          cancelOnError: true,
        );
      } catch (e, stack) {
        print(stack.toString());
      }
    }
  }

  void ppg(String deviceId) {
    if (ppgSubscription != null) {
      ppgSubscription.cancel();
      ppgSubscription = null;
      setState(() {
        _lastPpgData = null;
      });
    } else {
      try {
        ppgSubscription = polarBleSdk.ppg(deviceId).listen(
          (ppgData) {
            //print(ppgData.toString());
            setState(() {
              _lastPpgData = ppgData;
            });
          },
          onError: (e) {
            print(e);
          },
          onDone: () => print('done'),
          cancelOnError: true,
        );
      } catch (e, stack) {
        print(stack.toString());
      }
    }
  }

  @override
  bool get wantKeepAlive => true;
}
