import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

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
  final GoogleSignIn _googleSignIn = GoogleSignIn(
  scopes: ['https://www.googleapis.com/auth/gmail.readonly'],
  clientId: kIsWeb 
      ? '9874797301-8l18k3qfog27di2rge6mubkoh0chr0g8.apps.googleusercontent.com'
      : null, // Let it use the default for Android
);

  Future<bool> isSignedIn() async {
    return await _googleSignIn.isSignedIn();
  }

  Future<bool> signIn() async {
    try {
      GoogleSignInAccount? googleUser;
      
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
      
      print("Google Sign-In successful: ${googleUser.email}");
      return true;
    } catch (error) {
      print("Google Sign-In error: $error");
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      print("User signed out.");
    } catch (error) {
      print("Sign-out error: $error");
    }
  }

  Future<List<EmailMessage>> fetchEmails() async {
    try {
      final googleUser = await _googleSignIn.signInSilently();
      if (googleUser == null) {
        throw Exception("User not signed in");
      }

      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;

      if (accessToken == null) {
        throw Exception("Access token is null");
      }

      // Create credentials with UTC DateTime
      final credentials = AccessCredentials(
        AccessToken(
          'Bearer', 
          accessToken, 
          DateTime.now().toUtc().add(Duration(hours: 1))
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
        q: 'in:inbox',
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
