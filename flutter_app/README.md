# ESP32 BLE Configuration App

A Flutter application for iOS that allows you to configure an ESP32 device over BLE (Bluetooth Low Energy). This app sends WiFi credentials and OpenWeatherMap API settings to an ESP32 device.

## Features

- Scan for nearby ESP32 BLE devices
- Connect to an ESP32 device
- Configure WiFi settings (SSID and password)
- Configure OpenWeatherMap API settings (API key, city, and country code)
- Send all configuration to ESP32 in a single operation
- Save configuration locally for reuse
- View and edit saved configuration without connecting to a device

## Required Configuration

The following configuration data is sent to the ESP32:

```json
{
  "ssid": "your_wifi_name",
  "password": "your_wifi_password",
  "apiKey": "your_openweathermap_api_key",
  "city": "Seoul",
  "countryCode": "KR"
}
```

## How to Use

### Setting up a new ESP32 device

1. Enable Bluetooth on your iOS device
2. Launch the app
3. Tap the search icon to scan for ESP32 devices
4. Select your ESP32 device from the list
5. Enter your WiFi credentials and OpenWeatherMap API information (or use saved configuration)
6. Tap "Send Configuration to ESP32" to transmit the settings

### Managing saved configuration

1. From the main screen, tap the "View Saved Configuration" card or the settings icon
2. View and edit your saved configuration
3. Tap "Save Configuration" to store it locally
4. Use the trash icon to clear the saved configuration

## Requirements

- iOS device with Bluetooth 4.0+ capability
- ESP32 device with the corresponding BLE service implementation
- The ESP32 should have the following UUIDs configured:
  - Service UUID: `4fafc201-1fb5-459e-8fcc-c5c9c331914b`
  - Configuration Characteristic UUID: `beb5483e-36e1-4688-b7f5-ea07361b26a9`

## Development

This app was built with Flutter and uses the following packages:

- flutter_blue_plus: For BLE communication
- shared_preferences: For local storage of configuration
