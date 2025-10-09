import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Route instructions panel that displays turn-by-turn navigation steps
class RouteInstructionsPanel extends StatelessWidget {
  final List<Map<String, dynamic>> instructions;
  final double? totalDistance;
  final double? totalDuration;
  final VoidCallback? onClose;
  final bool isExpanded;

  const RouteInstructionsPanel({
    super.key,
    required this.instructions,
    this.totalDistance,
    this.totalDuration,
    this.onClose,
    this.isExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    if (instructions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with route summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Drag handle
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Title and close button
                Row(
                  children: [
                    Icon(Icons.directions, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'Route Directions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                    const Spacer(),
                    if (onClose != null)
                      IconButton(
                        onPressed: onClose,
                        icon: Icon(Icons.close, color: Colors.grey.shade600),
                        iconSize: 20,
                      ),
                  ],
                ),
                
                // Route summary
                if (totalDistance != null || totalDuration != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (totalDistance != null) ...[
                        Icon(Icons.straighten, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          '${totalDistance!.toStringAsFixed(1)} km',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                      if (totalDistance != null && totalDuration != null)
                        Text(' • ', style: TextStyle(color: Colors.grey.shade500)),
                      if (totalDuration != null) ...[
                        Icon(Icons.schedule, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          '${totalDuration!.toStringAsFixed(0)} min',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${instructions.length} steps',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          
          // Instructions list
          Flexible(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: instructions.length,
              itemBuilder: (context, index) {
                final instruction = instructions[index];
                return _buildInstructionItem(instruction, index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionItem(Map<String, dynamic> instruction, int index) {
    final type = instruction['type']?.toString() ?? 'straight';
    final instructionText = instruction['instruction']?.toString() ?? 'Continue';
    final distance = instruction['readable_distance']?.toString() ?? '';
    final duration = instruction['readable_duration']?.toString() ?? '';
    final roadName = instruction['name']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step number and icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getInstructionColor(type),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Stack(
              children: [
                Center(
                  child: Icon(
                    _getInstructionIcon(type),
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                Positioned(
                  top: 2,
                  right: 2,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _getInstructionColor(type),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          
          // Instruction details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  instructionText,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                if (roadName.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'on $roadName',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                if (distance.isNotEmpty || duration.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (distance.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            distance,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                        if (duration.isNotEmpty) const SizedBox(width: 8),
                      ],
                      if (duration.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            duration,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getInstructionColor(String type) {
    switch (type) {
      case 'turn-left':
      case 'turn-slight-left':
      case 'turn-sharp-left':
        return Colors.orange;
      case 'turn-right':
      case 'turn-slight-right':
      case 'turn-sharp-right':
        return Colors.blue;
      case 'roundabout-enter':
      case 'roundabout-exit':
        return Colors.purple;
      case 'fork':
      case 'merge':
        return Colors.teal;
      case 'uturn':
        return Colors.red;
      case 'depart':
        return Colors.green;
      case 'arrive':
        return Colors.red.shade600;
      default:
        return Colors.grey;
    }
  }

  IconData _getInstructionIcon(String type) {
    switch (type) {
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
      case 'roundabout-enter':
      case 'roundabout-exit':
        return Icons.roundabout_left;
      case 'fork':
        return Icons.call_split;
      case 'merge':
        return Icons.merge;
      case 'uturn':
        return Icons.u_turn_left;
      case 'depart':
        return Icons.start;
      case 'arrive':
        return Icons.place;
      default:
        return Icons.straight;
    }
  }
}