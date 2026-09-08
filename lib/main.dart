import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'providers/auth_service.dart';
import 'providers/product_provider.dart';
import 'providers/message_provider.dart';
import 'providers/favorites_provider.dart'; // <-- add this import
import 'screens/login_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://czhsxiwdubdmrdcahzfq.supabase.co',
    anonKey: 'sb_publishable_BrDKA5rQykPMIHs0yXtvlQ_knbWu1_-',
  );
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => MessageProvider()),
        ChangeNotifierProvider(create: (_) => FavoritesProvider()), // <-- add
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      try {
        await Supabase.instance.client.auth.refreshSession();
      } catch (_) {
        // Session might be invalid; user should login again
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UM Campus Marketplace',
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      home: const LoginScreen(),
    );
  }
}
