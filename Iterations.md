# Iteration #1
Fix the following issues:
1) When clicking add activity on a particular day, the new activity must be created on that day. It currently gets created in Day 1. 
2) Add a new category of activity for Stays that allows to capture check-in and checkout activities along with the relevant hotel/rental details. The UI must allow the user to select an existing stay and link it to the activity.
3) When creating a new stay, give the option to also automatically add/create check-in and check out activities on the corresponding dates / times.
4) When creating new flights, give the option to automatically add/create activities for the transport from airport to hotel and hotel to airport accordingly on the corresponding dates.
5) For the Activities tab, add the ability to group activities by day or category and also add ability to filter to a date range or all dates (default) in addition to the existing category filters. 
6) For the colors used in the Itinerary views, color-code stays and flights differently. Stays, must be color-coded according to the city. I.e. Stays at the same city, must be the same color. This should apply to the Full View as well as rows in the compact View. IN the compact view, if a particular row includes two cities, the code must correspond to the first city. The first city must be the one that is chronologically visited first according to the stays and or activities schedule.

# Iteration #2
1) Add a new "Map View" to the itinerary tab that shows all cities in an interactive map. Connecting lines must show the chronological sequence in which the cities will be visited. The name of the City must be displayed along with the sequence number of the chronological flow and ability to hover to see a summary of details of the stays in that city. Similarly, on the lines connecting each city, a quick text moniker that represents the flight (e.g. airline and flight number) must be used as the label for the connection with ability to hover to see the flight details. 
2) In the Full Itinerary View, the Night Number label should also include the city at which that night is spent.  

# Iteration #3
1) In the Compact View of the Itinerary tab, the color coding of the rows must be driven by the "Sleep At" City of the row. Text in all columns, must default to English. 
2) In the flights view, if Airport Ground Transfer Activities were created for a given flight. The link to those activities must be preserved in the flight itself and the UI must allow navigating to them from the flight details card. Similarly, the detail card for those activities must allow to navigate to the corresponding flight. Deleting the activity would remove the link to that activity. Deleting the flight should remove the linked activities. Users must also be able to link an existing transportation activity to an existing flight and the corresponding links must be created and managed accordingly. 
3) Provide the ability to delete trips
4) Remove the "+" button that allows to add any type of item from the Flights, Stays and Activities tabs. That button must only be available in the Itinerary tab. 


# Iteration #4
1) Similar to how activities can be linked to flights and managed consistently, enable users to also manage check-in and check-out activities linked to hotel stays in the same way as flights allow to navigate and manage transportation activities related to flights. I.e. Make the behavior of linking activities between flights and their corresponding transportation activities and stays and their corresponding check-in/out activities consistent. When editing a flight or a stay that has been linked to related activities, the linked activities should be shown and accessible in the flight or stay detail card. Avoid creating duplicates activities when saving flights or stays that already have related activities. 

# Iteration #5
Improve the map view by avoiding overlaps between the visual elements. If the same city has two different sequence numbers, ensure those do not visually overlap by creating a "call out". Also make the underlying map use Google maps to make the map interactive. Fix an issue where some flights are shown as transfers. Also avoid labels or any other visual elements to overlap with each other. 


# Iteration #6
1. Re-design the way flights and stays are shown in the Itinerary Full View in the following ways:

    1.1. Flights must ONLY appear as horizontal elements along with stays if the flight spans two or more days, otherwise flights must be shown as distinct flight cards inside the day itself along with activity cards. The new Flight cards must look and feel as the other Activity cards, but will represent the flight objects directly. Every flight must be rendered as a card in the corresponding day in the Itinerary Full View. Clicking on a Flight card must bring up the Flight's editing dialog. If flights are deleted/edited anywhere, the corresponding flight cards must be deleted/updated as well.    

    1.2. For the Stay horizontal cards on top of the days, there must always be two special ones at the beginning and the end. The beginning Stay should indicate the starting location. Similarly the end Stay must indicate the finishing location. These two must be prompted when creating a new trip and can be edited afterwards. Visually, their UI rectangles/cards must start at 50% vertical offset of the first day and end in the vertical middle of the first day for the starting one and the finish one must start in the vertical middle of the last day and end at 50% vertical offset of the last day's width. They should be both colored distinctively in Gray with the same color to set them apart from the actual Stays.

