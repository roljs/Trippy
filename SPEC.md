# Trippy - Technical Specification

## 1. Executive Summary & Overview
Trippy is a cross-platform itinerary management and collaborative travel planning application built with **Flutter** (optimized for Android, Web, and Desktop). Trippy organizes multi-modal travel journeys into an intuitive, high-density visualization system encompassing:
1. **Day-by-Day Itinerary Board**: Side-by-side vertical day columns with overarching horizontal stay rectangles spanning the length of stay in each location, complete with alternating colorways, stay duration details, and frictionless horizontal scrolling.
2. **Dedicated Travel Views**:
   - **Flights View**: Chronological breakdown of air travel segments with origin/destination routes, duration connectors, and airport/terminal/gate badges.
   - **Stays View**: Chronologically ordered accommodations highlighting nights count, check-in/out times, duration connectors, addresses, and booking references.
   - **Activities View**: Categorized activities and sights with filter chips, booking statuses, and checklist tracking.
   - **Trips Dashboard**: Multi-trip management, collaborative sharing via 6-character invite codes, and full JSON export/import.
3. **Multi-User Collaboration**: Role-based access control (**Owner**, **Editor**, **Viewer**) configurable per trip via a single alphanumeric invite code.
4. **Data Portability**: Full JSON export and import for single trips and entire trip databases.

---

## 2. System Architecture

```mermaid
graph TD
    subgraph Presentation ["Presentation Layer (Flutter)"]
        UI_DASH[Trip Dashboard Screen]
        UI_LOGI[Itinerary View (Multi-Day Stay Spans)]
        UI_FLT[Flights View]
        UI_STAY[Stays View (Chronological)]
        UI_ATTR[Activities View]
        UI_MODALS[Lightweight CRUD Sheets: Activity, Stay, Flight]
        UI_IMPORT[Trip JSON Import / Export Dialog]
        UI_SHARE[Trip Share & Member Role Modal]
    end

    subgraph State ["State Management (Riverpod)"]
        PROV_TRIP[userTripsProvider / activeTripProvider]
        PROV_ROLE[activeTripRoleProvider / canEditActiveTripProvider]
        PROV_STAYS[activeTripStaysProvider / sortedActiveTripStaysProvider]
        PROV_FLT[activeTripFlightsProvider]
        PROV_ACT[activeTripActivitiesProvider / activitiesByDayProvider]
    end

    subgraph Services ["Service Layer"]
        SVC_EXPORT[TripExportService]
        SVC_DL[Cross-Platform File Download Helper]
        SVC_UL[Cross-Platform File Upload Helper]
        EXT_IFACE[ItineraryExtractor Contract]
        EXT_MANUAL[Manual Form Extractor]
    end

    subgraph Data ["Data & Storage Layer"]
        REPO_IFACE[TripRepository]
        REPO_MOCK[MockTripRepository (In-Memory + Dual Test Trips)]
        OFFLINE[(Firestore Local Cache / Persistence - Production)]
    end

    subgraph Cloud ["Backend Services (Firebase)"]
        FB_AUTH[Firebase Authentication]
        FB_STORE[(Cloud Firestore)]
        FB_RULES[Security Rules: Owner / Editor / Viewer]
    end

    Presentation --> State
    State --> Services
    State --> Data
    Services --> Data
    Data --> OFFLINE
    Data <--> FB_AUTH
    Data <--> FB_STORE
    FB_STORE --- FB_RULES
```

---

## 3. Core Data Models

### 3.1 Trip (`Trip`)
Represents an overarching travel journey.
- `id` (String): Unique trip identifier.
- `title` (String): Display name of the trip (e.g., "Japan Odyssey: Tokyo & Kyoto").
- `destination` (String): Primary destination(s).
- `startDate` (DateTime): First day of the trip.
- `endDate` (DateTime): Final day of the trip.
- `coverImageUrl` (String?): Header/cover photo URL.
- `ownerId` (String): User ID of the creator.
- `inviteCode` (String): 6-8 character alphanumeric code for onboarding co-travelers (e.g., `TYO-8821`).
- `defaultInviteRole` (MemberRole): Default permission level granted to users joining via code (`editor` or `viewer`).
- `members` (Map<String, MemberRole>): Map of user IDs to permission roles.
- `createdAt` (DateTime), `updatedAt` (DateTime).
- **Computed Properties**:
  - `daysCount`: Total days in trip inclusive of start and end (`endDate.difference(startDate).inDays + 1`).
  - `daysList`: Normalized list of `DateTime` objects, one for each consecutive day.
  - `canUserEdit(userId)`: Convenience helper evaluating whether the specified user has editor/owner rights.

