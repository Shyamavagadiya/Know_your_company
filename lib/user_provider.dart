// providers/user_provider.dart
import 'package:flutter/foundation.dart';
import 'package:hcd_project2/auth_service.dart';
import 'package:hcd_project2/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserProvider with ChangeNotifier {
  UserModel? _currentUser;
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;

  Future<void> fetchCurrentUser() async {
    try {
      _isLoading = true;
      notifyListeners();

      final user = _authService.getCurrentUser();
      if (user != null) {
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          _currentUser = UserModel.fromMap(userDoc.data() as Map<String, dynamic>);
        }
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _authService.signOut();
      _currentUser = null;
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }
}