2. Create a new top level tab along the existing Itinerary, Flights, Stays, etc. tabs name "Day Planner" and make it the first and default view when opening a trip. If the current date is beyond the trip dates it should open on the first day of the trip, otherwise it should open on the day of the trip that corresponds to the current date. This new tab will focus on assisting the user to plan activities for a single day. The UI must show a vertical pane for a single day, similar to the ones in the trip Full View, but a bit expanded (without occupying the full screen) and with space on the right for "suggestions" that should appear as distinct, but subtle clickable cards, some of which can be just informative and others may be able to take action for the user. Each day must have a distinctive sub-header (in addition to the main header that indicates Day #, Date, etc. matching the header in the Itinerary's Full View) and a footer. The sub-header will be used to specify Wake-up location and the footer must be used to specify Sleep At location. Both must include links to the corresponding Stays. If one is missing, a placeholder text must indicate so. It will provide logic that detects potential missing activities and should make suggestions of activities to add. It should provide the following checks:

    2.1. Check if there's a food activity for each of the three typical meals: Breakfast, Lunch and Dinner. If activities for these meals are missing it should suggest adding the missing ones. The user should be able to click on the suggestions to get the corresponding activity automatically added at a standard time for the corresponding meal with the opportunity to add details before the activity is saved.

    2.2. Each day must have a clear wake-up and Sleep at locations. If these are missing the app must flag this and provide suggestions and clickable actions to create the corresponding Stays or fill in location details. 

    2.3. As the user fulfills the suggestions, they must disappear.

    2.4. The single-day view must show the activity cards in a size that is proportional to their length. The single-day view must include each hour of the day in a scrollable fashion to allow to see the full 24 hours, but the default view should optimize for showing the hours that have activities. E.g. If there are no activities from midnight until 8AM those hours should not be shown by default, however the user should be able to scroll up and down freely to visualize see empty hours.  

    2.5. The user must be able to add activities to the current day. 

    2.6. There must be a day navigation control that allows the user to navigate to the next and previous day of the trip or jump to a specific day. 

    2.7. There must be a header or label that indicates the current date and how many total days there are in the trip and the trip start and end dates. similar to how it is shown in the Itinerary view. 

3. All changes must keep the JSON import/export format compatible to allow importing trips that were exported with older versions of the app. 



# Iteration #7
1. Fix an issue that causes the screens to reload periodically even if no changes are happening in the app. Also fix an issue that causes an overnight flight to show in a second row of Stay headers in the Itinerary Full View when there is enough space for it to be rendered in the first/main row along with the other hotel stays. Also fix the suggestions logic in the Day PLanner view as it is missing suggestions for Breakfast and Dinners for days that don't have them. For meal activities allow the user to optionally tag them as either "Breakfast", "Lunch" or "Dinner" and use these tags to determine whether they are present or missing in a given day. Also, re-factor any background processes that may be continually running and may be impacting performance because the app seems to have slowed down considerably with the latest updates. 


# Iteration #8
In Day Planner, implement the following features:
1) Make the suggestions panel hideable into a single bulb icon floating on the side, so that in a mobile phone screen the day view occupies the entire screen and when the bulb icon is clicked the suggestions panel is shown on top. On browser and desktop, should still show on the side. 
2) Implement logic for the suggestions panel that checks for overlapping activities and allows the user to manage them and resolve overlaps. It should list which groups of activities are overlapping between each other and allow the user to select them individually within the suggestions panel to edit their details to resolve overlaps.
3) In the suggestions panel's header show start time of first activity and end time of last activity. 

# Iteration #9
1) Adjust the logic that calculates the flight duration shown in the Flights tab to consider time zone changes. For example, it currently shows that a SEA to HND flight's duration is 27h 40m, but in reality the flight is only 10h 40m due to time zone changes. 
2) Make the Flight edit dialog show a visual duration of the flight (similar to how it is currently shown in the Flights tab with a little plane icon and the duration above it) between the Departure and Arrival times while keeping those times as editable fields
3) Remove the duplicate "Airport Ground Transfer" panel at the bottom of the flight edit dialog that only shows checkboxes. Keep the "Linked Airport Ground Transfers" section that allows to manage links. When selecting Link Transfer, the list of selectable activities must be filtered to Transportation category only. 
4) Fix issue causing this message in the terminal: "Could not find a set of Noto fonts to display all missing characters. Please add a font asset for the missing characters. See: https://docs.flutter.dev/cookbook/design/fonts" 
5) Move the First and Last times from the Suggestions panel to the header of the Day panel. Instead of First and Last call them "Start" and "End"
6) Add logic to check if the set of locations for the Day covers all the locations of the activities for that day. If not, then suggest adding the missing locations.


# Iteration #10
1. The Flight cards in the day planner view must show the Departure - Arrival visual with duration in between, similar to how it is shown in the Flights card as opposed to just the Time. This is in addition to the other details about the flight. 
2. Add navigation elements to go from Day Planner view to Itinerary Full View for the same day and vice versa. E.g. In Full View add a "Plan Day" button and in the Day Planner view add a "Itinerary" button that navigates to that day in the Itinerary Full View.
3. Remove the "Sync linked Check-in & Check-out activities" section from the Edit stay dialog. Linked activities must always be synced. Add the ability to delete the linked activity from the Edit Activity dialog in addition to ability to just unlink it. Do this also for the linked activities in the Flight edit dialog to make both experiences of managing linking activities consistent.  
4. Itinerary tab: Add a new "Calendar View" that shows a traditional monthly calendar with each day as a square. The goal of this view is just to show where you are spending the day and the night at a glance (based on the locations set for that Day) and where are you staying for the night. A small clickable rectangle that bridges two consecutive days must show the location of the hotel where the user is spending the night and ability to click it to see the details of the stay. This view must allow navigating from a given day to the same day in the Full Itinerary view. This view must not show details of Activities or flights, unless a flight counts as a Stay (i.e. day-to-day transition). Each Day square must also include just the total count of activities planned for that day. And if there are flights happening on that day, it must show a clickable flight icon for each flight (different colors) that allows to see the details of the selected flight.

