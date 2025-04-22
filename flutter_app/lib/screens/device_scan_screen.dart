import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../services/ble_service.dart';
import '../services/storage_service.dart';
import '../models/config_model.dart';
import 'config_screen.dart';
import 'saved_config_screen.dart';

class DeviceScanScreen extends StatefulWidget {
  const DeviceScanScreen({super.key});

  @override
  _DeviceScanScreenState createState() => _DeviceScanScreenState();
}

class _DeviceScanScreenState extends State<DeviceScanScreen> {
  final BleService _bleService = BleService();
  bool _isScanning = false;
  String _statusMessage = '';
  bool _hasSavedConfig = false;

  @override
  void initState() {
    super.initState();
    _checkBluetoothState();
    _checkSavedConfig();
  }

  Future<void> _checkSavedConfig() async {
    ConfigData? config = await StorageService.loadConfigData();
    setState(() {
      _hasSavedConfig = config != null;
    });
  }

  Future<void> _checkBluetoothState() async {
    try {
      bool isOn = await FlutterBluePlus.isOn;
      if (!isOn) {
        setState(() {
          _statusMessage = 'Bluetooth is turned off. Please turn it on.';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error checking Bluetooth state: $e';
      });
    }
  }

  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _statusMessage = 'Scanning for ESP32 devices...';
    });

    try {
      await _bleService.startScan();

      // Automatically stop scan after 10 seconds
      Future.delayed(const Duration(seconds: 10), () {
        if (_isScanning) {
          _stopScan();
        }
      });
    } catch (e) {
      setState(() {
        _isScanning = false;
        _statusMessage = 'Error scanning: $e';
      });
    }
  }

  Future<void> _stopScan() async {
    if (!_isScanning) return;

    try {
      await _bleService.stopScan();
    } catch (e) {
      // Handle errors
    } finally {
      setState(() {
        _isScanning = false;
        _statusMessage = 'Scan completed';
      });
    }
  }

  void _connectToDevice(BluetoothDevice device) async {
    setState(() {
      _statusMessage = 'Connecting to ${device.platformName}...';
    });

    try {
      await _bleService.connectToDevice(device);

      if (!mounted) return;

      // Navigate to config screen after successful connection
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              ConfigScreen(device: device, bleService: _bleService),
        ),
      ).then((_) {
        // Disconnect when coming back to this screen
        _bleService.disconnectFromDevice(device);
        _checkSavedConfig();
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Connection failed: $e';
      });
    }
  }

  void _viewSavedConfig() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SavedConfigScreen(),
      ),
    ).then((_) {
      _checkSavedConfig();
    });
  }

  @override
  void dispose() {
    _bleService.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ESP32 Bluetooth Setup'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_hasSavedConfig)
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: _viewSavedConfig,
              tooltip: 'View Saved Configuration',
            ),
        ],
      ),
      body: Column(
        children: [
          if (_hasSavedConfig)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                child: InkWell(
                  onTap: _viewSavedConfig,
                  child: const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Icon(Icons.save),
                        SizedBox(width: 12),
                        Text('View Saved Configuration',
                            style: TextStyle(fontSize: 16)),
                        Spacer(),
                        Icon(Icons.arrow_forward_ios, size: 14),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              _statusMessage,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<ScanResult>>(
              stream: FlutterBluePlus.scanResults,
              initialData: const [],
              builder: (c, snapshot) {
                return ListView.builder(
                  itemCount: _bleService.discoveredDevices.length,
                  itemBuilder: (context, index) {
                    BluetoothDevice device =
                        _bleService.discoveredDevices[index];
                    return ListTile(
                      title: Text(device.platformName.isEmpty
                          ? 'Unknown device'
                          : device.platformName),
                      subtitle: Text(device.remoteId.toString()),
                      leading: const Icon(Icons.bluetooth),
                      onTap: () => _connectToDevice(device),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isScanning ? _stopScan : _startScan,
        tooltip: _isScanning ? 'Stop scan' : 'Start scan',
        child: Icon(_isScanning ? Icons.stop : Icons.search),
      ),
    );
  }
}
