import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
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
    // Initialize local notifications
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
    
    // Request permission for notifications
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    
    print('User notification permission status: ${settings.authorizationStatus}');
    
    // Get FCM token for this device
    String? token = await _firebaseMessaging.getToken();
    print('FCM Token: $token');
    
    // Handle incoming messages when app is in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');
      
      if (message.notification != null) {
        print('Message also contained a notification: ${message.notification}');
        // Show local notification
        _showNotification(
          message.notification!.title ?? 'New Message',
          message.notification!.body ?? 'You have a new message',
        );
      }
      
      // If the message is about a new email, add it to the stream
      if (message.data.containsKey('type') && message.data['type'] == 'new_email') {
        _emailStreamController.add(message.data);
      }
    });
    
    // Set up a listener for new emails in Firestore
    _setupEmailListener();
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
    
    // Also show system notification (works in background)
    _showNotification(title, body);
  }
  
  // Dispose resources
  void dispose() {
    _emailStreamController.close();
  }
}