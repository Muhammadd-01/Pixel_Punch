import 'package:go_router/go_router.dart';
import '../features/splash/splash_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/welcome/welcome_screen.dart';
import '../features/home/home_screen.dart';
import '../features/zones/zone_selection_screen.dart';
import '../features/characters/character_selection_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/game/game_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/auth/forgot_password_screen.dart';
import '../features/profile/profile_screen.dart';

class AppRouter {
  AppRouter._();

  static final router = GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/zones',
        builder: (context, state) => const ZoneSelectionScreen(),
      ),
      GoRoute(
        path: '/characters',
        builder: (context, state) => const CharacterSelectionScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/game',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return GameScreen(
            zoneId: extra?['zoneId'] as String? ?? 'zone_office',
            mode: extra?['mode'] as String? ?? 'solo',
            heroIds: extra?['heroIds'] as List<String>? ?? ['hero_striker'],
          );
        },
      ),
    ],
  );
}
