// providers/user_provider.dart
import 'package:flutter/foundation.dart';
import 'package:hcd_project2/auth_service.dart';
import 'package:hcd_project2/user_model.dart';
import 'package:hcd_project2/gmail_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProvider with ChangeNotifier {
  UserModel? _currentUser;
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GmailService _gmailService = GmailService();
  bool _isLoading = false;
  List<EmailMessage>? _fetchedEmails;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  List<EmailMessage>? get fetchedEmails => _fetchedEmails;
  bool get isAuthenticated => _auth.currentUser != null;

  // Listen to auth state changes
  void initAuthListener() {
    _auth.authStateChanges().listen((User? user) {
      if (user == null) {
        // User is signed out
        _currentUser = null;
        _fetchedEmails = null;
        notifyListeners();
      } else if (_currentUser == null || _currentUser!.uid != user.uid) {
        // User is signed in but our local data is not updated
        fetchCurrentUser();
      }
    });
  }

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
          if (await _gmailService.isSignedIn()) {
            // Only show emails from specific senders
            _fetchedEmails = await _gmailService.fetchEmails(
              allowedSenders: ['placements@marwadieducation.edu.in', 'shyama.vu3whg@gmail.com'],
              daysAgo: 30
            );
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
      // Sign out from Gmail service if signed in
      if (await _gmailService.isSignedIn()) {
        await _gmailService.signOut();
      }
      
      // Sign out from Firebase Auth
      await _authService.signOut();
      
      // Clear local user data
      _currentUser = null;
      _fetchedEmails = null;
      notifyListeners();
    } catch (e) {
      print('Error signing out: $e');
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
  
  // Method to store fetched emails from Gmail service
  Future<void> storeFetchedEmails(List<EmailMessage> emails) async {
    _fetchedEmails = emails;
    notifyListeners();
  }
}