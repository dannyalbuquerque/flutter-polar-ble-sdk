class PolarDeviceInfo {
  String deviceId;
  String address;
  int rssi;
  String name;
  bool connectable;

  PolarDeviceInfo(
      {this.deviceId, this.address, this.rssi, this.name, this.connectable});

  PolarDeviceInfo.fromJson(Map<String, dynamic> json) {
    deviceId = json['deviceId'];
    address = json['address'];
    rssi = json['rssi'];
    name = json['name'];
    connectable = json['connectable'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['deviceId'] = this.deviceId;
    data['address'] = this.address;
    data['rssi'] = this.rssi;
    data['name'] = this.name;
    data['connectable'] = this.connectable;
    return data;
  }
}
