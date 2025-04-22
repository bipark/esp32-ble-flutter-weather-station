#include <Wire.h>
#include <U8g2lib.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <time.h>
#include <SPIFFS.h>
#include <ArduinoJson.h>

// 파티션 스키마 변경 (컴파일 전 Arduino IDE에서 변경 필요)
// Tools > Partition Scheme > Huge APP (3MB No OTA/1MB SPIFFS)

// I2C 핀 설정
#define I2C_SDA 5
#define I2C_SCL 6

// 버퍼 크기 설정
#define MAX_MESSAGE_LENGTH 256  // 크기 증가 (더 긴 설정 수신을 위해)

// BLE 서비스 및 특성 UUID
#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"
#define CONFIG_UUID         "beb5483e-36e1-4688-b7f5-ea07361b26a9"  // 설정용 특성 UUID

// 설정 파일 경로
#define CONFIG_FILE "/config.json"

// WiFi 설정
String ssid = "";
String password = "";

// OpenWeatherMap API 설정
String apiKey = "";
String city = "Yongin";
String countryCode = "KR";

// 설정이 완료되었는지 확인하는 플래그
bool configLoaded = false;
bool configChanged = false;
bool shouldReboot = false;

// NTP 서버 설정
const char* ntpServer1 = "pool.ntp.org";
const char* ntpServer2 = "time.nist.gov";
const char* ntpServer3 = "time.google.com";
const long  gmtOffset_sec = 32400;  // 한국 시간대 (UTC+9 = 9시간 * 60분 * 60초)
const int   daylightOffset_sec = 0;  // 서머타임 없음

// OLED 디스플레이 설정
U8G2_SSD1306_72X40_ER_F_SW_I2C u8g2(U8G2_R0, /* clock=*/ I2C_SCL, /* data=*/ I2C_SDA, /* reset=*/ U8X8_PIN_NONE);

char message[MAX_MESSAGE_LENGTH] = "Wait...";
bool newData = false;
bool deviceConnected = false;
bool oldDeviceConnected = false;
bool timeInitialized = false;

// 날씨 데이터 구조체
struct WeatherData {
  float temperature;
  int humidity;
  long lastUpdate;
} weatherData;

// 시간 및 날짜 표시용 버퍼
char timeString[20] = "MM-DD HH:MM:SS";

// 내부 시간 관리용 변수
unsigned long timeLastSyncMillis = 0;  // 마지막으로 NTP 시간 동기화한 시점의 millis() 값
struct tm timeinfo_saved;             // 마지막으로 동기화한 시간 정보 저장

// 함수 프로토타입 선언
void saveConfig();
bool loadConfig();
bool syncTimeNTP();
void getWeatherData();
void updateTimeString();
void updateDisplay();
void updateStatusDisplay();

// BLE 콜백 클래스 간소화
class ServerCallbacks: public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) {
    deviceConnected = true;
    strcpy(message, "Connected");
    newData = true;
    Serial.println("Device connected");
  }
  void onDisconnect(BLEServer* pServer) {
    deviceConnected = false;
    strcpy(message, "Disconnected");
    newData = true;
    Serial.println("Device disconnected");
  }
};

// 일반 메시지 수신 콜백
class CharCallbacks: public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *pCharacteristic) {
    String value = pCharacteristic->getValue();
    if (value.length() > 0) {
      memset(message, 0, MAX_MESSAGE_LENGTH);
      int len = value.length() < MAX_MESSAGE_LENGTH-1 ? value.length() : MAX_MESSAGE_LENGTH-1;
      memcpy(message, value.c_str(), len);
      message[len] = '\0';
      Serial.print("Received: ");
      Serial.println(message);
      newData = true;
    }
  }
};

