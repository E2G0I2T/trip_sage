import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ItineraryService {
  final _functions = FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  Future<dynamic> generateItinerary({
    required String destination,
    required DateTime startDate,
    required DateTime endDate,
    required int budget,
    required String travelStyle,
  }) async {
    final callable = _functions.httpsCallable('generateItinerary');
    final response = await callable.call({
      'destination': destination,
      'startDate': _formatDate(startDate),
      'endDate': _formatDate(endDate),
      'budget': budget,
      'travelStyle': travelStyle,
    });
    return response.data;
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

final itineraryServiceProvider = Provider((ref) => ItineraryService());