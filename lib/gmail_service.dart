import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class EmailMessage {
  final String id;
  final String subject;
  final String from;
  final String date;
  final String snippet;

  EmailMessage({
    required this.id,
    required this.subject,
    required this.from,
    required this.date,
    required this.snippet,
  });
}

class GmailService {
  //working on different platform 
  final GoogleSignIn _googleSignIn = GoogleSignIn(
  scopes: ['https://www.googleapis.com/auth/gmail.readonly'],
  clientId: kIsWeb 
      ? '9874797301-8l18k3qfog27di2rge6mubkoh0chr0g8.apps.googleusercontent.com'
      : null, // Let it use the default for Android
  
);

  // Secure storage for persisting tokens
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  // Keys for storing tokens
  static const String _accessTokenKey = 'gmail_access_token';
  static const String _accessTokenExpiryKey = 'gmail_token_expiry';
  static const String _refreshTokenKey = 'gmail_refresh_token';

  Future<bool> isSignedIn() async {
    return await _googleSignIn.isSignedIn();
  }

  Future<bool> signIn() async {
    try {
      GoogleSignInAccount? googleUser;
      
      // Try to use stored tokens first
      if (await _hasValidStoredToken()) {
        print("Using stored token for authentication");
        return true;
      }
      
      if (kIsWeb) {
        // Try silently first
        googleUser = await _googleSignIn.signInSilently();
        
        // If silent sign-in fails, use regular sign-in
        if (googleUser == null) {
          googleUser = await _googleSignIn.signIn();
        }
      } else {
        // For mobile, continue using the regular approach
        googleUser = await _googleSignIn.signIn();
      }
      
      if (googleUser == null) {
        print("Google Sign-In failed: User canceled the sign-in process.");
        return false;
      }
      
      // Store authentication tokens
      await _storeAuthTokens(googleUser);
      
      print("Google Sign-In successful: ${googleUser.email}");
      return true;
    } catch (error) {
      print("Google Sign-In error: $error");
      return false;
    }
  }
  
  // Store authentication tokens securely
  Future<void> _storeAuthTokens(GoogleSignInAccount googleUser) async {
    try {
      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final expiryTime = DateTime.now().toUtc().add(Duration(hours: 1));
      
      if (accessToken != null) {
        await _secureStorage.write(key: _accessTokenKey, value: accessToken);
        await _secureStorage.write(key: _accessTokenExpiryKey, value: expiryTime.toIso8601String());
        
        // Store refresh token if available
        if (googleAuth.idToken != null) {
          await _secureStorage.write(key: _refreshTokenKey, value: googleAuth.idToken);
        }
      }
    } catch (e) {
      print("Error storing auth tokens: $e");
    }
  }
  
  // Check if we have a valid stored token
  Future<bool> _hasValidStoredToken() async {
    try {
      final storedToken = await _secureStorage.read(key: _accessTokenKey);
      final expiryString = await _secureStorage.read(key: _accessTokenExpiryKey);
      final refreshToken = await _secureStorage.read(key: _refreshTokenKey);
      
      if (storedToken == null || expiryString == null) {
        return false;
      }
      
      final expiry = DateTime.parse(expiryString);
      final now = DateTime.now().toUtc();
      
      // If token is expired but we have a refresh token, try to refresh it
      if (now.isAfter(expiry) && refreshToken != null && refreshToken.isNotEmpty) {
        print("Token expired, attempting to refresh");
        return await _refreshAccessToken(refreshToken);
      }
      
      // Return true if token exists and is not expired
      return storedToken.isNotEmpty && now.isBefore(expiry);
    } catch (e) {
      print("Error checking stored token: $e");
      return false;
    }
  }
  
  // Refresh the access token using the refresh token
  Future<bool> _refreshAccessToken(String refreshToken) async {
    try {
      // Try to use silent sign-in first as it's more reliable than manual refresh
      final googleUser = await _googleSignIn.signInSilently();
      
      if (googleUser != null) {
        await _storeAuthTokens(googleUser);
        print("Successfully refreshed token via silent sign-in");
        return true;
      }
      
      print("Silent sign-in failed, token could not be refreshed");
      return false;
    } catch (e) {
      print("Error refreshing token: $e");
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      
      // Clear stored tokens
      await _secureStorage.delete(key: _accessTokenKey);
      await _secureStorage.delete(key: _accessTokenExpiryKey);
      await _secureStorage.delete(key: _refreshTokenKey);
      
      print("User signed out and tokens cleared.");
    } catch (error) {
      print("Sign-out error: $error");
    }
  }

  Future<List<EmailMessage>> fetchEmails({String? filterEmail}) async {
    try {
      // Get access token - either from storage or by authenticating
      String? accessToken;
      DateTime tokenExpiry = DateTime.now().toUtc().add(Duration(hours: 1));
      
      // Check if we have a valid stored token first
      if (await _hasValidStoredToken()) {
        accessToken = await _secureStorage.read(key: _accessTokenKey);
        final expiryString = await _secureStorage.read(key: _accessTokenExpiryKey);
        if (expiryString != null) {
          tokenExpiry = DateTime.parse(expiryString);
        }
      } else {
        // No valid stored token, need to authenticate
        // Try silent sign-in first for all cases
        GoogleSignInAccount? googleUser = await _googleSignIn.signInSilently();
        
        // If silent sign-in fails, we need explicit sign-in
        if (googleUser == null) {
          print("Silent sign-in failed, attempting explicit sign-in");
          googleUser = await _googleSignIn.signIn();
          
          if (googleUser == null) {
            throw Exception("User not signed in");
          }
        }

        final googleAuth = await googleUser.authentication;
        accessToken = googleAuth.accessToken;
        
        // Store the new tokens
        await _storeAuthTokens(googleUser);
      }

      if (accessToken == null) {
        throw Exception("Access token is null");
      }

      // Create credentials with UTC DateTime
      final credentials = AccessCredentials(
        AccessToken(
          'Bearer', 
          accessToken, 
          tokenExpiry
        ),
        null, // refreshToken
        ['https://www.googleapis.com/auth/gmail.readonly'],
      );

      // Create an authenticated HTTP client
      final authClient = authenticatedClient(http.Client(), credentials);

      // Create Gmail API client
      final gmailApi = gmail.GmailApi(authClient);

      // Fetch messages
      final response = await gmailApi.users.messages.list(
        'me',
        maxResults: 20,
        q: filterEmail != null ? 'in:inbox from:$filterEmail' : 'in:inbox',
      );

      final List<EmailMessage> emails = [];

      if (response.messages != null) {
        for (var message in response.messages!) {
          if (message.id != null) {
            final messageDetail = await gmailApi.users.messages.get(
              'me',
              message.id!,
            );

            String subject = '';
            String from = '';
            String date = '';

            if (messageDetail.payload?.headers != null) {
              for (var header in messageDetail.payload!.headers!) {
                if (header.name == 'Subject') {
                  subject = header.value ?? '';
                } else if (header.name == 'From') {
                  from = header.value ?? '';
                } else if (header.name == 'Date') {
                  date = header.value ?? '';
                }
              }
            }

            String snippet = messageDetail.snippet ?? '';

            emails.add(
              EmailMessage(
                id: message.id!,
                subject: subject,
                from: from,
                date: date,
                snippet: snippet,
              ),
            );
          }
        }
      }

      // Close the HTTP client when done
      authClient.close();
      
      return emails;
    } catch (error) {
      print("Failed to fetch emails: $error");
      return [];
    }
  }
}
