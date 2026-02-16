import 'package:cloud_firestore/cloud_firestore.dart';

class AppConfigService {
  AppConfigService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Global config document path: `config/app`
  DocumentReference<Map<String, dynamic>> get _configDoc =>
      _firestore.collection('config').doc('app');

  /// Returns the active batch year (e.g. 2026). If unset/missing, returns null.
  Future<int?> getActiveBatchYear() async {
    final snap = await _configDoc.get();
    if (!snap.exists) return null;

    final data = snap.data();
    if (data == null) return null;

    final v = data['activeBatchYear'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  /// Stream of active batch year changes. Emits null when missing/unset.
  Stream<int?> watchActiveBatchYear() {
    return _configDoc.snapshots().map((snap) {
      if (!snap.exists) return null;
      final data = snap.data();
      if (data == null) return null;
      final v = data['activeBatchYear'];
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v);
      return null;
    });
  }

  /// Returns a list of alumni batch years recorded in config/app.alumniBatchYears.
  Future<List<int>> getAlumniBatchYears() async {
    final snap = await _configDoc.get();
    if (!snap.exists) return <int>[];
    final data = snap.data();
    if (data == null) return <int>[];
    final raw = data['alumniBatchYears'];
    if (raw is! List) return <int>[];

    final List<int> result = [];
    for (final item in raw) {
      if (item is int) {
        result.add(item);
      } else if (item is num) {
        result.add(item.toInt());
      } else if (item is String) {
        final parsed = int.tryParse(item);
        if (parsed != null) result.add(parsed);
      }
    }
    result.sort();
    return result;
  }
}

