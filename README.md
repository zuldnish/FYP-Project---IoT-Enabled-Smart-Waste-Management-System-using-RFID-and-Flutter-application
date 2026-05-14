# 🗑️ IoT-Enabled Smart Waste Management System
### For Reducing Waste in Residential Buildings

> A Final Year Project integrating **ESP32**, **RFID**, **ultrasonic & gas sensors**, **Firebase**, and a **Flutter mobile app** to automate waste monitoring and accountability in residential buildings.
![Prototype](Image/Prorotype.jpg)
![Physical Wiring](Image/Physical%20Wiring.jpg)

---

<!-- 📸 IMAGE SUGGESTION #1: Hero banner or system overview photo -->
<!-- Recommended: A wide photo of the full assembled smart bin prototype (ESP32 wired up with sensors visible) -->
<!-- Placement: Right below the title block, before the Table of Contents -->

---

## 📋 Table of Contents

- [Overview](#overview)
- [System Architecture](#system-architecture)
- [Hardware Components](#hardware-components)
- [Software Stack](#software-stack)
- [How It Works](#how-it-works)
- [Firebase Data Structure](#firebase-data-structure)
- [Mobile App](#mobile-app)
- [Project Structure](#project-structure)
- [Getting Started](#getting-started)
- [Future Improvements](#future-improvements)

---

## Overview

Residential buildings in Malaysia lack structured systems for organic waste tracking, leading to unregulated disposal and unsustainable habits. This project proposes a smart bin system where:

- Residents **scan their RFID card** before and after disposing waste
- An **ultrasonic sensor** measures the waste volume deposited per session
- An **MQ-135 gas sensor** monitors air quality near the bin
- All data is sent over **Wi-Fi** to **Firebase** in real time
- A **Flutter mobile app** gives building administrators a live dashboard of bin status, resident records, and warnings

---

## System Architecture

<!-- 📸 IMAGE SUGGESTION #2: System Architecture Diagram -->
<!-- Recommended: A block diagram showing the flow: RFID → ESP32 → WiFi → Firebase (RTDB + Firestore) → Flutter App -->
<!-- You can draw this in draw.io, Canva, or Lucidchart and export as a PNG -->

```
[RFID Card Scan]
      │
      ▼
[ESP32 Microcontroller] ◄── [Ultrasonic Sensor]
      │                 ◄── [MQ-135 Gas Sensor]
      │
      ▼ (HTTP over Wi-Fi)
┌─────────────────────────┐
│         Firebase         │
│  ┌──────────────────┐   │
│  │  Realtime DB     │   │  ← Waste disposal events per user
│  └──────────────────┘   │
│  ┌──────────────────┐   │
│  │    Firestore     │   │  ← Gas sensor readings
│  └──────────────────┘   │
└─────────────────────────┘
      │
      ▼
[Flutter Admin App]
```

---

## Hardware Components

| Component | Role |
|---|---|
| ESP32 | Main microcontroller — reads sensors, manages Wi-Fi, sends data to Firebase |
| PN532 RFID Module | Reads resident RFID cards (I2C mode, SDA=22, SCL=21) |
| Grove Ultrasonic Sensor | Measures bin fill level by detecting waste height (pin 32) |
| MQ-135 Gas Sensor | Monitors gas/air quality near the bin (pin 36) |
| RFID Cards/Tags | One per resident — used for identity verification before disposal |

<!-- 📸 IMAGE SUGGESTION #3: Hardware wiring/breadboard photo -->
<!-- Recommended: A labeled close-up photo of the ESP32 wired to the PN532, ultrasonic sensor, and MQ-135 on a breadboard or PCB -->
<!-- Label each component clearly if possible -->

**Pin Summary:**

```cpp
#define ULTRASONIC_PIN  32   // Grove ultrasonic sensor
#define GAS_PIN         36   // MQ-135 analog input
// PN532 RFID via I2C: SDA=22, SCL=21
```

**Fill Level Thresholds:**

| Threshold | Value | Action |
|---|---|---|
| Distance threshold | 5.0 cm | Marks bin as full |
| Fill level alert | ≥ 90% | Triggers admin notification in Firestore |

---

## Software Stack

| Layer | Technology |
|---|---|
| Firmware | Arduino C++ (ESP32) |
| Cloud Database | Firebase Realtime Database + Firestore |
| Mobile App | Flutter (Dart) |
| HTTP Communication | ArduinoJson + HTTPClient |
| Time Sync | NTP (UTC+8, Asia/Kuala Lumpur) |

---

## How It Works

### Waste Disposal Flow (Double RFID Scan)

1. **Resident scans RFID card** → ESP32 validates the UID against a whitelist
2. **Ultrasonic sensor records initial bin height** (first measurement)
3. Resident disposes waste
4. **Resident scans RFID card again** → ESP32 confirms same card
5. **Ultrasonic sensor records final bin height** (second measurement)
6. System calculates **waste thrown** = difference between first and second readings
7. Data is pushed to **Firebase Realtime Database** under the resident's UID
8. If bin fill level ≥ 90%, an **admin notification flag** is triggered in Firestore

### Gas Monitoring Flow

- Every **10 seconds**, the MQ-135 sensor takes a reading
- A **circular buffer of 10 samples** is averaged to smooth the value
- The average is mapped to a PPM range (0–2000) and pushed to **Firestore**

<!-- 📸 IMAGE SUGGESTION #4: Flowchart of the double-scan disposal process -->
<!-- Recommended: A simple flowchart: First Scan → Measure Initial → [Wait] → Second Scan → Measure Final → Calculate Waste → Push to Firebase -->
<!-- Tools: draw.io, Miro, or even hand-drawn and photographed -->

---

## Firebase Data Structure

### Realtime Database — Waste Disposal Events
```
/
└── {residentUID}/
    └── {year}/
        └── {month}/
            └── {day}/
                └── {hour}/
                    └── {minuteRange}/
                        ├── timestamp              : "2025-06-01T10:32:00Z"
                        ├── initial_height_cm      : 55.2
                        ├── final_height_cm        : 48.6
                        ├── initial_height_percent : 8
                        ├── final_height_percent   : 21
                        └── waste_thrown_cm        : 6.6
```

### Firestore — Gas Readings
```
data/
└── gas/
    ├── gas_reading   : 843      (integer, ppm)
    └── timestamp     : "2025-06-01T10:30:00Z"
```

<!-- 📸 IMAGE SUGGESTION #5: Screenshot of Firebase Realtime Database structure -->
<!-- Recommended: Export a screenshot of the actual tree from the Firebase console showing nested data under a resident UID -->

<!-- 📸 IMAGE SUGGESTION #6: Screenshot of Firestore data/gas document -->
<!-- Recommended: Screenshot of the Firestore console showing the gas_reading and timestamp fields -->

---

## Mobile App

The Flutter app is for **building administrators only** and provides:

### Dashboard
- 🟢 **Garbage Level Card** — live fill percentage from the latest RTDB entry, with color-coded progress bar (green / orange / red)
- 💨 **Gas Level Card** — latest MQ-135 reading from Firestore with color-coded status
- 🔄 Refresh button to pull the latest data on demand

<!-- 📸 IMAGE SUGGESTION #7: Screenshot of the Dashboard screen -->
<!-- Recommended: Screenshot of the Flutter app's main dashboard on a phone, showing the garbage level card, gas level card, and the two navigation buttons -->

### Resident Waste Records
Two tabs:
- **Resident List** — aggregated view per resident showing total disposal count, total waste thrown (cm), and last disposal timestamp
- **History** — chronological log of every individual disposal event across all residents

<!-- 📸 IMAGE SUGGESTION #8: Screenshot of Resident Waste Records page (both tabs) -->
<!-- Recommended: Side-by-side or two separate screenshots showing the Resident List tab and the History tab -->

### Residents with Warning
- Lists residents whose **total waste thrown exceeds 30%** of their bin's initial height
- Helps admins quickly identify overuse or improper disposal habits

<!-- 📸 IMAGE SUGGESTION #9: Screenshot of Residents with Warning page -->
<!-- Recommended: Screenshot showing a resident card flagged with total waste amount -->

### App Flow

```
Splash Screen (loading bar)
        │
        ▼
    Dashboard
    ├── Resident Waste Records
    │   ├── Resident List tab
    │   └── History tab
    ├── Residents with Warning
    └── Testing Page (raw Waste Data + Gas Readings tabs)
```

---

## Project Structure

```
├── firmware/
│   └── coding.ino                    # ESP32 Arduino firmware
│
├── flutter_app/
│   ├── main.dart                     # App entry point + splash screen logic
│   ├── splash_screen.dart            # Animated splash screen
│   ├── dashboard.dart                # Main dashboard with live sensor cards
│   ├── resident_waste_records.dart   # Resident list + history view
│   ├── resident_with_warning.dart    # Warning threshold filter page
│   ├── testing.dart                  # Raw data viewer (waste + gas tabs)
│   └── firebase_options.dart         # FlutterFire generated config
│
└── README.md
```

---

## Getting Started

### Hardware Setup
1. Wire the **PN532 RFID module** to ESP32 via I2C (SDA → GPIO 22, SCL → GPIO 21)
2. Connect the **Grove Ultrasonic Sensor** to GPIO 32
3. Connect the **MQ-135 Gas Sensor** analog output to GPIO 36
4. Flash `coding.ino` to the ESP32 using Arduino IDE

> ⚠️ Update the Wi-Fi credentials in `coding.ino` before flashing:
> ```cpp
> const char* ssid     = "YOUR_WIFI_SSID";
> const char* password = "YOUR_WIFI_PASSWORD";
> ```

### Flutter App Setup
1. Install [Flutter SDK](https://flutter.dev/docs/get-started/install)
2. Clone this repository and navigate to the `flutter_app/` folder
3. Run `flutter pub get` to install dependencies
4. Configure Firebase using the [FlutterFire CLI](https://firebase.flutter.dev/docs/cli):
   ```bash
   flutterfire configure
   ```
5. Replace `firebase_options.dart` with your own generated file
6. Run the app:
   ```bash
   flutter run
   ```

### Required Flutter Dependencies
```yaml
dependencies:
  firebase_core:
  firebase_database:
  cloud_firestore:
  intl:
```

---

## Future Improvements

- **Replace ultrasonic sensor with a load cell** for more accurate weight-based measurement
- **Add an LCD display on the bin** to show real-time weight feedback to residents at the point of disposal
- **Offline data caching** with automatic sync when Wi-Fi reconnects
- **ML-based predictive fill level alerts** before the bin reaches capacity
- **Expand resident registration** — RFID UIDs are currently hardcoded; future versions should support dynamic registration via the app

---

## 👨‍💻 Author

**Dzul Danish Ar-Rahman Bin Khairulaswari**  
Bachelor of Information Technology (Hons) — Internet of Things  
Universiti Kuala Lumpur MIIT

Supervisor: Assoc. Prof. Ts. Dr. Haidawati Binti Mohamad Nasir

---

*Final Year Project — 2024 / 2025*