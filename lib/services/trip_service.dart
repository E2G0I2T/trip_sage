import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TripService {
  final _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'tripsage',
  );

  Future<String> saveTrip({
    required String destination,
    required DateTime startDate,
    required DateTime endDate,
    required int budget,
    required String travelStyle,
    required List<dynamic> days,
  }) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      throw Exception('로그인 정보가 없어요.');
    }

    final docRef = await _db.collection('trips').add({
      'userId': userId,
      'destination': destination,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'budget': budget,
      'travelStyle': travelStyle,
      'days': days,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }
}

final tripServiceProvider = Provider((ref) => TripService());