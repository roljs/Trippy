# Trippy - Implementation Plan & Status

This document tracks the technical implementation phases, architectural decisions, and verification status of the **Trippy** project, maintained in sync with [`SPEC.md`](./SPEC.md) and the codebase.

**Current Overall Status**: **Active / Phase 1–9 Complete**  
**Static Analysis**: `0 issues` (`flutter analyze`)  
**Automated Tests**: `37/37 passed` (`flutter test`)

---

## 1. Phase Breakdown & Execution Status

### Phase 1: Environment & Project Foundation [COMPLETE]
- [x] Configure Flutter SDK and dependencies in [`pubspec.yaml`](./pubspec.yaml) (`flutter_riverpod`, `intl`, `uuid`, `cupertino_icons`).
- [x] Establish design system tokens in [`lib/core/theme/app_colors.dart`](./lib/core/theme/app_colors.dart) and [`lib/core/theme/app_theme.dart`](./lib/core/theme/app_theme.dart).
- [x] Implement core date utilities in [`lib/core/utils/date_formatters.dart`](./lib/core/utils/date_formatters.dart).
- [x] Implement domain models with JSON serialization:
  - [`Trip`](./lib/models/trip.dart)
  - [`Stay`](./lib/models/stay.dart)
  - [`Flight`](./lib/models/flight.dart)
  - [`Activity`](./lib/models/activity.dart)
  - [`MemberRole`](./lib/models/member_role.dart)
- [x] Create test suite for core models in [`test/models/trip_model_test.dart`](./test/models/trip_model_test.dart).

---

### Phase 2: State Management & Repository Layer [COMPLETE]
- [x] Define repository interface in [`lib/data/repositories/trip_repository.dart`](./lib/data/repositories/trip_repository.dart) for trips, stays, activities, and flights.
- [x] Implement [`MockTripRepository`](./lib/data/repositories/mock_trip_repository.dart) with broadcast stream controllers, safe upsert logic, and seed data.
- [x] Seed **two complete test trips** with full itineraries:
  1. **Trip 1: Japan Odyssey (Tokyo & Kyoto)**: 5 days, 3 stays, 2 flights, 11 activities.
  2. **Trip 2: Italian Dolce Vita (Rome, Florence & Amalfi)**: 6 days, 3 stays, 2 flights, 11 activities.
- [x] Setup Riverpod providers in [`lib/state/trip_providers.dart`](./lib/state/trip_providers.dart):
  - `userTripsProvider`, `activeTripProvider`, `activeTripRoleProvider`, `canEditActiveTripProvider`
  - `activeTripStaysProvider`, `sortedActiveTripStaysProvider` (chronological ordering)
  - `activeTripActivitiesProvider`, `activitiesByDayProvider` (chronological sorting by day)
  - `activeTripFlightsProvider`
- [x] Add repository unit tests in [`test/repositories/mock_trip_repository_test.dart`](./test/repositories/mock_trip_repository_test.dart).

---

### Phase 3: Custom Day-by-Day Itinerary Visualization [COMPLETE]
- [x] Implement [`LogisticsView`](./lib/views/logistics/logistics_view.dart) layout with horizontal canvas and "ITINERARY" header title.
- [x] **Center-to-Center Stay Spanning**:
  - Horizontal stay rectangles start at the center of the vertical column of the first day (`columnCenter(startIndex) = startIndex * stride + 155dp`) and end at the center of the vertical column of the checkout day (`startIndex * stride + nights * stride + 155dp`).
  - Allows two different stays to be partially on top of a single day (e.g. Day 3 checkout from Grand Hyatt Tokyo in the morning, and check-in to The Celestine Kyoto Gion in the afternoon).
  - Dynamic multi-track lane allocation prevents occlusion if stays overlap in time.
- [x] **Stay Header Details**:
  - Added explicit duration in nights (`X night` or `X nights`) to the details row of [`StayHeaderBridgeWidget`](./lib/views/logistics/widgets/stay_header_bridge_widget.dart) alongside Check-in, Check-out, and Confirmation Code.
  - Reduced horizontal margin to `3dp` for sleek visual capsule separation at column centers.
- [x] **Day Header Locations**:
  - Added location tags and `Edit` button to [`DayColumnWidget`](./lib/views/logistics/widgets/day_column_widget.dart).
  - Implemented [`LocationInferenceHelper`](./lib/core/utils/location_inference_helper.dart) to infer default country based on the target country of the most recent flight or transport event.
  - Implemented [`ManageDayLocationsDialog`](./lib/views/logistics/widgets/manage_day_locations_dialog.dart) allowing users to customize, add, delete, or reset locations per day.
  - Persisted custom locations into `Trip.dayLocations` with JSON serialization.
