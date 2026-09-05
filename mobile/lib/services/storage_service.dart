import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/recorded_activity.dart';

class StorageService {
  Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/activities.json');
  }

  Future<void> saveActivity(RecordedActivity activity) async {
    final file = await _getFile();
    final activities = await _loadAll();
    activities.add(activity.toJson());
    await file.writeAsString(jsonEncode(activities));
  }

  Future<List<RecordedActivity>> loadActivities() async {
    final list = await _loadAll();
    return list
        .map((j) => RecordedActivity.fromJson(j as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> deleteActivity(String id) async {
    final file = await _getFile();
    final activities = await _loadAll();
    activities.removeWhere((j) => j['id'] == id);
    await file.writeAsString(jsonEncode(activities));
  }

  Future<List<dynamic>> _loadAll() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      if (content.trim().isEmpty) return [];
      return jsonDecode(content) as List<dynamic>;
    } catch (_) {
      return [];
    }
  }
}
