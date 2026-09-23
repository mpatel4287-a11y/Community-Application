// ignore_for_file: unused_import, no_leading_underscores_for_local_identifiers

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:app_links/app_links.dart';
import 'dart:async';

import 'firebase_options.dart';
import 'auth/login_screen.dart';
// Updated imports to use lib/screens/admin/
import 'screens/admin/admin_dashboard.dart';
import 'screens/admin/family_list_screen.dart';
import 'screens/admin/member_list_screen.dart';
import 'screens/admin/group_management_screen.dart';
import 'screens/admin/event_management_screen.dart';
import 'screens/admin/analytics_dashboard.dart';
import 'screens/admin/system_health_screen.dart';
import 'screens/admin/notification_center_screen.dart';
import 'screens/admin/firms_list_screen.dart';
import 'screens/admin/admin_update_requests_screen.dart';
import 'screens/user/digital_id_screen.dart';
import 'models/member_model.dart';
import 'screens/user/settings_screen.dart';
import 'screens/user/member_detail_screen.dart';
import 'screens/user/user_profile_screen.dart';
import 'screens/user/enhanced_user_dashboard.dart';
import 'screens/user/user_notification_screen.dart';
import 'screens/user/user_calendar_screen.dart';
import 'screens/user/user_search_tab.dart';
import 'screens/user/qr_scanner_screen.dart';
import 'screens/user/member_update_request_screen.dart';

import 'services/session_manager.dart';
import 'services/theme_service.dart';
import 'services/language_service.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'services/fcm_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/connectivity_service.dart';
import 'widgets/offline_banner.dart';

// Top-level background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    debugPrint('Firebase background init note: $e');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final themeService = ThemeService();
  final languageService = LanguageService();

  // Initialize Firebase safely if not already initialized
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    debugPrint('Firebase init note: $e');
  }

  // Initialize core services in parallel
  await Future.wait([
    themeService.initialize(),
    languageService.initialize(),
  ]);

  // Enable offline persistence
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // Initialize FCM (non-blocking - don't let it prevent app startup)
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize FCM in the background without blocking app startup
  FcmService.initialize().catchError((error) {
    // Silently handle FCM initialization errors
    // The app will still work without push notifications
  });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => themeService),
        ChangeNotifierProvider(create: (_) => languageService),
      ],
      child: const MyApp(),
    ),
  );
}

/// Initial routing widget that checks session and redirects to appropriate screen
class InitialRoute extends StatefulWidget {
  const InitialRoute({super.key});

  @override
  State<InitialRoute> createState() => _InitialRouteState();
}

class _InitialRouteState extends State<InitialRoute> {
  @override
  void initState() {
    super.initState();
    _checkSessionAndNavigate();
  }

