import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';

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

  Future<dynamic> editItinerary({
    required Map currentItinerary,
    required String userMessage,
    required String destination,
    }) async {
    final callable = _functions.httpsCallable(
        'editItinerary',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 120)),
    );

    // Map을 JSON 문자열로 변환해서 넘기고 서버에서 파싱
    final response = await callable.call({
        'currentItineraryJson': jsonEncode(currentItinerary),
        'userMessage': userMessage,
        'destination': destination,
    });
    return response.data;
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

final itineraryServiceProvider = Provider((ref) => ItineraryService());