### 3.2 Stay (`Stay`)
Represents accommodations or overnight transit bridges between consecutive days.
- `id` (String): Unique identifier.
- `tripId` (String): Associated trip ID.
- `type` (StayType): Enum (`hotel`, `rental`, `overnightFlight`, `nightTrain`).
- `name` (String): Accommodation or carrier name (e.g., "Grand Hyatt Tokyo").
- `address` (String?): Physical location / address.
- `checkInDate` (DateTime), `checkInTime` (String?, e.g. "15:00").
- `checkOutDate` (DateTime), `checkOutTime` (String?, e.g. "11:00").
- `confirmationCode` (String?): Booking or confirmation reference.
- `notes` (String?): Special requests, amenities, or notes.
- `overnightFlight` (Flight?): Nested flight details if `type == StayType.overnightFlight`.
- **Computed Properties**:
  - `nights`: Total nights of the stay (`checkOutDate.difference(checkInDate).inDays`, minimum 1).
  - `coversTransition(day1, day2)`: Checks whether this stay covers the night between `day1` and `day2`.

### 3.3 Flight (`Flight`)
Represents airline travel segments.
- `id` (String), `tripId` (String).
- `airline` (String), `flightNumber` (String).
- `departureAirport` (String), `arrivalAirport` (String).
- `departureTime` (DateTime), `arrivalTime` (DateTime).
- `isOvernight` (bool): True if flight spans overnight across calendar days.
### 3.3 Flight (`Flight`)
Represents airline travel segments.
- `id` (String), `tripId` (String).
- `airline` (String), `flightNumber` (String).
- `departureAirport` (String), `arrivalAirport` (String).
- `departureTime` (DateTime), `arrivalTime` (DateTime).
- `isOvernight` (bool): True if flight spans overnight across calendar days.
- `isNightStay` (bool): When true, flight automatically appears as an overnight lodging stay header in the Itinerary view and Stays view. **Mutually exclusive** with `isMainArrival` and `isMainDeparture`.
- `isMainArrival` (bool): When true, marks the flight as the trip's primary arrival method, rendering as the Day 1 Arrival header. **Mutually exclusive** with `isNightStay`.
- `isMainDeparture` (bool): When true, marks the flight as the trip's primary departure method, rendering as the Final Day Departure header. **Mutually exclusive** with `isNightStay`.
- `terminal` (String?), `gate` (String?), `seat` (String?), `bookingRef` (String?), `notes` (String?).
- **Computed Properties**:
  - `spansAcrossDays`: True if `isOvernight` or `isNightStay` is set or arrival calendar date differs from departure.
  - `duration`: Calculated duration difference (`arrivalTime.difference(departureTime)`).

### 3.4 Activity (`Activity`)
Represents time-slotted events within a single calendar day.
- `id` (String), `tripId` (String).
- `date` (DateTime): Calendar day of the activity.
- `startTime` (String): 24-hour time string ("HH:mm").
- `endTime` (String?): Optional end time ("HH:mm").
- `title` (String): Display title.
- `category` (ActivityCategory): Enum (`attraction`, `dining`, `transport`, `entertainment`, `flight`, `custom`).
- `location` (String?), `notes` (String?), `cost` (double?).
- `bookingStatus` (BookingStatus): Enum (`planned`, `booked`, `ticketed`).
- `confirmationRef` (String?), `ticketUrl` (String?), `isCompleted` (bool).
- **Computed Properties**:
  - `startDateTime`: Combined `DateTime` constructed from `date` and `startTime` for chronological sorting.

### 3.5 Member Role (`MemberRole`)
- Enum: `owner`, `editor`, `viewer`.
- `isOwner`: True for `MemberRole.owner`.
- `canEdit`: True for `owner` and `editor`.
- `displayName`: Formatted string ("Owner", "Editor", "Viewer").

---

## 4. Custom Itinerary Visualization: Concrete Layout Specification

### 4.1 Visual Schematic (Arrival, Segmented Stays, & Departure Headers)

