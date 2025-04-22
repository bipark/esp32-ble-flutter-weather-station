import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/config_model.dart';

class StorageService {
  static const String configKey = 'esp32_config_data';

  // Save config data to SharedPreferences
  static Future<bool> saveConfigData(ConfigData configData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String jsonData = jsonEncode(configData.toJson());
      return await prefs.setString(configKey, jsonData);
    } catch (e) {
      print('Error saving config data: $e');
      return false;
    }
  }

  // Load config data from SharedPreferences
  static Future<ConfigData?> loadConfigData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? jsonData = prefs.getString(configKey);

      if (jsonData != null && jsonData.isNotEmpty) {
        Map<String, dynamic> data = jsonDecode(jsonData);
        return ConfigData.fromJson(data);
      }
      return null;
    } catch (e) {
      print('Error loading config data: $e');
      return null;
    }
  }

  // Clear saved config data
  static Future<bool> clearConfigData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(configKey);
    } catch (e) {
      print('Error clearing config data: $e');
      return false;
    }
  }
}
