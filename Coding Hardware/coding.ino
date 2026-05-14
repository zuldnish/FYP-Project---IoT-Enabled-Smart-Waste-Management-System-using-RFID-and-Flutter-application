#include <Wire.h>
#include <Adafruit_PN532.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <time.h>

// -------------------------- Pin Definitions -------------------------- //

// RFID sensor pins (I2C mode) - Using I2C constructor
Adafruit_PN532 nfc(-1, -1);  // I2C mode constructor

// Grove Ultrasonic sensor pin (single pin for both trigger and echo)
#define ULTRASONIC_PIN 32

// Gas sensor pins
#define GAS_PIN 36

// -------------------------- Configuration -------------------------- //
// WiFi credentials
const char* ssid = "Nibiru";
const char* password = "cataclysm";

// Timezone and NTP
const char* ntpServer1 = "asia.pool.ntp.org";
const char* ntpServer2 = "time.google.com";
const char* ntpServer3 = "ntp.aliyun.com";
const long gmtOffset_sec = 8 * 3600;  // For Asia/Kuala_Lumpur (UTC+8)
const int daylightOffset_sec = 0;

// Firebase Project ID
const char* FIREBASE_PROJECT_ID = "fypbin-8a1ae";

// RTDB base
const char* rtdbBaseUrl = "https://fypbin-8a1ae-default-rtdb.asia-southeast1.firebasedatabase.app";

// Firestore UIDs
String uid_user1 = "Amru";  // uid 1
String uid_user2 = "Dalia";  // uid 2
String uid_user3 = "Muuna";  // uid 3
String uid_admin = "jCHE4mKf9FXTeSxea7m5UhBlojh1";  // uid admin

// Unused variables - can be removed
float adcGas_user1 = -9999.0;
float adcGas_user2 = -9999.0;
float adcGas_user3 = -9999.0;

// -------------------------- Constants -------------------------- //

#define bufferSize 10

// Ultrasonic constants
#define distanceThreshold 5.0  // threshold in cm for trigger notification
#define fillLevelThreshold 90  // threshold in % for trigger notification (changed from 10 to 90)

// RFID constants
#define secondScanTimeout 5000UL
#define scanCooldown 2000UL

const char* validUIDs[] = {
  "538F4716",  // UID biru
  "36C54B00",  // UID putih
  "D364AF0E"   // UID biru2
};
const int numValidUIDs = sizeof(validUIDs) / sizeof(validUIDs[0]);

// Gas constants
#define minGasADC 100      
#define maxGasADC 3000     
#define minGasMapped 0     
#define maxGasMapped 2000  
#define millisInterval 10000UL

// -------------------------- Variables -------------------------- //

// Distance storage
float firstDistance = 0;
float secondDistance = 0;
float distanceDifferent = 0;
int firstFillLevel = 0;
int secondFillLevel = 0;
int fillLevelDifferent = 0;
bool triggerNotification = false;

// Timing
unsigned long lastScanTime = 0;
unsigned long firstScanTime = 0;
unsigned long secondScanTime = 0;
unsigned long previousMillis = 0;

// UID tracking
uint8_t uid[7];
uint8_t uidLength;
uint8_t firstUID[7];
uint8_t firstUIDLength = 0;
bool awaitingSecondScan = false;

// Gas variables
int adcGas = 0;
int bufferGas[bufferSize];
int bufferIndex = 0, bufferCount = 0;
int avgGas = 0;
int ppmGas = 0;

// WiFi reconnection variables
unsigned long lastWiFiCheck = 0;
const unsigned long wifiCheckInterval = 30000; // Check WiFi every 30 seconds

// -------------------------- Util Functions -------------------------- //

void connectToWiFi() {
  Serial.print("Connecting to WiFi");
  WiFi.begin(ssid, password);
  
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 30) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nConnected to WiFi");
    Serial.print("IP address: ");
    Serial.println(WiFi.localIP());
  } else {
    Serial.println("\nFailed to connect to WiFi");
  }
}

void checkWiFiConnection() {
  unsigned long currentMillis = millis();
  if (currentMillis - lastWiFiCheck >= wifiCheckInterval) {
    lastWiFiCheck = currentMillis;
    
    if (WiFi.status() != WL_CONNECTED) {
      Serial.println("WiFi disconnected. Attempting to reconnect...");
      connectToWiFi();
    }
  }
}

