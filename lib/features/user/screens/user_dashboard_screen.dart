import 'dart:async';
import 'package:flutter/material.dart';

import '../../../core/models/bus_status.dart';
import '../../../core/services/bus_service.dart';
import '../widgets/search_bar_widget.dart';
import '../widgets/bus_status_card.dart';
import 'live_bus_tracking_screen.dart';

class UserDashboardScreen extends StatefulWidget {
  const UserDashboardScreen({super.key});

  @override
  State<UserDashboardScreen> createState() => _UserDashboardScreenState();
}

class _UserDashboardScreenState extends State<UserDashboardScreen>
    with TickerProviderStateMixin {
  final BusService _busService = BusService.instance;
  final TextEditingController _searchController = TextEditingController();
  
  late TabController _tabController;
  StreamSubscription<List<BusStatus>>? _busStatusSubscription;
  
  List<BusStatus> _allBuses = [];
  List<BusStatus> _filteredBuses = [];
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadBuses();
  }

  Future<void> _loadBuses() async {
    setState(() => _isLoading = true);
    
    try {
      await _busService.initialize();
      final buses = await _busService.fetchAllBuses();
      
      if (mounted) {
        setState(() {
          _allBuses = buses;
          _filteredBuses = buses;
          _isLoading = false;
        });
      }
      
      // Listen to real-time updates
      _busStatusSubscription = _busService.busStatusStream.listen((buses) {
        if (mounted) {
          setState(() {
            _allBuses = buses;
            _filterBuses();
          });
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Failed to load buses: $e');
      }
    }
  }

  Future<void> _refreshBuses() async {
    try {
      final buses = await _busService.fetchAllBuses();
      setState(() {
        _allBuses = buses;
        _filterBuses();
      });
    } catch (e) {
      _showErrorSnackBar('Failed to refresh: $e');
    }
  }

  void _filterBuses() {
    if (_searchQuery.isEmpty) {
      _filteredBuses = _allBuses;
    } else {
      _filteredBuses = _busService.searchBuses(_searchQuery);
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _filterBuses();
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _navigateToLiveTracking(BusStatus bus) async {
    if (!bus.isActive || !bus.isOnline) {
      _showErrorSnackBar('Bus is currently offline');
      return;
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LiveBusTrackingScreen(bus: bus),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            // Header with search and status
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Campus Buses',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1A1D29),
                              letterSpacing: -1.2,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Track your college buses in real-time',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF6B7280),
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          // Live indicator
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFF10B981).withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${_allBuses.where((bus) => bus.isActive && bus.isOnline).length} live',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Refresh button
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF4F46E5).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              onPressed: _refreshBuses,
                              icon: const Icon(
                                Icons.refresh_rounded,
                                color: Color(0xFF4F46E5),
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Status Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatusCard(
                          title: 'Active Buses',
                          count: _allBuses.where((bus) => bus.isActive && bus.isOnline).length,
                          icon: Icons.directions_bus_rounded,
                          color: const Color(0xFF10B981),
                          subtitle: 'Currently running',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatusCard(
                          title: 'Total Routes',
                          count: _allBuses.map((bus) => bus.route.routeName).toSet().length,
                          icon: Icons.route_rounded,
                          color: const Color(0xFF3B82F6),
                          subtitle: 'Available routes',
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Search bar
                  SearchBarWidget(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    hintText: 'Search routes, bus numbers...',
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Status summary
                  if (!_isLoading) _buildStatusSummary(),
                ],
              ),
            ),
            
            // Tabs
            Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                labelColor: const Color(0xFF4F46E5),
                unselectedLabelColor: const Color(0xFF6B7280),
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
                indicatorColor: const Color(0xFF4F46E5),
                indicatorWeight: 3,
                indicatorSize: TabBarIndicatorSize.tab,
                tabs: const [
                  Tab(text: 'Active'),
                  Tab(text: 'Offline'),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: _isLoading 
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Loading buses...',
                            style: TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildBusList(true), // Active buses
                        _buildBusList(false), // Offline buses
                      ],
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: Implement quick actions like favorites, notifications
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Quick actions coming soon!'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        backgroundColor: const Color(0xFF4F46E5),
        foregroundColor: Colors.white,
        elevation: 8,
        icon: const Icon(Icons.star_rounded),
        label: const Text(
          'Favorites',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
              const Spacer(),
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: color,
                  height: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF6B7280),
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSummary() {
    final activeBuses = _allBuses.where((bus) => bus.isActive && bus.isOnline).length;
    final totalBuses = _allBuses.length;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF4F46E5).withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF4F46E5).withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5).withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              color: Color(0xFF4F46E5),
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$activeBuses of $totalBuses buses are currently active',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4F46E5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusList(bool isActive) {
    final buses = _filteredBuses.where((bus) {
      if (isActive) {
        return bus.isActive && bus.isOnline;
      } else {
        return !bus.isActive || !bus.isOnline;
      }
    }).toList();

    if (buses.isEmpty) {
      return _buildEmptyState(isActive);
    }

    return RefreshIndicator(
      onRefresh: _refreshBuses,
      color: const Color(0xFF4F46E5),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 16),
        itemCount: buses.length,
        itemBuilder: (context, index) {
          final bus = buses[index];
          return BusStatusCard(
            bus: bus,
            onTap: () => _navigateToLiveTracking(bus),
            margin: const EdgeInsets.only(bottom: 12),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isActive) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF6B7280).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isActive ? Icons.directions_bus_rounded : Icons.schedule_rounded,
              size: 48,
              color: const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isActive ? 'No active buses found' : 'All buses are currently active',
            style: const TextStyle(
              color: Color(0xFF1A1D29),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isActive 
              ? 'Check back later for live bus updates'
              : 'Great! All buses are running smoothly',
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (_searchQuery.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Try adjusting your search terms',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    _busStatusSubscription?.cancel();
    super.dispose();
  }
}