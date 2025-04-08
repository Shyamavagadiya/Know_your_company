import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hcd_project2/gmail_service.dart';

class FirebaseEmailService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionName = 'emailInfo';
  final String _targetEmail = 'shyama.vu3whg@gmail.com';

  /// Checks if the email is from the target sender (shyama.vu3whg@gmail.com)
  bool isFromTargetSender(String from) {
    // Email format can be "Name <email@example.com>" or just "email@example.com"
    return from.contains(_targetEmail);
  }

  /// Saves an email to Firestore
  Future<void> saveEmail(EmailMessage email) async {
    try {
      // Check if this email is already saved to avoid duplicates
      final existingDoc = await _firestore
          .collection(_collectionName)
          .where('id', isEqualTo: email.id)
          .get();

      if (existingDoc.docs.isNotEmpty) {
        print('Email with ID ${email.id} already exists in Firestore');
        return;
      }

      // Save the email to Firestore
      await _firestore.collection(_collectionName).doc(email.id).set({
        'id': email.id,
        'subject': email.subject,
        'from': email.from,
        'date': email.date,
        'snippet': email.snippet,
        'timestamp': FieldValue.serverTimestamp(),
      });

      print('Email saved to Firestore successfully');
    } catch (error) {
      print('Error saving email to Firestore: $error');
      rethrow;
    }
  }

  /// Saves multiple emails from the target sender to Firestore
  Future<void> saveEmailsFromTargetSender(List<EmailMessage> emails) async {
    try {
      int savedCount = 0;
      
      for (var email in emails) {
        if (isFromTargetSender(email.from)) {
          await saveEmail(email);
          savedCount++;
        }
      }
      
      print('Saved $savedCount emails from $_targetEmail to Firestore');
    } catch (error) {
      print('Error saving emails to Firestore: $error');
      rethrow;
    }
  }

  /// Retrieves all saved emails from Firestore
  Future<List<EmailMessage>> getSavedEmails() async {
    try {
      final snapshot = await _firestore
          .collection(_collectionName)
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return EmailMessage(
          id: data['id'],
          subject: data['subject'],
          from: data['from'],
          date: data['date'],
          snippet: data['snippet'],
        );
      }).toList();
    } catch (error) {
      print('Error retrieving emails from Firestore: $error');
      return [];
    }
  }
}