void setupTime() {
  configTime(gmtOffset_sec, daylightOffset_sec, ntpServer1, ntpServer2, ntpServer3);
  Serial.println("Waiting for time sync...");
  struct tm timeinfo;
  int attempts = 0;
  while (!getLocalTime(&timeinfo) && attempts < 10) {
    delay(1000);
    Serial.print(".");
    attempts++;
  }
  if (attempts < 10) {
    Serial.println("\nTime synchronized.");
  } else {
    Serial.println("\nTime sync failed, continuing anyway...");
  }
}

String getTimeISO8601() {
  struct tm timeinfo;
  if (!getLocalTime(&timeinfo)) {
    Serial.println("Failed to get time for ISO8601");
    return "1970-01-01T00:00:00Z"; // Fallback time
  }
  char buffer[25];
  strftime(buffer, sizeof(buffer), "%Y-%m-%dT%H:%M:%SZ", &timeinfo);
  return String(buffer);
}

String getFirestoreUID(String scannedUID) {
  if (scannedUID == "538F4716") return uid_user1; //biru
  if (scannedUID == "36C54B00") return uid_user2; //putih
  if (scannedUID == "D364AF0E") return uid_user3; //biru cakar
  return "unknown"; // Default fallback instead of "unknown"
}

void resetVariableScan() {
  firstDistance = 0;
  secondDistance = 0;
  distanceDifferent = 0;
  firstFillLevel = 0;
  secondFillLevel = 0;
  fillLevelDifferent = 0;

  awaitingSecondScan = false;
  firstUIDLength = 0;

  memset(firstUID, 0, sizeof(firstUID));
  // Don't reset previousMillis here as it's used for gas readings
}

int calculateMeanInt(int* arr, int len) {
  if (len == 0) return 0; // Prevent division by zero
  long sum = 0; // Use long to prevent overflow
  for (int i = 0; i < len; i++) sum += arr[i];
  return sum / len;
}

// -------------------------- Firebase Functions -------------------------- //

bool sendHttpRequest(const String& url, const String& payload, const String& method = "PATCH") {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi not connected, skipping HTTP request");
    return false;
  }

  HTTPClient http;
  http.begin(url);
  http.addHeader("Content-Type", "application/json");
  http.setTimeout(10000); // 10 second timeout
  
  int httpCode;
  if (method == "PATCH") {
    httpCode = http.PATCH(payload);
  } else if (method == "PUT") {
    httpCode = http.PUT(payload);
  } else {
    httpCode = http.POST(payload);
  }
  
  String response = http.getString();
  http.end();
  
  bool success = (httpCode >= 200 && httpCode < 300);
  if (!success) {
    Serial.printf("HTTP request failed with code %d: %s\n", httpCode, response.c_str());
  }
  
  return success;
}

void pushToGasSubCollection(int ppmGas) {
  StaticJsonDocument<200> doc;
  doc["fields"]["gas_reading"]["integerValue"] = ppmGas;
  doc["fields"]["timestamp"]["stringValue"] = getTimeISO8601();

  String payload;
  serializeJson(doc, payload);

  String url = "https://firestore.googleapis.com/v1/projects/"
               + String(FIREBASE_PROJECT_ID)
               + "/databases/(default)/documents/data/gas?updateMask.fieldPaths=gas_reading&updateMask.fieldPaths=timestamp";

  bool success = sendHttpRequest(url, payload);
  
  Serial.println("\n// ================ PUSH TO GAS SUBCOLLECTION ================ //");
  Serial.printf("Gas data sent to /data/gas/gas → %s\n", success ? "SUCCESS" : "FAILED");
  Serial.println("// ================ PUSH TO GAS SUBCOLLECTION ================ //\n");
}