# Iteration #11
1. For the Transport activities, instead of just one location enable specifying two locations: from and to. If the transportation activity is linked to a flight, the location must be set to the departure or arrival airport of that flight depending if the activity is To Airport or From Airport. This means the user must be able to set whether the transport is to or from the airport as a persistent attribute of the activity. I.e. Replace the existing "Quick To Airport" and "Quick: From Airport" buttons that only set the title of the activity with mutually exclusive buttons that remember their state labeled just "To Airport" and "From Airport". This should be conditioned on whether there is a linked flight or not. If no linked flight, then to airport or from airport tagging should be disabled. Similarly, the from/to fields must allow the user to either enter a location/address or select a stay as the location. If a stay is selected, the location must not be editable and instead show the name of the Hotel/Stay. and its address as read-only. The flights view must reflect which linked transporation activity is to and from. 
2. For Hotel & Stay activities, if it is linked to a Hotel/Stay, the location must be read-only and display the location/address of the hotel. If there is linked hotel the location must remain editable. 
3. The suggestions panel in the Day Planner view must also flag activities without end time. 
4. The suggestions panel must not suggest to add ,missing places to the day that are not cities. Only cities must be suggested. 
5. In the calendar view, each day square must show which day of the week it is. The location(s) of the day must be shown in bigger font as the main element of the day and at the center of the day's rectangle. The color coding of the city labels must match the color coding from the Full View. Use the same city color but a lighter shade for the bakground of the day's rectangle. Similar to the compact view, the city where the user is staying the night should be used to determine the color of the day's rectangle. 
6. In Calendar view the Stays must be rendered as rectangles that are floating on top of the two days they transition. They should be centered veritcally and partially overlap a resonable percentage of the day's rectangle that allows to show enough of the stay name while remaining a small UX element. The Stay rectagle must show the name of the hotel, not its address. The color of the stay rectangle must match the assigned color to the city where the hotel is. The total count of activities and the flight icons must be aligned to the bottom of the day's rectabgle with the former aligned to the left and the latter to the right. 

# Iteration #12
1. Eliminate the "Itinerary Role & Special Characteristics" section of the edit flight dialog. The Night / Stay Flight, Main Arrival Flight and Main Departure Flight attributes are no longer needed. Clean up the code accordingly. These have now been superseded by the new flight rendering logic. 
2. In the Day PLanner view, if a flight crosses two days it must be shown in both days and occupying all the hours within each day. Currently a flight that spans two days, only shows in the first day and only for partial hours, it's not rendered to cover the full hours that flight takes on that day. 
3. Fix the day navigator control in the Day PLanner, which after visiting the calendar view, it no longer allows to navigate to previous or next day or jump to specific day. Add a test case to ensure this is not broken in the future. 
4. The Day Navigation in the Itinerary Full View must be consistent with the one in the Day PLanner View, allowing to navigate to previous and next days as well as to jump to any desired day directly. 
5. Remove the category of "Flight" activities. It is no longer needed since flights are now directly rendered in the different views. 
6. On the Calendar view, clicking on the top right icon that allows to navigate to that day must navigate to the Day PLanner view of that day instead of the Full VIew. 
7. Make the Day Navigation controls in the Day PLanner view to be center with respect to the day instead of being right-aligned. Also on this view, remove the bottom-right "+" button for adding activities, since this is redundant.
8. Add a month navigator to the calendar view. 
9. Change the logic for coloring the City name labels in the calendar view, to use the color of the city that determines the color for the day for all city labels. I.e. All city names within the same day rectangle must be of the same color, determined by the color of the stay city. Remove the "acts" suffix from the total activity count on each day. 

# Iteration #13
1. Fix a visual issue in the Edit Flight dialog that causes the flight duration line/graphic to be aligned to the right, next to the arrival date. The line must be centered between the Departure and the Arrival date. 
2. For Transport activities, add a toggle to make it a flight transfer and make the link to flight section be displayed only when the this toggle is selected. Also position this section after the start and end times and before the Route Locations. 
3. On the Day PLanner View, add a map panel that can be toggled on and off, similar to the suggestions panel. The map panel must appear to the right and take advantage of as much real estate as possible on the desktop screens. On the phone the map will pop up on top of the day panel. It must be based on Google maps and when nothing is clicked or selected it must show all locations from the current day's activities as pins. When selecting/clicking on a transport activity it must show directions from the to and from. When selecting an activity that only has one location it must highlight that location on the map and center it.
4. The suggestions panel must flag Transport activities that are missing to and from. 

