import 'package:flutter/material.dart';
import '../models/route_response.dart';
import '../utils/polyline_decoder.dart';

class DirectionsPanel extends StatelessWidget {
  final RouteResponse response;
  final VoidCallback onDismiss;

  static const _directionIcons = {
    'north': Icons.arrow_upward,
    'south': Icons.arrow_downward,
    'east': Icons.arrow_forward,
    'west': Icons.arrow_back,
    'northeast': Icons.north_east,
    'northwest': Icons.north_west,
    'southeast': Icons.south_east,
    'southwest': Icons.south_west,
    'straight': Icons.arrow_upward,
  };

  const DirectionsPanel({
    super.key,
    required this.response,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final s = response.summary;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: const Offset(0, -2))],
      ),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          ),
          // summary bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${s.distanceKm.toStringAsFixed(2)} km  ·  ${s.durationFormatted}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                TextButton(onPressed: onDismiss, child: const Text('Dismiss')),
              ],
            ),
          ),
          const Divider(height: 1),
          // steps list
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: response.steps.length,
              itemBuilder: (context, i) {
                final step = response.steps[i];
                final icon = _directionIcons[step.direction] ?? Icons.arrow_upward;
                return Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: step.isCustomPath ? Colors.orange.shade50 : null,
                    borderRadius: BorderRadius.circular(8),
                    border: step.isCustomPath ? Border(left: BorderSide(color: Colors.orange.shade400, width: 3)) : null,
                  ),
                  child: Row(
                    children: [
                      Column(children: [
                        Icon(icon, size: 18, color: step.isCustomPath ? Colors.orange : Colors.grey.shade600),
                        if (step.isCustomPath) Text('CAMPUS', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.orange.shade700)),
                      ]),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('#${step.stepNumber}  ${step.instruction}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                            Text('${step.distanceMeters.toStringAsFixed(0)} m', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