void pushToAdminSubCollection(bool state) {
  StaticJsonDocument<100> doc;
  doc["fields"]["notification_trigger"]["booleanValue"] = state;

  String payload;
  serializeJson(doc, payload);

  String url = "https://firestore.googleapis.com/v1/projects/"
               + String(FIREBASE_PROJECT_ID)
               + "/databases/(default)/documents/data/admin?updateMask.fieldPaths=notification_trigger";

  bool success = sendHttpRequest(url, payload);

  Serial.println("\n// ================ PUSH TO ADMIN SUBCOLLECTION ================ //");
  Serial.printf("Admin flag set to %s → %s\n", state ? "true" : "false", success ? "SUCCESS" : "FAILED");
  Serial.println("// ================ PUSH TO ADMIN SUBCOLLECTION ================ //\n");
}

void pushToRTDB(String uid) {
  // Get current time
  struct tm timeinfo;
  if (!getLocalTime(&timeinfo)) {
    Serial.println("Failed to get time for RTDB push");
    return;
  }

  // Format date: YYYY-MM-DD
  char dateStr[11];
  snprintf(dateStr, sizeof(dateStr), "%04d-%02d-%02d", 
           timeinfo.tm_year + 1900, timeinfo.tm_mon + 1, timeinfo.tm_mday);

  // Month name
  const char* months[] = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", 
                          "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" };
  String monthName = months[timeinfo.tm_mon];

  // Day and hour
  char dayStr[3], hourStr[3];
  snprintf(dayStr, sizeof(dayStr), "%02d", timeinfo.tm_mday);
  snprintf(hourStr, sizeof(hourStr), "%02d", timeinfo.tm_hour);

  // Minute-second
  char minSecStr[6];
  snprintf(minSecStr, sizeof(minSecStr), "%02d-%02d", timeinfo.tm_min, timeinfo.tm_sec);

  // Build final RTDB path
  String path = "/" + uid + "/" + String(dateStr) + "/" + monthName + "/" + 
                String(dayStr) + "/" + String(hourStr) + "/" + String(minSecStr) + ".json";
  String url = String(rtdbBaseUrl) + path;

  // Prepare JSON data
  StaticJsonDocument<400> doc;
  doc["rfid_first_scan"] = awaitingSecondScan;
  doc["rfid_second_scan"] = !awaitingSecondScan;
  doc["final_height_cm"] = String(secondDistance, 2);
  doc["final_height_percent"] = secondFillLevel;
  doc["initial_height_cm"] = String(firstDistance, 2);
  doc["initial_height_percent"] = firstFillLevel;
  doc["waste_thrown_cm"] = String(distanceDifferent, 2);
  doc["waste_thrown_percent"] = fillLevelDifferent;
  doc["timestamp"] = getTimeISO8601();

  String jsonPayload;
  serializeJson(doc, jsonPayload);

  bool success = sendHttpRequest(url, jsonPayload, "PUT");

  Serial.println("\n// =================== PUSH TO RTDB =================== //");
  Serial.printf("Pushed data to RTDB [%s] → %s\n", path.c_str(), success ? "SUCCESS" : "FAILED");
  Serial.println("// =================== PUSH TO RTDB =================== //\n");
}

// -------------------------- Grove Ultrasonic Functions -------------------------- //