```
                       DAY 1                           DAY 2                           DAY 3
                  [Center: 300.0]                 [Center: 610.0]                 [Center: 920.0]
                        |                               |                               |
[=== ARRIVAL ===]------>|                               |                               |
 | NH203  •  ARR: 09:30 |                               |                               |
 ========================|=========== STAY 1 (NIGHT 1) ==========|=========== STAY 1 (NIGHT 2) ==========>|
                        | Grand Hyatt Tokyo • HOTEL • 2N        | (Div)                         |        |---->[=== DEPARTURE ===]
                        | In: 3:00 PM  •  Night 1               | Out: 11:00 AM  •  Night 2     |        |  | JL060 • DEP: 21:15  |
                        =================================================================================  ========================
                                                |                               |                                  |
            +-------------------------------------+             +-------------------------------------+             +-------------------------------------+
            | DAY 1: Thu, Oct 1                   |             | DAY 2: Fri, Oct 2                   |             | DAY 3: Sat, Oct 3                   |
            | 📍 Japan  📍 Tokyo            [Edit]|             | 📍 Japan  📍 Tokyo            [Edit]|             | 📍 Japan  📍 Tokyo            [Edit]|
            +-------------------------------------+             +-------------------------------------+             +-------------------------------------+
            | [09:30] ✈️ Arrival HND               |             | [08:30] 🍳 Tsukiji Mkt              |             | [10:00] 🛍️ Ginza Shopping           |
            | NH105 from SFO                      |             | Breakfast food crawl                |             | Department stores & cafes           |
            |-------------------------------------|             |-------------------------------------|             |-------------------------------------|
            | [11:30] 🚆 Keikyu Line to Roppongi  |             | [10:30] 🏛️ Senso-ji Temple Tour    |             | [15:00] 🏨 Hotel Checkout           |
            |-------------------------------------|             |-------------------------------------|             |-------------------------------------|
            | [15:00] 🏨 Check-in Grand Hyatt     |             | [14:30] 🛍️ Akihabara Electronics   |             | [21:15] 🛫 JL060 Departure to SFO   |
            +-------------------------------------+             +-------------------------------------+             +-------------------------------------+
```

### 4.2 Symmetrical Threshold Headers & Center-to-Center Geometry
- **Column Sizing & Canvas Coordinate System**:
  - `columnWidth = 290.0` dp, margin `10.0` dp on each side (`columnMargin = 20.0` dp, `totalColumnStride = 310.0` dp).
  - Canvas left runway offset: `canvasLeftOffset = 145.0` dp (50% of `columnWidth`), providing a clean threshold for arrival.
  - Column center: `columnCenter(i) = canvasLeftOffset + (i * totalColumnStride) + 155.0` dp.
