import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'utils/constants.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/auth/onboarding_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/otp_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/admin/admin_login_screen.dart';
import 'screens/admin/admin_panel_screen.dart';
import 'screens/tournaments/tournaments_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (Firebase.apps.isEmpty) {
    try {
      await Firebase.initializeApp();
    } on FirebaseException catch (e) {
      if (e.code != 'duplicate-app') {
        rethrow;
      }
    }
  }
  
  try {
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.playIntegrity,
    );
  } catch (e) {
    debugPrint('App Check activation failed: $e');
    
    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.debug,
      );
    } catch (e2) {
      debugPrint('Debug App Check also failed: $e2');
    }
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
        ),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/signup': (context) => const SignupScreen(),
        '/login': (context) => const LoginScreen(),
        '/verify-otp': (context) => const OtpScreen(),
        '/admin-login': (context) => const AdminLoginScreen(),
        '/admin-panel': (context) => const AdminPanelScreen(),
        '/home': (context) =>
            const HomeScreen(),
        '/tournaments': (context) => const TournamentsScreen(),
      },
    );
  }
}