# Iteration #14
1. Itinerary->Map View: Make the light map the default. Remove duplicate button to switch to dark map. Remove all numbering in the actual locations. Instead, just show the location names on the map and show the sequence numnbers in the transitions between locations. 
2. In the day planner, if any activities do not have locations, ignore them when rendering the map view
3. Fix an issue that causes locations in the map view in day planner to be shown at an incorrect position. For example the address 3942 West Lake Sammish Pkwy SE, Bellevue WA 98008, USA is shown as if it was in the Seattle Arboretum.
4. When seleting Transport activities with the map view shown in Day PLanner, show actual directions from Google Maps instead of just a line between the two points. The route shown must match what is shown when accessing Google Maps directly and entering the same start and end locations and times.
 
# Iteration #15
1. Implement Firebase Authentication (Google Sign-In and Guest/Anonymous Sign-In) to satisfy Firestore security rules requiring authenticated requests (`request.auth != null`).
2. Add AuthGate to securely gate app entry: unauthenticated users are presented with a branded SignInScreen with "Sign in with Google" and "Continue as Guest".
3. Add UserAccountButton on AppNavScaffold and TripDashboardScreen AppBars displaying user avatar, email/guest status, and account dialog with sign-out and guest-to-Google upgrade capability.
4. Protect userTripsProvider from firing queries when unauthenticated (`userId.isEmpty`), avoiding `[cloud_firestore/permission-denied]`.
5. Enhance error handling in TripDashboardScreen to display an informative error card with "Retry" and "Manage Account" actions when permission or auth errors occur.

# Iteration #16
1. Change the label of the "Day Planner" tab to just "Day" to better fit in mobile screens. 
2. For the calendar view (Itinerary), instead of showing the stays centered vertically across both days, align the stay rectangle towards the bottom, but without covering the visual elements at the bottom of the day squares. This is to avoid covering the labels of the main locations for each day which are also centered vertically. 
3. In the compact view (Itinerary) optimize the UI real estate for mobile by consolidating the Day of the Week column into the Date column by showing the day of the week as a small label under the date itself. Additionally, swap the order of Sleep At and Places to Visit, to show Sleep At column right after Date. 
4. Fix the map view in Day planner to zoom correctly and position the pins accurately for all cases, including when there are no activities for a day or when there are transport activities. Currently when zooming in, the map becomes pixelated and low resolution. Some of the pins are shown in incorrect locations, in particular the pin for the following address: 3942 W Lake Sammamish Pkwy SE, Bellevue, WA 98008, USA is shown as if it was located in the opposite shore of Lake Sammamish. 
5. Fix the rendering of card in the Flights tab. Currently in mobile screens, the departure and arrival airports occupy the whole width leaving no space for the flight duration and connection details in between causing them to be stacked vertically. 
6. In the Activities tab, Flights and Stays should not be included, only real Activities. 
7. On mobile screens, remove the Trip code with sharing button shown at the top. This currently causes the name of the trip to be truncated, so if UI real estate is limited, this button should not be shown.

# Iteration #17
1. In the Calendaer View (Itinerary), simplify the rendering of the day squares to only show the city/location where you are staying in bigger font inside a rectangle (as currently displayed), the other cities/locations must be shown in small grayed out font on top of the rectangle of the main city which should be centered on the square. 
2. Fix the Activities tab so that tyransfer activities do not show the title of the activity vertically wrapped because the icon/rectangle of the related dflight occupies most of the screen horizaontal real-estate. Optimize the rendering of this type of activity so the title of the activity is show fully and the flight icon takes minimal UI real estate 

# Iteration #18
1. In the caledar view, keep the main city rectangle always vertically centered, regardless of whether there is an additional lable on top. The additional city labels should be displayed on top of the vertically centered main city rectangle.
2. In all edit dialogs for activities, flights and stays, whenever there's an address, make its map icon clickable/tappable. Clicking the icon should open the default map app on the phone and center the map on the provided address. On the desktop it should open the address in google maps on the web browser.
3. Ensure all objects have a "Notes" section to store user-provided notes, files and links. Enhance this section to add the ability to add/remove links and attachments to all objects (activities, stays, flights).
4. Fix an issue with mobile view that causes any bottom buttons (e.g. "Save Changes" and "Delete") be almost covered by the phone's navigation bar on Android on edit dialogs and other screens that have buttons at the bottom of the screen.
5. On the Day PLanner view, on mobile phones, remove the floating buttons with warnings and map and instead show them on the top bar next to the day navigation control. The goal is to declutter the UI on small mobile screens. Also enable to navigate from day to day by swiping left and right.
 

 #Iteration #19
 1. Itineraty->Map View: Do not show rectangles for the locations in the map. Instead just show the pins for each location. This is to declutyter the UI as the rectangles cover the important parts of the map. Also fix the zoom in/ou so that the map actually zooms into more detailed views, currently zooming in just increases the size of the map's image/bitmap, but doesn't really add more details to the map. Lastly, zooming into the map should not make the icons and labels bigger, the icons and labels should remain at the same size (readable, but small) regardless of the level of zoom of the map. 
 2. Add a button to the map's navigation controls that allows to show a pop up dialog with a summary of interesting stats about the itinerary. Including number of flights, number of hours spent in flights, total destinations to be visited, number of different stays.
 3. Fix an issue that prevents changes to be saved. E.g. On android app I edited an activity (changed start and end times) and save button does nothing. Same with a flight. 
 4. Day Planner: To optimize vertical UI real estate in mobile apps, replace the current "Add Activity for this day" button which occupies a full row by a floating plus sign button (without a label) at the bottom right corner of the screen. Also enable adding new activities by double clicking/tapping on a blank section of the day. The plus button should not obstruct other non-scrollable visual elements. Similarly, simplify the "Add Flight", "Add Stay" and "Add Activity" buttons on mobile screens only to omit the label and just show the plus sign.

 # Iteration #20
 1. For transport activities, add a button in the Transport Route Locations section that opens up Google Maps in the browser or the default Maps app in mobile showing the directions from the From to the To address.
 2. In the Day PLanner view, allow the user to drag and drop activity cards to change their order and start time within the same day. The end time must be adjusted accordingly to keep the activity at the same duration. 
 3. For the attachments to any object, enabling uploading files from the local device and also pasting copied images fom the clipboard. Deploy any rules or config diles required to enable this to Firebase.


