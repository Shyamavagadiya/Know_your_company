import 'package:cloud_firestore/cloud_firestore.dart';

class BatchRolloverService {
  BatchRolloverService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _configDoc =>
      _firestore.collection('config').doc('app');

  /// Sets the active batch year that the app should show (Option A).
  Future<void> setActiveBatchYear(int year) async {
    await _configDoc.set({'activeBatchYear': year}, SetOptions(merge: true));
  }

  /// Marks all users for a given batch as alumni (sets `status: "alumni"`).
  ///
  /// This is client-side and depends on Firestore security rules allowing it
  /// (recommended: HOD-only).
  Future<void> markBatchUsersAsAlumni(int batchYear) async {
    await _updateAllMatching(
      collection: _firestore.collection('users'),
      query: _firestore.collection('users').where('batchYear', isEqualTo: batchYear),
      update: {'status': 'alumni'},
    );
  }

  /// Marks all students docs for a given batch as alumni (optional).
  Future<void> markBatchStudentsAsAlumni(int batchYear) async {
    await _updateAllMatching(
      collection: _firestore.collection('students'),
      query:
          _firestore.collection('students').where('batchYear', isEqualTo: batchYear),
      update: {'status': 'alumni'},
    );
  }

  /// Convenience: end old batch and switch to new batch.
  Future<void> rollover({
    required int oldBatchYear,
    required int newBatchYear,
  }) async {
    await markBatchUsersAsAlumni(oldBatchYear);
    await markBatchStudentsAsAlumni(oldBatchYear);
    // Record alumni batch and update active batch.
    await _configDoc.set({
      'activeBatchYear': newBatchYear,
      'alumniBatchYears': FieldValue.arrayUnion([oldBatchYear]),
    }, SetOptions(merge: true));
  }

  Future<void> _updateAllMatching({
    required CollectionReference collection,
    required Query query,
    required Map<String, dynamic> update,
  }) async {
    const pageSize = 400; // keep under 500 writes per batch

    Query pageQuery = query.limit(pageSize);
    DocumentSnapshot? lastDoc;

    while (true) {
      if (lastDoc != null) {
        pageQuery = query.startAfterDocument(lastDoc).limit(pageSize);
      }

      final snap = await pageQuery.get();
      if (snap.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        batch.update(collection.doc(doc.id), update);
      }
      await batch.commit();

      lastDoc = snap.docs.last;
    }
  }
}

