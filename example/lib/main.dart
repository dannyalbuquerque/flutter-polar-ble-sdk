import 'dart:io';

import 'package:flutter/material.dart';
import 'dart:async';

import 'package:polar_ble_sdk/polar_ble_sdk.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:polar_ble_sdk_example/device_view.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  PolarBleSdk polarBleSdk = PolarBleSdk();
  PermissionStatus _locationPermissionStatus = PermissionStatus.unknown;

  StreamSubscription searchSubscription;
  List<PolarDeviceInfo> devices = [];
  List<PolarDeviceInfo> selectedDevices = [];
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
        length: selectedDevices.length + 1,
        child: Scaffold(
          appBar: AppBar(
            bottom: TabBar(
              tabs: [
                Tab(text: "Search"),
                for (var device in selectedDevices) Tab(text: device.name)
              ],
            ),
            title: const Text('PolarBleSdk example app'),
          ),
          body: Platform.isIOS ||
                  _locationPermissionStatus == PermissionStatus.granted
              ? TabBarView(
                  children: [
                    _buildSearchView(),
                    for (var device in selectedDevices)
                      DeviceView(device: device, polarBleSdk: polarBleSdk)
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
                  setState(() {
                    if (selectedDevices.contains(device)) {
                      selectedDevices.remove(device);
                    } else {
                      selectedDevices.add(device);
                    }
                  });
                },
                selected: selectedDevices.contains(device),
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
