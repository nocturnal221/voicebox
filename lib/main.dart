import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'admin_home_screen.dart';
import 'app_settings.dart';
import 'app_theme.dart';
import 'login_screen.dart';
import 'splash_screen.dart';
import 'sub_admin_home_screen.dart';
import 'user_home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://fefwunrnyldbytdpgmpl.supabase.co',
    anonKey: 'sb_publishable_O-IPlVXqdxuzGFIeiaEjeQ_l7WsI9YS',
  );

  final prefs = await SharedPreferences.getInstance();
  if (prefs.getString('device_token') == null) {
    await prefs.setString('device_token', const Uuid().v4());
  }

  await AppSettings.load();
  runApp(const VoiceBoxApp());
}

class VoiceBoxApp extends StatelessWidget {
  const VoiceBoxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppSettings.themeMode,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'VoiceBox',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: mode,
          home: const SplashScreen(),
        );
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final session = snapshot.data!.session;
        if (session == null) return const LoginScreen();

        return FutureBuilder<Map<String, dynamic>?>(
          future: _getProfile(session.user.id),
          builder: (context, profileSnap) {
            if (profileSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final role = profileSnap.data?['role'] ?? 'user';

            if (role == 'main_admin') return const AdminHomeScreen();
            if (role == 'sub_admin') return const SubAdminHomeScreen();
            return const UserHomeScreen();
          },
        );
      },
    );
  }

  Future<Map<String, dynamic>?> _getProfile(String userId) async {
    try {
      final res = await Supabase.instance.client
          .from('profiles')
          .select('role, assigned_category')
          .eq('id', userId)
          .single();
      return res;
    } catch (_) {
      return {'role': 'user'};
    }
  }
}
