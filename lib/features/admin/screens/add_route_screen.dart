import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:latlong2/latlong.dart' as latlong;
import '../../../core/services/enhanced_routing_service.dart';
import '../../../core/services/college_admin_service.dart';
import '../../../core/services/nominatim_location_service.dart';
import '../../../core/models/bus_route.dart';
import '../../../shared/widgets/location_autocomplete_field.dart';
import '../../../shared/widgets/enhanced_navigation_map.dart';
import '../../../shared/widgets/route_instructions_panel.dart';

class AddRouteScreen extends StatefulWidget {
  const AddRouteScreen({super.key});

  @override
  State<AddRouteScreen> createState() => _AddRouteScreenState();
}

class _AddRouteScreenState extends State<AddRouteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _routeNameController = TextEditingController();
  final _routeCodeController = TextEditingController();
  final _startLocationController = TextEditingController();
  final _endLocationController = TextEditingController();
  final _viaControllers = <TextEditingController>[];
  
  // Enhanced location selection
  LocationSuggestion? _startLocationSuggestion;
  LocationSuggestion? _endLocationSuggestion;
  List<LocationSuggestion?> _viaLocationSuggestions = [];
  
  bool _isLoading = false;
  bool _routeGenerated = false;
  bool _showInstructions = false;
  double? _routeDistance;
  double? _routeDuration;
  List<LatLng> _routePoints = [];
  String _polylineData = '';
  List<Map<String, dynamic>> _routeInstructions = [];

  
  @override
  void initState() {
    super.initState();
    // Initialize with one via point controller
    _addViaController();
  }

  void _addViaController() {
    if (_viaControllers.length < 3) {
      _viaControllers.add(TextEditingController());
      _viaLocationSuggestions.add(null);
      setState(() {});
    }
  }

  void _removeViaController(int index) {
    if (_viaControllers.length > 0) {
      _viaControllers[index].dispose();
      _viaControllers.removeAt(index);
      _viaLocationSuggestions.removeAt(index);
      setState(() {});
    }
  }

  void _onStartLocationSelected(LocationSuggestion suggestion) {
    setState(() {
      _startLocationSuggestion = suggestion;
    });
  }

  void _onEndLocationSelected(LocationSuggestion suggestion) {
    setState(() {
      _endLocationSuggestion = suggestion;
    });
  }

  void _onViaLocationSelected(int index, LocationSuggestion suggestion) {
    setState(() {
      // Ensure the list is large enough
      while (_viaLocationSuggestions.length <= index) {
        _viaLocationSuggestions.add(null);
      }
      _viaLocationSuggestions[index] = suggestion;
    });
  }

  void _onStartLocationCleared() {
    setState(() {
      _startLocationSuggestion = null;
    });
  }

  void _onEndLocationCleared() {
    setState(() {
      _endLocationSuggestion = null;
    });
  }

  void _onViaLocationCleared(int index) {
    setState(() {
      if (index < _viaLocationSuggestions.length) {
        _viaLocationSuggestions[index] = null;
      }
    });
  }

  Future<void> _getRoute() async {
    if (_startLocationSuggestion == null || _endLocationSuggestion == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select start and end locations')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _routeGenerated = false; // Reset route state
    });

    try {
      // Prepare waypoints for routing (using latlong2.LatLng for enhanced routing)
      List<latlong.LatLng> waypoints = [latlong.LatLng(_startLocationSuggestion!.latitude, _startLocationSuggestion!.longitude)];
      
      // Add via locations that are selected
      for (final viaSuggestion in _viaLocationSuggestions) {
        if (viaSuggestion != null) {
          waypoints.add(latlong.LatLng(viaSuggestion.latitude, viaSuggestion.longitude));
        }
      }
      
      waypoints.add(latlong.LatLng(_endLocationSuggestion!.latitude, _endLocationSuggestion!.longitude));

      if (kDebugMode) {
        print('🛣️ Generating route between ${waypoints.length} waypoints');
        print('📍 Start: ${_startLocationSuggestion!.displayName}');
        print('📍 End: ${_endLocationSuggestion!.displayName}');
      }

      // Get directions using Enhanced Routing Service with multiple API fallback
      if (kDebugMode) {
        print('🚀 Using Enhanced Routing Service with multiple API fallback...');
      }
      final directions = await EnhancedRoutingService.getEnhancedRoute(
        waypoints,
        profile: 'driving-car',
        alternatives: false,
        steps: true,
        geometries: 'geojson',
      );
      
      // Validate route data
      if (directions.isEmpty || 
          directions['route_points'] == null || 
          (directions['route_points'] as List).isEmpty) {
        throw Exception('No valid route found between the selected locations');
      }

      final routePointsLatLong = directions['route_points'] as List<latlong.LatLng>;
      final distance = directions['distance_km'] as double?;
      final duration = directions['duration_minutes'] as double?;
      final instructions = directions['instructions'] as List<Map<String, dynamic>>? ?? [];
      
      // Convert latlong2.LatLng to bus_route.LatLng for compatibility with existing code
      final routePoints = routePointsLatLong.map((point) => 
          LatLng(point.latitude, point.longitude)).toList();
      
      setState(() {
        _routeDistance = distance;
        _routeDuration = duration;
        _routePoints = routePoints;
        _polylineData = directions['polyline_encoded'] ?? '';
        _routeInstructions = instructions;
        _routeGenerated = true;
      });

      if (kDebugMode) {
        print('✅ ENHANCED ROUTE GENERATED SUCCESSFULLY');
        print('📏 Distance: ${(distance ?? 0).toStringAsFixed(2)} km');
        print('⏱️ Duration: ${(duration ?? 0).toStringAsFixed(1)} minutes');
        print('🛣️ Route points: ${routePoints.length}');
        print('📊 Route source: ${directions['source'] ?? 'unknown'}');
        
        if (directions['fallback'] == true) {
          print('⚠️ Used fallback routing mechanism');
        }
        
        // Debug routing quality
        final routeQuality = routePoints.length > 20 ? 'High' : 
                           routePoints.length > 10 ? 'Medium' : 'Low';
        print('🎯 Route quality: $routeQuality (${routePoints.length} points)');
        
        // Debug turn-by-turn instructions
        print('🧭 Navigation instructions: ${instructions.length} steps');
        if (instructions.isNotEmpty) {
          print('🔍 Key navigation steps:');
          for (int i = 0; i < math.min(5, instructions.length); i++) {
            final instruction = instructions[i];
            final type = instruction['type'] ?? 'unknown';
            final text = instruction['instruction'] ?? 'No instruction';
            final distance = instruction['readable_distance'] ?? 'unknown distance';
            print('   ${i + 1}. [$type] $text ($distance)');
          }
        } else {
          print('⚠️ No turn-by-turn instructions generated');
        }
        
        // Debug route geometry
        print('📐 Route geometry analysis:');
        if (routePoints.length >= 2) {
          final startPoint = routePoints.first;
          final endPoint = routePoints.last;
          print('   Start: ${startPoint.latitude.toStringAsFixed(6)}, ${startPoint.longitude.toStringAsFixed(6)}');
          print('   End: ${endPoint.latitude.toStringAsFixed(6)}, ${endPoint.longitude.toStringAsFixed(6)}');
          
          // Calculate rough straight-line distance vs route distance
          final straightDistance = _calculateStraightLineDistance(startPoint, endPoint);
          final detourFactor = (distance ?? 0) / straightDistance;
          print('   Straight-line distance: ${straightDistance.toStringAsFixed(2)} km');
          print('   Route detour factor: ${detourFactor.toStringAsFixed(2)}x');
        }
        
        // Debug polyline encoding
        final polylineLength = directions['polyline_encoded']?.toString().length ?? 0;
        print('🔗 Polyline encoded: ${polylineLength > 0 ? '$polylineLength chars' : 'Not available'}');
      }

      // Show detailed success message with route information
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  const Text('Route Generated Successfully!', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '📏 Distance: ${(distance ?? 0).toStringAsFixed(1)} km  ⏱️ Duration: ${(duration ?? 0).toStringAsFixed(0)} min',
              ),
              Text(
                '🛣️ ${routePoints.length} route points following real roads',
                style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.9)),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );

    } catch (e) {
      if (kDebugMode) {
        print('❌ Route generation failed: $e');
      }
      
      setState(() {
        _routeGenerated = false;
        _routePoints = [];
        _routeDistance = null;
        _routeDuration = null;
        _polylineData = '';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.error, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  const Text('Route Generation Failed', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 4),
              Text('Error: ${e.toString()}'),
              const SizedBox(height: 4),
              const Text(
                'Please check your internet connection and try again',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveRoute() async {
    print('🎯 Save Route button clicked!');
    print('📝 Form state: ${_formKey.currentState != null ? "Available" : "Null"}');
    print('📋 Route name: "${_routeNameController.text.trim()}"');
    print('🏷️ Route code: "${_routeCodeController.text.trim()}"');
    print('📍 Start location: ${_startLocationSuggestion?.displayName}');
    print('📍 End location: ${_endLocationSuggestion?.displayName}');
    
    // Validate manually since Form widget might not be in tree during review mode
    if (_routeNameController.text.trim().isEmpty) {
      print('❌ Route name is empty');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Route name is required')),
      );
      return;
    }
    
    if (_routeCodeController.text.trim().isEmpty) {
      print('❌ Route code is empty');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Route code is required')),
      );
      return;
    }
    
    if (_startLocationSuggestion == null || _endLocationSuggestion == null) {
      print('❌ Start or end location not selected');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both start and end locations')),
      );
      return;
    }
    
    // Only validate form if it's available (in form view)
    if (_formKey.currentState != null && !_formKey.currentState!.validate()) {
      print('❌ Form validation failed - check required fields');
      return;
    }
    
    print('✅ Validation passed');
    if (_startLocationSuggestion == null || _endLocationSuggestion == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select start and end locations')),
      );
      return;
    }
    if (!_routeGenerated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please get route first')),
      );
      return;
    }

    // Validate route data
    if (_routeDistance == null || _routeDistance! <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid route distance. Please regenerate the route.')),
      );
      return;
    }

    if (_startLocationSuggestion == null || _endLocationSuggestion == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Start or end location is invalid. Please reselect locations.')),
      );
      return;
    }

    // Validate coordinate values
    if (_startLocationSuggestion!.latitude == 0 && _startLocationSuggestion!.longitude == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid start location coordinates. Please reselect start location.')),
      );
      return;
    }

    if (_endLocationSuggestion!.latitude == 0 && _endLocationSuggestion!.longitude == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid end location coordinates. Please reselect end location.')),
      );
      return;
    }

    // Show confirmation dialog
    print('📋 Showing confirmation dialog...');
    final bool? shouldSave = await _showSaveConfirmationDialog();
    print('💭 User choice: ${shouldSave == true ? "Save" : "Cancel"}');
    if (shouldSave != true) return;

    print('🚀 Starting route save process...');
    print('✅ Route name: ${_routeNameController.text.trim()}');
    print('📍 Start location: ${_startLocationSuggestion?.displayName}');
    print('📍 End location: ${_endLocationSuggestion?.displayName}');
    print('📏 Distance: $_routeDistance km');
    print('⏱️ Duration: $_routeDuration min');
    print('🗺️ Route points: ${_routePoints.length}');
    print('📋 Instructions: ${_routeInstructions.length}');

    setState(() {
      _isLoading = true;
    });

    try {
      // Convert via location suggestions to LatLng list (with null safety)
      final viaWaypoints = <LatLng>[];
      final validViaLocations = <LocationSuggestion>[];
      
      for (final viaSuggestion in _viaLocationSuggestions) {
        if (viaSuggestion != null) {
          viaWaypoints.add(LatLng(viaSuggestion.latitude, viaSuggestion.longitude));
          validViaLocations.add(viaSuggestion);
        }
      }

      print('💾 Calling database save...');
      final success = await CollegeAdminService.addBusRoute(
        routeName: _routeNameController.text.trim(),
        routeCode: _routeCodeController.text.trim(),
        startName: _getLocationName(_startLocationSuggestion),
        endName: _getLocationName(_endLocationSuggestion),
        startLocation: LatLng(_startLocationSuggestion?.latitude ?? 0.0, _startLocationSuggestion?.longitude ?? 0.0),
        endLocation: LatLng(_endLocationSuggestion?.latitude ?? 0.0, _endLocationSuggestion?.longitude ?? 0.0),
        waypoints: viaWaypoints,
        distanceKm: _routeDistance ?? 0.1, // Ensure it meets the > 0 constraint
        durationMinutes: _routeDuration?.round(),
        polylineData: _polylineData.isNotEmpty ? _polylineData : null,
        routePoints: _routePoints.isNotEmpty ? _routePoints : null,
        routeInstructions: _routeInstructions.isNotEmpty ? _routeInstructions : null,
        startLocationDetails: _startLocationSuggestion,
        endLocationDetails: _endLocationSuggestion,
        viaLocationDetails: validViaLocations,
      );

      if (success) {
        print('🏠 Navigating back to dashboard with success message...');
        // Navigate back to dashboard and switch to Routes tab
        Navigator.pop(context, {'success': true, 'tab': 2, 'message': 'Route "${_routeNameController.text.trim()}" saved successfully!'});
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save route')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving route: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<bool?> _showSaveConfirmationDialog() async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.save, color: Colors.green, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Confirm Route Save',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            constraints: const BoxConstraints(maxHeight: 400),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Please review the route details before saving:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Route Basic Info
                  _buildRouteDetailRow('Route Name:', _routeNameController.text.trim().isNotEmpty ? _routeNameController.text.trim() : 'Unnamed Route'),
                  if (_routeCodeController.text.trim().isNotEmpty)
                    _buildRouteDetailRow('Route Code:', _routeCodeController.text.trim()),
                  
                  const Divider(height: 24),
                  
                  // Location Details
                  _buildRouteDetailRow('From:', _getLocationName(_startLocationSuggestion)),
                  _buildRouteDetailRow('To:', _getLocationName(_endLocationSuggestion)),
                  if (_viaLocationSuggestions.where((v) => v != null).isNotEmpty)
                    _buildRouteDetailRow('Via Points:', '${_viaLocationSuggestions.where((v) => v != null).length} waypoint(s)'),
                  
                  const Divider(height: 24),
                  
                  // Route Statistics
                  if (_routeDistance != null && _routeDistance! > 0)
                    _buildRouteDetailRow('Distance:', '${(_routeDistance ?? 0).toStringAsFixed(1)} km'),
                  if (_routeDuration != null)
                    _buildRouteDetailRow('Estimated Duration:', '${_routeDuration?.round()} minutes'),
                  if (_routePoints.isNotEmpty)
                    _buildRouteDetailRow('Route Points:', '${_routePoints.length} coordinates'),
                  if (_routeInstructions.isNotEmpty)
                    _buildRouteDetailRow('Turn Instructions:', '${_routeInstructions.length} steps'),
                  
                  const SizedBox(height: 16),
                  
                  // Warning/Info Box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'This route will be saved to the database and made available for scheduling bus trips.',
                            style: TextStyle(fontSize: 12, color: Colors.orange),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            SizedBox(
              width: double.maxFinite,
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextButton.icon(
                      onPressed: () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Cancel'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).pop(true),
                      icon: const Icon(Icons.save, size: 18),
                      label: const Text('Save Route'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRouteDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getLocationName(LocationSuggestion? location) {
    if (location?.displayName == null) return 'Unknown';
    final parts = location!.displayName.split(',');
    if (parts.isEmpty) return 'Unknown';
    return parts.first.trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Create New Route',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
        shadowColor: Colors.black12,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (_routeGenerated)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _saveRoute,
                icon: const Icon(Icons.save, size: 18),
                label: const Text('Save Route'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    color: Color(0xFF2563EB),
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _routeGenerated ? 'Saving route...' : 'Generating route...',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : _routeGenerated
              ? _buildRouteReviewView()
              : _buildFormView(),
    );
  }

  Widget _buildFormView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Header
            Container(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Route Setup',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Configure your new bus route with locations and details',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            // Route Details Card
            Container(
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.route,
                            color: const Color(0xFF2563EB),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          'Route Information',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _routeNameController,
                      decoration: InputDecoration(
                        labelText: 'Route Name *',
                        hintText: 'e.g., Main Campus to City Center',
                        prefixIcon: Icon(
                          Icons.label_outline,
                          color: const Color(0xFF2563EB),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      style: const TextStyle(fontSize: 16),
                      validator: (value) {
                        if (value?.isEmpty ?? true) {
                          return 'Route name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _routeCodeController,
                      decoration: InputDecoration(
                        labelText: 'Route Code (Optional)',
                        hintText: 'e.g., R001, BUS-A',
                        prefixIcon: Icon(
                          Icons.tag,
                          color: Colors.grey[600],
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),

            // Locations Card
            Container(
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF059669).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.location_on,
                            color: const Color(0xFF059669),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          'Route Locations',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Start Location
                    LocationAutocompleteField(
                      controller: _startLocationController,
                      labelText: 'Start Location',
                      hintText: 'Enter starting point (e.g., College Main Gate)',
                      prefixIcon: Icons.trip_origin,
                      isRequired: true,
                      filterState: 'Andhra Pradesh',
                      onLocationSelected: _onStartLocationSelected,
                      onClearSelection: _onStartLocationCleared,
                    ),

                    const SizedBox(height: 20),

                    // Via Points Section
                    if (_viaControllers.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.alt_route,
                                color: Colors.grey[600],
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Via Points',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ...List.generate(_viaControllers.length, (index) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _buildViaLocationField(index),
                          )),
                        ],
                      ),

                    // Add Via Point Button
                    if (_viaControllers.length < 3)
                      InkWell(
                        onTap: _addViaController,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: const Color(0xFF2563EB).withOpacity(0.2), 
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            color: const Color(0xFF2563EB).withOpacity(0.05),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_circle_outline,
                                color: const Color(0xFF2563EB),
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Add Via Point (Optional)',
                                style: TextStyle(
                                  color: const Color(0xFF2563EB),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 24),

                    // End Location
                    LocationAutocompleteField(
                      controller: _endLocationController,
                      labelText: 'End Location',
                      hintText: 'Enter destination (e.g., Railway Station, Bus Stand)',
                      prefixIcon: Icons.location_on,
                      isRequired: true,
                      filterState: 'Andhra Pradesh',
                      onLocationSelected: _onEndLocationSelected,
                      onClearSelection: _onEndLocationCleared,
                    ),
                  ],
                ),
              ),
            ),

            // Get Route Button
            Container(
              width: double.infinity,
              height: 60,
              decoration: BoxDecoration(
                gradient: _startLocationSuggestion != null && _endLocationSuggestion != null
                    ? const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      )
                    : null,
                color: _startLocationSuggestion == null || _endLocationSuggestion == null
                    ? Colors.grey.shade300
                    : null,
                borderRadius: BorderRadius.circular(20),
                boxShadow: _startLocationSuggestion != null && _endLocationSuggestion != null
                    ? [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : null,
              ),
              child: ElevatedButton(
                onPressed: (_startLocationSuggestion != null && _endLocationSuggestion != null) ? _getRoute : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.route, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      'Generate Route',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildViaLocationField(int index) {
    return Row(
      children: [
        Expanded(
          child: LocationAutocompleteField(
            controller: _viaControllers[index],
            labelText: 'Via Point ${index + 1}',
            hintText: 'Enter intermediate location (optional)',
            prefixIcon: Icons.radio_button_unchecked,
            isRequired: false,
            filterState: 'Andhra Pradesh',
            onLocationSelected: (suggestion) => _onViaLocationSelected(index, suggestion),
            onClearSelection: () => _onViaLocationCleared(index),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () => _removeViaController(index),
          icon: const Icon(Icons.remove_circle_outline),
          color: Colors.red,
        ),
      ],
    );
  }

  Widget _buildRouteReviewView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Route Name Header (no card)
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.check, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Route Generated Successfully',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Route Name
                Text(
                  _routeNameController.text.isNotEmpty 
                      ? _routeNameController.text 
                      : 'New Route',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_routeCodeController.text.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Code: ${_routeCodeController.text}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Map Section (separate from name, no card)
          if (_routePoints.isNotEmpty) ...[
            Container(
              height: 400,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _buildRouteMapView(),
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Route Instructions Button (only show if instructions are available)
          if (_routeInstructions.isNotEmpty) ...[
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  setState(() {
                    _showInstructions = !_showInstructions;
                  });
                  if (kDebugMode) {
                    print('🧭 ${_showInstructions ? 'Showing' : 'Hiding'} route instructions panel');
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.directions,
                          color: Colors.blue.shade700,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Turn-by-Turn Directions',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'View ${_routeInstructions.length} navigation steps',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_routeInstructions.length} steps',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        _showInstructions ? Icons.expand_less : Icons.expand_more,
                        color: Colors.grey.shade600,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          
          // Route Instructions Panel (shown as bottom sheet when _showInstructions is true)
          if (_showInstructions && _routeInstructions.isNotEmpty) ...[
            const SizedBox(height: 16),
            RouteInstructionsPanel(
              instructions: _routeInstructions,
              totalDistance: _routeDistance,
              totalDuration: _routeDuration,
              onClose: () {
                setState(() {
                  _showInstructions = false;
                });
              },
            ),
          ],

          // Route Details Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Route Details',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Start Location
                  _buildLocationItem(
                    icon: Icons.trip_origin,
                    iconColor: Colors.green,
                    title: 'Start',
                    location: _startLocationController.text,
                  ),

                  // Via Locations
                  ...List.generate(_viaControllers.length, (index) {
                    if (_viaControllers[index].text.isNotEmpty) {
                      return _buildLocationItem(
                        icon: Icons.radio_button_unchecked,
                        iconColor: Colors.orange,
                        title: 'Via ${index + 1}',
                        location: _viaControllers[index].text,
                      );
                    }
                    return const SizedBox.shrink();
                  }),

                  // End Location
                  _buildLocationItem(
                    icon: Icons.location_on,
                    iconColor: Colors.red,
                    title: 'End',
                    location: _endLocationController.text,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 30),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _routeGenerated = false;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Edit Route'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saveRoute,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Save Route'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String location,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  location,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteMap() {
    if (_routePoints.isEmpty) {
      return Container(
        color: Colors.grey.shade100,
        child: const Center(
          child: Text(
            'No route data available',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    // Use OLA Maps for both web and mobile
    return _buildOlaMapView();
  }

  Widget _buildSimpleRouteVisualization() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Row(
              children: [
                Icon(Icons.map, color: Colors.blue.shade600, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Route Visualization',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Route summary
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                children: [
                  _buildRoutePoint(
                    Icons.trip_origin,
                    'Start Location',
                    _startLocationController.text,
                    Colors.green,
                  ),
                  
                  // Via points
                  ...List.generate(_viaLocationSuggestions.length, (index) {
                    final viaSuggestion = _viaLocationSuggestions[index];
                    if (viaSuggestion != null && index < _viaControllers.length) {
                      return _buildRoutePoint(
                        Icons.radio_button_unchecked,
                        'Via Point ${index + 1}',
                        _viaControllers[index].text,
                        Colors.orange,
                      );
                    }
                    return const SizedBox.shrink();
                  }),
                  
                  _buildRoutePoint(
                    Icons.location_on,
                    'End Location',
                    _endLocationController.text,
                    Colors.red,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Route info
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.straighten, color: Colors.blue.shade600, size: 16),
                        const SizedBox(height: 4),
                        Text(
                          '${(_routeDistance ?? 0).toStringAsFixed(1)} km',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const Text(
                          'Distance',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.access_time, color: Colors.green.shade600, size: 16),
                        const SizedBox(height: 4),
                        Text(
                          '${(_routeDuration ?? 0).toStringAsFixed(0)} min',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const Text(
                          'Duration',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.route, color: Colors.purple.shade600, size: 16),
                        const SizedBox(height: 4),
                        Text(
                          '${_routePoints.length}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const Text(
                          'Points',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade600, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Route generated successfully with ${_routePoints.length} coordinate points',
                      style: TextStyle(
                        color: Colors.green.shade800,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoutePoint(IconData icon, String title, String location, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                Text(
                  location,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOlaMapView() {
    // For now, show the route visualization since OLA Maps SDK is not available for Flutter web
    // In production, this would use the OLA Maps Flutter SDK
    return _buildEnhancedRouteVisualization();
  }

  Widget _buildEnhancedRouteVisualization() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.shade50,
            Colors.indigo.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with OLA Maps branding
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF1E40AF)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.map, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 8),
                Text(
                  'Route Directions',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade800,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green.shade600, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        'Generated',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Actual Map with Route Polyline
            Expanded(
              child: _buildRouteMapView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteMapView() {
    return Container(
      width: double.infinity,
      height: 600, // Increased height for better map visibility
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            // Map or placeholder
            _routePoints.isNotEmpty
                ? Builder(
                    builder: (context) {
                      final mapRoutePoints = _routePoints.map((point) => 
                          latlong.LatLng(point.latitude, point.longitude)).toList();
                      
                      if (kDebugMode) {
                        print('🗺️ MAP WIDGET DEBUG:');
                        print('   Route points count: ${_routePoints.length}');
                        print('   Map route points count: ${mapRoutePoints.length}');
                        print('   First point: ${mapRoutePoints.isNotEmpty ? '${mapRoutePoints.first.latitude}, ${mapRoutePoints.first.longitude}' : 'None'}');
                        print('   Last point: ${mapRoutePoints.isNotEmpty ? '${mapRoutePoints.last.latitude}, ${mapRoutePoints.last.longitude}' : 'None'}');
                        print('   Instructions count: ${_routeInstructions.length}');
                      }
                      
                      return EnhancedNavigationMap(
                        routePoints: mapRoutePoints,
                    turnByTurnInstructions: _routeInstructions,
                    startLocation: _startLocationSuggestion != null
                        ? latlong.LatLng(_startLocationSuggestion!.latitude, _startLocationSuggestion!.longitude)
                        : null,
                    endLocation: _endLocationSuggestion != null
                        ? latlong.LatLng(_endLocationSuggestion!.latitude, _endLocationSuggestion!.longitude)
                        : null,
                    waypoints: _viaLocationSuggestions
                        .where((v) => v != null)
                        .map((v) => latlong.LatLng(v!.latitude, v.longitude))
                        .toList(),
                    distance: _routeDistance,
                    duration: _routeDuration,
                    routeSource: 'enhanced_routing',
                    showInstructions: true,
                    showRouteInfo: true,
                    initialZoom: 12.0,
                    enableInteraction: true,
                    onRouteInfoTap: () {
                      if (kDebugMode) {
                        print('🗺️ Route info tapped - showing detailed information');
                        print('📏 Distance: ${_routeDistance?.toStringAsFixed(2)} km');
                        print('⏱️ Duration: ${_routeDuration?.toStringAsFixed(0)} min');
                        print('🛣️ Route points: ${_routePoints.length}');
                        print('📋 Instructions: ${_routeInstructions.length}');
                      }
                    },
                  );
                    }
                  )
                : Container(
                    color: Colors.grey.shade100,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.route_outlined, 
                            size: 64, 
                            color: Colors.grey.shade400
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Generate Route to View Map',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Real world map with accurate road directions\nwill be displayed here',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                                const SizedBox(width: 6),
                                Text(
                                  'Powered by OpenRouteService & OpenStreetMap',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            
            // Route generation loading overlay
            if (_isLoading)
              Container(
                color: Colors.white.withOpacity(0.9),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 80,
                            height: 80,
                            child: CircularProgressIndicator(
                              strokeWidth: 6,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
                            ),
                          ),
                          Icon(
                            Icons.route,
                            size: 32,
                            color: Colors.blue.shade600,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Generating Real Road Route...',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Calculating directions using real road data',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade600),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Following actual roads & highways',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebMapView() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            // Web Map using custom painter for now (OLA Maps SDK integration would go here)
            if (_routePoints.isNotEmpty)
              CustomPaint(
                painter: RoutePainter(
                  routePoints: _routePoints,
                  startPoint: _startLocationSuggestion,
                  endPoint: _endLocationSuggestion,
                  viaPoints: _viaLocationSuggestions.where((v) => v != null).cast<LocationSuggestion>().toList(),
                ),
                child: Container(),
              )
            else
              // Placeholder when no route is generated
              Container(
                color: Colors.grey.shade100,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.map_outlined, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'Generate Route to View Map',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Route map visualization will appear here',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            // Route info overlay
            if (_routePoints.isNotEmpty)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.route, color: Colors.blue.shade600, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        '${(_routeDistance ?? 0).toStringAsFixed(1)}km • ${(_routeDuration ?? 0).toStringAsFixed(0)}min',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            

          ],
        ),
      ),
    );
  }

  Widget _buildMobileMapView() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: _routePoints.isNotEmpty
            ? CustomPaint(
                painter: RoutePainter(
                  routePoints: _routePoints,
                  startPoint: _startLocationSuggestion,
                  endPoint: _endLocationSuggestion,
                  viaPoints: _viaLocationSuggestions.where((v) => v != null).cast<LocationSuggestion>().toList(),
                ),
                child: Container(),
              )
            : Container(
                color: Colors.grey.shade100,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.map_outlined, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'Generate Route to View Map',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Route visualization will appear here',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildMapStyleRoutePoint(
    IconData icon,
    String label,
    String location,
    Color color, {
    bool isFirst = false,
    bool isLast = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isFirst)
          Container(
            width: 2,
            height: 12,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.blue.shade300,
                  Colors.blue.shade500,
                ],
              ),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        
        Container(
          padding: const EdgeInsets.all(6),
          margin: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withOpacity(0.3), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 12),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: color,
                        letterSpacing: 0.3,
                      ),
                    ),
                    Text(
                      location,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        if (!isLast && _viaLocationSuggestions.isEmpty && label == 'START')
          Container(
            width: 2,
            height: 12,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.blue.shade500,
                  Colors.blue.shade300,
                ],
              ),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
      ],
    );
  }

  Widget _buildStatChip(IconData icon, String value, Color color) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 10),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoogleMapsView() {
    // Calculate map bounds
    double minLat = _routePoints.first.latitude;
    double maxLat = _routePoints.first.latitude;
    double minLng = _routePoints.first.longitude;
    double maxLng = _routePoints.first.longitude;

    for (final point in _routePoints) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }

    // Add padding to bounds
    final latPadding = (maxLat - minLat) * 0.1;
    final lngPadding = (maxLng - minLng) * 0.1;

    final gmaps.LatLngBounds bounds = gmaps.LatLngBounds(
      southwest: gmaps.LatLng(minLat - latPadding, minLng - lngPadding),
      northeast: gmaps.LatLng(maxLat + latPadding, maxLng + lngPadding),
    );

    // Create markers for start, end, and via points
    final Set<gmaps.Marker> markers = {};
    
    // Start marker
    markers.add(gmaps.Marker(
      markerId: const gmaps.MarkerId('start'),
      position: gmaps.LatLng(_routePoints.first.latitude, _routePoints.first.longitude),
      infoWindow: gmaps.InfoWindow(
        title: 'Start',
        snippet: _startLocationController.text,
      ),
      icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueGreen),
    ));

    // End marker
    markers.add(gmaps.Marker(
      markerId: const gmaps.MarkerId('end'),
      position: gmaps.LatLng(_routePoints.last.latitude, _routePoints.last.longitude),
      infoWindow: gmaps.InfoWindow(
        title: 'End',
        snippet: _endLocationController.text,
      ),
      icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueRed),
    ));

    // Via point markers
    for (int i = 0; i < _viaLocationSuggestions.length; i++) {
      final viaSuggestion = _viaLocationSuggestions[i];
      if (viaSuggestion != null && i < _viaControllers.length) {
        markers.add(gmaps.Marker(
          markerId: gmaps.MarkerId('via_$i'),
          position: gmaps.LatLng(viaSuggestion.latitude, viaSuggestion.longitude),
          infoWindow: gmaps.InfoWindow(
            title: 'Via ${i + 1}',
            snippet: _viaControllers[i].text,
          ),
          icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueOrange),
        ));
      }
    }

    // Create polyline for the route
    final gmaps.Polyline routePolyline = gmaps.Polyline(
      polylineId: const gmaps.PolylineId('route'),
      points: _routePoints.map((point) => gmaps.LatLng(point.latitude, point.longitude)).toList(),
      color: const Color(0xFF2563EB),
      width: 4,
      patterns: [],
    );

    return gmaps.GoogleMap(
      initialCameraPosition: gmaps.CameraPosition(
        target: gmaps.LatLng(
          (minLat + maxLat) / 2,
          (minLng + maxLng) / 2,
        ),
        zoom: 12,
      ),
      markers: markers,
      polylines: {routePolyline},
      onMapCreated: (gmaps.GoogleMapController controller) {
        // Fit bounds to show entire route
        controller.animateCamera(
          gmaps.CameraUpdate.newLatLngBounds(bounds, 50),
        );
      },
      mapType: gmaps.MapType.normal,
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: true,
      compassEnabled: true,
      mapToolbarEnabled: false,
    );
  }

  IconData _getManeuverIcon(String maneuverType) {
    switch (maneuverType.toLowerCase()) {
      case 'turn-left':
        return Icons.turn_left;
      case 'turn-right':
        return Icons.turn_right;
      case 'turn-slight-left':
        return Icons.turn_slight_left;
      case 'turn-slight-right':
        return Icons.turn_slight_right;
      case 'turn-sharp-left':
        return Icons.turn_sharp_left;
      case 'turn-sharp-right':
        return Icons.turn_sharp_right;
      case 'uturn-left':
      case 'uturn-right':
        return Icons.u_turn_left;
      case 'fork':
        return Icons.call_split;
      case 'roundabout':
        return Icons.roundabout_left;
      case 'depart':
        return Icons.start;
      case 'arrive':
        return Icons.place;
      default:
        return Icons.straight;
    }
  }

  /// Calculate straight-line distance between two points (Haversine formula)
  double _calculateStraightLineDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371.0; // Earth's radius in kilometers
    
    final double lat1Rad = point1.latitude * (math.pi / 180.0);
    final double lat2Rad = point2.latitude * (math.pi / 180.0);
    final double deltaLatRad = (point2.latitude - point1.latitude) * (math.pi / 180.0);
    final double deltaLngRad = (point2.longitude - point1.longitude) * (math.pi / 180.0);

    final double a = math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) *
        math.sin(deltaLngRad / 2) * math.sin(deltaLngRad / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  @override
  void dispose() {
    _routeNameController.dispose();
    _routeCodeController.dispose();
    _startLocationController.dispose();
    _endLocationController.dispose();
    for (final controller in _viaControllers) {
      controller.dispose();
    }
    super.dispose();
  }
}

/// Custom painter for drawing route polylines on canvas
class RoutePainter extends CustomPainter {
  final List<LatLng> routePoints;
  final LocationSuggestion? startPoint;
  final LocationSuggestion? endPoint;
  final List<LocationSuggestion> viaPoints;

  RoutePainter({
    required this.routePoints,
    this.startPoint,
    this.endPoint,
    this.viaPoints = const [],
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (routePoints.isEmpty) return;

    // Calculate bounds
    final bounds = _calculateBounds();
    if (bounds == null) return;

    // Draw map-like background
    _drawMapBackground(canvas, size);

    // Draw road network pattern
    _drawRoadNetwork(canvas, size);

    // Draw route polyline
    _drawRoute(canvas, size, bounds);

    // Draw markers
    _drawMarkers(canvas, size, bounds);

    // Draw compass
    _drawCompass(canvas, size);
  }

  void _drawMapBackground(Canvas canvas, Size size) {
    // Create a gradient background that looks like a map
    final backgroundPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.green.shade50,
          Colors.blue.shade50,
          Colors.grey.shade100,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);
  }

  void _drawRoadNetwork(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = Colors.grey.shade300.withOpacity(0.5)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final majorRoadPaint = Paint()
      ..color = Colors.grey.shade400.withOpacity(0.7)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    // Draw a realistic road grid pattern
    final random = math.Random(42); // Fixed seed for consistent pattern

    // Major horizontal roads
    for (int i = 0; i < 6; i++) {
      final y = (size.height / 6) * i + random.nextDouble() * 20 - 10;
      final startX = random.nextDouble() * size.width * 0.1;
      final endX = size.width - random.nextDouble() * size.width * 0.1;
      
      canvas.drawLine(Offset(startX, y), Offset(endX, y), majorRoadPaint);
    }

    // Major vertical roads
    for (int i = 0; i < 6; i++) {
      final x = (size.width / 6) * i + random.nextDouble() * 20 - 10;
      final startY = random.nextDouble() * size.height * 0.1;
      final endY = size.height - random.nextDouble() * size.height * 0.1;
      
      canvas.drawLine(Offset(x, startY), Offset(x, endY), majorRoadPaint);
    }

    // Minor roads (more organic pattern)
    for (int i = 0; i < 20; i++) {
      final startX = random.nextDouble() * size.width;
      final startY = random.nextDouble() * size.height;
      final length = 30 + random.nextDouble() * 60;
      final angle = random.nextDouble() * math.pi * 2;
      
      final endX = startX + math.cos(angle) * length;
      final endY = startY + math.sin(angle) * length;
      
      if (endX >= 0 && endX <= size.width && endY >= 0 && endY <= size.height) {
        canvas.drawLine(Offset(startX, startY), Offset(endX, endY), roadPaint);
      }
    }
  }

  MapBounds? _calculateBounds() {
    if (routePoints.isEmpty) return null;

    double minLat = routePoints.first.latitude;
    double maxLat = routePoints.first.latitude;
    double minLng = routePoints.first.longitude;
    double maxLng = routePoints.first.longitude;

    for (final point in routePoints) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }

    // Add some padding
    final latPadding = (maxLat - minLat) * 0.1;
    final lngPadding = (maxLng - minLng) * 0.1;

    return MapBounds(
      minLat - latPadding,
      maxLat + latPadding,
      minLng - lngPadding,
      maxLng + lngPadding,
    );
  }

  void _drawCompass(Canvas canvas, Size size) {
    const compassSize = 40.0;
    final compassCenter = Offset(size.width - compassSize - 10, compassSize + 10);

    // Compass background
    final compassBg = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..style = PaintingStyle.fill;

    final compassBorder = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(compassCenter, compassSize / 2, compassBg);
    canvas.drawCircle(compassCenter, compassSize / 2, compassBorder);

    // North arrow
    final arrowPaint = Paint()
      ..color = Colors.red.shade600
      ..style = PaintingStyle.fill;

    final arrowPath = Path();
    arrowPath.moveTo(compassCenter.dx, compassCenter.dy - 15);
    arrowPath.lineTo(compassCenter.dx - 4, compassCenter.dy - 5);
    arrowPath.lineTo(compassCenter.dx, compassCenter.dy);
    arrowPath.lineTo(compassCenter.dx + 4, compassCenter.dy - 5);
    arrowPath.close();

    canvas.drawPath(arrowPath, arrowPaint);

    // 'N' text
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'N',
        style: TextStyle(
          color: Colors.black87,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        compassCenter.dx - textPainter.width / 2,
        compassCenter.dy + 8,
      ),
    );
  }

  void _drawRoute(Canvas canvas, Size size, MapBounds bounds) {
    if (routePoints.length < 2) return;

    final routePaint = Paint()
      ..color = Colors.blue.shade700
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final shadowPaint = Paint()
      ..color = Colors.blue.shade700.withOpacity(0.2)
      ..strokeWidth = 7.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final borderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 6.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Create smooth curved path following route points
    final path = Path();
    final shadowPath = Path();
    final borderPath = Path();

    if (routePoints.isNotEmpty) {
      final firstPoint = _latLngToScreen(routePoints[0], bounds, size);
      path.moveTo(firstPoint.dx, firstPoint.dy);
      shadowPath.moveTo(firstPoint.dx, firstPoint.dy);
      borderPath.moveTo(firstPoint.dx, firstPoint.dy);

      // Create smooth curves between points for more realistic road representation
      for (int i = 1; i < routePoints.length; i++) {
        final currentPoint = _latLngToScreen(routePoints[i], bounds, size);
        
        if (i == 1) {
          // First segment - direct line
          path.lineTo(currentPoint.dx, currentPoint.dy);
          shadowPath.lineTo(currentPoint.dx, currentPoint.dy);
          borderPath.lineTo(currentPoint.dx, currentPoint.dy);
        } else {
          // Create smooth curves for more realistic road following
          final prevPoint = _latLngToScreen(routePoints[i - 1], bounds, size);
          final controlPoint1 = Offset(
            prevPoint.dx + (currentPoint.dx - prevPoint.dx) * 0.3,
            prevPoint.dy + (currentPoint.dy - prevPoint.dy) * 0.3,
          );
          final controlPoint2 = Offset(
            prevPoint.dx + (currentPoint.dx - prevPoint.dx) * 0.7,
            prevPoint.dy + (currentPoint.dy - prevPoint.dy) * 0.7,
          );

          // Add some variation to make it look more like roads
          final variation = math.sin(i * 0.5) * 2.0;
          final adjustedCurrent = Offset(
            currentPoint.dx + variation,
            currentPoint.dy + variation,
          );

          path.cubicTo(
            controlPoint1.dx, controlPoint1.dy,
            controlPoint2.dx, controlPoint2.dy,
            adjustedCurrent.dx, adjustedCurrent.dy,
          );
          shadowPath.cubicTo(
            controlPoint1.dx, controlPoint1.dy,
            controlPoint2.dx, controlPoint2.dy,
            adjustedCurrent.dx, adjustedCurrent.dy,
          );
          borderPath.cubicTo(
            controlPoint1.dx, controlPoint1.dy,
            controlPoint2.dx, controlPoint2.dy,
            adjustedCurrent.dx, adjustedCurrent.dy,
          );
        }
      }
    }

    // Draw in layers: shadow, white border, then main route
    canvas.drawPath(shadowPath, shadowPaint);
    canvas.drawPath(borderPath, borderPaint);
    canvas.drawPath(path, routePaint);

    // Add direction arrows along the route
    _drawDirectionArrows(canvas, size, bounds);
  }

  void _drawDirectionArrows(Canvas canvas, Size size, MapBounds bounds) {
    if (routePoints.length < 2) return;

    final arrowPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..style = PaintingStyle.fill;

    // Draw arrows at regular intervals
    for (int i = 0; i < routePoints.length - 1; i += math.max(1, routePoints.length ~/ 8)) {
      final startPoint = _latLngToScreen(routePoints[i], bounds, size);
      final endPoint = _latLngToScreen(routePoints[i + 1], bounds, size);

      // Calculate arrow direction
      final direction = math.atan2(endPoint.dy - startPoint.dy, endPoint.dx - startPoint.dx);
      final midPoint = Offset(
        (startPoint.dx + endPoint.dx) / 2,
        (startPoint.dy + endPoint.dy) / 2,
      );

      // Draw arrow
      _drawArrowHead(canvas, midPoint, direction, arrowPaint);
    }
  }

  void _drawArrowHead(Canvas canvas, Offset position, double direction, Paint paint) {
    const arrowSize = 8.0;
    final arrowPath = Path();

    // Calculate arrow points
    final tipX = position.dx + math.cos(direction) * arrowSize;
    final tipY = position.dy + math.sin(direction) * arrowSize;

    final leftX = position.dx + math.cos(direction - 2.5) * arrowSize * 0.6;
    final leftY = position.dy + math.sin(direction - 2.5) * arrowSize * 0.6;

    final rightX = position.dx + math.cos(direction + 2.5) * arrowSize * 0.6;
    final rightY = position.dy + math.sin(direction + 2.5) * arrowSize * 0.6;

    arrowPath.moveTo(tipX, tipY);
    arrowPath.lineTo(leftX, leftY);
    arrowPath.lineTo(rightX, rightY);
    arrowPath.close();

    canvas.drawPath(arrowPath, paint);
  }

  void _drawMarkers(Canvas canvas, Size size, MapBounds bounds) {
    // Draw start marker
    if (startPoint != null) {
      final screenPoint = _latLngToScreen(LatLng(startPoint!.latitude, startPoint!.longitude), bounds, size);
      _drawMarker(canvas, screenPoint, Colors.green, 'S', 12.0);
    }

    // Draw via markers
    for (int i = 0; i < viaPoints.length; i++) {
      final viaPoint = viaPoints[i];
      final screenPoint = _latLngToScreen(LatLng(viaPoint.latitude, viaPoint.longitude), bounds, size);
      _drawMarker(canvas, screenPoint, Colors.orange, '${i + 1}', 10.0);
    }

    // Draw end marker
    if (endPoint != null) {
      final screenPoint = _latLngToScreen(LatLng(endPoint!.latitude, endPoint!.longitude), bounds, size);
      _drawMarker(canvas, screenPoint, Colors.red, 'E', 12.0);
    }
  }

  void _drawMarker(Canvas canvas, Offset position, Color color, String label, double size) {
    // Draw marker circle
    final markerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    // Shadow
    canvas.drawCircle(position + const Offset(1, 1), size, shadowPaint);
    // Marker
    canvas.drawCircle(position, size, markerPaint);
    
    // White border
    final borderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(position, size, borderPaint);

    // Draw label
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.8,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      position - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }



  Offset _latLngToScreen(LatLng latLng, MapBounds bounds, Size size) {
    final x = ((latLng.longitude - bounds.minLng) / (bounds.maxLng - bounds.minLng)) * size.width;
    final y = ((bounds.maxLat - latLng.latitude) / (bounds.maxLat - bounds.minLat)) * size.height;
    return Offset(x, y);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Helper class for map bounds calculation
class MapBounds {
  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;

  MapBounds(this.minLat, this.maxLat, this.minLng, this.maxLng);
}