import 'package:flutter/material.dart';
import 'screens/home_shell.dart';
import 'services/app_state.dart';
import 'utils/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppState.instance.load();
  runApp(const MarkerCreatorApp());
}

class MarkerCreatorApp extends StatelessWidget {
  const MarkerCreatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Marker Creator',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const HomeShell(),
    );
  }
}
