import 'dart:convert';

import 'package:flutter/services.dart';

class BoholAddressRepository {
  static Map<String, List<String>>? _locations;

  static Future<Map<String, List<String>>> loadLocations() async {
    final cached = _locations;
    if (cached != null) return cached;

    final locations = await _readLocations();
    _locations = locations;
    return locations;
  }

  static Future<Map<String, List<String>>> _readLocations() async {
    final source = await rootBundle.loadString(
      'assets/data/bohol_locations.json',
    );
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic> || decoded.isEmpty) {
      throw const FormatException('Bohol municipality data is invalid.');
    }

    final locations = <String, List<String>>{};
    for (final entry in decoded.entries) {
      if (entry.value is! List) {
        throw const FormatException('Barangay data is invalid.');
      }
      locations[entry.key] = List<String>.from(entry.value as List);
    }
    return locations;
  }
}
