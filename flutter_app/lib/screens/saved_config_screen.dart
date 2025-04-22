import 'package:flutter/material.dart';
import '../models/config_model.dart';
import '../services/storage_service.dart';

class SavedConfigScreen extends StatefulWidget {
  const SavedConfigScreen({super.key});

  @override
  _SavedConfigScreenState createState() => _SavedConfigScreenState();
}

class _SavedConfigScreenState extends State<SavedConfigScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _ssidController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _countryCodeController = TextEditingController();

  bool _isLoading = false;
  bool _isLoadingData = true;
  String _statusMessage = '';
  bool _obscurePassword = true;

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
      } else {
        // If no saved config is found, show a message
        setState(() {
          _statusMessage = 'No saved configuration found.';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error loading configuration: $e';
      });
    } finally {
      setState(() {
        _isLoadingData = false;
      });
    }
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Saving configuration...';
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
      bool success = await StorageService.saveConfigData(configData);

      setState(() {
        _isLoading = false;
        _statusMessage = success
            ? 'Configuration saved successfully!'
            : 'Failed to save configuration.';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error: $e';
      });
    }
  }

  Future<void> _clearConfig() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Configuration'),
        content: const Text(
            'Are you sure you want to clear all saved configuration data?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await StorageService.clearConfigData();

              if (!mounted) return;

              setState(() {
                _ssidController.clear();
                _passwordController.clear();
                _apiKeyController.clear();
                _cityController.text = 'Seoul';
                _countryCodeController.text = 'KR';
                _statusMessage = 'Configuration cleared.';
              });
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Saved Configuration'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Configuration'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _clearConfig,
            tooltip: 'Clear Configuration',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Information card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Saved Configuration',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'This configuration will be used when connecting to an ESP32 device.',
                        style: TextStyle(fontSize: 14),
                      ),
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
                      color: _statusMessage.contains('success') ||
                              _statusMessage.contains('cleared')
                          ? Colors.green
                          : (_statusMessage.contains('Error') ||
                                  _statusMessage.contains('Failed')
                              ? Colors.red
                              : Colors.blue),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

              ElevatedButton(
                onPressed: _isLoading ? null : _saveConfig,
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
                          Text('Saving...'),
                        ],
                      )
                    : const Text('Save Configuration'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