// 설정 수신용 콜백
class ConfigCallbacks: public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *pCharacteristic) {
    String value = pCharacteristic->getValue();
    if (value.length() > 0) {
      Serial.print("Received config: ");
      Serial.println(value);
      
      // JSON 형식으로 설정 파싱
      StaticJsonDocument<512> doc;
      DeserializationError error = deserializeJson(doc, value.c_str());
      
      if (error) {
        Serial.print("deserializeJson() failed: ");
        Serial.println(error.c_str());
        return;
      }
      
      // 설정 값 추출
      if (doc.containsKey("ssid")) {
        ssid = doc["ssid"].as<String>();
        Serial.print("New SSID: ");
        Serial.println(ssid);
      }
      
      if (doc.containsKey("password")) {
        password = doc["password"].as<String>();
        Serial.println("New WiFi password received");
      }
      
      if (doc.containsKey("apiKey")) {
        apiKey = doc["apiKey"].as<String>();
        Serial.print("New API Key: ");
        Serial.println(apiKey);
      }
      
      if (doc.containsKey("city")) {
        city = doc["city"].as<String>();
        Serial.print("New City: ");
        Serial.println(city);
      }
      
      if (doc.containsKey("countryCode")) {
        countryCode = doc["countryCode"].as<String>();
        Serial.print("New Country Code: ");
        Serial.println(countryCode);
      }
      
      // 설정을 파일에 저장
      saveConfig();
      
      // 재부팅 필요함을 표시
      strcpy(message, "Config updated. Rebooting...");
      newData = true;
      shouldReboot = true;
    }
  }
};

BLEServer *pServer = NULL;
BLECharacteristic *pCharacteristic = NULL;
BLECharacteristic *pConfigCharacteristic = NULL;

// 설정을 SPIFFS에 저장
void saveConfig() {
  Serial.println("Saving configuration...");
  
  // JSON 문서 생성
  StaticJsonDocument<512> doc;
  doc["ssid"] = ssid;
  doc["password"] = password;
  doc["apiKey"] = apiKey;
  doc["city"] = city;
  doc["countryCode"] = countryCode;
  
  // 파일 열기 및 저장
  File configFile = SPIFFS.open(CONFIG_FILE, "w");
  if (!configFile) {
    Serial.println("Failed to open config file for writing");
    return;
  }
  
  // JSON 직렬화 및 파일에 쓰기
  if (serializeJson(doc, configFile) == 0) {
    Serial.println("Failed to write to file");
  } else {
    Serial.println("Config saved successfully");
    configChanged = true;
  }
  
  configFile.close();
}

// 설정을 SPIFFS에서 로드
bool loadConfig() {
  Serial.println("Loading configuration...");
  
  if (!SPIFFS.exists(CONFIG_FILE)) {
    Serial.println("Config file not found");
    return false;
  }
  
  // 파일 열기 및 읽기
  File configFile = SPIFFS.open(CONFIG_FILE, "r");
  if (!configFile) {
    Serial.println("Failed to open config file");
    return false;
  }
  
  // 파일 크기 확인
  size_t size = configFile.size();
  if (size > 1024) {
    Serial.println("Config file size is too large");
    configFile.close();
    return false;
  }
  
  // JSON 문서 생성 및 파싱
  StaticJsonDocument<512> doc;
  DeserializationError error = deserializeJson(doc, configFile);
  configFile.close();
  
  if (error) {
    Serial.print("deserializeJson() failed: ");
    Serial.println(error.c_str());
    return false;
  }
  
  // 설정 값 추출
  ssid = doc["ssid"].as<String>();
  password = doc["password"].as<String>();
  apiKey = doc["apiKey"].as<String>();
  city = doc["city"].as<String>();
  countryCode = doc["countryCode"].as<String>();
  
  Serial.println("Config loaded successfully");
  Serial.print("SSID: ");
  Serial.println(ssid);
  Serial.print("City: ");
  Serial.println(city);
  Serial.print("Country Code: ");
  Serial.println(countryCode);
  
  // 설정이 유효한지 확인
  if (ssid.length() == 0 || password.length() == 0 || apiKey.length() == 0) {
    Serial.println("Configuration is incomplete");
    return false;
  }
  
  return true;
}

