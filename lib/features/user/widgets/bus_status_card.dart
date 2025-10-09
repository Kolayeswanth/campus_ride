import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/bus_status.dart';
import '../../../core/services/favorites_service.dart';

class BusStatusCard extends StatelessWidget {
  final BusStatus bus;
  final VoidCallback? onTap;
  final EdgeInsets? margin;

  const BusStatusCard({
    super.key,
    required this.bus,
    this.onTap,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE5E7EB).withOpacity(0.8),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 2,
            offset: const Offset(0, 1),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bus.route.routeName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A1D29),
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            bus.busNumber ?? 'No bus number',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF6B7280),
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Heart icon
                    Container(
                      margin: const EdgeInsets.only(right: 12),
                      child: Consumer<FavoritesService>(
                        builder: (context, favoritesService, child) {
                          final isFavorite = favoritesService.isFavorite(bus.route.id);
                          
                          return GestureDetector(
                            onTap: () async {
                              await favoritesService.toggleFavorite(bus.route.id);
                              
                              // Show feedback to user
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isFavorite 
                                        ? 'Removed from favorites' 
                                        : 'Added to favorites',
                                  ),
                                  duration: const Duration(seconds: 1),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            child: Icon(
                              isFavorite 
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              size: 24,
                              color: isFavorite 
                                  ? Colors.red
                                  : const Color(0xFF6B7280),
                            ),
                          );
                        },
                      ),
                    ),
                    _buildStatusBadge(),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Info chips row
                Row(
                  children: [
                    _buildInfoChip(
                      icon: Icons.people_rounded,
                      label: bus.occupancyText,
                      color: _getOccupancyColor(),
                    ),
                    const SizedBox(width: 8),
                    if (bus.lastUpdateTime != null)
                      _buildInfoChip(
                        icon: Icons.access_time_rounded,
                        label: _formatLastUpdate(),
                        color: const Color(0xFF6B7280),
                      ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Content based on bus status
                if (bus.isActive && bus.isOnline) ...[
                  _buildActiveContent(),
                ] else ...[
                  _buildInactiveContent(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    Color backgroundColor;
    Color textColor;
    IconData icon;
    String statusText;
    
    // Use the actual status from the bus model
    switch (bus.status) {
      case BusCurrentStatus.active:
        if (bus.isOnline) {
          backgroundColor = const Color(0xFF10B981);
          textColor = Colors.white;
          icon = Icons.radio_button_checked_rounded;
          statusText = 'Live';
        } else {
          backgroundColor = const Color(0xFFF59E0B);
          textColor = Colors.white;
          icon = Icons.schedule_rounded;
          statusText = 'Active';
        }
        break;
      case BusCurrentStatus.inactive:
        backgroundColor = const Color(0xFF6B7280);
        textColor = Colors.white;
        icon = Icons.pause_circle_outline_rounded;
        statusText = 'Inactive';
        break;
      case BusCurrentStatus.offline:
        backgroundColor = const Color(0xFF6B7280);
        textColor = Colors.white;
        icon = Icons.radio_button_unchecked_rounded;
        statusText = 'Offline';
        break;
      case BusCurrentStatus.maintenance:
        backgroundColor = const Color(0xFFEF4444);
        textColor = Colors.white;
        icon = Icons.build_circle_outlined;
        statusText = 'Maintenance';
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: backgroundColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: textColor,
          ),
          const SizedBox(width: 6),
          Text(
            statusText,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveContent() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF4F46E5).withOpacity(0.08),
            const Color(0xFF7C3AED).withOpacity(0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF4F46E5).withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.my_location_rounded,
              color: Color(0xFF4F46E5),
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Live Tracking Available',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF4F46E5),
                    height: 1.2,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Tap to track real-time location',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6B7280),
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            color: Color(0xFF4F46E5),
            size: 16,
          ),
        ],
      ),
    );
  }

  Widget _buildInactiveContent() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B).withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFF59E0B).withOpacity(0.2),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.schedule_rounded,
                  color: Color(0xFDF59E0B),
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bus Currently Offline',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFDF59E0B),
                        height: 1.2,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Contact driver for more information',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6B7280),
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Contact buttons
        if (bus.hasAssignedDriver && bus.driverPhone != null)
          _buildContactButton(
            icon: Icons.phone_rounded,
            label: 'Call Driver',
            subtitle: bus.driverPhone!,
            onTap: () => _makePhoneCall(bus.driverPhone!),
            color: const Color(0xFF10B981),
          )
        else
          _buildContactButton(
            icon: Icons.support_agent_rounded,
            label: 'Contact Support',
            subtitle: 'Bus support team',
            onTap: () => _makePhoneCall('+1234567890'), // Default support number
            color: const Color(0xFF6B7280),
          ),
      ],
    );
  }

  Widget _buildContactButton({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Material(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: color,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6B7280),
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: color,
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getOccupancyColor() {
    if (bus.passengerCount == 0) return const Color(0xFF6B7280);
    
    final occupancyRatio = bus.passengerCount / bus.maxCapacity;
    
    if (occupancyRatio >= 0.8) {
      return const Color(0xFFEF4444); // Red for high occupancy
    } else if (occupancyRatio >= 0.6) {
      return const Color(0xFFF59E0B); // Orange for medium occupancy
    } else {
      return const Color(0xFF10B981); // Green for low occupancy
    }
  }

  String _formatLastUpdate() {
    if (bus.lastUpdateTime == null) return 'No data';
    
    final now = DateTime.now();
    final difference = now.difference(bus.lastUpdateTime!);
    
    if (difference.inSeconds < 30) {
      return 'Just now';
    } else if (difference.inMinutes < 1) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else {
      return '${difference.inHours}h ago';
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      }
    } catch (e) {
      debugPrint('Could not make phone call: $e');
    }
  }
}