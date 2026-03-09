// main.dart
// ignore_for_file: deprecated_member_use, avoid_types_as_parameter_names, use_build_context_synchronously

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'services.dart';
// NEW: import split screens instead of single screens.dart
import 'auth_screen.dart' as auth;
import 'home_screen.dart';

// ==================== CONFIG ====================
class UIConfig {
  static const Duration fast = Duration(milliseconds: 250);
  static const Duration medium = Duration(milliseconds: 450);
  static const Duration slow = Duration(milliseconds: 750);
  static const Curve curve = Curves.easeInOutCubic;
}

// ==================== MODELS ====================
class Budget {
  final String id;
  final double amount;
  final String expenseType;
  final DateTime dateTime;
  final String profileName;
  final String createdByUsername;
  final String createdBy;
  final String? imageUrl;
  final String? imagePath;

  Budget({
    required this.id,
    required this.amount,
    required this.expenseType,
    required this.dateTime,
    required this.profileName,
    required this.createdByUsername,
    required this.createdBy,
    this.imageUrl,
    this.imagePath,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'amount': amount,
    'expenseType': expenseType,
    'dateTime': dateTime.toIso8601String(),
    'profileName': profileName,
    'createdByUsername': createdByUsername,
    'createdBy': createdBy,
    if (imageUrl != null) 'imageUrl': imageUrl,
  };

  factory Budget.fromJson(Map<String, dynamic> json) => Budget(
    id: json['id'],
    amount: (json['amount'] as num).toDouble(),
    expenseType: json['expenseType'],
    dateTime: DateTime.parse(json['dateTime']),
    profileName: json['profileName'],
    createdByUsername: json['createdByUsername'] ?? 'Unknown',
    createdBy: json['createdBy'] ?? '',
    imageUrl: json['imageUrl'],
  );
}

// ==================== GLOBALS ====================
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const BuddyApp());
}

class BuddyApp extends StatelessWidget {
  const BuddyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: scaffoldMessengerKey,
      title: 'Buddy - Expense Tracker',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService().authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          return const HomeScreen();
        }

        return const auth.AuthScreen();
      },
    );
  }
}
