import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../models/models.dart';
import '../../state/trip_providers.dart';
import '../attractions/attractions_view.dart';
import '../dashboard/trip_dashboard_screen.dart';
import '../day_planner/day_planner_view.dart';
import '../flights/flights_view.dart';
import '../logistics/logistics_view.dart';
import '../stays/stays_view.dart';
import 'add_activity_sheet.dart';
import 'add_flight_sheet.dart';
import 'add_stay_sheet.dart';

class AppNavScaffold extends ConsumerStatefulWidget {
  const AppNavScaffold({super.key});

  @override
  ConsumerState<AppNavScaffold> createState() => _AppNavScaffoldState();
}

class _AppNavScaffoldState extends ConsumerState<AppNavScaffold> {
  int _currentIndex = 0;

  void _openAddActivity([Activity? activityToEdit, DateTime? initialDate]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddActivitySheet(
        activityToEdit: activityToEdit,
        initialDate: initialDate,
      ),
    );
  }

  void _openAddStay([Stay? stayToEdit, DateTime? initialCheckIn, DateTime? initialCheckOut]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddStaySheet(
        stayToEdit: stayToEdit,
        initialCheckInDate: initialCheckIn,
        initialCheckOutDate: initialCheckOut,
      ),
    );
  }

  void _openAddFlight([Flight? flightToEdit]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddFlightSheet(flightToEdit: flightToEdit),
    );
  }

  void _showQuickAddOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Add to Trip',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.attractionContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.event_note_rounded,
                      color: AppColors.attraction),
                ),
                title: const Text('Activity / Meal / Tour',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Add an activity inside a day column'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openAddActivity();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.stayContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.hotel_rounded,
                      color: AppColors.stay),
                ),
                title: const Text('Stay / Transition Bridge',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle:
                    const Text('Hotel or overnight stay spanning days'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openAddStay();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.flightContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.flight_takeoff_rounded,
                      color: AppColors.flight),
                ),
                title: const Text('Flight Booking',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Add airline leg to Flights view'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openAddFlight();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeTrip = ref.watch(activeTripProvider);
    final role = ref.watch(activeTripRoleProvider);
    final canEdit = ref.watch(canEditActiveTripProvider);

    return Scaffold(
      appBar: _currentIndex == 5 // Dashboard has its own app bar
          ? null
          : AppBar(
              titleSpacing: 16,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          activeTrip?.title ?? 'Trippy',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Role Pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: role.isOwner
                              ? const Color(0xFFFEF3C7)
                              : (role.canEdit
                                  ? const Color(0xFFDCFCE7)
                                  : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          role.displayName.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: role.isOwner
                                ? const Color(0xFFD97706)
                                : (role.canEdit
                                    ? const Color(0xFF15803D)
                                    : AppColors.textSecondary),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (activeTrip != null)
                    Text(
                      activeTrip.destination,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
              actions: [
                if (activeTrip != null) ...[
                  // Trip Code Quick Badge
                  ActionChip(
                    avatar: const Icon(Icons.share_rounded, size: 14),
                    label: Text(
                      activeTrip.inviteCode,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                    onPressed: () {
                      setState(() => _currentIndex = 5); // Switch to trips tab
                    },
                  ),
                  const SizedBox(width: 12),
                ],
              ],
            ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          DayPlannerView(
            onOpenAddActivity: ([date, act]) => _openAddActivity(act, date),
            onActivityTap: (act) => _openAddActivity(act),
            onStayTap: _openAddStay,
            onFlightTap: (f) => _openAddFlight(f),
            onAddStayForDates: (inD, outD) => _openAddStay(null, inD, outD),
          ),
          LogisticsView(
            onOpenAddActivity: ([date]) => _openAddActivity(null, date),
            onActivityTap: (act) => _openAddActivity(act),
            onStayTap: _openAddStay,
            onFlightTap: (f) => _openAddFlight(f),
            onAddStayForDates: (inD, outD) => _openAddStay(null, inD, outD),
          ),
          FlightsView(
            onAddFlight: _openAddFlight,
            onFlightTap: (f) => _openAddFlight(f),
          ),
          StaysView(
            onAddStay: _openAddStay,
            onStayTap: _openAddStay,
          ),
          AttractionsView(
            onAddActivity: _openAddActivity,
            onActivityTap: _openAddActivity,
          ),
          TripDashboardScreen(
            onTripSelected: () => setState(() => _currentIndex = 0),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 11,
        unselectedFontSize: 10,
        onTap: (idx) => setState(() => _currentIndex = idx),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.view_agenda_outlined),
            activeIcon: Icon(Icons.view_agenda_rounded),
            label: 'Day Planner',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_view_week_rounded),
            activeIcon: Icon(Icons.calendar_view_week_sharp),
            label: 'Itinerary',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.flight_rounded),
            activeIcon: Icon(Icons.flight_takeoff_rounded),
            label: 'Flights',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.hotel_outlined),
            activeIcon: Icon(Icons.hotel_rounded),
            label: 'Stays',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore_outlined),
            activeIcon: Icon(Icons.explore_rounded),
            label: 'Activities',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.luggage_outlined),
            activeIcon: Icon(Icons.luggage_rounded),
            label: 'Trips',
          ),
        ],
      ),
      floatingActionButton: canEdit && (_currentIndex == 0 || _currentIndex == 1)
          ? FloatingActionButton(
              onPressed: _showQuickAddOptions,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              tooltip: 'Add Booking or Activity',
              child: const Icon(Icons.add_rounded, size: 28),
            )
          : null,
    );
  }
}

