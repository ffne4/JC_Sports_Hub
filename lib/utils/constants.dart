// This file holds all constants used across the entire app
// A constant is a value that never changes - defined once, used everywhere
// 'class' is a blueprint. AppColors is a blueprint that holds color values
import 'package:flutter/material.dart';

class AppColors {
  // 'static' means you access this directly without creating an object
  // Example: AppColors.primary instead of AppColors().primary
  // 'const' means this value is fixed at compile time - never changes

  // Primary green - Makerere University color
  static const Color primary = Color(0xFF1B5E20);

  // Lighter green for buttons and accents
  static const Color accent = Color(0xFF4CAF50);

  // Dark background for cards
  static const Color dark = Color(0xFF121212);

  // White text
  static const Color textLight = Color(0xFFFFFFFF);

  // Grey text for subtitles
  static const Color textGrey = Color(0xFF9E9E9E);

  // Background color of most screens
  static const Color background = Color(0xFFF5F5F5);

  // Error color - for wrong inputs
  static const Color error = Color(0xFFD32F2F);

  // Gold color - for badges and predictions
  static const Color gold = Color(0xFFFFD700);
}

class AppStrings {
  // App name used across multiple screens
  static const String appName = 'JC Sports Hub';

  // University name
  static const String university = 'Makerere University Jinja Campus';

  // Admin email - ONLY this email gets admin access
  // This is your webmail Drake - change this to your actual webmail
  static const String adminEmail = 'wanswa.drake@students.mak.ac.ug';

  // Webmail domain for bachelor students
  static const String bachelorDomain = '@students.mak.ac.ug';

  // Mobile money number shown to users when depositing into their wallet.
  // Money is sent here manually, outside the app - change to your real number.
  static const String adminMomoNumber = '0768658988';
  static const String adminMomoName = 'Drake Wanswa';
}

class AppSizes {
  // Standard padding used across screens
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;

  // Border radius for cards and buttons
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 20.0;

  // Font sizes
  static const double fontSmall = 12.0;
  static const double fontMedium = 16.0;
  static const double fontLarge = 20.0;
  static const double fontXL = 28.0;
}