// 현재 시간을 내부 타이머 기반으로 계산하여 문자열로 반환
void updateTimeString() {
  if (!timeInitialized) {
    // 시간이 초기화되지 않았으면 메시지 표시
    strcpy(timeString, "Waiting NTP...");
    return;
  }
  
  // 내부 타이머 기반으로 시간 계산
  unsigned long currentMillis = millis();
  unsigned long elapsedSeconds = (currentMillis - timeLastSyncMillis) / 1000;
  
  // millis() 오버플로우 처리
  if (currentMillis < timeLastSyncMillis) {
    // millis()가 오버플로우되면 새로 NTP 시간 동기화
    Serial.println("millis() overflow detected, resyncing NTP time");
    syncTimeNTP();
    return;
  }
  
  // 저장된 시간 정보에 경과 시간 더하기
  time_t time_now = mktime(&timeinfo_saved) + elapsedSeconds;
  struct tm *timeinfo_current = localtime(&time_now);
  
  // MM-DD HH:MM:SS 형식으로 시간 문자열 생성 (초 추가)
  sprintf(timeString, "%02d-%02d %02d:%02d:%02d", 
          timeinfo_current->tm_mon + 1, timeinfo_current->tm_mday, 
          timeinfo_current->tm_hour, timeinfo_current->tm_min, timeinfo_current->tm_sec);  
}

// NTP 서버와 시간 동기화
bool syncTimeNTP() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("Cannot sync NTP: WiFi not connected");
    return false;
  }
  
  // 여러 NTP 서버를 시도하여 안정성 향상
  configTime(gmtOffset_sec, daylightOffset_sec, ntpServer1, ntpServer2, ntpServer3);
  Serial.println("Waiting for NTP time sync...");
  
  unsigned long startAttempt = millis();
  const int timeoutMs = 10000; // 10초 타임아웃
  
  while (!getLocalTime(&timeinfo_saved) && millis() - startAttempt < timeoutMs) {
    Serial.print(".");
    delay(500);
  }
  
  if (millis() - startAttempt >= timeoutMs) {
    Serial.println("\nFailed to obtain time after timeout");
    return false;
  }
  
  // 시간 동기화 성공 - 현재 millis() 값 저장
  timeLastSyncMillis = millis();
  timeInitialized = true;
  
  // 시간 문자열 업데이트
  updateTimeString();
  
  Serial.println("\nTime synchronized with NTP server");
  
  // 하루에 한 번 정도 NTP 재동기화를 위한 타이머 설정
  // 이건 선택적으로 구현 가능
  
  return true;
}

// ArduinoJson 없이 간단한 방식으로 온도와 습도 파싱
void getWeatherData() {
  if (WiFi.status() != WL_CONNECTED || apiKey.length() == 0) {
    Serial.println("Cannot get weather: WiFi not connected or API key missing");
    return;
  }
  
  HTTPClient http;
  String url = "https://api.openweathermap.org/data/2.5/weather?q=";
  url += city;
  url += ",";
  url += countryCode;
  url += "&appid=";
  url += apiKey;
  url += "&units=metric";
  
  Serial.println("Requesting URL: " + url);
  
  http.begin(url.c_str());
  int httpCode = http.GET();
  
  Serial.print("HTTP Response code: ");
  Serial.println(httpCode);
  
  if (httpCode > 0) {
    String payload = http.getString();
    Serial.println("Response payload: " + payload);
    
    // 간단한 문자열 파싱 (ArduinoJson 대체)
    int tempIndex = payload.indexOf("\"temp\":");
    int humIndex = payload.indexOf("\"humidity\":");
    
    if (tempIndex > 0 && humIndex > 0) {
      // 온도 파싱
      tempIndex += 7; // "temp": 다음 위치
      int tempEndIndex = payload.indexOf(",", tempIndex);
      String tempStr = payload.substring(tempIndex, tempEndIndex);
      weatherData.temperature = tempStr.toFloat();
      
      // 습도 파싱
      humIndex += 11; // "humidity": 다음 위치
      int humEndIndex = payload.indexOf(",", humIndex);
      if (humEndIndex < 0) humEndIndex = payload.indexOf("}", humIndex);
      String humStr = payload.substring(humIndex, humEndIndex);
      weatherData.humidity = humStr.toInt();
      
      weatherData.lastUpdate = millis();
      
      Serial.printf("Parsed data - Temperature: %.1f°C, Humidity: %d%%\n", 
                   weatherData.temperature, 
                   weatherData.humidity);
    } else {
      Serial.println("Error: Temperature or humidity data not found in response");
    }
  } else {
    Serial.print("Error code: ");
    Serial.println(httpCode);
  }
  http.end();
}

