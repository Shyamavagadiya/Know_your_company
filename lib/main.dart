import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:hcd_project2/firebase_options.dart';
import 'package:hcd_project2/gmail_screen.dart';
import 'package:hcd_project2/login_page.dart';
import 'package:hcd_project2/user_provider.dart';
import 'package:provider/provider.dart';
import 'package:hcd_project2/landing_page.dart';
import 'package:hcd_project2/module.dart';
import 'package:hcd_project2/home_screen.dart';
import 'package:hcd_project2/splash_screen.dart';
import 'package:hcd_project2/notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Background message handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('Handling a background message: ${message.messageId}');
}

// Initialize local notifications
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Set up background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  // Initialize local notifications
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  
  // Initialize notification service
  await NotificationService().initialize();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) {
          // Create and initialize the UserProvider
          final provider = UserProvider();
          // Initialize the auth state listener
          provider.initAuthListener();
          return provider;
        }),
      ],
      child: MaterialApp(
        title: 'Placement Management',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        // Use SplashScreen as the initial screen to check auth state
        home: SplashScreen(),
      ),
    );
  }
}