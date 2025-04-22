class ConfigData {
  String ssid;
  String password;
  String apiKey;
  String city;
  String countryCode;

  ConfigData({
    required this.ssid,
    required this.password,
    required this.apiKey,
    required this.city,
    required this.countryCode,
  });

  Map<String, dynamic> toJson() {
    return {
      'ssid': ssid,
      'password': password,
      'apiKey': apiKey,
      'city': city,
      'countryCode': countryCode,
    };
  }

  factory ConfigData.fromJson(Map<String, dynamic> json) {
    return ConfigData(
      ssid: json['ssid'] ?? '',
      password: json['password'] ?? '',
      apiKey: json['apiKey'] ?? '',
      city: json['city'] ?? '',
      countryCode: json['countryCode'] ?? '',
    );
  }
}