// BLE 초기화 함수
void setupBLE() {
  BLEDevice::init("ESP32_OLED");
  Serial.print("MAC Address: ");
  Serial.println(BLEDevice::getAddress().toString().c_str());
  
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new ServerCallbacks());
  
  BLEService *pService = pServer->createService(SERVICE_UUID);
  
  // 일반 메시지용 특성
  pCharacteristic = pService->createCharacteristic(
                    CHARACTERISTIC_UUID,
                    BLECharacteristic::PROPERTY_READ |
                    BLECharacteristic::PROPERTY_WRITE |
                    BLECharacteristic::PROPERTY_NOTIFY
                  );
  pCharacteristic->setCallbacks(new CharCallbacks());
  pCharacteristic->addDescriptor(new BLE2902());
  
  // 설정용 특성
  pConfigCharacteristic = pService->createCharacteristic(
                         CONFIG_UUID,
                         BLECharacteristic::PROPERTY_READ |
                         BLECharacteristic::PROPERTY_WRITE
                       );
  pConfigCharacteristic->setCallbacks(new ConfigCallbacks());
  
  pService->start();
  
  BLEAdvertising *pAdvertising = pServer->getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setMinPreferred(0x06);
  
  BLEAdvertisementData advData;
  advData.setName("ESP32_OLED");
  advData.setCompleteServices(BLEUUID(SERVICE_UUID));
  pAdvertising->setAdvertisementData(advData);
  
  pAdvertising->start();
  Serial.println("BLE advertising started - Device name: ESP32_OLED");
}

void showMessage(String message) {
  u8g2.clearBuffer();
  u8g2.setCursor(0, 10);
  u8g2.print(message);
  u8g2.sendBuffer();
}

// WiFi 연결 함수
bool connectWiFi() {
  if (ssid.length() == 0 || password.length() == 0) {
    Serial.println("WiFi credentials not set");
    return false;
  }
  
  showMessage("WiFi...");

  Serial.print("Connecting to WiFi");
  WiFi.begin(ssid.c_str(), password.c_str());
  
  // 30초 타임아웃으로 연결 시도
  uint8_t wifiRetries = 0;
  while (WiFi.status() != WL_CONNECTED && wifiRetries < 60) {
    delay(500);
    Serial.print(".");
    wifiRetries++;
  }
  Serial.println();
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("WiFi connected");
    Serial.print("IP address: ");
    Serial.println(WiFi.localIP());
    return true;
  } else {
    Serial.println("WiFi connection failed");
    return false;
  }
}

void initDisplay() {
  u8g2.begin();
  delay(100);  // 초기화 후 약간의 지연 추가
  
  u8g2.clearBuffer();
  u8g2.setFont(u8g2_font_6x10_tf);
  u8g2.setCursor(0, 10);
  u8g2.print("Init...");
  u8g2.sendBuffer();
  
  delay(500);  // 메시지를 잠시 표시
}

void setup() {
  Serial.begin(115200);
  Serial.println("Starting BLE OLED Display with Weather");
  
  initDisplay();
  
  // SPIFFS 초기화
  if (!SPIFFS.begin(true)) {
    Serial.println("SPIFFS initialization failed!");
    strcpy(message, "SPIFFS init failed");
  } else {
    Serial.println("SPIFFS initialized");
    
    // 설정 로드
    configLoaded = loadConfig();
    
    if (configLoaded) {
      strcpy(message, "Config loaded");
    } else {
      strcpy(message, "No config. Use BLE");
    }
  }
  
  // 설정이 있으면 WiFi 연결 시도
  bool wifiConnected = false;
  if (configLoaded) {
    wifiConnected = connectWiFi();
    
    if (wifiConnected) {
      // 시간 서버 초기화 (최초 한번만 NTP 서버와 동기화)
      Serial.println("Initializing NTP time...");
      showMessage("Get Time...");
      syncTimeNTP();
      
      // 날씨 데이터 초기화
      weatherData.temperature = 0.0;
      weatherData.humidity = 0;
      weatherData.lastUpdate = 0;
      
      // 날씨 데이터 가져오기
      Serial.println("Getting initial weather data...");
      getWeatherData();
    }
  }
  
  // BLE 설정
  Serial.println("Initializing BLE...");
  showMessage("Init BLE...");
  setupBLE();
  
  // 초기 화면 표시
  updateDisplay();
  Serial.println("Setup completed");
}

