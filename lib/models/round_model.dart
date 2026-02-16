import 'package:cloud_firestore/cloud_firestore.dart';

class Round {
  final String id;
  final String name;
  final String companyId;
  final int order;
  final Timestamp createdAt;
  final int? batchYear;

  Round({
    required this.id,
    required this.name,
    required this.companyId,
    required this.order,
    required this.createdAt,
    this.batchYear,
  });

  factory Round.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Round(
      id: doc.id,
      name: data['name'] ?? 'Unknown Round',
      companyId: data['companyId'] ?? '',
      order: data['order'] ?? 0,
      createdAt: data['createdAt'] ?? Timestamp.now(),
      batchYear: (data['batchYear'] is int)
          ? data['batchYear'] as int
          : (data['batchYear'] is num)
              ? (data['batchYear'] as num).toInt()
              : (data['batchYear'] is String)
                  ? int.tryParse(data['batchYear'] as String)
                  : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'companyId': companyId,
      'order': order,
      'createdAt': createdAt,
      'batchYear': batchYear,
    };
  }
}
