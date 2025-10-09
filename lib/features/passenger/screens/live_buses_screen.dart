import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/realtime_service.dart';
import '../../../core/services/trip_service.dart';
import '../../../core/services/favorites_service.dart';
import 'bus_tracking_screen.dart';

class LiveBusesScreen extends StatefulWidget {
  const LiveBusesScreen({super.key});

  @override
  State<LiveBusesScreen> createState() => _LiveBusesScreenState();
}

class _LiveBusesScreenState extends State<LiveBusesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RealtimeService>().loadInitialData();
      context.read<TripService>().loadRoutes();
      context.read<FavoritesService>().loadFavorites();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            backgroundColor: Theme.of(context).colorScheme.primary,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'Live Buses',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.secondary,
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Stats Card
                Consumer<RealtimeService>(
                  builder: (context, realtimeService, child) {
                    final stats = realtimeService.getActiveTripsStats();
                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Expanded(
                              child: _StatItem(
                                icon: Icons.directions_bus,
                                title: 'Active Buses',
                                value: '${stats['total_active_trips'] ?? 0}',
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            Container(
                              height: 40,
                              width: 1,
                              color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                            ),
                            Expanded(
                              child: _StatItem(
                                icon: Icons.route,
                                title: 'Routes',
                                value: '${stats['routes_in_use'] ?? 0}',
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                            ),
                            Container(
                              height: 40,
                              width: 1,
                              color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                            ),
                            Expanded(
                              child: _StatItem(
                                icon: Icons.gps_fixed,
                                title: 'Live',
                                value: '${stats['trips_with_recent_location'] ?? 0}',
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),

                // Active Buses Section
                Row(
                  children: [
                    Icon(
                      Icons.radio_button_checked,
                      color: Colors.green,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Active Buses',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Live Buses List
                Consumer2<RealtimeService, TripService>(
                  builder: (context, realtimeService, tripService, child) {
                    final activeTrips = realtimeService.activeTrips;
                    
                    if (activeTrips.isEmpty) {
                      return Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Icon(
                                Icons.directions_bus_outlined,
                                size: 64,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No active buses',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'All buses are currently offline. Check back later!',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    
                    return Column(
                      children: activeTrips.entries.map((entry) {
                        final tripId = entry.key;
                        final tripData = entry.value;
                        final locationData = realtimeService.getLatestDriverLocation(tripId);
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _BusCard(
                            tripId: tripId,
                            tripData: tripData,
                            locationData: locationData,
                            onTrack: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => BusTrackingScreen(
                                    tripId: tripId,
                                    tripData: tripData,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 20),

                // All Routes Section
                Text(
                  'All Routes',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                
                Consumer<TripService>(
                  builder: (context, tripService, child) {
                    final routes = tripService.routes;
                    
                    if (routes.isEmpty) {
                      return Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Icon(
                                Icons.route_outlined,
                                size: 64,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No routes available',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Routes will appear here when they become available.',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    
                    return Column(
                      children: routes.map((route) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _RouteCard(route: route),
                        );
                      }).toList(),
                    );
                  },
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          title,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _BusCard extends StatelessWidget {
  final String tripId;
  final Map<String, dynamic> tripData;
  final Map<String, dynamic>? locationData;
  final VoidCallback onTrack;

  const _BusCard({
    required this.tripId,
    required this.tripData,
    this.locationData,
    required this.onTrack,
  });

  @override
  Widget build(BuildContext context) {
    final routeName = tripData['bus_routes']?['route_name'] ?? 'Unknown Route';
    final isLive = locationData?['is_recent'] == true;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTrack,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isLive ? Colors.green.withOpacity(0.1) : Theme.of(context).colorScheme.surfaceVariant,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.directions_bus,
                  color: isLive ? Colors.green : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            routeName,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (isLive) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'LIVE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isLive ? 'Currently active' : 'Last seen ${_getTimeAgo(locationData)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getTimeAgo(Map<String, dynamic>? locationData) {
    if (locationData == null) return 'unknown';
    
    final ageSeconds = locationData['age_seconds'] as int? ?? 0;
    if (ageSeconds < 60) return '${ageSeconds}s ago';
    if (ageSeconds < 3600) return '${(ageSeconds / 60).round()}m ago';
    return '${(ageSeconds / 3600).round()}h ago';
  }
}

class _RouteCard extends StatelessWidget {
  final dynamic route;

  const _RouteCard({required this.route});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.route,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          route.routeName,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Consumer<FavoritesService>(
                        builder: (context, favService, _) {
                          final isFavorite = favService.isFavorite(route.id);
                          return IconButton(
                            onPressed: () async {
                              await favService.toggleFavorite(
                                route.id,
                                nickname: route.routeName,
                              );
                              
                              // Show feedback to user
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      isFavorite 
                                        ? 'Removed from favorites'
                                        : 'Added to favorites',
                                    ),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                            icon: Icon(
                              isFavorite ? Icons.favorite : Icons.favorite_border,
                              color: isFavorite ? Colors.red : Colors.grey,
                            ),
                            iconSize: 20,
                          );
                        },
                      ),
                    ],
                  ),
                  Text(
                    '${route.startName} → ${route.endName}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Offline',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
