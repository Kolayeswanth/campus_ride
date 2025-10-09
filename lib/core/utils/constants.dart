/// Application constants and configuration values
class AppConstants {
  // Prevent instantiation
  AppConstants._();

  // App Information
  static const String appName = 'CampusRide';
  static const String appVersion = '1.0.0';
  
  // Default location (Bangalore, India)
  static const double defaultLatitude = 12.9716;
  static const double defaultLongitude = 77.5946;
  
  // Map Configuration
  static const double defaultZoom = 15.0;
  static const double minZoom = 3.0;
  static const double maxZoom = 20.0;
  
  // Location accuracy
  static const double locationAccuracyThreshold = 50.0; // meters
  
  // Trip Configuration
  static const double nearbyRadius = 5.0; // kilometers
  static const int maxSearchResults = 10;
  static const int tripHistoryLimit = 50;
  
  // Real-time Configuration
  static const Duration realtimeUpdateInterval = Duration(seconds: 5);
  static const Duration locationUpdateInterval = Duration(seconds: 10);
  static const Duration heartbeatInterval = Duration(seconds: 30);
  
  // Network Configuration
  static const Duration networkTimeout = Duration(seconds: 30);
  static const int maxRetryAttempts = 3;
  static const Duration retryDelay = Duration(seconds: 2);
  
  // UI Configuration
  static const double borderRadius = 12.0;
  static const double buttonHeight = 48.0;
  static const double avatarSize = 40.0;
  
  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 400);
  static const Duration longAnimation = Duration(milliseconds: 600);
  
  // Storage Keys
  static const String userPrefsKey = 'user_preferences';
  static const String themeKey = 'theme_mode';
  static const String languageKey = 'language_code';
  static const String lastLocationKey = 'last_known_location';
  
  // API Endpoints
  static const String locationIQBaseUrl = 'https://us1.locationiq.com/v1';
  static const String olaMapsBaseUrl = 'https://api.olamaps.io/places/v1';
  
  // User Roles
  static const String rolePassenger = 'passenger';
  static const String roleDriver = 'driver';
  static const String roleAdmin = 'admin';
  static const String roleSuperAdmin = 'super_admin';
  
  // Trip Status
  static const String tripStatusActive = 'active';
  static const String tripStatusCompleted = 'completed';
  static const String tripStatusCancelled = 'cancelled';
  static const String tripStatusScheduled = 'scheduled';
  
  // Bus Status
  static const String busStatusActive = 'active';
  static const String busStatusInactive = 'inactive';
  static const String busStatusMaintenance = 'maintenance';
  
  // Validation Patterns
  static final RegExp emailPattern = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );
  
  static final RegExp phonePattern = RegExp(
    r'^\+?[1-9]\d{9,14}$',
  );
  
  static final RegExp busNumberPattern = RegExp(
    r'^[A-Z]{2}-\d{2}-[A-Z]{2}-\d{4}$',
  );
  
  // Error Messages
  static const String networkErrorMessage = 'Network connection failed. Please check your internet connection.';
  static const String locationErrorMessage = 'Unable to get your location. Please enable location services.';
  static const String authErrorMessage = 'Authentication failed. Please log in again.';
  static const String permissionErrorMessage = 'Permission denied. Please grant the required permissions.';
  
  // Success Messages
  static const String tripCreatedMessage = 'Trip created successfully!';
  static const String tripCompletedMessage = 'Trip completed successfully!';
  static const String profileUpdatedMessage = 'Profile updated successfully!';
  
  // Feature Flags
  static const bool enableOfflineMode = true;
  static const bool enableLocationHistory = true;
  static const bool enablePushNotifications = true;
  static const bool enableAnalytics = false; // Disable for privacy
  
  // Development Configuration
  static const bool debugLocationUpdates = false;
  static const bool mockLocationServices = false;
  static const bool enableDebugLogs = true;
}

/// Geographic and mapping constants
class GeoConstants {
  GeoConstants._();
  
  // Earth radius in kilometers
  static const double earthRadiusKm = 6371.0;
  
  // Degrees to kilometers conversion (approximate)
  static const double degreeToKm = 111.0;
  
  // India bounding box
  static const double indiaNorthLat = 37.6;
  static const double indiaSouthLat = 6.4;
  static const double indiaWestLon = 68.7;
  static const double indiaEastLon = 97.25;
  
  // Default search radius in kilometers
  static const double defaultSearchRadius = 10.0;
  static const double citySearchRadius = 50.0;
  static const double stateSearchRadius = 200.0;
  
  // Location accuracy levels
  static const double highAccuracy = 10.0; // meters
  static const double mediumAccuracy = 50.0; // meters
  static const double lowAccuracy = 100.0; // meters
}

/// Color constants for consistent theming
class ColorConstants {
  ColorConstants._();
  
  // Primary colors
  static const int primaryBlue = 0xFF2196F3;
  static const int primaryBlueLight = 0xFF64B5F6;
  static const int primaryBlueDark = 0xFF1976D2;
  
  // Secondary colors
  static const int secondaryGreen = 0xFF4CAF50;
  static const int secondaryOrange = 0xFFFF9800;
  static const int secondaryRed = 0xFFF44336;
  
  // Neutral colors
  static const int gray100 = 0xFFF5F5F5;
  static const int gray200 = 0xFFEEEEEE;
  static const int gray400 = 0xFFBDBDBD;
  static const int gray600 = 0xFF757575;
  static const int gray800 = 0xFF424242;
  static const int gray900 = 0xFF212121;
  
  // Status colors
  static const int successGreen = 0xFF4CAF50;
  static const int warningOrange = 0xFFFF9800;
  static const int errorRed = 0xFFF44336;
  static const int infoBlue = 0xFF2196F3;
}
