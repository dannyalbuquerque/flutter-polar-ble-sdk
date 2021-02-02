class HrData {
  int hr;
  List<int> rrs;
  double timestamp;

  HrData({this.hr, this.rrs, this.timestamp});

  HrData.fromJson(Map<String, dynamic> json) {
    hr = json['hr'];
    rrs = json['rrs'].cast<int>();
    timestamp = json['timestamp'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['hr'] = this.hr;
    data['rrs'] = this.rrs;
    data['timestamp'] = this.timestamp;
    return data;
  }

    String toString(){
    return "hr: $hr, rrs: $rrs";
  }
}