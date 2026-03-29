import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import '../../../core/models/student_models.dart';

class StudentMenuService {
  final FirebaseFirestore _db;
  final String _canteenId = 'default';

  StudentMenuService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  /// Returns a stream of the fully constructed daily menu for the given date.
  /// Uses recursive switchMap to ensure sub-collections are reactively watched.
  Stream<StudentDailyMenu?> watchDailyMenu(String date) {
    final docRef = _db
        .collection('canteens')
        .doc(_canteenId)
        .collection('dailyMenus')
        .doc(date);

    return docRef.snapshots().switchMap((menuSnapshot) {
      if (!menuSnapshot.exists) return Stream.value(null);
      final menuData = menuSnapshot.data()!;

      // 1. Listen to sessions collection
      return docRef.collection('sessions').snapshots().switchMap((
        sessionsSnap,
      ) {
        if (sessionsSnap.docs.isEmpty) {
          return Stream.value(
            StudentDailyMenu.fromMap(menuSnapshot.id, menuData, []),
          );
        }

        // 2. For each session, listen to its items and slots
        final sessionStreams = sessionsSnap.docs.map((sessionDoc) {
          final sessionId = sessionDoc.id;
          final sessionData = sessionDoc.data();

          final itemsStream = sessionDoc.reference.collection('items').snapshots();
          final slotsStream = sessionDoc.reference.collection('slots').snapshots();

          return Rx.combineLatest2(itemsStream, slotsStream, (
            itemsSnap,
            slotsSnap,
          ) {
            final items =
                itemsSnap.docs.map((d) {
                  return StudentMenuItem.fromMap(
                    d.id,
                    d.data(),
                    sessionId,
                    sessionData['sessionNameSnapshot'] ?? '',
                  );
                }).toList();

            final slots =
                slotsSnap.docs.map((d) {
                  return StudentMenuSlot.fromMap(d.id, d.data());
                }).toList();

            return StudentMenuSession.fromMap(
              sessionId,
              sessionData,
              items,
              slots,
            );
          });
        }).toList();

        // 3. Combine all session streams into one DailyMenu
        return Rx.combineLatest(sessionStreams, (List<StudentMenuSession> sessions) {
          final sortedSessions = List<StudentMenuSession>.from(sessions);
          sortedSessions.sort((a, b) => a.startTime.compareTo(b.startTime));
          return StudentDailyMenu.fromMap(menuSnapshot.id, menuData, sortedSessions);
        });
      });
    });
  }

  /// Get the categories available to map category IDs to names.
  Future<Map<String, String>> fetchCategoriesMap() async {
    final snapshot = await _db
        .collection('canteens')
        .doc(_canteenId)
        .collection('categories')
        .get();

    return {
      for (var doc in snapshot.docs)
        doc.id: (doc.data()['name'] as String?) ?? '',
    };
  }
}