float readGroveUltrasonicCM() {
  // Set pin as output for trigger
  pinMode(ULTRASONIC_PIN, OUTPUT);
  
  // Send trigger pulse
  digitalWrite(ULTRASONIC_PIN, LOW);
  delayMicroseconds(2);
  digitalWrite(ULTRASONIC_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(ULTRASONIC_PIN, LOW);
  
  // Set pin as input for echo
  pinMode(ULTRASONIC_PIN, INPUT);
  
  // Read echo pulse duration with timeout
  long duration = pulseIn(ULTRASONIC_PIN, HIGH, 30000);  // 30ms timeout
  
  if (duration == 0) {
    Serial.println("Grove ultrasonic sensor timeout");
    return 60.0;  // Return max distance on timeout
  }
  
  // Calculate distance in cm
  float distance = duration * 0.034 / 2;  // Speed of sound = 340 m/s = 0.034 cm/µs
  
  // Clamp distance to reasonable range (Grove sensor typically 2-350cm)
  if (distance > 60.0 || distance < 2.0) {
    distance = 60.0;
  }

  return distance;
}

int mapDistanceToFillLevel(float distance) {
  if (distance >= 60.0) return 0;   // Empty
  if (distance <= 5.0) return 100;  // Full

  float level = (60.0 - distance) / (60.0 - 5.0) * 100.0;
  return constrain((int)level, 0, 100);
}

// -------------------------- RFID Functions -------------------------- //

bool isValidUID(uint8_t* uid, uint8_t uidLength) {
  if (uidLength == 0 || uidLength > 7) return false;
  
  char formattedUID[30] = "";
  for (uint8_t i = 0; i < uidLength; i++) {
    char byteStr[4];
    sprintf(byteStr, "%02X", uid[i]);
    strcat(formattedUID, byteStr);
  }

  for (int i = 0; i < numValidUIDs; i++) {
    if (strcmp(formattedUID, validUIDs[i]) == 0) return true;
  }

  return false;
}

void printUID(const uint8_t* uid, uint8_t len) {
  for (uint8_t i = 0; i < len; i++) {
    Serial.printf("%02X", uid[i]);
  }
}

String getUIDString(const uint8_t* uid, uint8_t len) {
  if (len == 0 || len > 7) return "";
  
  char formattedUID[30] = "";
  for (uint8_t i = 0; i < len; i++) {
    char byteStr[4];
    sprintf(byteStr, "%02X", uid[i]);
    strcat(formattedUID, byteStr);
  }
  return String(formattedUID);
}

bool compareUIDs(const uint8_t* uid1, uint8_t len1, const uint8_t* uid2, uint8_t len2) {
  if (len1 != len2 || len1 == 0) return false;
  return memcmp(uid1, uid2, len1) == 0;
}

// -------------------------- Setup Functions -------------------------- //

void setup() {
  Serial.begin(115200);
  delay(1000);
  
  Serial.println("=== Smart Bin System Starting ===");

  // Initialize pins
  pinMode(ULTRASONIC_PIN, OUTPUT);  // Will be switched between INPUT/OUTPUT as needed
  pinMode(GAS_PIN, INPUT);

  // Initialize I2C explicitly
  Serial.println("Initializing I2C for PN532...");
  Wire.begin(22, 21);     // SDA=22, SCL=21 for ESP32
  Wire.setClock(100000);  // 100kHz for stability
  Serial.println("I2C initialized - SDA=21, SCL=22, Clock=100kHz");

  // Initialize PN532
  Serial.println("Initializing PN532 in I2C mode...");
  nfc.begin();
  
  uint32_t version = nfc.getFirmwareVersion();
  if (!version) {
    Serial.println("ERROR: PN532 not responding to commands");
    Serial.println("Try checking:");
    Serial.println("1. Jumper settings for I2C mode");
    Serial.println("2. Power supply voltage");
    Serial.println("3. Pull-up resistors on SDA/SCL");
    Serial.println("4. I2C address (should be 0x24)");
    Serial.println("Continuing without PN532...");
  } else {
    Serial.print("Found PN532 chip! Version: 0x");
    Serial.println(version, HEX);
    
    // Configure for RFID reading
    nfc.SAMConfig();
    Serial.println("PN532 ready for card detection!");
  }

  // Test Grove ultrasonic sensor
  Serial.println("Testing Grove ultrasonic sensor...");
  float testDistance = readGroveUltrasonicCM();
  Serial.printf("Grove ultrasonic test reading: %.2f cm\n", testDistance);

  // Connect to WiFi
  connectToWiFi();
  
  // Setup time only if WiFi connected
  if (WiFi.status() == WL_CONNECTED) {
    setupTime();
    // Initialize Firestore notification
    pushToAdminSubCollection(false);
  }

  Serial.println("=== Setup Complete ===\n");
}

// -------------------------- Loop Functions -------------------------- //

void loop() {
  unsigned long currentMillis = millis();

  // Check WiFi connection periodically
  checkWiFiConnection();

  // Read gas sensor only when not awaiting second scan
  if (!awaitingSecondScan) {
    if (currentMillis - previousMillis >= millisInterval) {
      previousMillis = currentMillis;

      // Read actual gas sensor (uncomment next line and comment the random line)
      // adcGas = analogRead(GAS_PIN);
      adcGas = random(100, 3001);  // Simulate MQ-135 for testing
      
      // Update circular buffer
      bufferGas[bufferIndex] = adcGas;
      bufferIndex = (bufferIndex + 1) % bufferSize;
      if (bufferCount < bufferSize) bufferCount++;
      
      avgGas = calculateMeanInt(bufferGas, bufferCount);
      ppmGas = map(avgGas, minGasADC, maxGasADC, minGasMapped, maxGasMapped);
      ppmGas = constrain(ppmGas, 0, maxGasMapped);

      pushToGasSubCollection(ppmGas);

      // Print gas readings
      Serial.println("\n// ==================== GAS READING ==================== //");
      Serial.printf("MQ-135 ADC Value      : %d ADC\n", adcGas);
      Serial.printf("MQ-135 Average Value  : %d ADC\n", avgGas);
      Serial.printf("Estimated PPM         : %d ppm\n", ppmGas);
      Serial.println("// ==================== GAS READING ==================== //\n");
    }
  }

  // Check for second scan timeout
  if (awaitingSecondScan && currentMillis - firstScanTime >= secondScanTimeout) {
    Serial.println("\n// ================ SECOND SCAN TIMEOUT ================ //");
    Serial.println("Timeout waiting for second scan - resetting");
    Serial.println("// ================ SECOND SCAN TIMEOUT ================ //\n");
    resetVariableScan();
  }

  // RFID card detection
  if (nfc.readPassiveTargetID(PN532_MIFARE_ISO14443A, uid, &uidLength)) {
    
    // Cooldown between scans
    if (currentMillis - lastScanTime < scanCooldown) {
      return;
    }
    
    lastScanTime = currentMillis;

    // First scan logic
    if (!awaitingSecondScan) {
      String scannedUIDStr = getUIDString(uid, uidLength);
      Serial.printf("\nScanned UID: %s\n", scannedUIDStr.c_str());

      if (!isValidUID(uid, uidLength)) {
        Serial.println("Unauthorized UID - access denied\n");
        return;
      }

      // Store first scan data
      memcpy(firstUID, uid, uidLength);
      firstUIDLength = uidLength;
      awaitingSecondScan = true;
      firstScanTime = currentMillis;

      Serial.print("First scan UID: ");
      printUID(uid, uidLength);
      
      // Read initial distance using Grove sensor
      firstDistance = readGroveUltrasonicCM();
      firstFillLevel = mapDistanceToFillLevel(firstDistance);
      Serial.printf("\nFirst distance: %.2f cm\n", firstDistance);
      Serial.printf("First fill level: %d%%\n", firstFillLevel);

      // Reset admin notification flag
      if (triggerNotification) {
        pushToAdminSubCollection(false);
        triggerNotification = false;
        Serial.println("Admin notification flag reset");
      }

    } else {
      // Second scan logic
      if (compareUIDs(firstUID, firstUIDLength, uid, uidLength)) {
        secondScanTime = currentMillis;

        Serial.print("\nSecond scan UID: ");
        printUID(uid, uidLength);

        // Read final distance using Grove sensor
        secondDistance = readGroveUltrasonicCM();
        secondFillLevel = mapDistanceToFillLevel(secondDistance);
        Serial.printf("\nSecond distance: %.2f cm\n", secondDistance);
        Serial.printf("Second fill level: %d%%\n", secondFillLevel);

        // Calculate differences
        distanceDifferent = fabs(secondDistance - firstDistance);
        fillLevelDifferent = abs(secondFillLevel - firstFillLevel);
        Serial.printf("Distance difference: %.2f cm\n", distanceDifferent);
        Serial.printf("Fill level difference: %d%%\n", fillLevelDifferent);

        // Check if bin is getting full
        if (secondFillLevel >= fillLevelThreshold) {
          triggerNotification = true;
          Serial.println("*** BIN FULL ALERT ***");
          pushToAdminSubCollection(true);
        }

        // Push data to database
        String uidStr = getFirestoreUID(getUIDString(uid, uidLength));
        pushToRTDB(uidStr);

        // Reset for next cycle
        resetVariableScan();

      } else {
        Serial.println("\nDifferent UID detected - waiting for matching card");
      }
    }
  }
  
  // Small delay to prevent overwhelming the system
  delay(100);
}