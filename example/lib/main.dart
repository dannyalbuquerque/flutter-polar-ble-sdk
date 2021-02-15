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
  TextEditingController deviceIdCtrl1 = TextEditingController(text: '370C0628');
  TextEditingController deviceIdCtrl2 = TextEditingController(text: '7F01D527');
  PolarBleSdk polarBleSdk = PolarBleSdk();
  PermissionStatus _locationPermissionStatus = PermissionStatus.unknown;
  Map<String, AccelerometerData> _lastAccData = Map();
  Map<String, HrData> _lastHrData = Map();
  Map<String, EcgData> _lastEcgData = Map();
  Map<String, PpgData> _lastPpgData = Map();
  Map<String, bool> connectedDevices = Map();

  Map<String, StreamSubscription> accSubscriptions = Map();
  Map<String, StreamSubscription> hrSubscriptions = Map();
  Map<String, StreamSubscription> ecgSubscriptions = Map();
  Map<String, StreamSubscription> ppgSubscriptions = Map();

  StreamSubscription searchSubscription;
  List<DeviceInfo> devices = [];
  bool searchOnlyPolar = true;

  @override
  void initState() {
    _checkPermissions();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            bottom: TabBar(
              tabs: [
                Tab(text: "Search"),
                Tab(text: "Device 1"),
                Tab(text: "Device 2"),
              ],
            ),
            title: const Text('PolarBleSdk example app'),
          ),
          body: Platform.isIOS ||
                  _locationPermissionStatus == PermissionStatus.granted
              ? TabBarView(
                  children: [
                    _buildSearchView(),
                    _buildDevice(deviceIdCtrl1),
                    _buildDevice(deviceIdCtrl2),
                  ],
                )
              : Center(child: Text('Location permission needed')),
        ),
      ),
    );
  }

  Widget _buildSearchView() {
    return Column(
      children: [
        SizedBox(
          height: 32,
        ),
        Center(
          child: RaisedButton(
            onPressed: search,
            child: Text('Search'),
          ),
        ),
        SizedBox(
          height: 16,
        ),
        SwitchListTile.adaptive(
            title: Text("Show only Polar devices"),
            value: searchOnlyPolar,
            onChanged: (value) {
              setState(() {
                searchOnlyPolar = value;
              });
            }),
        SizedBox(
          height: 32,
        ),
        Expanded(
          child: ListView.builder(
            itemCount: devices.length,
            itemBuilder: (context, index) {
              final device = devices[index];
              if (searchOnlyPolar && !device.name.contains("Polar"))
                return Container();
              return ListTile(
                onTap: () {
                  deviceIdCtrl1.text = device.deviceId;
                },
                title:
                    Text("${device.name.isNotEmpty ? device.name : 'unknown'}"),
                subtitle: Text("${device.address}"),
                trailing: Container(
                  height: 64,
                  width: 64,
                  child: Row(
                    children: [
                      Text("${device.rssi}"),
                      SizedBox(
                        width: 8,
                      ),
                      Icon(
                        Icons.circle,
                        color: device.connectable ? Colors.green : Colors.red,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDevice(TextEditingController controller) {
    String deviceId = controller.text;
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 16, 32, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text('Device ID: '),
                SizedBox(width: 8),
                Expanded(child: TextField(controller: controller)),
              ],
            ),
            Center(
              child: Row(
                children: [
                  RaisedButton(
                    onPressed: () {
                      setState(() {
                        controller.text = '7F01D527';
                      });
                    },
                    child: Text('OH1'),
                  ),
                  SizedBox(width: 16),
                  RaisedButton(
                    onPressed: () {
                      setState(() {
                        controller.text = '370C0628';
                      });
                    },
                    child: Text('H10'),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            RaisedButton(
              onPressed: !connectedDevices.containsKey(deviceId)
                  ? () => connect(deviceId)
                  : null,
              child: Text('Connect'),
            ),
            RaisedButton(
              onPressed: connectedDevices.containsKey(deviceId)
                  ? () => disconnect(deviceId)
                  : null,
              child: Text('Disconnect'),
            ),
            // RaisedButton(
            //   onPressed: autoconnect,
            //   child: Text('Autoconnect'),
            // ),
            //RaisedButton(onPressed: hrBroadcast, child: Text('HR broadcast'),),
            SizedBox(height: 16),
            RaisedButton(
              onPressed: connectedDevices.containsKey(deviceId)
                  ? () => hr(deviceId)
                  : null,
              child: Text('HR'),
            ),
            RaisedButton(
              onPressed: connectedDevices.containsKey(deviceId)
                  ? () => acc(deviceId)
                  : null,
              child: Text('ACC'),
            ),
            RaisedButton(
              onPressed: connectedDevices.containsKey(deviceId)
                  ? () => ecg(deviceId)
                  : null,
              child: Text('ECG'),
            ),
            RaisedButton(
              onPressed: connectedDevices.containsKey(deviceId)
                  ? () => ppg(deviceId)
                  : null,
              child: Text('PPG'),
            ),
            SizedBox(height: 32),
            _lastAccData.containsKey(deviceId)
                ? Text('$deviceId: ${_lastAccData[deviceId].toString()}')
                : Container(),
            _lastHrData.containsKey(deviceId)
                ? Text('$deviceId: ${_lastHrData[deviceId].toString()}')
                : Container(),
            _lastEcgData.containsKey(deviceId)
                ? Text('$deviceId: ${_lastEcgData[deviceId].toString()}')
                : Container(),
            _lastPpgData.containsKey(deviceId)
                ? Text('$deviceId: ${_lastPpgData[deviceId].toString()}')
                : Container(),
          ],
        ),
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

  void connect(String deviceId) async {
    try {
      await polarBleSdk.connect(deviceId);
      setState(() {
        connectedDevices[deviceId] = true;
      });
      print('connected to $deviceId');
    } catch (e, stack) {
      print(stack.toString());
    }
  }

  void disconnect(String deviceId) async {
    try {
      hrSubscriptions[deviceId]?.cancel();
      accSubscriptions[deviceId]?.cancel();
      ecgSubscriptions[deviceId]?.cancel();
      ppgSubscriptions[deviceId]?.cancel();
      hrSubscriptions.remove(deviceId);
      accSubscriptions.remove(deviceId);
      ecgSubscriptions.remove(deviceId);
      ppgSubscriptions.remove(deviceId);
      setState(() {
        _lastHrData.remove(deviceId);
        _lastAccData.remove(deviceId);
        _lastEcgData.remove(deviceId);
        _lastPpgData.remove(deviceId);
      });
      await polarBleSdk.disconnect(deviceId);
      print('disconnected of $deviceId');
      setState(() {
        connectedDevices.remove(deviceId);
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
    if (accSubscriptions[deviceId] != null) {
      accSubscriptions[deviceId].cancel();
      accSubscriptions[deviceId] = null;
      setState(() {
        _lastAccData.remove(deviceId);
      });
    } else {
      try {
        accSubscriptions[deviceId] = polarBleSdk.acc(deviceId).listen(
          (accData) {
            print(accData.toString());
            setState(() {
              _lastAccData[deviceId] = accData;
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
    if (hrSubscriptions[deviceId] != null) {
      hrSubscriptions[deviceId].cancel();
      hrSubscriptions.remove(deviceId);
      setState(() {
        _lastHrData.remove(deviceId);
      });
    } else {
      try {
        hrSubscriptions[deviceId] = polarBleSdk.hr(deviceId).listen(
          (hrData) {
            print(hrData.toString());
            setState(() {
              _lastHrData[deviceId] = hrData;
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
    if (ecgSubscriptions[deviceId] != null) {
      ecgSubscriptions[deviceId].cancel();
      ecgSubscriptions[deviceId] = null;
      setState(() {
        _lastEcgData.remove(deviceId);
      });
    } else {
      try {
        ecgSubscriptions[deviceId] = polarBleSdk.ecg(deviceId).listen(
          (ecgData) {
            print(ecgData.toString());
            setState(() {
              _lastEcgData[deviceId] = ecgData;
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
    if (ppgSubscriptions[deviceId] != null) {
      ppgSubscriptions[deviceId].cancel();
      ppgSubscriptions[deviceId] = null;
      setState(() {
        _lastPpgData.remove(deviceId);
      });
    } else {
      try {
        ppgSubscriptions[deviceId] = polarBleSdk.ppg(deviceId).listen(
          (ppgData) {
            print(ppgData.toString());
            setState(() {
              _lastPpgData[deviceId] = ppgData;
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

  void search() {
    if (searchSubscription != null) {
      searchSubscription.cancel();
      searchSubscription = null;
      setState(() {
        devices.clear();
      });
    } else {
      try {
        searchSubscription = polarBleSdk.searchForDevice().listen(
          (deviceInfo) {
            setState(() {
              devices.add(deviceInfo);
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
}