- [x] **Alternating Color Palettes**:
  - Implemented 6 modern gradient colorways in [`StayHeaderBridgeWidget`](./lib/views/logistics/widgets/stay_header_bridge_widget.dart).
  - Alternate colorways across consecutive stays, with signature sky-blue gradient for overnight flights.
  - Render empty transition slots for days without accommodation.
- [x] **Enhanced Horizontal Scrolling**:
  - Wrapped canvas in draggable [`Scrollbar`](./lib/views/logistics/logistics_view.dart).
  - Configured `AppHorizontalScrollBehavior` supporting mouse, trackpad, and touch drag.
  - Added vertical mouse wheel to horizontal translation via `Listener(onPointerSignal: ...)`.
  - Added header navigation buttons: `Day 1`, `Prev Day (◀)`, `Next Day (▶)`.

---

### Phase 4: Dedicated Travel Views [COMPLETE]
- [x] **Stays View** ([`lib/views/stays/stays_view.dart`](./lib/views/stays/stays_view.dart)):
  - Dedicated tab displaying all stay reservations in chronological order.
  - Lodging type badges, duration pills (`X NIGHTS`), check-in/out times with visual connector.
  - Address display, overnight flight callout, and monospace confirmation code with copy-to-clipboard button.
- [x] **Flights View** ([`lib/views/flights/flights_view.dart`](./lib/views/flights/flights_view.dart)):
  - Chronological flight legs with origin/destination badges, flight duration graphics, and terminal/gate/seat pills.
- [x] **Activities View** ([`lib/views/attractions/attractions_view.dart`](./lib/views/attractions/attractions_view.dart)):
  - Renamed from "Attractions" tab to "Activities" with search and category filtering.
  - Consistent terminology: references "activities" across lists, chips, empty states, and creation sheets.
- [x] **Trips Dashboard** ([`lib/views/dashboard/trip_dashboard_screen.dart`](./lib/views/dashboard/trip_dashboard_screen.dart)):
  - Multi-trip list with destination, date range, duration, role pills, and active status indicators.
- [x] **Navigation Scaffold** ([`lib/views/common/app_nav_scaffold.dart`](./lib/views/common/app_nav_scaffold.dart)):
  - Integrated 5 tabs with `BottomNavigationBarType.fixed` (Itinerary, Flights, Stays, Activities, Trips).

---

### Phase 5: CRUD Sheets, Collaboration & JSON Export/Import [COMPLETE]
- [x] Build lightweight data entry bottom-sheets:
  - [`AddActivitySheet`](./lib/views/common/add_activity_sheet.dart): Fixed category selection overflow/cutoff bug using responsive `Wrap` for category chips (ensuring "Other" is always visible and selectable across all screen widths), and unified naming to "Activity".
  - [`AddStaySheet`](./lib/views/common/add_stay_sheet.dart)
  - [`AddFlightSheet`](./lib/views/common/add_flight_sheet.dart)
- [x] Implement collaborative trip invite flow:
  - Unique 6-character invite code generation ([`CodeGenerator`](./lib/core/utils/code_generator.dart)).
  - Configurable default invite role (**Editor** vs. **Viewer**).
  - Join trip dialog and share modal.
- [x] **Trip JSON Export & Import**:
  - Defined [`TripBundle`](./lib/models/trip_bundle.dart) and [`TripDatabaseBundle`](./lib/models/trip_bundle.dart).
  - Implemented [`TripExportService`](./lib/services/export_import/trip_export_service.dart).
  - Implemented cross-platform file download helper ([`file_download_helper.dart`](./lib/services/export_import/file_download_helper.dart)) using web blob anchors on web and file write on IO.
  - Implemented cross-platform file upload helper ([`file_upload_helper.dart`](./lib/services/export_import/file_upload_helper.dart)).
  - Single-trip export button on each trip card.
  - Database options popup menu with "Export All Trips" and "Import Trips from JSON".
  - Import dialog with local `.json` file picking, text paste, and clipboard support.

---

### Phase 6: Automated Testing & Verification [COMPLETE]
- [x] **Model Unit Tests** ([`test/models/trip_model_test.dart`](./test/models/trip_model_test.dart)):
  - Validates date math, days list, role permissions, and serialization.
