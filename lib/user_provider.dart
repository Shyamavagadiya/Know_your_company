// providers/user_provider.dart
import 'package:flutter/foundation.dart';
import 'package:hcd_project2/auth_service.dart';
import 'package:hcd_project2/user_model.dart';
import 'package:hcd_project2/gmail_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserProvider with ChangeNotifier {
  UserModel? _currentUser;
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  List<EmailMessage>? _fetchedEmails;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  List<EmailMessage>? get fetchedEmails => _fetchedEmails;

  Future<void> fetchCurrentUser() async {
    try {
      _isLoading = true;
      notifyListeners();

      final user = _authService.getCurrentUser();
      if (user != null) {
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          _currentUser = UserModel.fromMap(userDoc.data() as Map<String, dynamic>);
          
          // Fetch emails for the user if they're authenticated
          final GmailService gmailService = GmailService();
          if (await gmailService.isSignedIn()) {
            _fetchedEmails = await gmailService.fetchEmails();
          }
        }
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      print('Error fetching current user: $e');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _authService.signOut();
      _currentUser = null;
      _fetchedEmails = null;
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }
  
  // Set current user from document snapshot (for Google Sign-In)
  Future<void> setCurrentUserFromDoc(DocumentSnapshot userDoc, List<EmailMessage>? emails) async {
    try {
      if (userDoc.exists) {
        _currentUser = UserModel.fromMap(userDoc.data() as Map<String, dynamic>);
        _fetchedEmails = emails;
        notifyListeners();
      }
    } catch (e) {
      print('Error setting current user from doc: $e');
      rethrow;
    }
  }
}