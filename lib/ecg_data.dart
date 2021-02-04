class EcgData {
  List<int> samples;
  int timestamp;

  EcgData({this.samples, this.timestamp});

  EcgData.fromJson(Map<String, dynamic> json) {
    samples = json['samples'].cast<int>();
    timestamp = json['timestamp'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['samples'] = this.samples;
    data['timestamp'] = this.timestamp;
    return data;
  }
}