- [x] **Repository Unit Tests** ([`test/repositories/mock_trip_repository_test.dart`](./test/repositories/mock_trip_repository_test.dart)):
  - Validates seeding of both test trips (*Japan Odyssey* and *Italian Dolce Vita*).
  - Validates invite code joining and role assignment.
- [x] **Export & Import Tests** ([`test/services/export_import_test.dart`](./test/services/export_import_test.dart)):
  - Validates single trip `TripBundle` serialization roundtrip.
  - Validates full database `TripDatabaseBundle` export.
  - Validates JSON import persistence and error handling.
- [x] **Widget Tests** ([`test/widget_test.dart`](./test/widget_test.dart)):
  - Validates full navigation scaffold across all 5 tabs (Itinerary, Flights, Stays, Activities, Trips).
  - Validates multi-day continuous stay rectangle rendering and stay duration details.
  - Validates Arrival Header on Day 1, Departure Header on the final day, and multi-night Stay segmentation.

---

### Phase 7: Symmetrical Arrival/Departure Headers & Night Segmentation [COMPLETE]
- [x] **Day 1 Arrival Header**:
  - Starts at $50\%$ column width to the left of Day 1's left edge ($X = 10.0\text{ dp}$), ends at Day 1 vertical center ($X = 300.0\text{ dp}$).
  - Full $290.0\text{ dp}$ width banner rendering arrival flight or transport method.
  - Sourced from Day 1 arrival flights, transport activities, or placeholder with interactive tap to edit.
- [x] **Last Day Departure Header**:
  - Starts at vertical center of final day ($X_{\text{center}}(\text{lastDay})$), ends at $50\%$ column width past the final day's right edge.
  - Full $290.0\text{ dp}$ width banner rendering departure flight or transport method.
  - Sourced from final day departure flights, transport activities, or placeholder.
- [x] **Stay Header Multi-Night Segmentation**:
  - Segmented internally into $N$ equal sections with vertical divider marks (`1.5dp` width, `white.withValues(alpha: 0.35)`) at each intermediate day center.
  - Sub-element labels (`Night 1`, `Night 2`, etc.) clearly portray each night bridging the afternoon of one day to the morning of the following day.
- [x] **Trip Creation Transport Flow**:
  - Prompt for Primary Arrival Method and Return Departure Method (Flight, Train, Car, Bus, Ferry, Other) in `_CreateTripDialog`.
  - Automatically provisions placeholder `Flight` and/or `Activity` records on Day 1 and the final day.
- [x] **Dedicated Tests** ([`test/views/itinerary_transport_headers_test.dart`](./test/views/itinerary_transport_headers_test.dart)):
  - Standalone unit tests for `TransportHeaderBridgeWidget` (Arrival and Departure) and `StayHeaderBridgeWidget` night segmentation.

---

### Phase 8: Flights Management & Outside Stay Night Labels [COMPLETE]
- [x] **Flight CRUD in Flights View**:
  - Add flights via prominent `FloatingActionButton.extended` ("Add Flight") and empty-state action button in [`FlightsView`](./lib/views/flights/flights_view.dart).
  - Edit existing flights by tapping any flight card or selecting "Edit Flight" from card popup menu.
  - Remove flights with confirmation dialog (`Delete Flight?`).
  - Implemented delete and update methods on [`MockTripRepository`](./lib/data/repositories/mock_trip_repository.dart) and [`AddFlightSheet`](./lib/views/common/add_flight_sheet.dart).
- [x] **Itinerary Flagging on Flights**:
  - `isNightStay`: Mark flight as an overnight stay, automatically synthesizing a `Stay` representation in `sortedActiveTripStaysProvider` and rendering a stay header bridge in both Itinerary and Stays views.
  - `isMainArrival`: Mark flight as the trip's primary arrival method, prioritized when displaying the Day 1 Arrival Header in the Itinerary view.
  - `isMainDeparture`: Mark flight as the trip's primary departure method, prioritized when displaying the Final Day Departure Header in the Itinerary view.
  - Enforced mutual exclusivity across trip flights for arrival/departure on save in `AddFlightSheet`.
