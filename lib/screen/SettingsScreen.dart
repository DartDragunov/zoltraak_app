import 'package:flutter/material.dart';
import 'package:zoltraak_app/notifier/SettingsNotifier.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DropdownButton<AppThemeMode>(
              value: SettingsNotifier().themeMode,
              items: const [
                DropdownMenuItem(
                  value: AppThemeMode.dark,
                  child: Text('Dark Theme'),
                ),
                DropdownMenuItem(
                  value: AppThemeMode.light,
                  child: Text('Light Theme'),
                ),
                DropdownMenuItem(
                  value: AppThemeMode.neonGreen,
                  child: Text('Neon Green Theme'),
                ),
                DropdownMenuItem(
                  value: AppThemeMode.neonOrange,
                  child: Text('Neon Orange Theme'),
                ),
              ],
              onChanged: (AppThemeMode? newTheme) {
                if (newTheme != null) {
                  SettingsNotifier().setThemeMode(newTheme);
                  setState(() {});
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