- **Day 1 Arrival Header**:
  - **Starts at**: `columnCenter(0) - columnWidth` (10.0 dp, representing a 50% column width offset to the left of Day 1's left edge at 155.0 dp).
  - **Ends at**: `columnCenter(0)` (300.0 dp, Day 1 vertical center line).
  - **Width**: `290.0` dp (matches standard column width).
  - **Visual Semantics**: Embodies the arrival journey entering from outside the destination into Day 1, meeting Stay 1 at the center axis with a clean 6 dp separation.
  - **Direct Edit Linking**: Clicking the Arrival header directly invokes the edit bottom sheet (`AddFlightSheet` or `AddActivitySheet`) for the underlying arrival transport entry.
- **Last Day Departure Header**:
  - **Starts at**: `columnCenter(lastDayIndex)` (vertical center of the final trip day).
  - **Ends at**: `columnCenter(lastDayIndex) + columnWidth` (representing a 50% column width offset past the last day's right edge).
  - **Width**: `290.0` dp.
  - **Visual Semantics**: Embodies departure from the final day center line into the onward journey home.
  - **Direct Edit Linking**: Clicking the Departure header directly invokes the edit bottom sheet (`AddFlightSheet` or `AddActivitySheet`) for the underlying departure transport entry.
- **Continuous Night Numbering Across Stays**:
  - Night numbering continues to increase sequentially across stays throughout the trip rather than resetting to "Night 1" on stay boundaries.
  - A stay starting on day column index $s$ receives `startNightNumber = s + 1`. For an $N$-night stay spanning days $s \dots s+N$, its sub-elements are numbered `Night (s + 1)`, `Night (s + 2)`, $\dots$, `Night (s + N)`.
  - For example, if Stay 1 is 2 nights (Day 1 to Day 3), it displays `Night 1` and `Night 2`; Stay 2 (Day 3 to Day 5) seamlessly displays `Night 3` and `Night 4`.
- **Stay Headers with Outside Top Night Labels**:
  - Starts at `columnCenter(startIndex)` and spans to `columnCenter(startIndex + nights)` with `width = nights * totalColumnStride`.
  - **Outside Top Night Labels**:
    - Night number labels (`Night 1`, `Night 2`, etc.) float **outside and on top** of the horizontal rectangle, cleanly decluttering the interior of the header itself.
    - Each label is centered horizontally between the previous left edge or divider and the next night divider or right edge at $X = (s + 0.5) \times \text{segmentWidth}$.
    - Styled as elevated pill badges matching the stay's active gradient colorway.
  - **Interior Segmentation Dividers**:
    - For stays with $N > 1$ nights, discrete vertical dividers (`white.withValues(alpha: 0.35)`, width: 1.5 dp, height: 38 dp) are rendered inside the rectangle at every intermediate boundary (`k * 310.0` dp), aligning with the exact vertical center of intermediate days.
  - **Unified Rectangle Baseline**:
    - All horizontal headers (Arrival, Stays, and Departure) share a matching top spacing ($20\text{ dp}$) so their main rectangle bodies align along the exact same horizontal baseline across the screen.
    - Lane stride is set to `94.0` dp, providing ample breathing room for the floating night badges without collisions.
  - Container margin is set to `horizontal: 3` dp, leaving a clean 6 dp gap between consecutive stays and transport headers.
- **Trip Creation Transport Flow**:
  - When creating a trip, users are prompted for:
    1. **Primary Arrival Method**: Flight, Train / Rail, Car / Drive, Bus, Ferry, Other.
    2. **Return Departure Method**: Flight, Train / Rail, Car / Drive, Bus, Ferry, Other.
  - Automatically provisions placeholder `Flight` and/or `Activity` records on Day 1 and the final day, pre-tagged with `isMainArrival: true` and `isMainDeparture: true`.

### 4.3 Day Header Locations Specification
- **Per-Day Locations**: Each day column header indicates one or more locations (e.g. `📍 Japan`, `📍 Tokyo`).
- **Default Country Inference Engine** (`LocationInferenceHelper`):
  - Defaults to the target country of the most recent flight or transport activity on or before that day.
  - Parses arrival airports, destination cities, and keyword mappings.
  - Falls back to the destination country of the overall trip if no prior flights occurred.
- **User Customization & Persistence**:
  - Users can tap the location tags or `Edit` button to open the `ManageDayLocationsDialog`.
  - Supports adding new locations, removing existing tags, or reverting to default.
  - Custom locations are stored in `Trip.dayLocations` (`Map<String, List<String>>`) and serialized to JSON.

### 4.4 Enhanced Horizontal Scrolling
- **Scrollbar**: Draggable horizontal `Scrollbar` with `thumbVisibility: true` and `trackVisibility: true`.
- **Pointer Drag Support**: `AppHorizontalScrollBehavior` supporting dragging with mouse, trackpad, and touch.
- **Mouse Wheel Translation**: Vertical mouse wheel ticks over the board translate directly into horizontal scroll offset via `Listener(onPointerSignal: ...)`.
- **Header Navigation Controls**: `Day 1` quick return button, `Prev Day (◀)` button (`-310dp`), and `Next Day (▶)` button (`+310dp`).

---

## 5. Travel Views & Modals (Standardized Card UX)

All three primary travel views (`FlightsView`, `StaysView`, `ActivitiesView`) adhere to a **standardized card interaction model**:
1. **Direct Tap on Card**: Defaults to opening the full Edit bottom sheet for that item.
2. **Three-Dots Options Menu**: Positioned on the top right of every card (`PopupMenuButton<String>`), offering explicit:
   - `Edit <Item>`: Opens the edit sheet.
   - `Delete <Item>`: Displays a confirmation `AlertDialog` ("Delete [Item]?", "Are you sure you want to delete this [item]? This action cannot be undone.") before removing the entity.
3. **Floating Action Button**: Prominent `FloatingActionButton.extended` on each screen for adding items ("Add Flight", "Add Stay", "Add Activity").
4. **Role Enforcement**: Options menus, delete buttons, and FABs are restricted to users with `canEdit` privileges.

### 5.1 Stays View (`StaysView`)
- Displays all stays for the active trip sorted **chronologically** (via `sortedActiveTripStaysProvider`).
- Standardized card layout with three-dots menu (`Edit Stay`, `Delete Stay`) and tap-to-edit.
- Lodging type badge (`HOTEL`, `RENTAL`, `OVERNIGHT FLIGHT`, `NIGHT TRAIN`).
- Total nights duration pill (`X NIGHTS`).
- Dates card with Check-in / Check-out timestamps and visual duration connector.
- Formatted address with location pin.
- Overnight flight route and times callout (if applicable).
- Monospace confirmation code badge with copy-to-clipboard button.
- **Robust Stay Deletion**:
  - Standard stays are removed from the repository.
  - Synthesized flight-backed stays (`stay_flight_<id>`) seamlessly reset `flight.isNightStay = false` on the underlying flight record and trigger real-time updates across controllers, eliminating zombie stay regeneration.

### 5.2 Flights View (`FlightsView`) & Flight Management
- Displays airline legs ordered chronologically.
- Standardized card layout with three-dots menu (`Edit Flight`, `Delete Flight`) and tap-to-edit.
- **Itinerary Roles & Status Badges**:
  - `🌙 NIGHT STAY`: Mark flight as an overnight stay, automatically surfacing it as a lodging stay header bridge in the Itinerary view and Stays view.
  - `✈️ MAIN ARRIVAL`: Mark flight as the trip's primary arrival flight, displaying as the Day 1 Arrival header in the Itinerary view.
  - `🛫 MAIN DEPARTURE`: Mark flight as the trip's primary departure flight, displaying as the Final Day Departure header in the Itinerary view.
  - `OVERNIGHT`: Indicates flights spanning into the next calendar day.
- **Mutual Exclusivity**:
  - A flight cannot simultaneously be an arrival/departure flight and an overnight night stay. Toggling `isNightStay` resets arrival/departure, and toggling arrival/departure resets `isNightStay`.
- Route row: Origin departure airport & time $\rightarrow$ duration flight graphic $\rightarrow$ Destination arrival airport & time.
- Badges: Terminal, Gate, Seat, Booking Reference.

### 5.3 Activities View (`ActivitiesView`)
- Categorized activity breakdown by category (`Attraction`, `Food & Dining`, `Transport`, `Entertainment`, `Flight`, `Other`).
- Standardized card layout with three-dots menu (`Edit Activity`, `Delete Activity`) and tap-to-edit.
- Status badges: `Planned`, `Booked`, `Ticketed`.
- Date, start/end times, location, notes, and ticket links.
- Consistent terminology: references "activities" uniformly across lists, chips, empty states, and creation sheets.
- Edit/Add Activity dialog utilizes multi-line responsive `Wrap` for category chips, ensuring all chips (including "Other") remain fully visible and selectable across all screen widths.

### 5.4 Trips Dashboard (`TripDashboardScreen`)
- Lists all trips with active status indicator, destination, date range, days count, and role pill.
- Create new trip dialog with date range picker and default invite role setting.
- Join trip modal via 6-character code.
- Share modal displaying invite code, clipboard copy, and co-traveler role manager.
- Single-trip export button on each trip card.
- Database options menu with "Export All Trips" and "Import Trips from JSON".

---

## 6. Export & Import Specification

### 6.1 Single Trip Bundle (`TripBundle`)
```json
{
  "version": 1,
  "trip": {
    "id": "trip_japan_2026",
    "title": "Japan Odyssey: Tokyo & Kyoto",
    "destination": "Tokyo & Kyoto, Japan",
    "startDate": "2026-10-01T00:00:00.000",
    "endDate": "2026-10-05T00:00:00.000",
    "ownerId": "user_current",
    "inviteCode": "TYO-8821",
    "defaultInviteRole": "editor",
    "members": { "user_current": "owner" },
    "createdAt": "2026-09-20T00:00:00.000",
    "updatedAt": "2026-09-20T00:00:00.000"
  },
  "stays": [ /* List of Stay objects */ ],
  "activities": [ /* List of Activity objects */ ],
  "flights": [ /* List of Flight objects */ ]
}
```

### 6.2 Database Bundle (`TripDatabaseBundle`)
```json
{
  "version": 1,
  "exportedAt": "2026-09-22T06:45:00.000Z",
  "trips": [
    /* Array of TripBundle objects */
  ]
}
```

### 6.3 Export & Download Flow
- Web: Initiates direct browser download via HTML blob object URL and programmatic anchor click (`file_download_web.dart`).
- Desktop/IO: Saves file directly to the user's `Downloads` folder (`file_download_io.dart`).
- SnackBar alert with a "Copy JSON" action to copy the formatted string directly to the clipboard.

### 6.4 Import Flow
- Handled via `_ImportTripDialog`:
  - **Option 1**: Local `.json` file picker (`file_upload_web.dart` via input element, or IO fallback).
  - **Option 2**: Direct text paste area with "Paste from Clipboard" button.
- Validates JSON format and detects single bundle vs. multi-trip database bundle.
- Automatically assigns the current user as owner/member and upserts into the active repository without duplicating IDs.

---

## 7. Multi-User Collaboration & Security Model

### 7.1 Single Code Collaboration Flow
1. **Trip Creation**: System generates a 6-8 character uppercase code (e.g., `TYO-8821`). The owner selects the code's default joining role: **Editor** or **Viewer**.
2. **Joining a Trip**: Co-travelers enter the code in the "Join Trip" dialog. The repository validates the code and adds the user into `members[userId] = defaultInviteRole`.
3. **Role Enforcement**:
   - **Owner**: Full itinerary control, delete trip, reconfigure default invite role.
   - **Editor**: Can add, edit, and delete activities, stays, and flights.
   - **Viewer**: Read-only access across all views; action buttons, bottom-sheets, and FABs are hidden.

---

## 8. Dual Test Trip Dataset

### 8.1 Trip 1: Japan Odyssey (Tokyo & Kyoto)
- **ID**: `trip_japan_2026`
- **Destination**: Tokyo & Kyoto, Japan (5 Days)
- **Stays (2)**:
  1. Grand Hyatt Tokyo (Day 1 - Day 3, 2 nights hotel)
  2. The Celestine Kyoto Gion (Day 3 - Day 5, 2 nights hotel)
  *(Note: Sample stays avoid overlapping with Arrival on Day 1 or Departure on Day 5)*
- **Flights (2)**: ANA HND Arrival (NH203, `isMainArrival: true`) & JAL KIX-SFO (JL060, `isMainDeparture: true`).
- **Activities (11)**: Shibuya crossing, Tsukiji market, Senso-ji temple, Akihabara, Roppongi Hills, Nozomi Bullet Train, Fushimi Inari, Kinkaku-ji, Arashiyama Bamboo Grove, etc.

### 8.2 Trip 2: Italian Dolce Vita (Rome, Florence & Amalfi)
- **ID**: `trip_italy_2026`
- **Destination**: Rome, Florence & Positano, Italy (6 Days)
- **Stays (3)**:
  1. Hotel Artemide, Rome (Day 1 - Day 3, 2 nights hotel)
  2. Villa Cora, Florence (Day 3 - Day 5, 2 nights historic villa hotel)
  3. Le Sirenuse Villa, Positano (Day 5 - Day 6, 1 night vacation rental)
- **Flights (2)**: Delta DL148 (JFK -> FCO) & Air France AF432 (NAP -> JFK).
- **Activities (11)**: Colosseum Gladiator Arena, Trastevere food walk, Vatican Museums & Sistine Chapel, Pantheon gelato crawl, Frecciarossa high-speed train, Uffizi Gallery, Florence Duomo climb, Tuscan sunset at Piazzale Michelangelo, Amalfi coastal drive, Positano cliffside dinner at La Sponda.

---

## 9. Verification & Quality Standards
- **Static Analysis**: `flutter analyze` must pass with zero issues.
- **Automated Test Suite**:
  - Model serialization & computed properties (`trip_model_test.dart`).
  - Repository CRUD, membership, and dual test trip seeding (`mock_trip_repository_test.dart`).
  - JSON export/import and schema roundtrips (`export_import_test.dart`).
  - Widget tests for all 5 navigation tabs and multi-day stay spanning (`widget_test.dart`).