# Iteration #21
1. Remove the Booking Status section (along with the Confirmation Booking Reference) from Hotel & Stay Activities and Flights that have Stays/Flights linked to them, since these are covered in the Stay and Flights tabs respectively. Also remove the Location / Address (Linked Stay) field, since this is also redundant information when there's a linked Stay.
2. For the Add Link function, allow to specify a friendly name for the link, if provided, the friendly name should be displayed instead of the full URL. The friendly name should be editable later as well as the url itself. Similarly, allow to specify/edit friendly names for pasted images and uploaded attachments.
3. In Itinerary Full View, remove the label on the top right corner of the stays that reads "hotel - 1N", this is redundant information and takes valuable space that otherwise can be use to display more of the Stay name.
4. Day PLanner: For the new drag and drop feature, add a visual cue (like a semi-transparent ghost card or highlight of the target slot) to indicate where the card will drop when the user releases the drag and also align all drop targets to 15min increments. Lastly add the ability to grab the bottom edge of the activity card to extend or shorten the duration, also limited to 15min increments. 

# Iteration #22
1. [x] Create and enable an MCP Server for Trippy that can be used from Claude, ChatGPT, Gemini web apps, desktop apps and mobile apps. The MCP server should allow clients to read and write trips and all of their details through existing APIs (or create new APIs as needed). It must authenticate with the same Google accounts that control Firebase access. The main use case will be to ask Claude/ChatGPT/Gemini for a proposed daily itinerary and it should be able to directly translate the suggested itinerary once approved by the user into Trippy activities, flights and stays for the corresponding day or date range. The clients should also be able to modify trip details and read all trip details to answer questions about the trip and modify any object as needed to reflect changes desired by the user.
   - **MCP Server Implementation (`bin/trippy_mcp_server.dart`, `lib/mcp/`)**:
     - Standard JSON-RPC 2.0 MCP protocol supporting stdio, SSE (`/sse`, `/messages`), and HTTP POST (`/mcp`, `/api/trips`).
     - Supports direct execution via `dart run bin/trippy_mcp_server.dart` or IDE configurations in `mcp_config.json`.
     - 16 registered MCP tools covering full CRUD and itinerary orchestration:
       - `trippy_list_trips`, `trippy_get_trip_details`, `trippy_create_trip`, `trippy_update_trip`
       - `trippy_list_activities`, `trippy_create_activity`, `trippy_update_activity`, `trippy_delete_activity`
       - `trippy_list_stays`, `trippy_create_stay`, `trippy_update_stay`, `trippy_delete_stay`
       - `trippy_list_flights`, `trippy_create_flight`, `trippy_update_flight`, `trippy_delete_flight`
       - `trippy_apply_suggested_itinerary` (translates full multi-day daily itineraries into atomic activities, stays, and flights with date ranges)
       - `trippy_authenticate` (verifies Google account email & Firebase auth tokens for `trippy-prod-4524f`)
2. [x] All objects (activities, stays, flights, etc.) should track a last-modified timestamp and also should know whether the object was modified through the Trippy UI by the user of through the MCP server, so when making changes through the MCP server those changes should be flagged accordingly. On all object card details there should be an UI element that shows the last modified timestamp and whether it was through Trippy UI or MCP server. This flag should be displayed as an icon or text element that is easily understandable by the user.
   - Added `lastModifiedAt` and `lastModifiedSource` (`'ui'` vs `'mcp'`) fields and getters (`isModifiedByMcp`, `isModifiedByUi`) to `Activity`, `Stay`, `Flight`, and `Trip`.
   - Updated `FirestoreTripRepository` and `MockTripRepository` to automatically stamp modification metadata on all writes.
   - Updated `firestore.rules` to enforce valid timestamp and `'ui' | 'mcp'` source constraints.
   - Built `ModificationSourceBadge` (`lib/views/common/modification_source_badge.dart`):
     - Displays purple robot icon and `"MCP Server • <time>"` for MCP modifications.
     - Displays slate edit icon and `"Trippy UI • <time>"` for direct UI modifications.
     - Integrated across Attractions card, Stays card, Flights card, Day Planner timeline card, Logistics activity card, and edit/add sheets.
