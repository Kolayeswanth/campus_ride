import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/trip_service.dart';
import '../../core/services/background_location_service.dart';
import '../../core/services/location_permissions_handler.dart';
import '../../core/models/driver_trip.dart';

/// Enhanced Driver Dashboard with Background Location Management
class EnhancedDriverDashboard extends StatefulWidget {
  const EnhancedDriverDashboard({super.key});

  @override
  State<EnhancedDriverDashboard> createState() => _EnhancedDriverDashboardState();
}

class _EnhancedDriverDashboardState extends State<EnhancedDriverDashboard> 
    with WidgetsBindingObserver {
  bool _hasPermissions = false;
  bool _isCheckingPermissions = true;
  Map<String, dynamic>? _activeTripInfo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissionsAndActiveTrip();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // Check permissions when app comes back to foreground
    if (state == AppLifecycleState.resumed) {
      _checkPermissionsAndActiveTrip();
    }
  }

  Future<void> _checkPermissionsAndActiveTrip() async {
    setState(() => _isCheckingPermissions = true);
    
    try {
      // Check permissions
      final hasPermissions = await LocationPermissionsHandler.hasAllPermissions();
      
      // Check for active background trip
      final activeTripInfo = await BackgroundLocationService.getActiveTripInfo();
      
      setState(() {
        _hasPermissions = hasPermissions;
        _activeTripInfo = activeTripInfo;
        _isCheckingPermissions = false;
      });
    } catch (e) {
      setState(() {
        _isCheckingPermissions = false;
      });
      print('❌ Error checking permissions and active trip: $e');
    }
  }

  Future<void> _requestPermissions() async {
    final granted = await LocationPermissionsHandler.requestAllPermissions(context);
    if (granted) {
      setState(() {
        _hasPermissions = true;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ All permissions granted! Background tracking is ready.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _startTrip() async {
    if (!_hasPermissions) {
      await _requestPermissions();
      return;
    }

    final tripService = context.read<TripService>();
    
    // Show route selection dialog
    await _showRouteSelectionDialog(tripService);
  }

  Future<void> _showRouteSelectionDialog(TripService tripService) async {
    await tripService.fetchDriverRoutes();
    final routes = tripService.routes;

    if (routes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No routes available. Please contact admin.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (mounted) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Route'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: routes.map((route) => ListTile(
              title: Text(route.routeName),
              subtitle: Text('${route.startLocation.name} → ${route.endLocation.name}'),
              onTap: () async {
                Navigator.of(context).pop();
                await _startTripForRoute(tripService, route.id);
              },
            )).toList(),
          ),
        ),
      );
    }
  }

  Future<void> _startTripForRoute(TripService tripService, String routeId) async {
    try {
      setState(() => _isCheckingPermissions = true);
      
      // Start the trip (this will automatically start background tracking)
      final trip = await tripService.startDriverTrip(routeId);
      
      if (trip != null) {
        await _checkPermissionsAndActiveTrip();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🚌 Trip started! Location tracking active even when app is closed.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to start trip: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isCheckingPermissions = false);
    }
  }

  Future<void> _endTrip() async {
    final confirmed = await _showEndTripConfirmation();
    if (!confirmed) return;

    try {
      setState(() => _isCheckingPermissions = true);
      
      final tripService = context.read<TripService>();
      final success = await tripService.endDriverTrip();
      
      if (success) {
        await _checkPermissionsAndActiveTrip();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🏁 Trip ended successfully. Background tracking stopped.'),
              backgroundColor: Colors.blue,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to end trip: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isCheckingPermissions = false);
    }
  }

  Future<bool> _showEndTripConfirmation() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Trip?'),
        content: const Text('Are you sure you want to end the current trip? This will stop location tracking.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('End Trip'),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Driver Dashboard'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showPermissionStatus,
          ),
        ],
      ),
      body: _isCheckingPermissions
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Checking permissions and active trips...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildPermissionCard(),
                  const SizedBox(height: 16),
                  _buildTripStatusCard(),
                  const SizedBox(height: 16),
                  _buildActionButtons(),
                ],
              ),
            ),
    );
  }

  Widget _buildPermissionCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _hasPermissions ? Colors.green.shade100 : Colors.orange.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _hasPermissions ? Icons.check_circle : Icons.warning,
                    color: _hasPermissions ? Colors.green.shade700 : Colors.orange.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Background Location',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      Text(
                        _hasPermissions 
                            ? 'Ready for background tracking'
                            : 'Permissions needed for background tracking',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (!_hasPermissions) ...[
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _requestPermissions,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade600,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Grant Permissions'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTripStatusCard() {
    final hasActiveTrip = _activeTripInfo != null;
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: hasActiveTrip ? Colors.blue.shade100 : Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    hasActiveTrip ? Icons.directions_bus : Icons.bus_alert,
                    color: hasActiveTrip ? Colors.blue.shade700 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasActiveTrip ? 'Active Trip' : 'No Active Trip',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      Text(
                        hasActiveTrip 
                            ? _activeTripInfo!['routeName'] ?? 'Campus Route'
                            : 'Start a trip to begin tracking',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (hasActiveTrip) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Background tracking active - your location is being shared even when the app is closed',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    final hasActiveTrip = _activeTripInfo != null;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!hasActiveTrip)
          ElevatedButton.icon(
            onPressed: _hasPermissions ? _startTrip : _requestPermissions,
            icon: Icon(_hasPermissions ? Icons.play_arrow : Icons.warning),
            label: Text(_hasPermissions ? 'Start Trip' : 'Setup Permissions First'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _hasPermissions ? Colors.green.shade600 : Colors.orange.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        if (hasActiveTrip)
          ElevatedButton.icon(
            onPressed: _endTrip,
            icon: const Icon(Icons.stop),
            label: const Text('End Trip'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
      ],
    );
  }

  Future<void> _showPermissionStatus() async {
    final status = await LocationPermissionsHandler.getPermissionStatus();
    
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Permission Status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: status.entries.map((entry) => 
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        '${entry.key}:',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        entry.value,
                        style: TextStyle(
                          color: entry.value.contains('granted') 
                              ? Colors.green.shade700 
                              : Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }
}