- [x] **Outside & On-Top Stay Night Labels**:
  - Relocated night number labels (`Night 1`, `Night 2`, etc.) outside and on top of the horizontal stay rectangle in [`StayHeaderBridgeWidget`](./lib/views/logistics/widgets/stay_header_bridge_widget.dart).
  - Mathematical segment centering: Each label is centered between the previous left edge or divider and the next night divider or right edge at $X = (s + 0.5) \times \text{segmentWidth}$.
  - Completely decluttered the interior of the stay rectangle by removing internal night counter text.
  - Preserved subtle intermediate vertical divider lines (`white.withValues(alpha: 0.35)`).
- [x] **Unified Baseline Alignment**:
  - Added 20dp top spacing to [`TransportHeaderBridgeWidget`](./lib/views/logistics/widgets/transport_header_bridge_widget.dart) and empty stay slots.
  - Guaranteed Arrival, Stay, and Departure rectangles all start at $Y = 20.0\text{ dp}$ with height 70dp along an identical horizontal baseline.
  - Adjusted Itinerary lane stride to `94.0` dp to ensure floating night pill badges have clear breathing room without collisions.
- [x] **Flight Status Badges in FlightsView**:
  - Added visual badges: `🌙 NIGHT STAY`, `✈️ MAIN ARRIVAL`, `🛫 MAIN DEPARTURE`, `OVERNIGHT`.
- [x] **Dedicated Automated Tests**:
  - [`test/views/stay_header_night_labels_test.dart`](./test/views/stay_header_night_labels_test.dart): Verifies outside top label row, segment centering, and empty slot rendering.
  - [`test/views/flights_management_test.dart`](./test/views/flights_management_test.dart): Verifies serialization of flight flags, repository CRUD, `sortedActiveTripStaysProvider` synthesis, and `FlightsView` badges/FAB.

---

### Phase 9: Continuous Night Numbering, Direct Transport Linking, Flight Exclusivity, Card Standardization, and Stay Deletion Bug Fix [COMPLETE]
- [x] **Continuous Night Numbering Across Stays**:
  - Night numbering continues sequentially across stays throughout the trip instead of resetting at stay boundaries.
  - Added `final int startNightNumber` to [`StayHeaderBridgeWidget`](./lib/views/logistics/widgets/stay_header_bridge_widget.dart), calculated in [`LogisticsView`](./lib/views/logistics/logistics_view.dart) as `startNightNumber = startIndex + 1`.
  - For an $N$-night stay spanning days $s \dots s+N$, pill badges label `Night (s + 1)`, `Night (s + 2)`, $\dots$, `Night (s + N)`.
- [x] **Arrival / Departure Header Direct Edit Linking**:
  - Added `onFlightTap` callback to [`LogisticsView`](./lib/views/logistics/logistics_view.dart), wired to `_openAddFlight` in [`AppNavScaffold`](./lib/views/common/app_nav_scaffold.dart).
  - Clicking on the Day 1 Arrival Header or Final Day Departure Header directly opens the edit bottom sheet (`AddFlightSheet` for flights or `AddActivitySheet` for transport activities).
- [x] **Flight Mutual Exclusivity**:
  - A flight cannot simultaneously be an arrival or departure flight (`isMainArrival` or `isMainDeparture`) and also an overnight night stay (`isNightStay`).
  - Enforced in [`Flight`](./lib/models/flight.dart) constructor, `copyWith`, and `fromMap`.
  - Enforced in [`AddFlightSheet`](./lib/views/common/add_flight_sheet.dart): toggling `isNightStay` automatically unchecks arrival/departure, and toggling arrival or departure unchecks `isNightStay`.
- [x] **Seed Test Data Overlap Elimination**:
  - Updated Trip 1 seed data in [`MockTripRepository`](./lib/data/repositories/mock_trip_repository.dart) to eliminate `stay_03` which overlapped with the Day 5 departure header.
  - Set `flt_02` (JL060) to `isNightStay: false` since it serves as `isMainDeparture: true`.
- [x] **Card Standardization Across Flights, Stays, and Activities**:
  - Standardized card UI across [`FlightsView`](./lib/views/flights/flights_view.dart), [`StaysView`](./lib/views/stays/stays_view.dart), and [`AttractionsView`](./lib/views/attractions/attractions_view.dart).
  - Tapping card body opens edit sheet.
  - Three-dots menu (`Icons.more_vert` / `PopupMenuButton<String>`) provides explicit "Edit" and "Delete" actions.
  - Delete action displays an `AlertDialog` confirmation before deletion.
  - Prominent `FloatingActionButton.extended` across all 3 screens ("Add Flight", "Add Stay", "Add Activity").