3. [x] Day Planner: When dragging an activity, the floating card that dynamically appears on the side to indicate the new location should also dynamically update the target time and show that in the card, to let the user know at what time the activity would be dropped at.
   - In `DayPlannerView`:
     - Added `_hoverDropStartMinutesNotifier` to dynamically broadcast hover drag positions without full widget rebuilds.
     - Updated `_buildActivityDragFeedback` to observe hover minutes and dynamically show `Target: HH:mm` badge with key `'drag_feedback_target_time'` and formatted time ranges.
     - Enhanced timeline ghost card (`'timeline_ghost_card'`) with `'timeline_floating_target_time_badge'` displaying real-time target time alongside the 15-minute slot indicator.


# Iteration #23
1. [x] Across all UI, remove the text label from the badges that indicate if an activity was updated via MCP. The badge should just include the little robot icon. For activities last updated via the UI, no badge/icon should be shown. The absence of a badge should convey that the activity was updated/created by the user through the UI.
   - In `lib/views/common/modification_source_badge.dart`:
     - If `!isMcp` (i.e. updated via UI or source is unset), returns `SizedBox.shrink()` so no icon or badge is displayed.
     - For MCP modifications, renders only the purple robot icon (`Icons.smart_toy_rounded`) within the rounded container with tooltip, omitting all text labels.
   - Updated widget tests in `test/views/iteration_22_enhancements_test.dart`.
2. [x] Update the Trippy MCP server to support adding links and attachments to all object types (`Stay`, `Activity`, `Flight`), plus support `ticketUrl` in `trippy_update_activity`:
   - Updated tool schemas in `lib/mcp/trippy_mcp_models.dart`:
     - `trippy_create_activity`: added `ticketUrl`, `links`, `attachments`.
     - `trippy_update_activity`: added `ticketUrl`, `links`, `addLinks`, `attachments`, `addAttachments`.
     - `trippy_create_stay`: added `links`, `attachments`.
     - `trippy_update_stay`: added `links`, `addLinks`, `attachments`, `addAttachments`.
     - `trippy_create_flight`: added `links`, `attachments`.
     - `trippy_update_flight`: added `links`, `addLinks`, `attachments`, `addAttachments`.
     - `trippy_apply_suggested_itinerary`: added `ticketUrl`, `confirmationRef`, `links`, `attachments` to items schema for activities, stays, and flights.
   - Built flexible string & object parser (`_parseStringList`) in `lib/mcp/trippy_mcp_service.dart`:
     - Supports `"Label|URL"` format.
     - Supports raw URL strings.
     - Supports structured JSON arrays: `[{"label": "Name", "url": "https://..."}]` or `[{"title": "Name", "url": "https://..."}]`.
     - Supports both full replacement (`links`, `attachments`) and incremental appending (`addLinks`, `addAttachments`).
   - Added unit test suite in `test/mcp/trippy_mcp_server_test.dart` verifying link, attachment, and `ticketUrl` handling across all object types.

3. [x] Smart Deduplication & In-Place Update for `trippy_apply_suggested_itinerary`:
   - Updated `_handleApplySuggestedItinerary` in `lib/mcp/trippy_mcp_service.dart` to match existing activities, stays, and flights before creating new ones.
   - Matching heuristics:
     - Exact ID match (`id` or `activityId` / `stayId` / `flightId`).
     - Normalized alphanumeric title/name equality on the target date.
     - Substring containment match on the target date (e.g. "Gonpachi Nishiazabu" vs "Dinner at Gonpachi Nishiazabu").
     - Time + location overlap on the target date.
   - In-place merge behavior:
     - Preserves original database IDs and creation timestamps.
     - Merges `links` and `attachments` using deduplicated sets without clobbering existing links.
     - Merges notes cleanly without duplicate repetitions.
     - Updates `bookingStatus`, `ticketUrl`, `confirmationRef`, `cost`, and times when provided.
   - Returns separate counts in response: `activitiesCount`, `updatedActivitiesCount`, `createdActivitiesCount`.
   - Cleaned up pre-existing duplicates on 2026-11-05 in production Firestore (`trip_thailandia_2026`).
   - Added unit test in `test/mcp/trippy_mcp_server_test.dart` verifying that existing activities are updated in-place rather than duplicated.
4. [x] Documented web and mobile client configuration instructions for the hosted Trippy MCP Server (`https://trippy-mcp-server-392329008088.us-central1.run.app/mcp`) in `README.md` and `README_MCP.md`:
   - Added dedicated `## Model Context Protocol (MCP) Server` section to `README.md` with live Cloud Run endpoints (HTTP POST `/mcp`, SSE `/sse`, and health check `/health`).
   - Documented step-by-step configuration for Web clients (Gemini Web, Google AI Studio, Gemini Live, ChatGPT Custom GPTs / Actions).
   - Documented step-by-step configuration for Mobile clients (iOS and Android MCP apps like Chatbox Mobile, LibreChat Mobile, TypingMind, and voice/chat workflows on Gemini & ChatGPT mobile).
   - Documented Desktop IDE settings (Claude Desktop, Antigravity IDE, Cursor) and authentication modes (sample in-memory sandbox vs live Cloud Firestore).

