import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';
import 'home_page.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const BeadPatternApp(),
    ),
  );
}

class BeadPatternApp extends StatelessWidget {
  const BeadPatternApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '拼豆图纸生成器',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}
