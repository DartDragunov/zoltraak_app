import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:zoltraak_app/model/SerialModel.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:zoltraak_app/screen/LoadingSceen.dart';
import 'package:zoltraak_app/screen/HomeScreen.dart';
import 'package:zoltraak_app/screen/SettingsScreen.dart';
import 'package:zoltraak_app/notifier/SettingsNotifier.dart';
import 'package:zoltraak_app/screen/RoadConfigScreen.dart';
import 'package:zoltraak_app/screen/PlayScreen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Desktop platforms need the FFI-based SQLite factory
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  // Register the serial singleton (port opens in MyApp.initState).
  // Update port name and baud rate to match the target device before deploying.
  SerialModel.initialize('/dev/ttyS8', 921600);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    SettingsNotifier().addListener(() {
      setState(() {});
    });
    SerialModel.instance.connect();
  }

  @override
  void dispose() {
    SettingsNotifier().removeListener(() {});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: SettingsNotifier().themeData,
      initialRoute: '/loading',
      routes: {
        '/loading': (context) => const LoadingScreen(),
        '/home': (context) => const Home(),
        '/settings': (context) => const Settings(),
        '/waveformSettings': (context) => const WaveformSettingsWidget(),
        '/play': (context) => const PlayScreen(),
        // '/debug': (context) => const DebugScreen(),
        // '/easterEgg': (context) => const EasterEggScreen(),
        // '/waveformpreInfo': (context) => const PreInfoScreen(),
        // '/waveformexecution': (context) => const ExecutionScreen(),
        // '/waveformpostInfo': (context) => const PostInfoScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
