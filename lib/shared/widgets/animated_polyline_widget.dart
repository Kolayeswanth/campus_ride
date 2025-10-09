import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;

/// Animated polyline widget that draws the route progressively like Apple Maps
class AnimatedPolylineWidget extends StatefulWidget {
  final List<latlong.LatLng> routePoints;
  final Color color;
  final double strokeWidth;
  final Color borderColor;
  final double borderStrokeWidth;
  final Duration animationDuration;
  final VoidCallback? onAnimationComplete;

  const AnimatedPolylineWidget({
    super.key,
    required this.routePoints,
    this.color = const Color(0xFF007AFF), // Apple Maps blue
    this.strokeWidth = 5.0,
    this.borderColor = Colors.white,
    this.borderStrokeWidth = 1.5,
    this.animationDuration = const Duration(milliseconds: 2000),
    this.onAnimationComplete,
  });

  @override
  State<AnimatedPolylineWidget> createState() => _AnimatedPolylineWidgetState();
}

class _AnimatedPolylineWidgetState extends State<AnimatedPolylineWidget>
    with SingleTickerProviderStateMixin {
  
  late AnimationController _animationController;
  late Animation<double> _animation;
  List<latlong.LatLng> _currentPoints = [];
  Timer? _animationTimer;

  @override
  void initState() {
    super.initState();
    _initializeAnimation();
  }

  void _initializeAnimation() {
    _animationController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _animation.addListener(_updatePoints);
    _animation.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onAnimationComplete?.call();
      }
    });
  }

  void _updatePoints() {
    if (widget.routePoints.isEmpty) return;

    final progress = _animation.value;
    final targetIndex = (progress * (widget.routePoints.length - 1)).floor();
    final targetProgress = progress * (widget.routePoints.length - 1) - targetIndex;

    setState(() {
      _currentPoints = widget.routePoints.take(targetIndex + 1).toList();
      
      // Add interpolated point for smooth animation
      if (targetIndex < widget.routePoints.length - 1 && targetProgress > 0) {
        final currentPoint = widget.routePoints[targetIndex];
        final nextPoint = widget.routePoints[targetIndex + 1];
        
        final interpolatedLat = currentPoint.latitude + 
            (nextPoint.latitude - currentPoint.latitude) * targetProgress;
        final interpolatedLng = currentPoint.longitude + 
            (nextPoint.longitude - currentPoint.longitude) * targetProgress;
        
        _currentPoints.add(latlong.LatLng(interpolatedLat, interpolatedLng));
      }
    });
  }

  void startAnimation() {
    _animationController.reset();
    _animationController.forward();
  }

  void stopAnimation() {
    _animationController.stop();
  }

  void resetAnimation() {
    _animationController.reset();
    setState(() {
      _currentPoints = [];
    });
  }

  @override
  void didUpdateWidget(AnimatedPolylineWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (oldWidget.routePoints != widget.routePoints) {
      resetAnimation();
      if (widget.routePoints.isNotEmpty) {
        // Auto-start animation when new route points are provided
        Future.delayed(const Duration(milliseconds: 100), () {
          startAnimation();
        });
      }
    }
  }

  @override
  void dispose() {
    _animationTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentPoints.length < 2) {
      return const SizedBox.shrink();
    }

    return PolylineLayer(
      polylines: [
        // Border/shadow polyline for better visibility
        if (widget.borderStrokeWidth > 0)
          Polyline(
            points: _currentPoints,
            color: widget.borderColor,
            strokeWidth: widget.strokeWidth + widget.borderStrokeWidth * 2,
          ),
        // Main polyline
        Polyline(
          points: _currentPoints,
          color: widget.color,
          strokeWidth: widget.strokeWidth,
        ),
      ],
    );
  }
}

/// Enhanced animated polyline with pulsing effect for route endpoints
class EnhancedAnimatedPolyline extends StatefulWidget {
  final List<latlong.LatLng> routePoints;
  final Color routeColor;
  final double strokeWidth;
  final Duration animationDuration;
  final bool showPulsingMarkers;
  final VoidCallback? onAnimationComplete;

