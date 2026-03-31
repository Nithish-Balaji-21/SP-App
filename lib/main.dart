import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StatePharmacyApp());
}

class StatePharmacyApp extends StatelessWidget {
  const StatePharmacyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF1A237E);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'State Pharmacy',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: navy,
          primary: navy,
          surface: Colors.white,
        ),
        textTheme: GoogleFonts.latoTextTheme(),
        appBarTheme: const AppBarTheme(
          backgroundColor: navy,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFFF8F9FF),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: navy,
            foregroundColor: Colors.white,
            textStyle: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      home: kIsWeb ? const _AndroidOnlyScreen() : const HomeScreen(),
    );
  }
}

class _AndroidOnlyScreen extends StatelessWidget {
  const _AndroidOnlyScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('STATE PHARMACY')),
      body: const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: Text(
            'This app is Android-only because it uses local SQLite (sqflite).\n\n'
            'Run on an Android device or emulator:\n'
            'flutter run -d android',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, height: 1.4),
          ),
        ),
      ),
    );
  }
}
