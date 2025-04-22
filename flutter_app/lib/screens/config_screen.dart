import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:convert';
import '../services/ble_service.dart';
import '../models/config_model.dart';
import '../services/storage_service.dart';

class ConfigScreen extends StatefulWidget {
  final BluetoothDevice device;
  final BleService bleService;

  const ConfigScreen({
    super.key,
    required this.device,
    required this.bleService,
  });

  @override
  _ConfigScreenState createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _ssidController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _cityController =
      TextEditingController(text: 'Seoul');
  final TextEditingController _countryCodeController =
      TextEditingController(text: 'KR');

  bool _isLoading = false;
  String _statusMessage = '';
  bool _obscurePassword = true;
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _loadSavedConfig();
  }

  Future<void> _loadSavedConfig() async {
    setState(() {
      _isLoadingData = true;
    });

    try {
      ConfigData? savedConfig = await StorageService.loadConfigData();

      if (savedConfig != null) {
        setState(() {
          _ssidController.text = savedConfig.ssid;
          _passwordController.text = savedConfig.password;
          _apiKeyController.text = savedConfig.apiKey;
          _cityController.text = savedConfig.city;
          _countryCodeController.text = savedConfig.countryCode;
        });
      }
    } catch (e) {
      print('Error loading saved configuration: $e');
    } finally {
      setState(() {
        _isLoadingData = false;
      });
    }
  }

  @override
  void dispose() {
    _ssidController.dispose();
    _passwordController.dispose();
    _apiKeyController.dispose();
    _cityController.dispose();
    _countryCodeController.dispose();
    super.dispose();
  }

  Future<void> _sendConfig() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Sending configuration to device...';
    });

    try {
      // Create config data object
      ConfigData configData = ConfigData(
        ssid: _ssidController.text.trim(),
        password: _passwordController.text.trim(),
        apiKey: _apiKeyController.text.trim(),
        city: _cityController.text.trim(),
        countryCode: _countryCodeController.text.trim(),
      );

      // Save config data locally
      await StorageService.saveConfigData(configData);

      // Send data via BLE
      bool success =
          await widget.bleService.sendConfigData(widget.device, configData);

      setState(() {
        _isLoading = false;
        _statusMessage = success
            ? 'Configuration sent successfully!'
            : 'Failed to send configuration. Please try again.';
      });

      if (success) {
        // Wait for a moment to show success message
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('ESP32 Configuration'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('ESP32 Configuration'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Device info
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Connected to: ${widget.device.platformName}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text('ID: ${widget.device.remoteId}'),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // WiFi Settings
              const Text(
                'WiFi Settings',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              TextFormField(
                controller: _ssidController,
                decoration: const InputDecoration(
                  labelText: 'WiFi Name (SSID)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.wifi),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter WiFi SSID';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'WiFi Password',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter WiFi password';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // OpenWeatherMap API Settings
              const Text(
                'OpenWeatherMap API Settings',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              TextFormField(
                controller: _apiKeyController,
                decoration: const InputDecoration(
                  labelText: 'API Key',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.vpn_key),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter OpenWeatherMap API key';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _cityController,
                decoration: const InputDecoration(
                  labelText: 'City',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_city),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter city name';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _countryCodeController,
                decoration: const InputDecoration(
                  labelText: 'Country Code',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.flag),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter country code';
                  }
                  if (value.length != 2) {
                    return 'Country code should be 2 characters (eg. KR, US)';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              if (_statusMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    _statusMessage,
                    style: TextStyle(
                      color: _statusMessage.contains('success')
                          ? Colors.green
                          : (_statusMessage.contains('Error')
                              ? Colors.red
                              : Colors.blue),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

              ElevatedButton(
                onPressed: _isLoading ? null : _sendConfig,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                ),
                child: _isLoading
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.0),
                          ),
                          SizedBox(width: 12),
                          Text('Sending...'),
                        ],
                      )
                    : const Text('Send Configuration to ESP32'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