  const EnhancedAnimatedPolyline({
    super.key,
    required this.routePoints,
    this.routeColor = const Color(0xFF007AFF),
    this.strokeWidth = 5.0,
    this.animationDuration = const Duration(milliseconds: 2000),
    this.showPulsingMarkers = true,
    this.onAnimationComplete,
  });

  @override
  State<EnhancedAnimatedPolyline> createState() => _EnhancedAnimatedPolylineState();
}

class _EnhancedAnimatedPolylineState extends State<EnhancedAnimatedPolyline>
    with TickerProviderStateMixin {
  
  late AnimationController _routeAnimationController;
  late AnimationController _pulseAnimationController;
  late Animation<double> _routeAnimation;
  late Animation<double> _pulseAnimation;
  
  List<latlong.LatLng> _animatedPoints = [];
  bool _animationCompleted = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    // Route drawing animation
    _routeAnimationController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _routeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _routeAnimationController,
      curve: Curves.easeOut,
    ));

    _routeAnimation.addListener(_updateRoutePoints);
    _routeAnimation.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _animationCompleted = true;
        });
        widget.onAnimationComplete?.call();
      }
    });

    // Pulsing markers animation
    _pulseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseAnimationController,
      curve: Curves.easeInOut,
    ));

    // Start pulsing animation
    if (widget.showPulsingMarkers) {
      _pulseAnimationController.repeat(reverse: true);
    }
  }

  void _updateRoutePoints() {
    if (widget.routePoints.isEmpty) return;

    final progress = _routeAnimation.value;
    final targetPointCount = (progress * widget.routePoints.length).ceil();
    
    setState(() {
      _animatedPoints = widget.routePoints.take(targetPointCount).toList();
    });
  }

  void startRouteAnimation() {
    setState(() {
      _animationCompleted = false;
    });
    _routeAnimationController.forward(from: 0.0);
  }

  @override
  void didUpdateWidget(EnhancedAnimatedPolyline oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (oldWidget.routePoints != widget.routePoints && widget.routePoints.isNotEmpty) {
      // Reset and start animation for new route
      _animatedPoints.clear();
      _animationCompleted = false;
      Future.delayed(const Duration(milliseconds: 200), () {
        startRouteAnimation();
      });
    }
  }

  @override
  void dispose() {
    _routeAnimationController.dispose();
    _pulseAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Animated route polyline
        if (_animatedPoints.length >= 2)
          PolylineLayer(
            polylines: [
              // Shadow/border
              Polyline(
                points: _animatedPoints,
                color: Colors.black.withOpacity(0.3),
                strokeWidth: widget.strokeWidth + 2,
              ),
              // Main route
              Polyline(
                points: _animatedPoints,
                color: widget.routeColor,
                strokeWidth: widget.strokeWidth,
              ),
            ],
          ),
        
        // Pulsing markers for start and end points
        if (widget.showPulsingMarkers && widget.routePoints.isNotEmpty)
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return MarkerLayer(
                markers: [
                  // Start marker
                  if (widget.routePoints.isNotEmpty)
                    Marker(
                      point: widget.routePoints.first,
                      child: _buildPulsingMarker(
                        color: Colors.green,
                        icon: Icons.trip_origin,
                        scale: _pulseAnimation.value,
                      ),
                      width: 40,
                      height: 40,
                    ),
                  
                  // End marker (only show if animation is completed or close to completion)
                  if (widget.routePoints.length > 1 && 
                      (_animationCompleted || _routeAnimation.value > 0.8))
                    Marker(
                      point: widget.routePoints.last,
                      child: _buildPulsingMarker(
                        color: Colors.red,
                        icon: Icons.location_on,
                        scale: _pulseAnimation.value,
                      ),
                      width: 40,
                      height: 40,
                    ),
                ],
              );
            },
          ),
      ],
    );
  }

  Widget _buildPulsingMarker({
    required Color color,
    required IconData icon,
    required double scale,
  }) {
    return Transform.scale(
      scale: scale,
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: color,
          size: 24,
        ),
      ),
    );
  }
}