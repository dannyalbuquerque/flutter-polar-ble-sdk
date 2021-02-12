class PpgData{
    List<int> samples;
  int timestamp;

  PpgData({this.samples, this.timestamp});

  PpgData.fromJson(Map<String, dynamic> json) {
    samples = json['samples'].cast<int>();
    timestamp = json['timestamp'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['samples'] = this.samples;
    data['timestamp'] = this.timestamp;
    return data;
  }

  @override
  String toString() {
    return "samples (${samples.length}): ${samples.toString()} @$timestamp";
  }
}