void loop() {
  // 새 데이터가 있으면 디스플레이 업데이트
  if (newData) {
    updateDisplay();
    newData = false;
  }
  
  // 재부팅 요청이 있으면 처리
  if (shouldReboot) {
    delay(2000);  // 메시지 표시를 위한 지연
    ESP.restart();
  }
  
  // 연결 관리
  if (deviceConnected != oldDeviceConnected) {
    if (!deviceConnected) {
      Serial.println("Device disconnected - restarting advertising");
      delay(500);
      pServer->startAdvertising();
      Serial.println("Advertising restarted");
    }
    oldDeviceConnected = deviceConnected;
  }
  
  // 연결 상태에 따라 주기적으로 상태 업데이트
  static unsigned long lastStatusUpdate = 0;
  if (millis() - lastStatusUpdate > 3000) {
    updateStatusDisplay();
    lastStatusUpdate = millis();
  }
  
  // 10분(600000ms)마다 날씨 업데이트
  static unsigned long lastWeatherUpdate = 0;
  if (millis() - lastWeatherUpdate >= 600000 && WiFi.status() == WL_CONNECTED) {
    Serial.println("Updating weather data...");
    getWeatherData();
    newData = true;
    lastWeatherUpdate = millis();
  }
  
  // 1초마다 시간 업데이트 (내부 타이머 기반)
  static unsigned long lastTimeDisplayUpdate = 0;
  if (millis() - lastTimeDisplayUpdate >= 1000) {
    updateTimeString();
    newData = true;
    lastTimeDisplayUpdate = millis();
  }
  
  // 매일 한 번 NTP 서버와 시간 재동기화 (선택 사항)
  static unsigned long lastTimeSyncUpdate = 0;
  if (millis() - lastTimeSyncUpdate >= 86400000 && WiFi.status() == WL_CONNECTED) { // 24시간마다
    Serial.println("Daily NTP resync...");
    syncTimeNTP();
    lastTimeSyncUpdate = millis();
  }
  
  delay(10);
}

void updateDisplay() {
  
  // 날짜와 시간 표시 (첫번째 줄)
  u8g2.clearBuffer();

  u8g2.setFont(u8g2_font_5x8_tf);  // 더 작은 폰트로 변경하여 모든 정보가 표시되도록 함
  u8g2.setCursor(0, 8);
  u8g2.print(timeString);
    
  // 온도 및 습도 표시 - 중앙 정렬
  u8g2.setFont(u8g2_font_6x10_tf);  // 기존 폰트 크기로 복원
  
  char tempStr[16];
  sprintf(tempStr, "%.1fC", weatherData.temperature);
  
  // 텍스트 폭 계산 후 중앙에 위치시키기
  int tempWidth = u8g2.getStrWidth(tempStr);
  u8g2.setCursor((70 - tempWidth) / 2, 25);  
  u8g2.print(tempStr);
  
  char humStr[16];
  sprintf(humStr, "%d%%", weatherData.humidity);
  
  // 텍스트 폭 계산 후 중앙에 위치시키기
  int humWidth = u8g2.getStrWidth(humStr);
  u8g2.setCursor((70 - humWidth) / 2, 38);  
  u8g2.print(humStr);
  
  u8g2.sendBuffer();
}

void updateStatusDisplay() {
  if (!deviceConnected) {
    static int dots = 0;
    strcpy(message, "Wait");
    for (int i = 0; i < dots; i++) {
      strcat(message, ".");
    }
    dots = (dots + 1) % 4;
    newData = true;
  }
}