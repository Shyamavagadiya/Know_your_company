import 'package:cloud_firestore/cloud_firestore.dart';

class Round {
  final String id;
  final String name;
  final String companyId;
  final int order;
  final Timestamp createdAt;

  Round({
    required this.id,
    required this.name,
    required this.companyId,
    required this.order,
    required this.createdAt,
  });

  factory Round.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Round(
      id: doc.id,
      name: data['name'] ?? 'Unknown Round',
      companyId: data['companyId'] ?? '',
      order: data['order'] ?? 0,
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'companyId': companyId,
      'order': order,
      'createdAt': createdAt,
    };
  }
}
