import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final String _emailCollection = 'emailInfo';
  
  // For tracking the last processed email to avoid duplicate notifications
  String? _lastProcessedEmailId;
  
  // Stream controller for new email notifications
  final StreamController<Map<String, dynamic>> _emailStreamController = 
      StreamController<Map<String, dynamic>>.broadcast();
  
  // Stream that UI can listen to for new email notifications
  Stream<Map<String, dynamic>> get emailStream => _emailStreamController.stream;
  
  // Constructor
  factory NotificationService() {
    return _instance;
  }
  
  NotificationService._internal();
  
  // Initialize Firebase Messaging and Local Notifications
  Future<void> initialize() async {
    // Handle web platform differently
    if (kIsWeb) {
      // For web, we'll use a simplified initialization
      // that doesn't block the UI
      try {
        // Request permission for notifications in web
        // but don't block app rendering if it fails
        FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        ).then((settings) {
          print('Web notification permission status: ${settings.authorizationStatus}');
          
          // Get FCM token for web
          return FirebaseMessaging.instance.getToken();
        }).then((token) {
          print('Web FCM Token: $token');
          
          // Set up message listener for web
          FirebaseMessaging.onMessage.listen(_handleMessage);
          
          // Set up a listener for new emails in Firestore
          _setupEmailListener();
        }).catchError((error) {
          // Log error but don't block app rendering
          print('Error initializing web notifications: $error');
        });
      } catch (e) {
        print('Exception in web notification initialization: $e');
      }
    } else {
      // For mobile platforms, use the full initialization
      try {
        // Initialize local notifications for mobile
        const AndroidInitializationSettings initializationSettingsAndroid =
            AndroidInitializationSettings('@mipmap/ic_launcher');
        const InitializationSettings initializationSettings = InitializationSettings(
          android: initializationSettingsAndroid,
        );
        await _localNotifications.initialize(
          initializationSettings,
          onDidReceiveNotificationResponse: (NotificationResponse response) {
            // Handle notification tap
            print('Notification tapped: ${response.payload}');
          },
        );
        
        // Request permission for notifications on mobile
        NotificationSettings settings = await _firebaseMessaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        
        print('Mobile notification permission status: ${settings.authorizationStatus}');
        
        // Get FCM token for mobile device
        String? token = await _firebaseMessaging.getToken();
        print('Mobile FCM Token: $token');
        
        // Handle incoming messages when app is in foreground
        FirebaseMessaging.onMessage.listen(_handleMessage);
        
        // Set up a listener for new emails in Firestore
        _setupEmailListener();
      } catch (e) {
        print('Exception in mobile notification initialization: $e');
      }
    }
  }
  
  // Handle incoming messages
  void _handleMessage(RemoteMessage message) {
    print('Got a message whilst in the foreground!');
    print('Message data: ${message.data}');
    
    if (message.notification != null) {
      print('Message also contained a notification: ${message.notification}');
      // Show local notification (only on mobile)
      if (!kIsWeb) {
        _showNotification(
          message.notification!.title ?? 'New Message',
          message.notification!.body ?? 'You have a new message',
        );
      }
    }
    
    // If the message is about a new email, add it to the stream
    if (message.data.containsKey('type') && message.data['type'] == 'new_email') {
      _emailStreamController.add(message.data);
    }
  }
  
  // Set up a listener for new emails in Firestore
  void _setupEmailListener() {
    _firestore
        .collection(_emailCollection)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final latestEmail = snapshot.docs.first.data();
        final emailId = latestEmail['id'];
        
        // Check if this is a new email (not previously processed)
        if (_lastProcessedEmailId != emailId) {
          _lastProcessedEmailId = emailId;
          
          // Create notification data
          final emailData = {
            'type': 'new_email',
            'id': emailId,
            'subject': latestEmail['subject'],
            'from': latestEmail['from'],
            'date': latestEmail['date'],
            'snippet': latestEmail['snippet'],
          };
          
          // Add the new email to the stream for UI updates
          _emailStreamController.add(emailData);
          
          // Show a notification
          _showNotification(
            'New Email Received',
            'From: ${latestEmail['from']}\nSubject: ${latestEmail['subject']}',
            payload: emailId,
          );
        }
      }
    });
  }
  
  // Show a local notification using flutter_local_notifications
  Future<void> _showNotification(String title, String body, {String? payload}) async {
    // Skip for web platform
    if (kIsWeb) {
      print('Local notifications not supported on web platform');
      return;
    }
    
    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'email_channel',
        'Email Notifications',
        channelDescription: 'Notifications for new filtered emails',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
      );
      
      const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);
      
      await _localNotifications.show(
        DateTime.now().millisecond, // Unique ID
        title,
        body,
        platformDetails,
        payload: payload,
      );
    } catch (e) {
      print('Error showing notification: $e');
    }
  }
  
  // Show a notification in the UI (when app is in foreground)
  void showLocalNotification(BuildContext context, String title, String body) {
    // Show in-app notification using SnackBar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(body),
          ],
        ),
        action: SnackBarAction(
          label: 'View',
          onPressed: () {
            // Navigate to email details or list
          },
        ),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
      ),
    );
    
    // Also show system notification (only for mobile platforms)
    if (!kIsWeb) {
      _showNotification(title, body);
    }
  }
  
  // Dispose resources
  void dispose() {
    _emailStreamController.close();
  }
}