# Iteration #24
1. [x] Allow Trippy users to self-serve in generating PAT tokens for themselves via the Trippy app. This includes the ability to list and delete existing tokens. This should show up in an app-level settings page in the trippy app.
   - **Settings & AI Tokens Screen (`lib/views/settings/settings_screen.dart`)**:
     - Built comprehensive app-level Settings screen accessible from the AppBar (`Icons.settings_outlined`) and the User Account menu.
     - Profile section displaying user avatar, name, email, account type, UID, and sign-in / sign-out controls.
     - **Self-Serve Personal Access Token (PAT) Generator**:
       - Cryptographically secure 192-bit random token generation using `Random.secure()` formatted with `trippy_pat_<hex>`.
       - Computes SHA-256 hash client-side and stores metadata securely in Firestore collection `/mcp_api_keys/{keyHash}`:
         - `userId`: User's Firebase UID
         - `email`: User's email
         - `description`: Custom label (e.g., "Grok Bot Assistant", "Claude Desktop")
         - `tokenPrefix`: First 16 characters for identification in UI (raw token is never stored)
         - `createdAt`: ISO 8601 timestamp
       - One-time reveal modal with one-click copy buttons for:
         - Raw PAT secret (`trippy_pat_...`)
         - HTTP POST endpoint URL (`https://trippy-mcp-server-...run.app/mcp?key=...`)
         - SSE endpoint URL (`https://trippy-mcp-server-...run.app/sse?key=...`)
     - **Active Token Management**:
       - Real-time Firestore stream of active tokens owned by the signed-in user.
       - Token list with description, prefix, creation date, and instant revoke/delete action with confirmation modal.
     - **AI Assistant Setup Quick Guide**:
       - Interactive expandable cards with instructions for Grok Bot on X, Google AI Studio / Gemini, and Claude Desktop.
   - **Firestore Security Rules**:
     - Added rule `match /mcp_api_keys/{keyHash}` permitting authenticated users to read, create, and delete strictly their own tokens (`resource.data.userId == request.auth.uid`). Deployed to production.

2. [x] Fix UI issue in Day Planner: When there is an activity that lasts 15mins or less, its height is too small to be visible. Enforce a minimum height for activities in the Day Planner, regardless of the duration of the activity. Also, ensure that activities that start exactly at the hour are exactly aligned with the hour's horizontal line. Currently, some activities that start at the hour, show slightly above the corresponding hours' line. Same applies for the activities bottom edge, doesn't exactly aligns with the hour lines.
   - In `lib/views/day_planner/day_planner_view.dart`:
     - **Exact Hourly Grid Line Alignment**:
       - Separated time label rendering from horizontal grid line rendering.
       - Horizontal 1px dividing lines are now positioned at exact pixel offsets `top: h * hourHeight, height: 1.0` spanning `left: 52, right: 0` for all 24 hours.
       - Time labels are centered at `top: h * hourHeight - 7.0, height: 14.0`, preventing Flutter's Row layout from pushing the line down by 7dp.
       - Activities starting at the hour (`topPos = startMinutes * (hourHeight / 60)`) align with the horizontal hour line down to the exact pixel; activities ending on the hour align with the bottom line.
     - **Minimum Activity Height Enforcement**:
       - Defined `minActivityHeight = 48.0 dp` across all timeline activity cards.
       - Calculated card height is clamped: `cardHeight = math.max(minActivityHeight, durationMinutes * (hourHeight / 60))`.
       - Activities $\le 15$ minutes (which previously rendered at only 18dp) now display at a legible 48dp height with visible titles, category icons, time badges, and drag handles without visual clipping.
       - Location sub-line visibility threshold adjusted to `cardHeight >= 54`.
       - Drag feedback ghost cards also enforce `max(48.0, ...)` minimum height for consistent drag-and-drop feedback.

3. [x] Enable adding notes, links and attachments at the trip level:
   - **Data Model & Firestore (`lib/models/trip.dart`)**:
     - Added `notes` (`String?`), `links` (`List<String>`), and `attachments` (`List<String>`) to `Trip` model.
     - Updated `copyWith`, `toMap`, and `fromMap` with full backward compatibility for legacy trips without notes.
     - Updated `firestore.rules` validation schema (`isValidTrip`) to allow `notes`, `links`, and `attachments`.
   - **MCP Server Trip Tools (`lib/mcp/trippy_mcp_models.dart`, `lib/mcp/trippy_mcp_service.dart`)**:
     - Extended `trippy_create_trip` tool schema with `notes`, `links`, and `attachments`.
     - Extended `trippy_update_trip` tool schema with `notes`, `links`, `addLinks`, `attachments`, and `addAttachments`.
     - Updated handlers to parse string lists, label-URL pairs, and JSON objects, saving directly to Firestore in authenticated mode.
   - **Trippy UI Integration**:
     - **Trip Creation (`_CreateTripDialog` in `lib/views/dashboard/trip_dashboard_screen.dart`)**:
       - Integrated `NotesAndAttachmentsSection` into the create trip workflow.
     - **Trip Editing (`EditTripDialog`)**:
       - Created reusable public `EditTripDialog` with title, destination, start/end locations, date range picker, and full `NotesAndAttachmentsSection`.
       - Added edit button (`Icons.edit_note_rounded`) to each trip card on the Trips dashboard.
       - Added trip summary badges (Notes indicator, link count badge, attachment file count badge) on each trip card.
     - **Active Trip Quick Access (`lib/views/common/app_nav_scaffold.dart`)**:
       - Added Trip Notes button (`Icons.description_outlined` with badge indicator) in the AppBar across all views when an active trip is selected, allowing instant viewing and editing of trip-level notes, links, and attachments without having to leave the current tab.

