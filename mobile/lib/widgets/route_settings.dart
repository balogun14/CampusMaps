import 'package:flutter/material.dart';
import '../theme.dart';

class RouteSettingsWidget extends StatelessWidget {
  final String costing;
  final bool avoidStairs;
  final double walkingSpeed;
  final ValueChanged<String> onCostingChanged;
  final ValueChanged<bool> onAvoidStairsChanged;
  final ValueChanged<double> onWalkingSpeedChanged;

  const RouteSettingsWidget({
    super.key,
    required this.costing,
    required this.avoidStairs,
    required this.walkingSpeed,
    required this.onCostingChanged,
    required this.onAvoidStairsChanged,
    required this.onWalkingSpeedChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: Color(0x1A000000), blurRadius: 16, offset: Offset(0, -4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 44, height: 5,
              decoration: BoxDecoration(
                color: AppTheme.purpleLight,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.purpleLight.withAlpha(60),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.tune, color: AppTheme.purple, size: 18),
              ),
              const SizedBox(width: 10),
              const Text('Route Settings',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: costing,
            decoration: const InputDecoration(
              labelText: 'Costing',
              prefixIcon: Icon(Icons.directions_car, size: 20),
            ),
            items: const [
              DropdownMenuItem(value: 'pedestrian', child: Text('Pedestrian')),
              DropdownMenuItem(value: 'campus_pedestrian', child: Text('Campus Pedestrian')),
              DropdownMenuItem(value: 'auto', child: Text('Auto')),
              DropdownMenuItem(value: 'bicycle', child: Text('Bicycle')),
            ],
            onChanged: (v) {
              if (v != null) onCostingChanged(v);
            },
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.stairs, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                const Text('Avoid stairs', style: TextStyle(fontSize: 14)),
                const Spacer(),
                Switch(
                  value: avoidStairs,
                  onChanged: onAvoidStairsChanged,
                  activeThumbColor: AppTheme.coral,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.speed, size: 18, color: Colors.grey),
              const SizedBox(width: 8),
              Text('Walking speed: ${walkingSpeed.toStringAsFixed(1)} km/h',
                  style: const TextStyle(fontSize: 13)),
            ],
          ),
          Slider(
            value: walkingSpeed,
            min: 1.0,
            max: 8.0,
            divisions: 14,
            activeColor: AppTheme.teal,
            inactiveColor: AppTheme.tealLight.withAlpha(80),
            label: '${walkingSpeed.toStringAsFixed(1)} km/h',
            onChanged: onWalkingSpeedChanged,
          ),
        ],
      ),
    );
  }
}
