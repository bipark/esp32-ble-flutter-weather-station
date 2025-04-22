import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/config_model.dart';

class BleService {
  // ESP32 BLE UUIDs
  static const String ESP32_SERVICE_UUID =
      "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  static const String ESP32_CHAR_UUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8";
  static const String ESP32_CONFIG_UUID =
      "beb5483e-36e1-4688-b7f5-ea07361b26a9";

  StreamSubscription<List<ScanResult>>? _scanSubscription;
  List<BluetoothDevice> discoveredDevices = [];

  // Start scanning for BLE devices
  Future<void> startScan() async {
    // Clear previous results
    discoveredDevices.clear();

    // Check if Bluetooth is on
    if (!(await FlutterBluePlus.isOn)) {
      throw Exception("Bluetooth is turned off");
    }

    // Start scanning
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

    // Listen to scan results
    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult result in results) {
        if (!discoveredDevices.contains(result.device) &&
            result.device.platformName.isNotEmpty &&
            result.device.platformName.contains("ESP32")) {
          discoveredDevices.add(result.device);
        }
      }
    });
  }

  // Stop scanning
  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    await _scanSubscription?.cancel();
    _scanSubscription = null;
  }

  // Connect to a device
  Future<BluetoothDevice> connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect();
      return device;
    } catch (e) {
      print('Error connecting to device: $e');
      throw Exception('Failed to connect to device');
    }
  }

  // Disconnect from device
  Future<void> disconnectFromDevice(BluetoothDevice device) async {
    try {
      await device.disconnect();
    } catch (e) {
      print('Error disconnecting from device: $e');
    }
  }

  // Send config data to ESP32
  Future<bool> sendConfigData(
      BluetoothDevice device, ConfigData configData) async {
    try {
      // Discover services
      List<BluetoothService> services = await device.discoverServices();

      // Find our service
      BluetoothService? espService;
      for (BluetoothService service in services) {
        if (service.uuid.toString() == ESP32_SERVICE_UUID) {
          espService = service;
          break;
        }
      }

      if (espService == null) {
        throw Exception('ESP32 service not found');
      }

      // Find config characteristic
      BluetoothCharacteristic? configChar;
      for (BluetoothCharacteristic characteristic
          in espService.characteristics) {
        if (characteristic.uuid.toString() == ESP32_CONFIG_UUID) {
          configChar = characteristic;
          break;
        }
      }

      if (configChar == null) {
        throw Exception('Config characteristic not found');
      }

      // Convert config data to JSON and then to bytes
      String jsonData = jsonEncode(configData.toJson());
      List<int> bytes = utf8.encode(jsonData);

      // Write data to characteristic
      await configChar.write(bytes);
      return true;
    } catch (e) {
      print('Error sending config data: $e');
      return false;
    }
  }
}
