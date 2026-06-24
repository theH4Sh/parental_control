import 'package:flutter/material.dart';

import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/parent_dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AuthService.instance.init();
  await NotificationService.instance.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Parental Control',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F0E17),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF8906),
          secondary: Color(0xFFE53170),
          surface: Color(0xFF1E1F29),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E1F29),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
        ),
      ),
      // Decide initial route based on auth state
      initialRoute: AuthService.instance.isLoggedIn ? '/home' : '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) {
          if (AuthService.instance.isParent) {
            return const ParentDashboardScreen();
          } else {
            return const HomeScreen();
          }
        },
      },
    );
  }
}
