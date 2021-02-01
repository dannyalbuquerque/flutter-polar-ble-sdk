class AccelerometerData {
  int x;
  int y;
  int z;
  int timestamp;

  AccelerometerData({this.x, this.y, this.z, this.timestamp});

  AccelerometerData.fromJson(Map<String, dynamic> json) {
    x = json['x'];
    y = json['y'];
    z = json['z'];
    timestamp = json['timestamp'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['x'] = this.x;
    data['y'] = this.y;
    data['z'] = this.z;
    data['timestamp'] = this.timestamp;
    return data;
  }

  String toString(){
    return "x: $x, y: $y, z: $z";
  }

}