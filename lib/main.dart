import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://fefwunrnyldbytdpgmpl.supabase.co',
    anonKey: 'sb_publishable_O-IPlVXqdxuzGFIeiaEjeQ_l7WsI9YS',
  );

  runApp(const VoiceBoxApp());
}

class VoiceBoxApp extends StatelessWidget {
  const VoiceBoxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VoiceBox',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.light,
        ),
        //useMaterial3: true,
      ),
      home: SplashScreen(),
    );
  }
}
