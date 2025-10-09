import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FavoritesService extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  
  Set<String> _favoriteRouteIds = {};
  bool _isLoading = false;

  Set<String> get favoriteRouteIds => _favoriteRouteIds;
  bool get isLoading => _isLoading;

  /// Load user's favorite routes
  Future<void> loadFavorites() async {
    if (_isLoading) return; // Prevent multiple concurrent calls
    
    _isLoading = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        _isLoading = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          notifyListeners();
        });
        return;
      }

      final response = await _supabase
          .from('user_favorites')
          .select('route_id')
          .eq('user_id', userId);

      _favoriteRouteIds = (response as List)
          .map((item) => item['route_id'] as String)
          .toSet();

      if (kDebugMode) {
        print('Loaded ${_favoriteRouteIds.length} favorite routes');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading favorites: $e');
      }
    } finally {
      _isLoading = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }

  /// Check if a route is in favorites
  bool isFavorite(String routeId) {
    return _favoriteRouteIds.contains(routeId);
  }

  /// Toggle favorite status for a route
  Future<bool> toggleFavorite(String routeId, {String? nickname}) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      if (isFavorite(routeId)) {
        // Remove from favorites
        await _supabase
            .from('user_favorites')
            .delete()
            .eq('user_id', userId)
            .eq('route_id', routeId);

        _favoriteRouteIds.remove(routeId);
        
        if (kDebugMode) {
          print('Removed route $routeId from favorites');
        }
      } else {
        // Add to favorites
        await _supabase
            .from('user_favorites')
            .insert({
              'user_id': userId,
              'route_id': routeId,
              'nickname': nickname,
              'notification_enabled': true,
            });

        _favoriteRouteIds.add(routeId);
        
        if (kDebugMode) {
          print('Added route $routeId to favorites');
        }
      }

      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error toggling favorite: $e');
      }
      return false;
    }
  }

  /// Get detailed favorite routes with route information
  Future<List<Map<String, dynamic>>> getFavoriteRoutesDetails() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _supabase
          .from('user_favorites')
          .select('*, bus_routes(*)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      if (kDebugMode) {
        print('Error getting favorite routes details: $e');
      }
      return [];
    }
  }

  /// Update favorite route nickname
  Future<bool> updateFavoriteNickname(String routeId, String nickname) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      await _supabase
          .from('user_favorites')
          .update({'nickname': nickname})
          .eq('user_id', userId)
          .eq('route_id', routeId);

      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error updating favorite nickname: $e');
      }
      return false;
    }
  }

  /// Toggle notification for a favorite route
  Future<bool> toggleNotification(String routeId, bool enabled) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      await _supabase
          .from('user_favorites')
          .update({'notification_enabled': enabled})
          .eq('user_id', userId)
          .eq('route_id', routeId);

      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error toggling favorite notification: $e');
      }
      return false;
    }
  }

  /// Clear all favorites (for logout)
  void clearFavorites() {
    _favoriteRouteIds.clear();
    notifyListeners();
  }

  /// Get user's favorite routes with details
  Future<List<Map<String, dynamic>>> getFavorites() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _supabase
          .from('user_favorites')
          .select('''
            route_id,
            nickname,
            notification_enabled,
            created_at,
            routes:route_id (
              id,
              route_name,
              start_location,
              end_location,
              start_latitude,
              start_longitude,
              end_latitude,
              end_longitude
            )
          ''')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      if (kDebugMode) {
        print('Error getting favorites: $e');
      }
      return [];
    }
  }

  /// Remove a route from favorites
  Future<bool> removeFavorite(String routeId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      await _supabase
          .from('user_favorites')
          .delete()
          .eq('user_id', userId)
          .eq('route_id', routeId);

      _favoriteRouteIds.remove(routeId);
      notifyListeners();
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error removing favorite: $e');
      }
      return false;
    }
  }
}