# Iteration #25
1. [x] Full Offline Travel Support (Eager Caching & Local Attachment Storage):
   - **Firestore Local Persistence Configuration (`lib/main.dart`)**:
     - Configured Firestore settings on app initialization: `FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true, cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED)`.
     - Ensures that all read documents across trips, stays, flights, and activities are automatically persisted in the local SQLite/IndexedDB offline cache engine.
   - **Platform-Agnostic Attachment Storage Layer (`lib/services/offline/attachment_storage/`)**:
     - `AttachmentStorage` abstract platform interface with runtime and test overrides.
     - `AttachmentStorageIo`: On mobile (iOS, Android) and desktop (Windows, macOS, Linux), stores attachment files locally in `trippy_attachments_cache/` using `path_provider` with seamless fallback for tests and constrained environments.
     - `AttachmentStorageWeb`: In-memory byte cache for Web environments where direct filesystem access is restricted.
   - **Attachment Cache Service (`lib/services/offline/attachment_cache_service.dart`)**:
     - Computes SHA-256 hash keys for consistent, filesystem-safe local caching of URLs.
     - Performs automatic file extension and MIME type detection (`.pdf`, `.png`, `.jpg`, `.jpeg`, `.webp`, `.gif`).
     - Eager local byte saving upon attachment upload via `AttachmentUploadHelper`.
     - Direct offline retrieval of raw bytes (`getCachedBytes`) or local file paths (`getCachedFilePath`).
     - Storage size tracking and cache wipe capabilities.
   - **Offline Sync Coordinator (`lib/services/offline/offline_sync_service.dart`)**:
     - `TripOfflineStatus` data model tracking cached counts for stays, flights, activities, total/cached attachments, and disk usage.
     - `prefetchTripForOffline(tripId)`: Eagerly downloads and warms Firestore cache for trip root, stays, flights, and daily activities, while sequentially downloading and caching all external attachments with granular progress reporting callbacks (`0% -> 100%`).
     - `checkTripStatus(tripId)`: Evaluates offline readiness and detects missing attachments.
     - `removeTripOfflineCache(tripId)`: Wipes a trip's attachments from disk when storage needs to be reclaimed.
     - Riverpod providers: `offlineSyncServiceProvider`, `syncingTripsProvider`, `isTripSyncingProvider`, `tripOfflineStatusProvider`, `activeTripOfflineStatusProvider`.
   - **In-App Attachment Preview Dialog (`lib/views/common/attachment_preview_dialog.dart`)**:
     - Full-featured in-app modal preview dialog supporting offline viewing.
     - Zoomable and pannable image viewer (`InteractiveViewer`) directly loading from cached offline bytes.
     - Dedicated PDF and document preview cards indicating local cache availability vs Cloud Storage.
     - Open local file action on Desktop/Mobile (`Process.run` / `OpenFilex`) and external fallback launch via `url_launcher`.
     - Offline status indicators (e.g., "Stored in local offline cache", "Make Available Offline").
   - **UI Integration & Offline Travel Mode Controls**:
     - **App Navigation Scaffold (`lib/views/common/app_nav_scaffold.dart`)**:
       - Added Offline Travel Mode action button (`Icons.cloud_sync_outlined`) in the top AppBar when an active trip is selected, showing a green check badge when fully cached offline.
     - **Trip Dashboard (`lib/views/dashboard/trip_dashboard_screen.dart`)**:
       - Added "Offline Ready" green badge on trip cards when all details and attachments are cached locally.
       - Added "Offline Sync" icon button on each trip card's action row for 1-tap download and status inspection.
     - **Offline Sync Dialog (`lib/views/common/offline_sync_dialog.dart`)**:
       - Modern status modal showing detailed breakdown (Stays & Lodgings, Flights & Transportation, Daily Activities, Files & Attachments), live sync progress bar, "Make Available Offline" / "Update Offline Cache" button, and "Clear Cache" button.
     - **Settings Screen (`lib/views/settings/settings_screen.dart`)**:
       - Added "Offline Travel Storage" management card with dynamic cached size display and a "Clear File Cache" button.
     - **Notes & Attachments Chips (`lib/views/common/notes_and_attachments_section.dart`)**:
       - Attachment chips open `AttachmentPreviewDialog` on tap for instantaneous in-app offline preview.