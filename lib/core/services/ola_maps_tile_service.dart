import 'package:flutter/foundation.dart';
import '../../app_config.dart';

/// Service for Ola Maps tile layer configuration and URL generation
class OlaMapsTileService {
  
  /// Generate Ola Maps tile URL template with authentication
  static String getTileUrlTemplate({
    String style = 'default',
    String format = 'png',
  }) {
    final apiKey = AppConfig.olaMapsApiKey;
    
    // Ola Maps tile server URL format
    // Note: This is a placeholder - actual Ola Maps tile URLs may differ
    return 'https://api.olamaps.io/tiles/v1/$style/{z}/{x}/{y}.$format?api_key=$apiKey';
  }
  
  /// Get available map styles from Ola Maps
  static List<OlaMapStyle> getAvailableStyles() {
    return [
      OlaMapStyle(
        id: 'default',
        name: 'Default',
        description: 'Standard street map with POIs',
        isDark: false,
      ),
      OlaMapStyle(
        id: 'satellite',
        name: 'Satellite',
        description: 'High-resolution satellite imagery',
        isDark: false,
      ),
      OlaMapStyle(
        id: 'hybrid',
        name: 'Hybrid',
        description: 'Satellite imagery with street overlays',
        isDark: false,
      ),
      OlaMapStyle(
        id: 'traffic',
        name: 'Traffic',
        description: 'Real-time traffic information overlay',
        isDark: false,
      ),
      OlaMapStyle(
        id: 'dark',
        name: 'Dark Mode',
        description: 'Dark theme optimized for night usage',
        isDark: true,
      ),
    ];
  }
  
  /// Configure tile layer options for better performance
  static Map<String, dynamic> getTileLayerOptions({
    required String style,
    int maxZoom = 20,
    int minZoom = 3,
    bool retinaMode = true,
  }) {
    return {
      'urlTemplate': getTileUrlTemplate(style: style),
      'maxZoom': maxZoom,
      'minZoom': minZoom,
      'retinaMode': retinaMode,
      'userAgentPackageName': 'com.campusride.app',
      'additionalOptions': {
        'attribution': '© Ola Maps',
        'tms': false,
        'keepBuffer': 2,
      },
    };
  }
  
  /// Handle tile loading errors with fallback
  static void handleTileError(dynamic tile, Object error, StackTrace? stackTrace) {
    if (kDebugMode) {
      print('🗺️ Ola Maps tile loading error: $error');
      if (tile != null) {
        print('📍 Tile info: z=${tile.coordinates?.z}, x=${tile.coordinates?.x}, y=${tile.coordinates?.y}');
      }
    }
    
    // Could implement fallback to OpenStreetMap or cached tiles here
  }
}

/// Ola Maps style configuration
class OlaMapStyle {
  final String id;
  final String name;
  final String description;
  final bool isDark;
  
  const OlaMapStyle({
    required this.id,
    required this.name,
    required this.description,
    this.isDark = false,
  });
  
  @override
  String toString() => 'OlaMapStyle(id: $id, name: $name, isDark: $isDark)';
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OlaMapStyle && other.id == id;
  }
  
  @override
  int get hashCode => id.hashCode;
}