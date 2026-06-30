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
    if (userId == null) throw Exception('로그인 정보가 없어요.');

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

  Future<List<Map<String, dynamic>>> fetchTrips() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) throw Exception('로그인 정보가 없어요.');

    final snapshot = await _db
        .collection('trips')
        .where('userId', isEqualTo: userId)
        .get();  // orderBy 제거

    final docs = snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();

    // 클라이언트에서 createdAt 내림차순 정렬
    docs.sort((a, b) {
      final aTime = a['createdAt'];
      final bTime = b['createdAt'];
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return (bTime as Timestamp).compareTo(aTime as Timestamp);
    });

    return docs;
  }

  Future<void> deleteTrip(String tripId) async {
    await _db.collection('trips').doc(tripId).delete();
  }

  Future<void> updateTrip({
    required String tripId,
    required List<dynamic> days,
  }) async {
    await _db.collection('trips').doc(tripId).update({
      'days': days,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

final tripServiceProvider = Provider((ref) => TripService());