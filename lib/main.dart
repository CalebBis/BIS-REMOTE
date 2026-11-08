import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/remote_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  ));
  runApp(const BisRemoteApp());
}

/// Racine de l'application Télécommande Universelle.
class BisRemoteApp extends StatelessWidget {
  const BisRemoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        title: 'BisTv Remote',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.dark,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          colorSchemeSeed: const Color(0xFF00C8F0),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF111418),
          colorScheme: const ColorScheme.dark(
            surface: Color(0xFF1B2223),
            surfaceContainer: Color(0xFF1B2223),
            surfaceContainerHigh: Color(0xFF262D2E),
            surfaceContainerHighest: Color(0xFF262D2E),
            primary: Color(0xFF00C8F0),
            onPrimary: Color(0xFF111418),
            primaryContainer: Color(0xFF00525A),
            onPrimaryContainer: Color(0xFF00C8F0),
            onSurface: Color(0xFFE3E8E8),
            onSurfaceVariant: Color(0xFF8E999A),
            error: Color(0xFFE53935),
            errorContainer: Color(0xFFA01818),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF111418),
            elevation: 0,
          ),
        ),
        home: const RemoteScreen(),
      ),
    );
  }
}
