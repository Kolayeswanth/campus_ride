import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/favorites_service.dart';
import '../../core/models/user_profile.dart';
import '../../features/auth/screens/unified_login_screen.dart';
import '../../features/auth/screens/college_selection_screen.dart';
import '../../features/passenger/screens/main_navigation_screen.dart';
import '../../features/driver/screens/driver_home_screen.dart';
import '../../features/admin/screens/super_admin_dashboard_screen.dart';
import '../../features/admin/screens/college_admin_dashboard_screen.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _servicesInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeUserServices();
    });
  }

  Future<void> _initializeUserServices() async {
    if (_servicesInitialized) return;
    
    try {
      // Initialize favorites service for authenticated user
      await context.read<FavoritesService>().loadFavorites();
      if (mounted) {
        setState(() {
          _servicesInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _servicesInitialized = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        // Show loading spinner while checking auth state
        if (authService.isLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // If not authenticated, show login screen
        if (!authService.isAuthenticated) {
          return const UnifiedLoginScreen();
        }

        // If user profile is null or needs profile completion
        if (authService.userProfile == null) {
          if (authService.needsProfileCompletion) {
            // User needs to complete their profile (select college)
            return const CollegeSelectionScreen(isProfileCompletion: true);
          }
          
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading profile...'),
                ],
              ),
            ),
          );
        }

        // If services are not initialized yet, show loading
        if (!_servicesInitialized) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Setting up...'),
                ],
              ),
            ),
          );
        }

        // Route based on user role
        final userRole = UserRole.fromString(authService.userRole ?? 'passenger');
        
        switch (userRole) {
          case UserRole.driver:
            return const DriverHomeScreen();
          case UserRole.admin:
            return const CollegeAdminDashboardScreen();
          case UserRole.superAdmin:
            return const SuperAdminDashboardScreen();
          case UserRole.passenger:
          default:
            return const MainNavigationScreen();
        }
      },
    );
  }
}
