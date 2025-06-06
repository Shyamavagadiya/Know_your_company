// services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Constructor that sets persistence
  AuthService() {
    // Firebase Auth on web already uses LOCAL persistence by default
    // For mobile platforms, this is also the default
    // This ensures the user stays logged in even after app restart
    if (!kIsWeb) {
      _auth.setPersistence(Persistence.LOCAL);
    }
  }
  
  // Check if a user exists in Firestore by email
  Future<bool> checkUserExistsByEmail(String email) async {
    try {
      final QuerySnapshot result = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      
      return result.docs.isNotEmpty;
    } catch (e) {
      print('Error checking if user exists: $e');
      return false;
    }
  }

  // Sign up with email and password
  Future<UserCredential> signUp({
    required String email,
    required String password,
    required String name,
    required String role,
  }) async {
    try {
      // Create user with email and password
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Add user to Firestore
      await _firestore.collection('users').doc(result.user!.uid).set({
        'uid': result.user!.uid,
        'email': email,
        'name': name,
        'role': role,
        'profilePicture': '',
        'fcmToken': '',
        'createdAt': FieldValue.serverTimestamp(),
        'lastActive': FieldValue.serverTimestamp(),
      });

      // If role is student, create student document
      if (role == 'student') {
        await _firestore.collection('students').doc(result.user!.uid).set({
          'uid': result.user!.uid,
          'rollNumber': '',
          'sem': 1,
          'cgpa': 0.0,
          'resume': '',
          'skillset': [],
          'placementStatus': 'not_placed',
          'eligibilityCriteria': {
            'cgpaCutoff': 0.0,
            'allowBacklogs': false,
            'backlogs': 0,
          },
        });
      }

      return result;
    } catch (e) {
      rethrow;
    }
  }

  // Sign in with email and password
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      return await _auth.signOut();
    } catch (e) {
      rethrow;
    }
  }

  // Get current user
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Get user role
  Future<String> getUserRole(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      return doc['role'];
    } catch (e) {
      rethrow;
    }
  }
  
  // Get user document by email
  Future<DocumentSnapshot?> getUserDocByEmail(String email) async {
    try {
      final QuerySnapshot result = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      
      if (result.docs.isNotEmpty) {
        return result.docs.first;
      }
      return null;
    } catch (e) {
      print('Error getting user document by email: $e');
      return null;
    }
  }
  
  // Check if a user account is linked to Google Sign-In
  Future<bool> isGoogleLinkedAccount(String email) async {
    try {
      final userDoc = await getUserDocByEmail(email);
      if (userDoc != null && userDoc.data() is Map<String, dynamic>) {
        final userData = userDoc.data() as Map<String, dynamic>;
        // Check if the account has a 'googleLinked' field set to true
        // or if the 'authProvider' field is set to 'google'
        return userData['googleLinked'] == true || 
               userData['authProvider'] == 'google';
      }
      return false;
    } catch (e) {
      print('Error checking if account is Google-linked: $e');
      return false;
    }
  }
}