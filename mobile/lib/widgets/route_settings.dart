import 'package:flutter/material.dart';

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
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Route Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: costing,
              decoration: const InputDecoration(labelText: 'Costing', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
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
            const SizedBox(height: 6),
            Row(
              children: [
                const Text('Avoid stairs', style: TextStyle(fontSize: 13)),
                const Spacer(),
                Switch(
                  value: avoidStairs,
                  onChanged: onAvoidStairsChanged,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
            Text('Walking speed: ${walkingSpeed.toStringAsFixed(1)} km/h', style: const TextStyle(fontSize: 12)),
            Slider(
              value: walkingSpeed,
              min: 1.0,
              max: 8.0,
              divisions: 14,
              label: '${walkingSpeed.toStringAsFixed(1)} km/h',
              onChanged: onWalkingSpeedChanged,
            ),
          ],
        ),
      ),
    );
  }
}
