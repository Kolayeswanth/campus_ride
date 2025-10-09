import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/driver_service.dart';
import '../../../core/services/location_tracking_service.dart';
import '../../../core/services/location_permissions_handler.dart';
import '../../../core/models/bus_route.dart';
import '../../../core/models/driver_trip.dart';
import '../widgets/live_tracking_map.dart';
import '../../../shared/widgets/driver_navigation_map.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  Map<String, dynamic>? driverProfile;
  DriverTrip? currentTrip;
  Map<String, dynamic> todayStats = {};
  bool isLoading = true;
  bool isStartingTrip = false;

  @override
  void initState() {
    super.initState();
    _loadDriverData();
  }

  Future<void> _loadDriverData() async {
    setState(() => isLoading = true);
    
    try {
      final profile = await DriverService.getDriverProfile();
      final trip = await DriverService.getCurrentTrip();
      final stats = await DriverService.getTodayStats();
      
      if (mounted) {
        setState(() {
          driverProfile = profile;
          currentTrip = trip;
          todayStats = stats;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading driver data: $e');
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // If trip is active, show fullscreen map with trip progress overlay
    if (currentTrip != null) {
      return _buildActiveTripScreen();
    }
    
    // Otherwise show regular dashboard
    return Scaffold(
      backgroundColor: Colors.white, // Light background
      body: RefreshIndicator(
        onRefresh: _loadDriverData,
        child: CustomScrollView(
          slivers: [
            // Dark Modern App Bar
            SliverAppBar(
              expandedHeight: 180,
              floating: false,
              pinned: true,
              elevation: 0,
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 10), // Reduced from 20
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF007AFF).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(
                                  Icons.directions_bus,
                                  size: 28,
                                  color: Color(0xFF007AFF),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Good ${_getGreeting()}!',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Color(0xFF6C757D),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      driverProfile?['name'] ?? 'Driver',
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF212529),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined, color: Color(0xFF8E8E93)),
                  onPressed: () {
                    // Add notification functionality
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.logout_outlined, color: Color(0xFF8E8E93)),
                  onPressed: _showSignOutDialog,
                ),
              ],
            ),
            
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (isLoading)
                    _buildLoadingState()
                  else if (driverProfile == null)
                    _buildErrorState()
                  else ...[
                    // Assigned Route Card
                    _buildAssignedRouteCard(),
                    const SizedBox(height: 100), // Bottom spacing
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTripScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Fullscreen Navigation Map
          if (currentTrip != null && driverProfile?['assignedRoute'] != null)
            DriverNavigationMap(
              currentTrip: currentTrip!,
              assignedRoute: driverProfile!['assignedRoute'],
              onStopTrip: _endTrip,
              onMapControllerReady: (centerFunction) {
                _mapCenterFunction = centerFunction;
              },
            ),
          

          
          // Trip Progress Bottom Sheet Style UI
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildTripProgressSheet(),
          ),
          
          // Top Status Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildTripStatusBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildTripStatusBar() {
    // Return empty container to hide navigation card completely
    return const SizedBox.shrink();
  }



  Widget _buildTripProgressSheet() {
    final route = driverProfile?['assignedRoute'] as BusRoute?;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        border: Border.all(
          color: const Color(0xFF007AFF).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFDEE2E6),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Trip Status Row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: currentTrip?.direction == TripDirection.inbound 
                            ? const Color(0xFF34C759)
                            : const Color(0xFF007AFF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        currentTrip?.direction == TripDirection.inbound 
                            ? Icons.u_turn_left 
                            : Icons.play_arrow,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentTrip?.direction == TripDirection.inbound 
                                ? 'Return Journey' 
                                : 'Outbound Journey',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF212529),
                            ),
                          ),
                          Text(
                            route?.routeName ?? 'Unknown Route',
                            style: const TextStyle(
                              color: Color(0xFF6C757D),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF34C759).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'ACTIVE',
                        style: TextStyle(
                          color: Color(0xFF34C759),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Only show secondary actions when trip is not active
                if (currentTrip == null || currentTrip!.status != TripStatus.active) ...[
                  const SizedBox(height: 12),
                  
                  // Secondary Actions Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildSecondaryActionButton(
                          icon: Icons.people,
                          label: 'Passengers',
                          onPressed: _showPassengerCount,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildSecondaryActionButton(
                          icon: Icons.warning,
                          label: 'Report Issue',
                          onPressed: _showReportIssue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildSecondaryActionButton(
                          icon: Icons.coffee,
                          label: 'Break',
                          onPressed: _takeBreak,
                        ),
                      ),
                    ],
                  ),
                ],
                
                const SizedBox(height: 16),
                
                // Trip Control Actions
                Row(
                  children: [
                    if (currentTrip?.direction == TripDirection.outbound)
                      Expanded(
                        child: _buildTripActionButton(
                          icon: Icons.u_turn_left,
                          label: 'Start Return',
                          color: const Color(0xFF34C759),
                          onPressed: _startInboundTrip,
                        ),
                      ),
                    if (currentTrip?.direction == TripDirection.outbound)
                      const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.stop,
                        label: 'End Trip',
                        color: const Color(0xFFFF3B30),
                        onPressed: _endTrip,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withOpacity(0.2)),
        ),
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
      ),
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildTripActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: !isStartingTrip ? onPressed : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withOpacity(0.2)),
        ),
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
      ),
      icon: isStartingTrip 
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            )
          : Icon(icon, size: 18),
      label: Text(
        isStartingTrip ? 'Starting...' : label,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildSecondaryActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF6C757D),
        side: const BorderSide(color: Color(0xFFDEE2E6)),
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  void _showTripOptionsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Trip Options',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF212529),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.location_on, color: Color(0xFF007AFF)),
              title: const Text('Relocate on Map', style: TextStyle(color: Color(0xFF212529))),
              onTap: () {
                Navigator.pop(context);
                // Add relocate functionality
              },
            ),
            ListTile(
              leading: const Icon(Icons.report_problem, color: Color(0xFFFF9500)),
              title: const Text('Report Issue', style: TextStyle(color: Color(0xFF212529))),
              onTap: () {
                Navigator.pop(context);
                _showReportIssueDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0277BD)),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
          const SizedBox(height: 16),
          const Text(
            'Unable to load driver information',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Please check your connection and try again',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadDriverData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Consumer<LocationTrackingService>(
      builder: (context, locationService, child) {
        // Get live data from current trip
        final currentTripDistance = locationService.totalDistance / 1000; // Convert to km
        final currentTripDuration = locationService.tripStartTime != null 
            ? DateTime.now().difference(locationService.tripStartTime!).inMinutes
            : 0;
        
        // Combine with today's stats
        final totalTrips = (todayStats['totalTrips'] ?? 0) + (currentTrip != null ? 1 : 0);
        final totalDistance = (todayStats['totalDistanceKm'] ?? 0.0) + currentTripDistance;
        final totalTime = (todayStats['totalDurationMinutes'] ?? 0) + currentTripDuration;
        
        return Row(
          children: [
            Expanded(child: _buildStatCard(
              'Trips Today',
              '$totalTrips',
              Icons.route_outlined,
              const Color(0xFF10B981),
            )),
            const SizedBox(width: 12),
            Expanded(child: _buildStatCard(
              'Distance',
              '${totalDistance.toStringAsFixed(1)} km',
              Icons.straighten_outlined,
              const Color(0xFF3B82F6),
            )),
            const SizedBox(width: 12),
            Expanded(child: _buildStatCard(
              'Time',
              '${totalTime.toInt()} min',
              Icons.schedule_outlined,
              const Color(0xFF8B5CF6),
            )),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentTripCard() {
    if (currentTrip == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.access_time_outlined,
                size: 32,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Active Trip',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start your assigned route when ready',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF007AFF).withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.play_circle_filled, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Trip In Progress',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  currentTrip!.status.name.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (currentTrip!.route != null) ...[
            Text(
              currentTrip!.route!.routeName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${currentTrip!.route!.startName} → ${currentTrip!.route!.endName}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14,
              ),
            ),
          ],
          const SizedBox(height: 20),
          // Live tracking map for active trips
          if (currentTrip!.status == TripStatus.active) ...[
            Container(
              height: 300, // Increased map size
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: LiveTrackingMap(currentTrip: currentTrip!),
              ),
            ),
            const SizedBox(height: 16),
            
            // Trip stats outside the map
            Consumer<LocationTrackingService>(
              builder: (context, locationService, child) {
                final currentDistance = locationService.totalDistance / 1000;
                final tripDuration = locationService.tripStartTime != null 
                    ? DateTime.now().difference(locationService.tripStartTime!)
                    : Duration.zero;
                
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF007AFF).withOpacity(0.2),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildTripInfoItem(
                          'Distance',
                          '${currentDistance.toStringAsFixed(1)} km',
                          Icons.straighten,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: Colors.white.withOpacity(0.3),
                      ),
                      Expanded(
                        child: _buildTripInfoItem(
                          'Duration',
                          _formatTripDuration(tripDuration),
                          Icons.access_time,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: Colors.white.withOpacity(0.3),
                      ),
                      Expanded(
                        child: _buildTripInfoItem(
                          'Status',
                          currentTrip!.status.name.toUpperCase(),
                          Icons.info_outline,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: currentTrip!.status == TripStatus.active 
                      ? () => _pauseTrip() 
                      : () => _resumeTrip(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: Icon(currentTrip!.status == TripStatus.active ? Icons.pause : Icons.play_arrow),
                  label: Text(currentTrip!.status == TripStatus.active ? 'Pause' : 'Resume'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _endTrip,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.stop),
                  label: const Text('End Trip'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAssignedRouteCard() {
    // Only show the assigned route
    final route = driverProfile?['assignedRoute'] as BusRoute?;
    
    if (route == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF007AFF).withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF007AFF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.route_outlined,
                size: 32,
                color: Color(0xFF007AFF),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Assigned Route',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Contact admin to get a route assigned',
              style: TextStyle(
                color: Color(0xFF8E8E93),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF007AFF).withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF007AFF).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.route,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Assigned Route',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF8E8E93),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      route.routeName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: currentTrip != null 
                      ? (currentTrip!.direction == TripDirection.inbound 
                          ? const Color(0xFF34C759).withOpacity(0.2) 
                          : const Color(0xFF007AFF).withOpacity(0.2))
                      : const Color(0xFF007AFF).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  currentTrip != null 
                      ? (currentTrip!.direction == TripDirection.inbound 
                          ? 'RETURN ACTIVE' 
                          : 'OUTBOUND ACTIVE')
                      : 'ASSIGNED',
                  style: TextStyle(
                    color: currentTrip != null 
                        ? (currentTrip!.direction == TripDirection.inbound 
                            ? const Color(0xFF34C759) 
                            : const Color(0xFF007AFF))
                        : const Color(0xFF007AFF),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2C2C2E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF007AFF).withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF007AFF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.my_location,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        currentTrip?.direction == TripDirection.inbound 
                            ? route.endName // Show end as start for return trips
                            : route.startName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                Container(
                  margin: const EdgeInsets.only(left: 10),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      Row(
                        children: List.generate(
                          5,
                          (index) => Container(
                            margin: const EdgeInsets.only(right: 4),
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                              color: Color(0xFF8E8E93),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF3B30),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        currentTrip?.direction == TripDirection.inbound 
                            ? route.startName // Show start as end for return trips
                            : route.endName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Duration info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2C2C2E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF007AFF).withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.access_time,
                  size: 16,
                  color: Color(0xFF8E8E93),
                ),
                const SizedBox(width: 8),
                Text(
                  '${route.estimatedDurationMinutes ?? 30} min',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF8E8E93),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Trip control buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: (currentTrip == null && !isStartingTrip) ? _startTrip : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007AFF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                    shadowColor: const Color(0xFF007AFF).withOpacity(0.3),
                  ),
                  icon: isStartingTrip 
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.play_arrow, size: 18),
                  label: Text(
                    isStartingTrip ? 'Starting...' : 'Start Trip',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: (currentTrip == null && !isStartingTrip) ? _startInboundTrip : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF34C759),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                    shadowColor: const Color(0xFF34C759).withOpacity(0.3),
                  ),
                  icon: isStartingTrip 
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.u_turn_left, size: 18),
                  label: Text(
                    isStartingTrip ? 'Starting...' : 'Return Trip',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  'Report Issue',
                  'Report technical problems',
                  Icons.report_problem_outlined,
                  const Color(0xFFF59E0B),
                  () => _showReportIssueDialog(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionCard(
                  'Emergency',
                  'Emergency contact',
                  Icons.emergency_outlined,
                  const Color(0xFFEF4444),
                  () => _showEmergencyDialog(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  'Settings',
                  'App preferences',
                  Icons.settings_outlined,
                  const Color(0xFF64748B),
                  () => Navigator.pushNamed(context, '/driver/settings'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionCard(
                  'Help',
                  'Get support',
                  Icons.help_outline,
                  const Color(0xFF6366F1),
                  () => Navigator.pushNamed(context, '/driver/help'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startTrip() async {
    await _startTripWithDirection(TripDirection.outbound, 'Trip started successfully!');
  }

  Future<void> _startInboundTrip() async {
    await _startTripWithDirection(TripDirection.inbound, 'Return trip started successfully!');
  }

  Future<void> _startTripWithDirection(TripDirection direction, String successMessage) async {
    if (isStartingTrip) return; // Prevent multiple taps
    
    setState(() {
      isStartingTrip = true;
    });
    
    try {
      final assignedRoute = driverProfile?['assignedRoute'] as BusRoute?;
      if (assignedRoute == null) {
        throw Exception('No assigned route found');
      }
      
      // 1. FIRST: Check location permissions for background tracking
      print('🔐 Checking background location permissions before trip start...');
      final hasAllPermissions = await LocationPermissionsHandler.hasAllPermissions();
      
      if (!hasAllPermissions) {
        // Show permission dialog to user
        final shouldContinue = await _showPermissionWarningDialog();
        if (!shouldContinue) {
          setState(() => isStartingTrip = false);
          return;
        }
        print('⚠️ User chose to continue without full permissions');
      } else {
        print('✅ All background location permissions are granted');
      }
      
      // 2. Get current position before starting trip
      final locationService = Provider.of<LocationTrackingService>(context, listen: false);
      
      // Force a position update before starting
      print('🔄 Getting current position before trip start...');
      try {
        final permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
          await Geolocator.requestPermission();
        }
        
        final currentPos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
        
        print('🚌 TRIP START - Current Position: ${currentPos.latitude}, ${currentPos.longitude}');
      } catch (e) {
        print('⚠️ Could not get current position: $e');
        final cachedPos = locationService.currentPosition;
        if (cachedPos != null) {
          print('🚌 TRIP START - Using cached position: ${cachedPos.latitude}, ${cachedPos.longitude}');
        } else {
          print('🚌 TRIP START - No position available');
        }
      }
      
      // Log route coordinates based on direction
      if (direction == TripDirection.outbound) {
        print('🗺️ OUTBOUND ROUTE - Start: ${assignedRoute.startLocation.latitude}, ${assignedRoute.startLocation.longitude}');
        print('🗺️ OUTBOUND ROUTE - End: ${assignedRoute.endLocation.latitude}, ${assignedRoute.endLocation.longitude}');
      } else {
        print('🗺️ RETURN ROUTE - Start: ${assignedRoute.endLocation.latitude}, ${assignedRoute.endLocation.longitude}');
        print('🗺️ RETURN ROUTE - End: ${assignedRoute.startLocation.latitude}, ${assignedRoute.startLocation.longitude}');
      }
      
      await DriverService.startTrip(routeId: assignedRoute.id, direction: direction);
      await _loadDriverData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$successMessage\n🔔 Background tracking active - location shared even when app is closed'),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start trip: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isStartingTrip = false;
        });
      }
    }
  }

  Future<void> _pauseTrip() async {
    try {
      if (currentTrip?.id == null) {
        throw Exception('No active trip to pause');
      }
      
      await DriverService.pauseTrip(currentTrip!.id);
      await _loadDriverData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trip paused'),
            backgroundColor: Color(0xFFF59E0B),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pause trip: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _resumeTrip() async {
    try {
      if (currentTrip?.id == null) {
        throw Exception('No paused trip to resume');
      }
      
      await DriverService.resumeTrip(currentTrip!.id);
      await _loadDriverData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trip resumed'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to resume trip: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _endTrip() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Trip'),
        content: const Text('Are you sure you want to end this trip?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('End Trip'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        if (currentTrip?.id == null) {
          throw Exception('No active trip to end');
        }
        await DriverService.endTrip(currentTrip!.id);
        await _loadDriverData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Trip ended successfully'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to end trip: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AuthService>().signOut();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  void _showReportIssueDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Issue'),
        content: const Text('This feature will be available soon. Contact your admin for urgent issues.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showEmergencyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Emergency Contact'),
        content: const Text('Emergency contact feature will be available soon. Call campus security directly for immediate assistance.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  VoidCallback? _mapCenterFunction;

  void _centerMapOnCurrentPosition() {
    if (_mapCenterFunction != null) {
      _mapCenterFunction!();
    } else {
      print('📍 Map center function not available yet');
    }
  }

  void _showEmergencyOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '🚨 Emergency Actions',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.local_hospital, color: Color(0xFFFF3B30)),
              title: const Text('Medical Emergency', style: TextStyle(color: Color(0xFF212529))),
              onTap: () {
                Navigator.pop(context);
                _handleEmergency('medical');
              },
            ),
            ListTile(
              leading: const Icon(Icons.security, color: Color(0xFFF59E0B)),
              title: const Text('Security Issue', style: TextStyle(color: Color(0xFF212529))),
              onTap: () {
                Navigator.pop(context);
                _handleEmergency('security');
              },
            ),
            ListTile(
              leading: const Icon(Icons.build, color: Color(0xFF007AFF)),
              title: const Text('Vehicle Breakdown', style: TextStyle(color: Color(0xFF212529))),
              onTap: () {
                Navigator.pop(context);
                _handleEmergency('breakdown');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _handleEmergency(String type) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          'Emergency Alert Sent',
          style: const TextStyle(color: Color(0xFF212529)),
        ),
        content: Text(
          'Your $type emergency alert has been sent to campus security and administration.',
          style: const TextStyle(color: Color(0xFF8E8E93)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showPassengerCount() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '👥 Update Passenger Count',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildPassengerCountButton('0-10', '🟢'),
                _buildPassengerCountButton('11-20', '🟡'),
                _buildPassengerCountButton('21-30', '🟠'),
                _buildPassengerCountButton('30+', '🔴'),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Tap to update current passenger count',
              style: TextStyle(color: Color(0xFF8E8E93), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPassengerCountButton(String label, String indicator) {
    return ElevatedButton(
      onPressed: () {
        Navigator.pop(context);
        _updatePassengerCount(label);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFE9ECEF),
        foregroundColor: const Color(0xFF212529),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(indicator, style: const TextStyle(fontSize: 20)),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  void _updatePassengerCount(String count) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Passenger Count Updated', style: TextStyle(color: Color(0xFF212529))),
        content: Text(
          'Passenger count set to: $count',
          style: const TextStyle(color: Color(0xFF8E8E93)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showReportIssue() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '⚠️ Report Issue',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.construction, color: Color(0xFFF59E0B)),
              title: const Text('Road Construction', style: TextStyle(color: Color(0xFF212529))),
              onTap: () => _reportIssue('Road Construction'),
            ),
            ListTile(
              leading: const Icon(Icons.traffic, color: Color(0xFFFF3B30)),
              title: const Text('Heavy Traffic', style: TextStyle(color: Color(0xFF212529))),
              onTap: () => _reportIssue('Heavy Traffic'),
            ),
            ListTile(
              leading: const Icon(Icons.cloud, color: Color(0xFF007AFF)),
              title: const Text('Weather Issue', style: TextStyle(color: Color(0xFF212529))),
              onTap: () => _reportIssue('Weather Issue'),
            ),
            ListTile(
              leading: const Icon(Icons.more_horiz, color: Color(0xFF8E8E93)),
              title: const Text('Other', style: TextStyle(color: Color(0xFF212529))),
              onTap: () => _reportIssue('Other'),
            ),
          ],
        ),
      ),
    );
  }

  void _reportIssue(String issue) {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Issue Reported', style: TextStyle(color: Color(0xFF212529))),
        content: Text(
          'Thank you for reporting: $issue\nYour report has been sent to the administration.',
          style: const TextStyle(color: Color(0xFF8E8E93)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _takeBreak() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Break Time', style: TextStyle(color: Color(0xFF212529))),
        content: const Text(
          'Break mode activated. Your trip will be paused and students will be notified of the delay.',
          style: TextStyle(color: Color(0xFF8E8E93)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _pauseTrip();
            },
            child: const Text('Start Break'),
          ),
        ],
      ),
    );
  }

  void _contactSupport() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '📞 Contact Support',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.phone, color: Color(0xFF34C759)),
              title: const Text('Call Campus Security', style: TextStyle(color: Color(0xFF212529))),
              subtitle: const Text('+91 1234567890', style: TextStyle(color: Color(0xFF8E8E93))),
              onTap: () => _makeCall('+91 1234567890'),
            ),
            ListTile(
              leading: const Icon(Icons.chat, color: Color(0xFF007AFF)),
              title: const Text('Live Chat Support', style: TextStyle(color: Color(0xFF212529))),
              onTap: () => _openLiveChat(),
            ),
            ListTile(
              leading: const Icon(Icons.email, color: Color(0xFFF59E0B)),
              title: const Text('Send Email', style: TextStyle(color: Color(0xFF212529))),
              subtitle: const Text('support@campus.edu', style: TextStyle(color: Color(0xFF8E8E93))),
              onTap: () => _sendEmail(),
            ),
          ],
        ),
      ),
    );
  }

  void _makeCall(String number) {
    Navigator.pop(context);
    // In a real app, would use url_launcher to make calls
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Calling...', style: TextStyle(color: Color(0xFF212529))),
        content: Text(
          'Calling $number',
          style: const TextStyle(color: Color(0xFF8E8E93)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _openLiveChat() {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Live Chat', style: TextStyle(color: Color(0xFF212529))),
        content: const Text(
          'Live chat feature will be available soon.',
          style: TextStyle(color: Color(0xFF8E8E93)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _sendEmail() {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Email Support', style: TextStyle(color: Color(0xFF212529))),
        content: const Text(
          'Opening email client...',
          style: TextStyle(color: Color(0xFF8E8E93)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildTripInfoItem(String label, String value, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  String _formatTripDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  /// Show dialog warning about missing background location permissions
  Future<bool> _showPermissionWarningDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange.shade600),
            const SizedBox(width: 8),
            const Text('Background Location'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Some location permissions are missing for optimal background tracking.'),
            SizedBox(height: 12),
            Text('Without these permissions:'),
            Text('• Location sharing may stop when app is closed'),
            Text('• Background notifications may not work'),
            SizedBox(height: 12),
            Text('You can continue, but location tracking may be limited.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade600),
            child: const Text('Continue Anyway'),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }
}
