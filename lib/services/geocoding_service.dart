import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GeocodingService {
  final _functions = FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  Future<List<LatLng?>> geocodeAll(List<String> queries) async {
    final callable = _functions.httpsCallable('geocodePlaces');
    final response = await callable.call({'queries': queries});
    final results = (response.data as Map)['results'] as List;

    return results.map((r) {
      if (r == null) return null;
      final map = r as Map;
      return LatLng(
        (map['lat'] as num).toDouble(),
        (map['lng'] as num).toDouble(),
      );
    }).toList();
  }
}

final geocodingServiceProvider = Provider((ref) => GeocodingService());