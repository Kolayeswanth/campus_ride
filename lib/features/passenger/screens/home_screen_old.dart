import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/bus_service.dart';
import '../../../core/models/bus_status.dart';
import '../../user/widgets/bus_status_card.dart';
import '../../user/screens/live_bus_tracking_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final BusService _busService = BusService.instance;
  List<BusStatus> _buses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBuses();
  }

  Future<void> _loadBuses() async {
    setState(() => _isLoading = true);
    
    try {
      await _busService.initialize();
      
      final authService = context.read<AuthService>();
      final collegeId = authService.userProfile?.collegeId;
      
      if (collegeId != null) {
        final buses = await _busService.fetchAllBuses(collegeId: collegeId);
        if (mounted) {
          setState(() {
            _buses = buses;
            _isLoading = false;
          });
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _navigateToLiveTracking(BusStatus bus) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LiveBusTrackingScreen(bus: bus),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().userProfile;
    final displayName = user?.displayName ?? 'User';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Hello $displayName',
            style: const TextStyle(
              color: Colors.black,
              fontSize: 24,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite, color: Colors.red),
            onPressed: () {
              Navigator.pushNamed(context, '/user/favorites');
            },
          ),
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black54),
            onPressed: () {
              Navigator.pushNamed(context, '/user/dashboard');
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadBuses,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // Bus Cards List
                  if (_buses.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text(
                          'No buses available',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    ..._buses.map((bus) => Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: BusStatusCard(
                            bus: bus,
                            onTap: () => _navigateToLiveTracking(bus),
                            margin: EdgeInsets.zero,
                          ),
                        )),
                ],
              ),
            ),
    );
  }
}
