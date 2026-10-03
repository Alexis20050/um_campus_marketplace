import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'providers/admin_provider.dart';
import 'providers/auth_service.dart';
import 'providers/favorites_provider.dart';
import 'providers/message_provider.dart';
import 'providers/moderation_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/product_provider.dart';
import 'providers/rating_provider.dart';
import 'providers/theme_provider.dart';

import 'screens/auth_gate.dart';

import 'theme/app_theme.dart';

// ============================================================
// SUPABASE CONFIGURATION
// ============================================================
//
// Build-time override:
//
// flutter run \
//   --dart-define=SUPABASE_URL=https://xxx.supabase.co \
//   --dart-define=SUPABASE_ANON_KEY=sb_publishable_xxx
//
// The Supabase publishable/anon key is designed to be used by
// client applications.
//
// NEVER put the service_role key in Flutter.
// Backend protection must rely on RLS / RPC / Edge Functions.
// ============================================================

const _supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://czhsxiwdubdmrdcahzfq.supabase.co',
);

const _supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: 'sb_publishable_BrDKA5rQykPMIHs0yXtvlQ_knbWu1_-',
);

// ============================================================
// MAIN
// ============================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: _supabaseUrl,
    publishableKey: _supabasePublishableKey,
  );

  runApp(
    MultiProvider(
      providers: [
        // ------------------------------------------------------
        // APP / THEME
        // ------------------------------------------------------
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),

        // ------------------------------------------------------
        // AUTH
        // ------------------------------------------------------
        ChangeNotifierProvider<AuthService>(create: (_) => AuthService()),

        // ------------------------------------------------------
        // MARKETPLACE
        // ------------------------------------------------------
        ChangeNotifierProvider<ProductProvider>(
          create: (_) => ProductProvider(),
        ),

        ChangeNotifierProvider<MessageProvider>(
          create: (_) => MessageProvider(),
        ),

        ChangeNotifierProvider<FavoritesProvider>(
          create: (_) => FavoritesProvider(),
        ),

        ChangeNotifierProvider<RatingProvider>(create: (_) => RatingProvider()),

        // ------------------------------------------------------
        // SAFETY / MODERATION
        // ------------------------------------------------------
        ChangeNotifierProvider<ModerationProvider>(
          create: (_) => ModerationProvider(),
        ),

        // ------------------------------------------------------
        // NOTIFICATIONS
        // ------------------------------------------------------
        ChangeNotifierProvider<NotificationProvider>(
          create: (_) => NotificationProvider(),
        ),

        // ------------------------------------------------------
        // ADMIN
        // ------------------------------------------------------
        ChangeNotifierProvider<AdminProvider>(create: (_) => AdminProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

// ============================================================
// ROOT APP
// ============================================================

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late final AppLinks _appLinks;

  StreamSubscription<Uri>? _linkSubscription;

  // Prevent multiple deep-link handlers from being initialized.
  bool _deepLinksInitialized = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _initDeepLinks();
  }

  // ============================================================
  // DEEP LINKS
  // ============================================================

  Future<void> _initDeepLinks() async {
    if (_deepLinksInitialized) {
      return;
    }

    _deepLinksInitialized = true;

    _appLinks = AppLinks();

    // ----------------------------------------------------------
    // COLD START
    // ----------------------------------------------------------

    try {
      final initialLink = await _appLinks.getInitialLink();

      if (kDebugMode) {
        debugPrint('COLD START LINK: $initialLink');
      }

      if (initialLink != null) {
        await _handleAuthLink(initialLink);
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('Initial deep link error: $e');

        debugPrintStack(stackTrace: stackTrace);
      }
    }

    // ----------------------------------------------------------
    // WARM START
    // ----------------------------------------------------------

    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) async {
        if (kDebugMode) {
          debugPrint('WARM START LINK: $uri');
        }

        await _handleAuthLink(uri);
      },
      onError: (Object error) {
        if (kDebugMode) {
          debugPrint('Deep link stream error: $error');
        }
      },
    );
  }

  // ============================================================
  // HANDLE AUTH CALLBACK
  // ============================================================

  Future<void> _handleAuthLink(Uri uri) async {
    try {
      await Supabase.instance.client.auth.getSessionFromUrl(uri);
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('Deep link handling error: $e');

        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  // ============================================================
  // APP LIFECYCLE
  // ============================================================

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshSession();
    }
  }

  Future<void> _refreshSession() async {
    final auth = Supabase.instance.client.auth;

    // No reason to refresh when there is no active session.
    if (auth.currentSession == null) {
      return;
    }

    try {
      await auth.refreshSession();

      if (kDebugMode) {
        debugPrint('Supabase session refreshed.');
      }
    } catch (e) {
      // Non-fatal.
      //
      // Supabase can retry/refresh again during the next
      // authenticated operation.
      if (kDebugMode) {
        debugPrint('Session refresh skipped/failed: $e');
      }
    }
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _linkSubscription?.cancel();

    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      title: 'UM Campus Marketplace',

      debugShowCheckedModeBanner: false,

      // --------------------------------------------------------
      // THEME
      // --------------------------------------------------------
      theme: lightTheme,

      darkTheme: darkTheme,

      themeMode: themeProvider.mode,

      // --------------------------------------------------------
      // AUTH / ADMIN ROUTING
      // --------------------------------------------------------
      //
      // AuthGate decides:
      //
      // Not logged in
      //      -> LoginScreen
      //
      // Normal user
      //      -> MainScreen
      //
      // Admin / Moderator
      //      -> AdminMainScreen
      //
      // Do NOT add another MultiProvider inside AuthGate.
      // --------------------------------------------------------
      home: const AuthGate(),
    );
  }
}
