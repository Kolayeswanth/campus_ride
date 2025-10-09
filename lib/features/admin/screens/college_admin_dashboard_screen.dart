import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/college_admin_service.dart';
import 'add_route_screen.dart';

class CollegeAdminDashboardScreen extends StatefulWidget {
  const CollegeAdminDashboardScreen({super.key});

  @override
  State<CollegeAdminDashboardScreen> createState() => _CollegeAdminDashboardScreenState();
}

class _CollegeAdminDashboardScreenState extends State<CollegeAdminDashboardScreen> with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Consumer<AuthService>(
          builder: (context, authService, _) {
            final profile = authService.userProfile;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'College Admin',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Welcome, ${profile?.displayName ?? 'Admin'}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            );
          },
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 80,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () {
              // Handle notifications
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              if (value == 'logout') {
                _showSignOutDialog();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout),
                    SizedBox(width: 8),
                    Text('Sign Out'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
            Tab(icon: Icon(Icons.people), text: 'Drivers'),
            Tab(icon: Icon(Icons.route), text: 'Routes'),
            Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const _OverviewTabContent(),
          const _DriversTabContent(),
          _RoutesTabContent(tabController: _tabController),
          const _AnalyticsTabContent(),
        ],
      ),
    );
  }

  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.read<AuthService>().signOut();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

// Overview Tab with Live Data
class _OverviewTabContent extends StatefulWidget {
  const _OverviewTabContent();

  @override
  State<_OverviewTabContent> createState() => _OverviewTabContentState();
}

class _OverviewTabContentState extends State<_OverviewTabContent> {
  Map<String, dynamic> stats = {};
  List<Map<String, dynamic>> activities = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    print('📊 Loading dashboard stats...');
    final dashboardStats = await CollegeAdminService.getDashboardStats();
    final recentActivities = await CollegeAdminService.getRecentActivity();
    
    print('📊 Dashboard Stats: $dashboardStats');
    print('📊 Activities count: ${recentActivities.length}');
    print('📊 Active Drivers value: ${dashboardStats['activeDrivers']}');
    print('📊 Total Routes value: ${dashboardStats['totalRoutes']}');
    
    if (mounted) {
      setState(() {
        stats = dashboardStats;
        activities = recentActivities;
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quick Stats
            isLoading
                ? const Center(child: CircularProgressIndicator())
                : GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.2,
                    children: [
                      _StatCard(
                        title: 'Active Drivers',
                        value: '${stats['activeDrivers'] ?? 0}',
                        icon: Icons.person,
                        color: Colors.blue,
                      ),
                      _StatCard(
                        title: 'Bus Routes',
                        value: '${stats['totalRoutes'] ?? 0}',
                        icon: Icons.route,
                        color: Colors.green,
                      ),
                      _StatCard(
                        title: 'Active Trips',
                        value: '${stats['activeTrips'] ?? 0}',
                        icon: Icons.directions_bus,
                        color: Colors.orange,
                      ),
                      _StatCard(
                        title: 'Total Students',
                        value: '${stats['totalStudents'] ?? 0}',
                        icon: Icons.school,
                        color: Colors.purple,
                      ),
                    ],
                  ),

            const SizedBox(height: 24),

            // Recent Activity
            Text(
              'Recent Activity',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : activities.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Center(child: Text('No recent activity')),
                        )
                      : Column(
                          children: activities.asMap().entries.map((entry) {
                            int index = entry.key;
                            var activity = entry.value;
                            return Column(
                              children: [
                                ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: _getColorFromString(activity['color']).withOpacity(0.1),
                                    child: Icon(
                                      _getIconData(activity['icon']),
                                      color: _getColorFromString(activity['color']),
                                    ),
                                  ),
                                  title: Text(activity['title']),
                                  subtitle: Text(activity['subtitle']),
                                  trailing: Text(
                                    activity['time'],
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ),
                                if (index < activities.length - 1) 
                                  const Divider(height: 1),
                              ],
                            );
                          }).toList(),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'person_add':
        return Icons.person_add;
      case 'route':
        return Icons.route;
      case 'check_circle':
        return Icons.check_circle;
      default:
        return Icons.info;
    }
  }

