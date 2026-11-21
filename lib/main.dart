import 'package:flutter/material.dart';
import 'ui/editor_screen.dart';

void main() {
  runApp(const SvgBuilderApp());
}

class SvgBuilderApp extends StatelessWidget {
  const SvgBuilderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SVG Builder',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueAccent,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const EditorScreen(),
    );
  }
}