  Future<void> _checkSessionAndNavigate() async {
    final hasSession = await SessionManager.hasSession();
    final isAdmin = await SessionManager.getIsAdmin() == true;
    final role = await SessionManager.getRole();
    final isStaff = isAdmin || role == 'admin' || role == 'manager';

    if (mounted) {
      if (hasSession && isStaff) {
        Navigator.pushReplacementNamed(context, '/admin');
      } else if (hasSession) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

/// Route guard widget that prevents unauthorized route jumping via web URL or deep links
class AuthGuard extends StatefulWidget {
  final Widget child;
  final bool requireAdmin;
  final bool requireUser;
  final bool isLoginRoute;

  const AuthGuard({
    super.key,
    required this.child,
    this.requireAdmin = false,
    this.requireUser = false,
    this.isLoginRoute = false,
  });

  @override
  State<AuthGuard> createState() => _AuthGuardState();
}

class _AuthGuardState extends State<AuthGuard> {
  bool _isChecking = true;
  bool _isAuthorized = false;

  @override
  void initState() {
    super.initState();
    _evaluateSession();
  }

  @override
  void didUpdateWidget(covariant AuthGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _evaluateSession();
  }

  Future<void> _evaluateSession() async {
    final hasSession = await SessionManager.hasSession();
    final isAdmin = await SessionManager.getIsAdmin() == true;
    final role = await SessionManager.getRole();
    final isStaff = isAdmin || role == 'admin' || role == 'manager';

    if (!mounted) return;

    if (widget.isLoginRoute) {
      // When visiting login route, clear active session to enforce fresh authentication
      await SessionManager.clearSession();
      if (mounted) {
        setState(() {
          _isChecking = false;
          _isAuthorized = true;
        });
      }
      return;
    }

    if (widget.requireAdmin) {
      if (!hasSession || !isStaff) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
        });
      } else {
        setState(() {
          _isChecking = false;
          _isAuthorized = true;
        });
      }
      return;
    }

    if (widget.requireUser) {
      if (!hasSession) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
        });
      } else {
        setState(() {
          _isChecking = false;
          _isAuthorized = true;
        });
      }
      return;
    }

    setState(() {
      _isChecking = false;
      _isAuthorized = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking || !_isAuthorized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    return widget.child;
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  void _initDeepLinks() {
    _appLinks = AppLinks();

    // Check initial link if app was opened via link
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleDeepLink(uri);
    });

    // Listen to incoming links while app is running
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });
  }

  void _handleDeepLink(Uri uri) {
    debugPrint('Received Deep Link: $uri');

    // Expected format: https://domain.com/member?id=MEMBER_ID&family=FAMILY_ID
    if (uri.path == '/member') {
      final memberId = uri.queryParameters['id'];
      final familyDocId = uri.queryParameters['family'];

      if (memberId != null && memberId.isNotEmpty) {
        // Navigate to Member Detail screen
        navigatorKey.currentState?.pushNamed(
          '/user/member-detail',
          arguments: {
            'memberId': memberId,
            'familyDocId': familyDocId,
          },
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final languageService = Provider.of<LanguageService>(context);

    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Ramanagara Patidar Samaj',
      theme: themeService.getTheme(),
      locale: languageService.locale,
      supportedLocales: const [Locale('en'), Locale('gu')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        final scale = themeService.textScale;
        
        Widget mainContent = MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: themeService.isDarkMode
                    ? [
                        const Color(0xFF0F172A), // Dark Slate
                        const Color(0xFF000000), // Pure Black
                        const Color(0xFF1E1B4B), // Very Dark Indigo
                      ]
                    : [
                        const Color(0xFFE2E8F0), // Light Slate
                        const Color(0xFFF8FAFC), // Off white
                        const Color(0xFFE0E7FF), // Very Light Indigo
                      ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
            child: child!,
          ),
        );

        if (kIsWeb) {
          return Container(
            color: themeService.isDarkMode ? Colors.black : Colors.grey.shade200,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const OfflineBanner(),
                      Expanded(child: mainContent),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        
        return mainContent;
      },
      // Start with initial route - it will check session and redirect
      home: const InitialRoute(),
      routes: {
        '/login': (_) => const AuthGuard(isLoginRoute: true, child: LoginScreen()),
        '/admin': (_) => const AuthGuard(requireAdmin: true, child: AdminDashboard()),
        '/admin/families': (_) => const AuthGuard(requireAdmin: true, child: FamilyListScreen()),
        '/admin/groups': (_) => const AuthGuard(requireAdmin: true, child: GroupManagementScreen()),
        '/admin/events': (_) => const AuthGuard(requireAdmin: true, child: EventManagementScreen()),
        '/admin/analytics': (_) => const AuthGuard(requireAdmin: true, child: AnalyticsDashboard()),
        '/admin/system-health': (_) => const AuthGuard(requireAdmin: true, child: SystemHealthScreen()),
        '/admin/notifications': (_) => const AuthGuard(requireAdmin: true, child: NotificationCenterScreen()),
        '/admin/firms': (_) => const AuthGuard(requireAdmin: true, child: FirmsListScreen()),
        '/admin/update-requests': (_) => const AuthGuard(requireAdmin: true, child: AdminUpdateRequestsScreen()),
        '/home': (_) => const AuthGuard(requireUser: true, child: EnhancedUserDashboard()),
        '/user/settings': (_) => const AuthGuard(requireUser: true, child: SettingsScreen()),
        '/user/profile': (_) => const AuthGuard(requireUser: true, child: UserProfileScreen()),
        '/user/notifications': (_) => const AuthGuard(requireUser: true, child: UserNotificationScreen()),
        '/user/qr-scanner': (_) => const AuthGuard(requireUser: true, child: QRScannerScreen()),
        '/user/update-request': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          final target = args is MemberModel ? MemberUpdateRequestScreen(targetMember: args) : const MemberUpdateRequestScreen();
          return AuthGuard(requireUser: true, child: target);
        },
        '/user/member-detail': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          if (args is Map<String, dynamic>) {
            return AuthGuard(
              requireUser: true,
              child: MemberDetailScreen(
                memberId: args['memberId'] ?? '',
                familyDocId: args['familyDocId'],
                subFamilyDocId: args['subFamilyDocId'],
              ),
            );
          }
          return const AuthGuard(requireUser: true, child: MemberDetailScreen(memberId: '', familyDocId: null));
        },
      },
      onGenerateRoute: (settings) {
        // Custom animated page route
        PageRoute<T> _buildRoute<T extends Object?>(
          Widget page, {
          RouteSettings? routeSettings,
        }) {
          return PageRouteBuilder<T>(
            settings: routeSettings ?? settings,
            pageBuilder: (context, animation, secondaryAnimation) => page,
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position:
                          Tween<Offset>(
                            begin: const Offset(0.0, 0.05),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            ),
                          ),
                      child: child,
                    ),
                  );
                },
            transitionDuration: const Duration(milliseconds: 300),
          );
        }

        // Handle admin members route with arguments
        if (settings.name == '/admin/members') {
          if (settings.arguments == null) {
            return _buildRoute(
              const Scaffold(
                body: Center(
                  child: Text('Error: Missing arguments for member list'),
                ),
              ),
            );
          }
          final args = settings.arguments as Map<String, dynamic>;
          return _buildRoute(
            AuthGuard(
              requireAdmin: true,
              child: MemberListScreen(
                familyDocId: args['familyDocId'],
                familyName: args['familyName'],
                subFamilyDocId: args['subFamilyDocId'],
              ),
            ),
          );
        }
        if (settings.name == '/user/digital-id') {
          final args = settings.arguments as MemberModel;
          return _buildRoute(AuthGuard(requireUser: true, child: DigitalIdScreen(member: args)));
        }
        // Fallback for any unhandled route - go to login
        return _buildRoute(const AuthGuard(isLoginRoute: true, child: LoginScreen()));
      },
    );
  }
}
