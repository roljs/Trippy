# ✈️ Trippy - Collaborative Travel Itinerary & Trip Planner

**Trippy** is a cross-platform itinerary management and collaborative travel planning application built with **Flutter** (optimized for Web, Desktop, and Mobile). It organizes complex multi-modal travel journeys into an intuitive, high-density visualization system featuring multi-day stay spanning, threshold arrivals and departures, dedicated travel leg views, role-based collaboration, and complete JSON data portability.

---

## 📖 Table of Contents

- [Overview](#-overview)
- [Key Features](#-key-features)
  - [1. Visual Day-by-Day Itinerary Board](#1-visual-day-by-day-itinerary-board)
  - [2. Dedicated Travel Views](#2-dedicated-travel-views)
  - [3. Multi-User Collaboration & Roles](#3-multi-user-collaboration--roles)
  - [4. Data Portability (Export & Import)](#4-data-portability-export--import)
  - [5. Pre-Seeded Dual Test Trips](#5-pre-seeded-dual-test-trips)
- [Architecture & Tech Stack](#-architecture--tech-stack)
- [Project Structure](#-project-structure)
- [Prerequisites](#-prerequisites)
- [Step-by-Step Setup Guide](#-step-by-step-setup-guide)
  - [Step 1: Clone the Repository](#step-1-clone-the-repository)
  - [Step 2: Verify Flutter Environment](#step-2-verify-flutter-environment)
  - [Step 3: Install Dependencies](#step-3-install-dependencies)
  - [Step 4: Run the Application](#step-4-run-the-application)
- [Testing & Quality Verification](#-testing--quality-verification)
- [Building for Production](#-building-for-production)
- [Troubleshooting](#-troubleshooting)

---

## 🌟 Overview

Planning multi-destination trips often results in disjointed spreadsheets, scattered confirmation emails, and confusion over overnight transit and hotel check-in/out dates.

**Trippy** solves this with an architectural, visual-first approach:
- Accommodations and overnight transit span continuously across day columns as horizontal banner cards with floating night indicators.
- First-day arrivals and final-day departures are framed by clean threshold headers aligned along a shared canvas baseline.
- Dedicated sub-views provide specialized interfaces for flights, stays, activities, and trip dashboard management.
- Co-travelers can collaborate in real-time or export/import their itineraries as offline JSON bundles.

---

## ✨ Key Features

### 1. Visual Day-by-Day Itinerary Board & Dual View Modes
- **Dual View Modes (Full View vs Compact View)**:
  - **Full View**: The signature horizontal scrolling board featuring overarching multi-day stay bridges, day columns, arrival/departure threshold headers, and horizontal scroll gestures.
  - **Compact View**: A vertical tabular summary similar to an itinerary spreadsheet. Displays 1 row per day with Date, Day of the Week, Places to Visit (comma-separated summary), Sleep At (with interactive hover hotel details card), and succinct Notes for flights and highlights. Rows are dynamically banded in pastel tints matching regional destination clusters.
- **Overarching Stay Rectangles**: Multi-night accommodations span across calendar columns with center-to-center geometric alignment.
- **Outside Floating Night Badges**: Elevated pill badges (`Night 1`, `Night 2`, etc.) float cleanly on top of the stay rectangle with interior segment dividers.
- **Continuous Night Numbering**: Sequential night numbers continue across different stays throughout the trip without resetting.
- **Arrival & Departure Threshold Headers**:
  - **Day 1 Arrival**: Visual entry header leading from outside the destination into Day 1 center axis.
  - **Final Day Departure**: Visual departure header leading out from the final day center axis into the journey home.
  - Tapping either header immediately opens the corresponding edit sheet.
- **Fluid Horizontal Navigation**:
  - Horizontal drag support with mouse, trackpad, or touch.
  - Vertical mouse-wheel-to-horizontal translation for fast desktop browsing.
  - Interactive top bar shortcuts: **Day 1**, **Prev Day (◀)**, and **Next Day (▶)**.
- **Smart Location Inference**:
  - Automatically identifies countries and cities based on latest flights and transport legs.
  - Allows full manual override and persistence of per-day destination tags (`📍 Japan`, `📍 Tokyo`).

### 2. Dedicated Travel Views
All cards across travel views adhere to a standardized card UX (tap-to-edit, three-dots menu for quick actions, delete confirmation dialogs, and floating action buttons):
- **Stays View**:
  - Chronological accommodation cards with lodging type badges (`HOTEL`, `RENTAL`, `OVERNIGHT FLIGHT`, `NIGHT TRAIN`).
  - Total nights count, check-in/out timestamps with visual duration connector, address, and copyable confirmation codes.
- **Flights View**:
  - Origin/destination airport routes with departure/arrival times and flight duration connectors.
  - Terminal, gate, seat, and booking reference badges.
  - Role status badges with mutual exclusivity:
    - `🌙 NIGHT STAY`: Surfaces flight as an overnight lodging bridge on the Itinerary Board.
    - `✈️ MAIN ARRIVAL`: Renders flight as Day 1 Arrival header.
    - `🛫 MAIN DEPARTURE`: Renders flight as Final Day Departure header.
- **Activities View**:
  - Time-slotted schedule filterable by category (`Attraction`, `Food & Dining`, `Transport`, `Entertainment`, `Flight`, `Other`).
  - Status tracking badges (`Planned`, `Booked`, `Ticketed`), cost, ticket links, notes, and checklist completion.
- **Trips Dashboard**:
  - Manage multiple trips, switch active trip context, configure default invite roles, and launch JSON imports/exports.

### 3. Multi-User Collaboration & Roles
- **6-Character Invite Codes**: Each trip generates a unique code (e.g., `TYO-8821`).
- **Role-Based Permissions**:
  - **Owner**: Full itinerary control, delete trip, transfer ownership, manage member roles.
  - **Editor**: Add, modify, and delete activities, stays, and flights.
  - **Viewer**: Read-only access across all views; action buttons and mutation dialogs are automatically hidden.

### 4. Data Portability (Export & Import)
- **JSON Export**:
  - Export single trips (`TripBundle`) or your complete database (`TripDatabaseBundle`).
  - Cross-platform file saving (direct browser blob download on Web; direct user `Downloads/` directory save on Desktop/IO).
  - Quick "Copy JSON" clipboard fallback action.
- **JSON Import**:
  - Pick local `.json` files or paste raw JSON directly from clipboard with schema validation and automatic de-duplication.

### 5. Pre-Seeded Dual Test Trips
Trippy comes pre-loaded with two realistic travel itineraries for immediate exploration:
1. **Japan Odyssey (Tokyo & Kyoto)**: 5 days, 2 hotels (Grand Hyatt Tokyo & The Celestine Kyoto Gion), ANA & JAL flights, and 11 iconic activities (Shibuya Crossing, Tsukiji Market, Senso-ji, Bullet Train, Fushimi Inari, etc.).
2. **Italian Dolce Vita (Rome, Florence & Amalfi)**: 6 days, 3 stays (Hotel Artemide, Villa Cora, Le Sirenuse), Delta & Air France flights, and 11 activities across 3 Italian regions.

---

## 🏗️ Architecture & Tech Stack

- **Framework**: [Flutter](https://flutter.dev/) (Channel `stable`, SDK `^3.13.4` / tested on Flutter `3.47+`)
- **Language**: [Dart](https://dart.dev/)
- **State Management**: [Riverpod](https://riverpod.dev/) (`flutter_riverpod: ^3.4.3`) for reactive, unidirectional state flow
- **Styling & UI**: Material Design 3 (`AppTheme`) with custom canvas geometry for stay and flight threshold layouts
- **Date & Number Formatting**: [`intl`](https://pub.dev/packages/intl) (`^0.20.3`)
- **Identifiers**: [`uuid`](https://pub.dev/packages/uuid) (`^4.6.0`)
- **Storage Layer**: Offline-first repository pattern (`TripRepository` interface with `MockTripRepository` in-memory persistence and seeding)

---

## 📁 Project Structure

```text
trippy/
├── lib/
│   ├── core/
│   │   ├── constants/        # App dimensions, column stride, and layout constants
│   │   ├── theme/            # Material 3 colors, typography, and card styles
│   │   └── utils/            # Scroll behavior, location inference, date helpers
│   ├── data/
│   │   └── repositories/     # TripRepository contract & MockTripRepository implementation
│   ├── models/               # Trip, Stay, Flight, Activity, and MemberRole data models
│   ├── services/             # Export/Import logic and cross-platform file I/O helpers
│   ├── state/                # Riverpod providers, trip controllers, and permission states
│   ├── views/
│   │   ├── activities/       # Activities view, cards, and add/edit bottom sheets
│   │   ├── common/           # Navigation scaffold, tab bar, and shared modals
│   │   ├── dashboard/        # Trips dashboard, share dialog, and import modal
│   │   ├── flights/          # Flights view, cards, and add/edit bottom sheets
│   │   ├── itinerary/        # Day-by-day board, stay spans, headers, and day columns
│   │   └── stays/            # Stays view, lodging cards, and add/edit bottom sheets
│   └── main.dart             # Application entrypoint with ProviderScope
├── test/
│   ├── models/               # Model serialization & computed property tests
│   ├── repositories/         # Repository CRUD, invite code, and location tests
│   ├── services/             # JSON export/import roundtrip tests
│   ├── views/                # Widget tests for cards, menus, and badges
│   └── widget_test.dart      # Navigation scaffold and tab switching tests
├── pubspec.yaml              # Dependencies and asset configuration
└── README.md
```

---

## ⚙️ Prerequisites

Before you begin, ensure you have the following installed on your development machine:

1. **Git**: [Download Git](https://git-scm.com/)
2. **Flutter SDK**: Version `3.13.4` or newer (stable channel recommended).
   - Follow the official [Flutter Install Guide](https://docs.flutter.dev/get-started/install) for your OS (Windows, macOS, or Linux).
3. **Platform Toolchains** (depending on where you plan to run the app):
   - **Web**: Google Chrome or Chromium browser.
   - **Windows Desktop**: Visual Studio 2022 with the *"Desktop development with C++"* workload.
   - **macOS Desktop / iOS**: Xcode and CocoaPods.
   - **Android**: Android Studio and Android SDK command-line tools.

---

## 🚀 Step-by-Step Setup Guide

### Step 1: Clone the Repository
Open your terminal and clone the repository to your local machine:
```bash
git clone https://github.com/your-username/trippy.git
cd trippy
```

### Step 2: Verify Flutter Environment
Check that Flutter is properly installed and that your target platform toolchain is ready:
```bash
flutter doctor
```
> Ensure there are green checkmarks for your desired target (e.g., Chrome for Web or Visual Studio for Windows).

### Step 3: Install Dependencies
Fetch all required Dart and Flutter packages declared in `pubspec.yaml`:
```bash
flutter pub get
```

### Step 4: Run the Application

You can launch Trippy on any supported device or target platform:

#### 🌐 Run in Chrome (Web - Recommended for quick testing):
```bash
flutter run -d chrome
```

#### 🪟 Run on Windows Desktop:
```bash
flutter run -d windows
```

#### 📱 Run on Android (Emulator or Connected Device):
```bash
flutter run -d android
```

#### 🍏 Run on macOS Desktop:
```bash
flutter run -d macos
```

#### 📋 View All Available Devices:
```bash
flutter devices
```

---

## 🧪 Testing & Quality Verification

Trippy comes with a comprehensive suite of automated unit, repository, service, and widget tests.

### Run All Unit and Widget Tests
```bash
flutter test
```

### Run Static Code Analysis
Ensure the codebase adheres to strict linting rules and static typing:
```bash
flutter analyze
```

---

## 📦 Building for Production

When you are ready to compile a production release:

### Build for Web:
```bash
flutter build web --release
```
The optimized web bundle will be generated in `build/web/`.

### Build for Windows Desktop:
```bash
flutter build windows --release
```
The standalone executable and asset bundle will be generated in `build/windows/runner/Release/`.

### Build Android APK / App Bundle:
```bash
# APK
flutter build apk --release

# App Bundle (for Google Play)
flutter build appbundle --release
```

---

## ❓ Troubleshooting

- **Target platform not recognized**: Run `flutter doctor` and verify that the target platform is enabled in Flutter (e.g. `flutter config --enable-windows-desktop` or `flutter config --enable-web`).
- **Dependencies out of sync**: If dependencies change or you encounter caching issues, run:
  ```bash
  flutter clean
  flutter pub get
  ```
- **Web CORS or browser popups**: When testing JSON export on web, ensure your browser allows file downloads from `localhost`.

---

## 📄 License

This project is licensed under the terms specified in the repository.
