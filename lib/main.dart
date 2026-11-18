import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gd_college/screens/login_screen.dart';
import 'package:gd_college/services/session_service.dart';
import 'package:gd_college/fees_management/screens/verify_receipt_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  SessionService.instance.attach();

  runApp(const ProviderScope(child: StudentApp()));
}

/// A 12-digit receipt code carried in the launch URL, if any — the public
/// verify route. Accepts `?c=CODE` as well as hash forms (`#/verify/CODE`,
/// `#/verify?c=CODE`) so QR scans land here however the web build routes.
String? _initialVerifyCode() {
  final uri = Uri.base;
  final q = (uri.queryParameters['c'] ?? '').trim();
  if (RegExp(r'^\d{12}$').hasMatch(q)) return q;
  final frag = uri.fragment;
  final fromParam = RegExp(r'c=(\d{12})').firstMatch(frag);
  if (fromParam != null) return fromParam.group(1);
  final fromPath = RegExp(r'verify/(\d{12})').firstMatch(frag);
  if (fromPath != null) return fromPath.group(1);
  return null;
}

class StudentApp extends StatelessWidget {
  const StudentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LKLMS Management',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A3C6E),
          brightness: Brightness.light,
        ),
        fontFamily: 'Poppins',
        fontFamilyFallback: ['Roboto'],
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A3C6E),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A3C6E),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF1A3C6E), width: 2),
          ),
          labelStyle: const TextStyle(color: Colors.grey),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
      home: _initialVerifyCode() != null
          ? VerifyReceiptScreen(
              initialCode: _initialVerifyCode()!,
            )
          : Scaffold(body: LoginPage(),),
      navigatorKey: appNavigatorKey,
      builder: (context, child) =>
          SessionActivityDetector(child: child ?? const SizedBox.shrink()),
    );
  }
}
