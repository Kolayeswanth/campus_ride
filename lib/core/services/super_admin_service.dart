import 'package:supabase_flutter/supabase_flutter.dart';

class SuperAdminService {
  static final _client = Supabase.instance.client;

  // Dashboard Stats
  static Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      // Get total routes
      final routesResponse = await _client
          .from('bus_routes')
          .select('id')
          .count(CountOption.exact);

      // Get active drivers
      final driversResponse = await _client
          .from('user_profiles')
          .select('id')
          .eq('role', 'driver')
          .count(CountOption.exact);

      // Get total users
      final usersResponse = await _client
          .from('user_profiles')
          .select('id')
          .count(CountOption.exact);

      // Get total colleges
      final collegesResponse = await _client
          .from('colleges')
          .select('id')
          .count(CountOption.exact);

      return {
        'totalRoutes': routesResponse.count,
        'activeDrivers': driversResponse.count,
        'totalUsers': usersResponse.count,
        'totalColleges': collegesResponse.count,
      };
    } catch (e) {
      print('Error fetching dashboard stats: $e');
      return {
        'totalRoutes': 0,
        'activeDrivers': 0,
        'totalUsers': 0,
        'totalColleges': 0,
      };
    }
  }

  // Recent Activity
  static Future<List<Map<String, dynamic>>> getRecentActivity() async {
    try {
      // Get recent user registrations
      final recentUsers = await _client
          .from('user_profiles')
          .select('display_name, role, created_at')
          .order('created_at', ascending: false)
          .limit(5);

      // Get recent route updates
      final recentRoutes = await _client
          .from('bus_routes')
          .select('route_name, updated_at')
          .order('updated_at', ascending: false)
          .limit(3);

      List<Map<String, dynamic>> activities = [];

      // Process recent users
      for (var user in recentUsers) {
        activities.add({
          'type': 'user_registered',
          'title': 'New ${user['role']} registered',
          'subtitle': '${user['display_name'] ?? 'User'} joined as ${user['role']}',
          'time': _formatTimeAgo(DateTime.parse(user['created_at'])),
          'icon': 'person_add',
          'color': 'green',
        });
      }

      // Process recent routes
      for (var route in recentRoutes) {
        activities.add({
          'type': 'route_updated',
          'title': 'Route updated',
          'subtitle': '${route['route_name']} route modified',
          'time': _formatTimeAgo(DateTime.parse(route['updated_at'])),
          'icon': 'route',
          'color': 'blue',
        });
      }

      // Sort by time and return top 5
      activities.sort((a, b) => a['time'].compareTo(b['time']));
      return activities.take(5).toList();
    } catch (e) {
      print('Error fetching recent activity: $e');
      return [];
    }
  }

  // Routes Management
  static Future<List<Map<String, dynamic>>> getAllRoutes() async {
    try {
      final response = await _client
          .from('bus_routes')
          .select('''
            id,
            route_name,
            route_code,
            is_active,
            college_id,
            colleges!inner(name)
          ''')
          .order('route_name');

      return response.map<Map<String, dynamic>>((route) => {
        'id': route['id'],
        'routeName': route['route_name'] ?? 'Unknown Route',
        'routeCode': route['route_code'] ?? '',
        'collegeName': route['colleges']?['name'] ?? 'Unknown College',
        'status': route['is_active'] == true ? 'Active' : 'Inactive',
        'statusColor': route['is_active'] == true ? 'green' : 'grey',
      }).toList();
    } catch (e) {
      print('Error fetching routes: $e');
      return [];
    }
  }

  // Users Management
  static Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final response = await _client
          .from('user_profiles')
          .select('id, display_name, email, role, created_at')
          .order('created_at', ascending: false);

      return response.map<Map<String, dynamic>>((user) => {
        'id': user['id'],
        'name': user['display_name'] ?? 'Unknown',
        'email': user['email'] ?? '',
        'role': user['role'] ?? 'passenger',
        'joinDate': _formatDate(DateTime.parse(user['created_at'])),
      }).toList();
    } catch (e) {
      print('Error fetching users: $e');
      return [];
    }
  }

  // Colleges Management
  static Future<List<Map<String, dynamic>>> getAllColleges() async {
    try {
      final response = await _client
          .from('colleges')
          .select('id, name, address, contact_email, contact_phone')
          .order('name');

      return response.map<Map<String, dynamic>>((college) => {
        'id': college['id'],
        'name': college['name'] ?? 'Unknown College',
        'address': college['address'] ?? '',
        'email': college['contact_email'] ?? '',
        'phone': college['contact_phone'] ?? '',
      }).toList();
    } catch (e) {
      print('Error fetching colleges: $e');
      return [];
    }
  }

  // User filtering by role
  static Future<List<Map<String, dynamic>>> getUsersByRole(String role) async {
    try {
      final response = await _client
          .from('user_profiles')
          .select('id, display_name, email, role, created_at')
          .eq('role', role)
          .order('created_at', ascending: false);

      return response.map<Map<String, dynamic>>((user) => {
        'id': user['id'],
        'name': user['display_name'] ?? 'Unknown',
        'email': user['email'] ?? '',
        'role': user['role'] ?? 'passenger',
        'joinDate': _formatDate(DateTime.parse(user['created_at'])),
      }).toList();
    } catch (e) {
      print('Error fetching users by role: $e');
      return [];
    }
  }

  // Helper methods
  static String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  // Create new college with admin user
  static Future<Map<String, dynamic>> createCollegeWithAdmin({
    required String collegeName,
    required String address,
    required String city,
    required String state,
    required String adminEmail,
    required String adminPassword,
    required String adminName,
    String? postalCode,
    String? contactPhone,
  }) async {
    try {
      // First, create the college
      final collegeResponse = await _client
          .from('colleges')
          .insert({
            'name': collegeName,
            'address': address,
            'city': city,
            'state': state,
            'postal_code': postalCode,
            'contact_email': adminEmail,
            'contact_phone': contactPhone,
            'is_active': true,
          })
          .select()
          .single();

      final collegeId = collegeResponse['id'];

      // Create admin user account in auth
      final authResponse = await _client.auth.signUp(
        email: adminEmail,
        password: adminPassword,
      );

      if (authResponse.user != null) {
        // Create user profile for the admin
        await _client.from('user_profiles').insert({
          'id': authResponse.user!.id,
          'email': adminEmail,
          'display_name': adminName,
          'role': 'admin',
          'college_id': collegeId,
          'is_active': true,
        });

        return {
          'success': true,
          'message': 'College and admin user created successfully',
          'collegeId': collegeId,
          'adminId': authResponse.user!.id,
        };
      } else {
        // If user creation failed, delete the college
        await _client.from('colleges').delete().eq('id', collegeId);
        return {
          'success': false,
          'message': 'Failed to create admin user account',
        };
      }
    } catch (e) {
      print('Error creating college with admin: $e');
      return {
        'success': false,
        'message': 'Error creating college: ${e.toString()}',
      };
    }
  }

  static String _formatDate(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}