- [x] **Stay Deletion Bug Fix**:
  - Fixed deletion bug where overnight flight-backed stays (`stay_flight_<id>`) failed to delete or instantly re-synthesized.
  - In [`MockTripRepository.deleteStay`](./lib/data/repositories/mock_trip_repository.dart), identified flight-backed stay IDs, reset the underlying flight's `isNightStay = false`, and broadcast the change on `_flightsControllers`.
- [x] **Dedicated Automated Tests**:
  - [`test/views/card_standardization_and_delete_test.dart`](./test/views/card_standardization_and_delete_test.dart): Verifies 3-dots popup menus, delete confirmation dialogs, Arrival/Departure direct header linking, and flight-backed stay deletion.
  - Updated [`test/views/stay_header_night_labels_test.dart`](./test/views/stay_header_night_labels_test.dart) to verify continuous night numbering with `startNightNumber`.
  - Updated [`test/views/flights_management_test.dart`](./test/views/flights_management_test.dart) to verify mutual exclusivity.

---

## 2. File Structure & Component Map

```
Trippy/
├── SPEC.md                                    # Technical specification
├── implementation_plan.md                     # Implementation plan & tracking (this file)
├── original_implementation_plan.md            # Initial architectural plan
├── pubspec.yaml                               # Flutter project configuration
├── lib/
│   ├── main.dart                              # Application entrypoint & ProviderScope
│   ├── core/
│   │   ├── theme/                             # Colors, typography, and Material 3 themes
│   │   └── utils/                             # Date formatters, code generator, location helper
│   ├── models/
│   │   ├── trip.dart                          # Overarching trip entity
│   │   ├── stay.dart                          # Lodging & overnight stay bridges
│   │   ├── flight.dart                        # Airline travel segments with itinerary flags
│   │   ├── activity.dart                      # Daily activities & attractions
│   │   ├── member_role.dart                   # Role permissions (Owner, Editor, Viewer)
│   │   ├── trip_bundle.dart                   # Single & database JSON bundle models
│   │   └── models.dart                        # Barrel export file
│   ├── data/repositories/
│   │   ├── trip_repository.dart               # Repository interface contract
│   │   └── mock_trip_repository.dart          # In-memory repository with 2 test trips & CRUD
│   ├── state/
│   │   └── trip_providers.dart                # Riverpod state management, flight/stay synthesis
│   ├── services/
│   │   ├── export_import/                     # JSON export/import and download/upload helpers
│   │   └── ingestion/                         # Extensible itinerary document extraction interface
│   └── views/
│       ├── common/                            # AppNavScaffold, quick-add, and CRUD bottom sheets
│       ├── logistics/                         # LogisticsView, DayColumn, StayHeaderBridge, TransportHeader
│       ├── flights/                           # FlightsView and FlightCard with badges
│       ├── stays/                             # StaysView and StayCard
│       ├── attractions/                       # AttractionsView and activity filtering
│       └── dashboard/                         # TripDashboardScreen, share modal, and import dialog
└── test/
    ├── models/trip_model_test.dart            # Model serialization tests
    ├── repositories/mock_trip_repository_test.dart # Repository and dual-trip tests
    ├── services/export_import_test.dart       # Export & import unit tests
    ├── views/itinerary_transport_headers_test.dart # Arrival/Departure headers & segmentation tests
    ├── views/stay_header_night_labels_test.dart # Outside on-top night labels tests
    ├── views/flights_management_test.dart     # Flight CRUD, flags, and stay synthesis tests
    ├── views/card_standardization_and_delete_test.dart # 3-dots menus, header linking & stay deletion tests
    └── widget_test.dart                       # Full application widget test suite
```

---

## 3. Verification Commands & Results

### Static Analysis
```powershell
flutter analyze
```
*Result: `No issues found! (0 warnings, 0 errors)`*

### Automated Test Suite
```powershell
flutter test
```
*Result: `All 37 tests passed!`*

---

## 4. Future Roadmap & Extensibility
1. **Cloud Firestore Live Sync**: Drop-in implementation of `TripRepository` backed by Cloud Firestore with offline cache enabled (`FirestoreTripRepository`).
2. **Multimodal Document Ingestion**: Hook up AI / PDF / Email parser to the existing [`ItineraryExtractor`](./lib/services/ingestion/itinerary_extractor.dart) interface to automatically populate draft itineraries.
3. **Interactive Calendar Export**: Support `.ics` iCalendar file generation in `TripExportService` for syncing with Google Calendar and Apple Calendar.
