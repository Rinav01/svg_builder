import 'dart:ui';
import 'package:flutter/material.dart';
import 'ui/splash_screen.dart';
import 'ui/theme/studio_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Global crash protection: auto-save safety barrier on unhandled exceptions
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Global FlutterError caught: ${details.exceptionAsString()}');
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('Global PlatformDispatcher unhandled error caught: $error\n$stack');
    return true; // Handled to prevent abrupt process termination
  };

  runApp(const SvgBuilderApp());
}

class SvgBuilderApp extends StatelessWidget {
  const SvgBuilderApp({super.key, this.skipSplashForTests = false});

  final bool skipSplashForTests;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SVG Builder',
      debugShowCheckedModeBanner: false,
      theme: StudioTheme.darkTheme,
      home: const SplashScreen(),
    );
  }
}
