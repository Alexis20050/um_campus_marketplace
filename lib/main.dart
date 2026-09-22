import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:app_links/app_links.dart';
import 'providers/auth_service.dart';
import 'providers/product_provider.dart';
import 'providers/message_provider.dart';
import 'providers/favorites_provider.dart';
import 'providers/theme_provider.dart'; // <-- new
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
        ChangeNotifierProvider(create: (_) => ThemeProvider()), // <-- new
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => MessageProvider()),
        ChangeNotifierProvider(create: (_) => FavoritesProvider()),
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
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    try {
      final initialLink = await _appLinks.getInitialLink();
      debugPrint('COLD START LINK: $initialLink');
      if (initialLink != null) {
        await Supabase.instance.client.auth.getSessionFromUrl(initialLink);
      }
    } catch (e) {
      debugPrint('Initial deep link error: $e');
    }

    _linkSubscription = _appLinks.uriLinkStream.listen((uri) async {
      debugPrint('WARM START LINK: $uri');
      try {
        await Supabase.instance.client.auth.getSessionFromUrl(uri);
      } catch (e) {
        debugPrint('Deep link handling error: $e');
      }
    }, onError: (err) => debugPrint('Deep link stream error: $err'));
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      try {
        await Supabase.instance.client.auth.refreshSession();
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      title: 'UM Campus Marketplace',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeProvider.mode,
      home: const LoginScreen(),
    );
  }
}