  Color _getColorFromString(String colorName) {
    switch (colorName) {
      case 'green':
        return Colors.green;
      case 'blue':
        return Colors.blue;
      case 'orange':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}

// Drivers Tab with Live Data
class _DriversTabContent extends StatefulWidget {
  const _DriversTabContent();

  @override
  State<_DriversTabContent> createState() => _DriversTabContentState();
}

class _DriversTabContentState extends State<_DriversTabContent> {
  List<Map<String, dynamic>> drivers = [];
  List<Map<String, dynamic>> filteredDrivers = [];
  final TextEditingController _searchController = TextEditingController();
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDrivers();
    _searchController.addListener(_filterDrivers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDrivers() async {
    setState(() => isLoading = true);
    final collegeDrivers = await CollegeAdminService.getCollegeDrivers();
    if (mounted) {
      setState(() {
        drivers = collegeDrivers;
        filteredDrivers = collegeDrivers;
        isLoading = false;
      });
    }
  }

  void _filterDrivers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      filteredDrivers = drivers.where((driver) {
        return driver['name'].toString().toLowerCase().contains(query) ||
               driver['email'].toString().toLowerCase().contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadDrivers,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Add Driver button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Drivers (${filteredDrivers.length})',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _showAddDriverDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Driver'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Search Bar
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search drivers by name or email...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
              ),
            ),
            const SizedBox(height: 16),
            
            // Drivers List
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredDrivers.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _searchController.text.isNotEmpty 
                                    ? Icons.search_off 
                                    : Icons.people_outline,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchController.text.isNotEmpty 
                                    ? 'No drivers found matching "${_searchController.text}"'
                                    : 'No drivers found',
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: Colors.grey[600],
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if (_searchController.text.isEmpty) ...[
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: _showAddDriverDialog,
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add First Driver'),
                                ),
                              ],
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: filteredDrivers.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final driver = filteredDrivers[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: driver['isActive'] 
                                      ? Colors.green.withOpacity(0.1)
                                      : Colors.grey.withOpacity(0.1),
                                  child: Icon(
                                    Icons.person,
                                    color: driver['isActive'] ? Colors.green : Colors.grey,
                                  ),
                                ),
                                title: Text(
                                  driver['name'],
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  driver['isActive'] ? 'Active Driver' : 'Inactive Driver',
                                  style: TextStyle(
                                    color: driver['isActive'] ? Colors.green : Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                                trailing: const Icon(Icons.more_vert, size: 20),
                                onTap: () => _showDriverOptions(driver),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDriverDetails(Map<String, dynamic> driver) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: driver['isActive'] 
                  ? Colors.green.withOpacity(0.1)
                  : Colors.grey.withOpacity(0.1),
              child: Icon(
                Icons.person,
                color: driver['isActive'] ? Colors.green : Colors.grey,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                driver['name'],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: driver['isActive'] 
                      ? Colors.green.withOpacity(0.1)
                      : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      driver['isActive'] ? Icons.check_circle : Icons.cancel,
                      color: driver['isActive'] ? Colors.green : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      driver['isActive'] ? 'Active Driver' : 'Inactive Driver',
                      style: TextStyle(
                        color: driver['isActive'] ? Colors.green : Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Contact Information
              _buildDetailRow(Icons.email, 'Email', driver['email']),
              const SizedBox(height: 12),
              
              if (driver['phone'].toString().isNotEmpty) ...[
                _buildDetailRow(Icons.phone, 'Phone', driver['phone']),
                const SizedBox(height: 12),
              ],
              
              _buildDetailRow(Icons.calendar_today, 'Joined', driver['joinDate']),
              const SizedBox(height: 12),
              
              if (driver['licenseNumber'] != null && driver['licenseNumber'].toString().isNotEmpty) ...[
                _buildDetailRow(Icons.credit_card, 'License', driver['licenseNumber']),
                const SizedBox(height: 12),
              ],
              
              if (driver['experience'] != null) ...[
                _buildDetailRow(Icons.work, 'Experience', '${driver['experience']} years'),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showDriverOptions(driver);
            },
            child: const Text('Actions'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showAddDriverDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final phoneController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add New Driver'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email Address *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                    helperText: 'Minimum 6 characters',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number (Optional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'The driver will receive login credentials via email.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading ? null : () async {
                if (nameController.text.trim().isEmpty ||
                    emailController.text.trim().isEmpty ||
                    passwordController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill in all required fields'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                if (passwordController.text.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Password must be at least 6 characters'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                setDialogState(() => isLoading = true);

                try {
                  final result = await CollegeAdminService.addDriver(
                    name: nameController.text.trim(),
                    email: emailController.text.trim(),
                    password: passwordController.text,
                    phone: phoneController.text.trim(),
                  );

                  if (result['success'] == true) {
                    Navigator.pop(context);
                    
                    // Show success message with temporary password
                    final tempPassword = result['temp_password'];
                    if (tempPassword != null) {
                      _showTempPasswordDialog(context, nameController.text.trim(), tempPassword);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Driver added successfully!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                    _loadDrivers(); // Refresh the list
                  } else {
                    final errorMessage = result['error'] ?? 'Failed to add driver. Please try again.';
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(errorMessage),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                } finally {
                  setDialogState(() => isLoading = false);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Add Driver'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDriverOptions(Map<String, dynamic> driver) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              driver['name'],
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.blue),
              title: const Text('Edit Driver'),
              onTap: () {
                Navigator.pop(context);
                _showEditDriverDialog(driver);
              },
            ),
            ListTile(
              leading: Icon(
                driver['isActive'] ? Icons.block : Icons.check_circle,
                color: driver['isActive'] ? Colors.red : Colors.green,
              ),
              title: Text(driver['isActive'] ? 'Deactivate Driver' : 'Activate Driver'),
              onTap: () {
                Navigator.pop(context);
                _toggleDriverStatus(driver);
              },
            ),
            ListTile(
              leading: const Icon(Icons.route, color: Colors.orange),
              title: Text(driver['assignedRoute'] != null ? 'Manage Route' : 'Assign Route'),
              onTap: () {
                Navigator.pop(context);
                _showAssignRouteDialog(driver);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Remove Driver'),
              onTap: () {
                Navigator.pop(context);
                _showRemoveDriverDialog(driver);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDriverDialog(Map<String, dynamic> driver) {
    final nameController = TextEditingController(text: driver['name']);
    final emailController = TextEditingController(text: driver['email']);
    final phoneController = TextEditingController(text: driver['phone']);
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          title: Row(
            children: [
              const Icon(Icons.edit, color: Colors.blue, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Edit Driver',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email Address *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading ? null : () async {
                if (nameController.text.trim().isEmpty || 
                    emailController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill all required fields')),
                  );
                  return;
                }

                setDialogState(() => isLoading = true);
                
                try {
                  final success = await CollegeAdminService.updateDriver(
                    driverId: driver['id'],
                    name: nameController.text.trim(),
                    email: emailController.text.trim(),
                    phone: phoneController.text.trim(),
                  );

                  if (success) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Driver updated successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    _loadDrivers(); // Refresh the list
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Failed to update driver'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                } finally {
                  setDialogState(() => isLoading = false);
                }
              },
              child: isLoading 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleDriverStatus(Map<String, dynamic> driver) async {
    try {
      final success = await CollegeAdminService.toggleDriverStatus(driver['id']);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              driver['isActive'] 
                  ? 'Driver deactivated successfully' 
                  : 'Driver activated successfully'
            ),
            backgroundColor: Colors.green,
          ),
        );
        _loadDrivers(); // Refresh the list
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update driver status'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showAssignRouteDialog(Map<String, dynamic> driver) {
    showDialog(
      context: context,
      builder: (context) => _RouteAssignmentDialog(
        driver: driver,
        onRouteAssigned: () {
          _loadDrivers(); // Refresh the list
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Route assignment updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        },
      ),
    );
  }

  void _showRemoveDriverDialog(Map<String, dynamic> driver) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Driver'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to remove ${driver['name']} from your college?',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                border: Border.all(color: Colors.red.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red.shade600, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'This will:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Delete driver profile permanently\n• Remove any assigned routes\n• This action cannot be undone',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.red.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final result = await CollegeAdminService.removeDriver(driver['id']);
                
                // Check if widget is still mounted before showing SnackBar
                if (mounted) {
                  if (result['success'] == true) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result['message'] ?? 'Driver removed successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    _loadDrivers(); // Refresh the list
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result['error'] ?? 'Failed to remove driver'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove Driver'),
          ),
        ],
      ),
    );
  }

  void _showTempPasswordDialog(BuildContext context, String driverName, String tempPassword) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 12),
              Expanded(child: Text('Driver Added Successfully')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Driver "$driverName" has been created successfully.',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  border: Border.all(color: Colors.orange.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Temporary Password',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    SelectableText(
                      tempPassword,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Please share this password with the driver. They should change it after first login.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                // Copy to clipboard
                Clipboard.setData(ClipboardData(text: tempPassword));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Password copied to clipboard'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.copy, size: 16),
                  SizedBox(width: 4),
                  Text('Copy Password'),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Driver $driverName added successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: Text('Done'),
            ),
          ],
        );
      },
    );
  }
}

// Routes Tab with Live Data
class _RoutesTabContent extends StatefulWidget {
  final TabController? tabController;
  
  const _RoutesTabContent({this.tabController});

  @override
  State<_RoutesTabContent> createState() => _RoutesTabContentState();
}

class _RoutesTabContentState extends State<_RoutesTabContent> {
  List<Map<String, dynamic>> routes = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    final collegeRoutes = await CollegeAdminService.getCollegeRoutes();
    if (mounted) {
      setState(() {
        routes = collegeRoutes;
        isLoading = false;
      });
    }
  }

  Future<void> _navigateToAddRoute() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddRouteScreen(),
      ),
    );

    // Handle result from AddRouteScreen
    if (result is Map<String, dynamic> && result['success'] == true) {
      // Refresh the routes list
      _loadRoutes();
      
      // Switch to Routes tab if tabController is available
      if (widget.tabController != null && result['tab'] != null) {
        widget.tabController!.animateTo(result['tab']);
      }
      
      // Show success message
      if (result['message'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    result['message'],
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else if (result == true) {
      // Fallback for old format
      _loadRoutes();
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadRoutes,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Bus Routes (${routes.length})',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _navigateToAddRoute(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('Add Route'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : routes.isEmpty
                      ? const Center(child: Text('No routes found'))
                      : ListView.separated(
                          itemCount: routes.length,
                          separatorBuilder: (context, index) => const Divider(),
                          itemBuilder: (context, index) {
                            final route = routes[index];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: route['isActive'] 
                                    ? Colors.blue.withOpacity(0.1)
                                    : Colors.grey.withOpacity(0.1),
                                child: Icon(
                                  Icons.route,
                                  color: route['isActive'] ? Colors.blue : Colors.grey,
                                ),
                              ),
                              title: Text(route['routeName']),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (route['routeCode'].isNotEmpty)
                                    Text('Code: ${route['routeCode']}'),
                                  Text('${route['startName']} → ${route['endName']}'),
                                ],
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: route['isActive'] 
                                      ? Colors.green.withOpacity(0.1)
                                      : Colors.grey.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  route['isActive'] ? 'Active' : 'Inactive',
                                  style: TextStyle(
                                    color: route['isActive'] ? Colors.green : Colors.grey,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              isThreeLine: true,
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// Analytics Tab with Live Data
class _AnalyticsTabContent extends StatefulWidget {
  const _AnalyticsTabContent();

  @override
  State<_AnalyticsTabContent> createState() => _AnalyticsTabContentState();
}

class _AnalyticsTabContentState extends State<_AnalyticsTabContent> {
  Map<String, dynamic> analytics = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    final analyticsData = await CollegeAdminService.getAnalyticsData();
    if (mounted) {
      setState(() {
        analytics = analyticsData;
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadAnalytics,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Analytics (Last 30 Days)',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            isLoading
                ? const Center(child: CircularProgressIndicator())
                : GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.8,
                    children: [
                      _StatCard(
                        title: 'Total Trips',
                        value: '${analytics['totalTrips'] ?? 0}',
                        icon: Icons.directions_bus,
                        color: Colors.blue,
                      ),
                      _StatCard(
                        title: 'Avg Duration',
                        value: '${analytics['averageDuration'] ?? 0}m',
                        icon: Icons.timer,
                        color: Colors.green,
                      ),
                      _StatCard(
                        title: 'Total Distance',
                        value: '${(analytics['totalDistance'] ?? 0.0).toStringAsFixed(1)}km',
                        icon: Icons.straighten,
                        color: Colors.orange,
                      ),
                      _StatCard(
                        title: 'Avg Passengers',
                        value: '${analytics['averagePassengers'] ?? 0}',
                        icon: Icons.people,
                        color: Colors.purple,
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }
}

// Helper Widget
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    print('🏷️ StatCard - Title: $title, Value: $value'); // Debug print
    return Card(
      elevation: 2,
      color: color.withOpacity(0.9), // Dark card background
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top row with icon
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Colors.white, size: 14),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Value (large number) - flexible size
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 4),
            
            // Title (description) - flexible size
            Flexible(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteAssignmentDialog extends StatefulWidget {
  final Map<String, dynamic> driver;
  final VoidCallback onRouteAssigned;

  const _RouteAssignmentDialog({
    required this.driver,
    required this.onRouteAssigned,
  });

  @override
  State<_RouteAssignmentDialog> createState() => _RouteAssignmentDialogState();
}

class _RouteAssignmentDialogState extends State<_RouteAssignmentDialog> {
  List<Map<String, dynamic>> availableRoutes = [];
  Map<String, dynamic>? selectedRoute;
  bool isLoading = true;
  bool isAssigning = false;

  @override
  void initState() {
    super.initState();
    _loadAvailableRoutes();
  }

  Future<void> _loadAvailableRoutes() async {
    try {
      final routes = await CollegeAdminService.getUnassignedRoutes();
      if (mounted) {
        setState(() {
          availableRoutes = routes;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading routes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _assignRoute(String routeId) async {
    setState(() => isAssigning = true);
    
    try {
      final success = await CollegeAdminService.assignRouteToDriver(
        driverId: widget.driver['id'],
        routeId: routeId,
      );

      if (success) {
        Navigator.pop(context);
        widget.onRouteAssigned();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to assign route'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isAssigning = false);
      }
    }
  }

  Future<void> _unassignRoute() async {
    setState(() => isAssigning = true);
    
    try {
      final success = await CollegeAdminService.unassignRouteFromDriver(
        driverId: widget.driver['id'],
      );

      if (success) {
        Navigator.pop(context);
        widget.onRouteAssigned();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to unassign route'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isAssigning = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasAssignedRoute = widget.driver['assignedRoute'] != null;
    
    return AlertDialog(
      backgroundColor: Colors.white,
      title: Row(
        children: [
          Icon(
            hasAssignedRoute ? Icons.swap_horiz : Icons.route,
            color: Colors.orange,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              hasAssignedRoute ? 'Manage Route Assignment' : 'Assign Route',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Driver info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.driver['name'],
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Current assignment (if any)
            if (hasAssignedRoute) ...[
              const Text(
                'Currently Assigned Route:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.driver['assignedRoute']?['route_name'] ?? 
                      widget.driver['assignedRoute']?['name'] ?? 'Unknown Route',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (widget.driver['assignedRoute']?['route_code'] != null || 
                        widget.driver['assignedRoute']?['code'] != null)
                      Text(
                        'Code: ${widget.driver['assignedRoute']?['route_code'] ?? widget.driver['assignedRoute']?['code']}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: isAssigning ? null : _unassignRoute,
                icon: isAssigning
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.remove_circle),
                label: Text(isAssigning ? 'Unassigning...' : 'Unassign Route'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
            ],

            // Available routes
            Text(
              hasAssignedRoute ? 'Or Assign Different Route:' : 'Available Routes:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : availableRoutes.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.route_outlined,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No unassigned routes available',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: availableRoutes.length,
                          itemBuilder: (context, index) {
                            final route = availableRoutes[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: const Icon(Icons.route, color: Colors.green),
                                title: Text(
                                  route['route_name'] ?? route['name'] ?? 'Unknown Route',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: (route['route_code'] ?? route['code']) != null 
                                    ? Text('Code: ${route['route_code'] ?? route['code']}')
                                    : null,
                                trailing: ElevatedButton(
                                  onPressed: isAssigning 
                                      ? null 
                                      : () => _assignRoute(route['id'] ?? ''),
                                  child: const Text('Assign'),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: isAssigning ? null : () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}


