import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  // Supabase Configuration
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  // Ola Maps Configuration  
  static String get olaMapsApiKey => dotenv.env['OLA_MAPS_API_KEY'] ?? '';
  
  // Backup services (use only when Ola Maps doesn't provide the service)
  static String get openRouteServiceApiKey => dotenv.env['OPENROUTESERVICE_API_KEY'] ?? '';
  
  // Additional API keys from .env
  static String get locationIQApiKey => dotenv.env['LOCATIONIQ_API_KEY'] ?? '';
  static String get mapTilerApiKey => dotenv.env['MAPTILER_API_KEY'] ?? '';
  static String get mapLibreStyleUrl => dotenv.env['MAPLIBRE_STYLE_URL'] ?? '';
  
  // Environment check
  static bool get isDevelopment => const bool.fromEnvironment('dart.vm.product') != true;
  
  // API Base URLs
  static const String olaMapsBaseUrl = 'https://api.olamaps.io';
  static const String olaMapsDirectionsUrl = 'https://api.olamaps.io/routing/v1';
  
  // Map Configuration
  static const double defaultZoom = 14.0;
  static const double minZoom = 3.0;
  static const double maxZoom = 20.0;
  
  // Route Animation Configuration
  static const int routeAnimationDuration = 2000; // milliseconds
  static const int routeAnimationSteps = 50;
}
