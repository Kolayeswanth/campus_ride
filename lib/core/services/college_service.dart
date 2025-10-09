import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/college.dart';

class CollegeService {
  static CollegeService? _instance;
  static CollegeService get instance => _instance ??= CollegeService._internal();
  
  CollegeService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  List<College> _cachedColleges = [];
  DateTime? _lastFetch;

  /// Get all active colleges from Supabase
  Future<List<College>> getAllColleges() async {
    // Use cached data if available and not stale (cache for 5 minutes)
    if (_cachedColleges.isNotEmpty && 
        _lastFetch != null && 
        DateTime.now().difference(_lastFetch!).inMinutes < 5) {
      return _cachedColleges;
    }

    try {
      if (kDebugMode) {
        print('🏫 Fetching colleges from Supabase...');
      }

      // Fetch from Supabase colleges table
      final response = await _supabase
          .from('colleges')
          .select()
          .eq('is_active', true)
          .order('name');

      final List<dynamic> collegesData = response as List<dynamic>;
      
      _cachedColleges = collegesData.map((data) {
        return College(
          id: data['id'] as String,
          name: data['name'] as String,
          address: data['address'] as String,
          city: data['city'] as String,
          state: data['state'] as String,
          country: 'India', // Default as schema doesn't have country field
          logoUrl: null, // Schema doesn't have logo field yet
          websiteUrl: null, // Schema doesn't have website field yet  
          createdAt: DateTime.parse(data['created_at'] as String),
          updatedAt: DateTime.parse(data['updated_at'] as String),
          isActive: data['is_active'] as bool? ?? true,
        );
      }).toList();

      _lastFetch = DateTime.now();

      if (kDebugMode) {
        print('🏫 Loaded ${_cachedColleges.length} colleges from database');
      }

      return _cachedColleges;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to fetch colleges from Supabase: $e');
        print('🏫 Falling back to empty list - admin needs to add colleges');
      }
      
      // Return empty list if no colleges in database
      // Admin should add colleges through the admin panel
      return [];
    }
  }

  /// Get college by ID from Supabase
  Future<College?> getCollegeById(String collegeId) async {
    try {
      // First try to find in cache
      if (_cachedColleges.isNotEmpty) {
        try {
          return _cachedColleges.firstWhere((college) => college.id == collegeId);
        } catch (e) {
          // Not in cache, fetch from database
        }
      }

      // Fetch directly from database
      final response = await _supabase
          .from('colleges')
          .select()
          .eq('id', collegeId)
          .eq('is_active', true)
          .single();

      return College(
        id: response['id'] as String,
        name: response['name'] as String,
        address: response['address'] as String,
        city: response['city'] as String,
        state: response['state'] as String,
        country: 'India', // Default as schema doesn't have country field
        logoUrl: null, // Schema doesn't have logo field yet
        websiteUrl: null, // Schema doesn't have website field yet
        createdAt: DateTime.parse(response['created_at'] as String),
        updatedAt: DateTime.parse(response['updated_at'] as String),
        isActive: response['is_active'] as bool? ?? true,
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ College not found with ID: $collegeId - $e');
      }
      return null;
    }
  }

  /// Search colleges by name or city
  List<College> searchColleges(String query) {
    if (query.isEmpty) return _cachedColleges;
    
    final lowercaseQuery = query.toLowerCase();
    return _cachedColleges.where((college) {
      return college.name.toLowerCase().contains(lowercaseQuery) ||
             college.city.toLowerCase().contains(lowercaseQuery) ||
             college.state.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }

  /// Clear cached colleges (for refresh)
  void clearCache() {
    _cachedColleges.clear();
  }
}
