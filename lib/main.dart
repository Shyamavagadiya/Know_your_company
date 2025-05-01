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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, // This line is crucial
  );
  runApp(MyApp());
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