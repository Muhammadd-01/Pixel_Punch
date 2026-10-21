import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../game/models/custom_villain.dart';

/// Stores villains generated from face photos. Portraits are small PNGs kept
/// as base64 so this works the same on mobile, desktop and web.
class CustomVillainService extends ChangeNotifier {
  static const String _storageKey = 'custom_villains_v1';
  static const int maxVillains = 12;

  final List<CustomVillain> _villains = [];
  bool _loaded = false;

  List<CustomVillain> get villains => List.unmodifiable(_villains);
  bool get isLoaded => _loaded;

  CustomVillain? byId(String id) {
    for (final v in _villains) {
      if (v.id == id) return v;
    }
    return null;
  }

  List<CustomVillain> forZone(String zoneId) =>
      _villains.where((v) => v.zoneId == zoneId).toList();

  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null) {
        final list = jsonDecode(raw) as List;
        _villains
          ..clear()
          ..addAll(list.map(
              (e) => CustomVillain.fromJson(e as Map<String, dynamic>)));
      }
    } catch (e) {
      debugPrint('[CustomVillainService] load failed: $e');
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> save(CustomVillain villain) async {
    final index = _villains.indexWhere((v) => v.id == villain.id);
    if (index >= 0) {
      _villains[index] = villain;
    } else {
      _villains.insert(0, villain);
      if (_villains.length > maxVillains) _villains.removeLast();
    }
    notifyListeners();
    await _persist();
  }

  Future<void> delete(String id) async {
    _villains.removeWhere((v) => v.id == id);
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _storageKey,
        jsonEncode(_villains.map((v) => v.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('[CustomVillainService] save failed: $e');
    }
  }
}
