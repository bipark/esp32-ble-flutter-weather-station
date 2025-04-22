# ESP32 BLE 플러터 날씨 스테이션

## 프로젝트 개요

이 프로젝트는 ESP32 마이크로컨트롤러와 OLED 디스플레이를 사용하여 만든 소형 날씨 표시 장치와, 이를 설정하기 위한 Flutter 모바일 앱으로 구성되어 있습니다. BLE(Bluetooth Low Energy) 통신을 통해 모바일 앱에서 ESP32 장치의 WiFi 설정과 OpenWeatherMap API 키 등을 구성할 수 있습니다.

## 구성 요소

### 1. ESP32 하드웨어 장치 (blue_disp)

- **주요 기능**:
  - WiFi를 통한 인터넷 연결
  - NTP 서버에서 시간 동기화
  - OpenWeatherMap API에서 날씨 데이터 수신
  - OLED 디스플레이에 시간과 날씨 정보 표시
  - BLE를 통한 모바일 앱 연결 및 설정 수신

- **사용된 하드웨어**:
  - ESP32 개발 보드
  - SSD1306 72x40 OLED 디스플레이 (I2C 연결)

- **사용된 라이브러리**:
  - U8g2lib (OLED 디스플레이 제어)
  - BLE 관련 라이브러리 (BLEDevice, BLEServer 등)
  - WiFi, HTTPClient (인터넷 연결 및 API 요청)
  - SPIFFS (설정 저장)
  - ArduinoJson (설정 데이터 처리)

### 2. 모바일 앱 (flutter_app)

- **주요 기능**:
  - BLE 장치 스캔 및 연결
  - WiFi 설정 (SSID, 비밀번호)
  - OpenWeatherMap API 키 설정
  - 날씨 데이터를 위한 도시 및 국가 코드 설정
  - 설정 저장 및 관리

- **개발 플랫폼**:
  - Flutter (iOS 및 Android 지원)

- **주요 라이브러리**:
  - flutter_blue_plus (BLE 통신)
  - shared_preferences (설정 저장)

## 설치 방법

### ESP32 펌웨어 설치

1. Arduino IDE를 설치합니다.
2. Arduino IDE에서 ESP32 보드 관리자를 추가합니다.
3. 필요한 라이브러리를 설치합니다:
   - U8g2lib
   - ArduinoJson
4. ESP32 보드를 선택하고 파티션 스키마를 "Huge APP (3MB No OTA/1MB SPIFFS)"로 설정합니다.
5. `blue_disp.ino` 스케치를 컴파일하고 ESP32 보드에 업로드합니다.

### 모바일 앱 설치

1. Flutter 개발 환경을 설정합니다.
2. 프로젝트 폴더에서 필요한 패키지를 설치합니다:
   ```
   cd flutter_app
   flutter pub get
   ```
3. 앱을 실행합니다:
   ```
   flutter run
   ```
   또는 릴리스 APK를 빌드합니다:
   ```
   flutter build apk
   ```

## 사용 방법

1. ESP32 장치에 전원을 공급합니다.
2. 모바일 앱을 실행하고 BLE 스캔을 시작합니다.
3. 목록에서 "ESP32" 장치를 선택합니다.
4. 설정 화면에서 다음 정보를 입력합니다:
   - WiFi SSID
   - WiFi 비밀번호
   - OpenWeatherMap API 키 (https://openweathermap.org에서 무료로 발급 가능)
   - 날씨 데이터를 가져올 도시 이름
   - 국가 코드 (예: KR, US 등)
5. 설정을 저장하면 ESP32 장치가 재부팅되고 입력한 설정을 사용하여 인터넷에 연결합니다.
6. 연결이 성공하면 장치 디스플레이에 현재 시간과 날씨 정보가 표시됩니다.

## 문제 해결

- ESP32 장치가 검색되지 않는 경우:
  - Bluetooth가 켜져 있는지 확인하세요.
  - 장치가 전원에 연결되어 있는지 확인하세요.
  - 장치를 재부팅해 보세요.

- WiFi에 연결되지 않는 경우:
  - 입력한 SSID와 비밀번호가 정확한지 확인하세요.
  - ESP32가 2.4GHz WiFi 네트워크만 지원함을 확인하세요.

- 날씨 데이터가 표시되지 않는 경우:
  - API 키가 올바른지 확인하세요.
  - 도시 이름과 국가 코드가 정확한지 확인하세요.

## 라이선스

이 프로젝트는 MIT 라이선스 하에 배포됩니다.