import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'providers/auth_service.dart';
import 'providers/product_provider.dart';
import 'screens/login_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase with your project URL and anon key
  await Supabase.initialize(
    url:
        'https://czhsxiwdubdmrdcahzfq.supabase.co', // Replace with your actual URL
    anonKey:
        'sb_publishable_BrDKA5rQykPMIHs0yXtvlQ_knbWu1_-', // Replace with your actual anon key
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UM Campus Marketplace',
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      home: const LoginScreen(), // Start at login; auth state will redirect
    );
  }
}
