import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/game_state_service.dart';
import 'package:image_picker/image_picker.dart';
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
import '../features/villain_lab/villain_lab_screen.dart';
import '../features/villain_lab/villain_forge_screen.dart';
import '../features/friends/friends_screen.dart';
import '../features/multiplayer/lobby_screen.dart';
import '../core/widgets/page_transitions.dart';

class AppRouter {
  AppRouter._();

  static final router = GoRouter(
    initialLocation: '/splash',
    // Game data is loaded on the splash screen; deep links (web refresh,
    // restored routes) go through it first.
    redirect: (context, state) {
      final loaded = context.read<GameStateService>().isLoaded;
      if (!loaded && state.matchedLocation != '/splash') return '/splash';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) => PixelPageTransitions.dissolve(
          key: state.pageKey,
          child: const OnboardingScreen(),
        ),
      ),
      GoRoute(
        path: '/welcome',
        pageBuilder: (context, state) => PixelPageTransitions.dissolve(
          key: state.pageKey,
          child: const WelcomeScreen(),
        ),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => PixelPageTransitions.slideUp(
          key: state.pageKey,
          child: const LoginScreen(),
        ),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (context, state) => PixelPageTransitions.slideUp(
          key: state.pageKey,
          child: const RegisterScreen(),
        ),
      ),
      GoRoute(
        path: '/forgot-password',
        pageBuilder: (context, state) => PixelPageTransitions.slideUp(
          key: state.pageKey,
          child: const ForgotPasswordScreen(),
        ),
      ),
      GoRoute(
        path: '/home',
        pageBuilder: (context, state) => PixelPageTransitions.dissolve(
          key: state.pageKey,
          child: const HomeScreen(),
        ),
      ),
      GoRoute(
        path: '/profile',
        pageBuilder: (context, state) => PixelPageTransitions.slideRight(
          key: state.pageKey,
          child: const ProfileScreen(),
        ),
      ),
      GoRoute(
        path: '/zones',
        pageBuilder: (context, state) => PixelPageTransitions.slideRight(
          key: state.pageKey,
          child: const ZoneSelectionScreen(),
        ),
      ),
      GoRoute(
        path: '/characters',
        pageBuilder: (context, state) => PixelPageTransitions.slideRight(
          key: state.pageKey,
          child: const CharacterSelectionScreen(),
        ),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (context, state) => PixelPageTransitions.slideRight(
          key: state.pageKey,
          child: const SettingsScreen(),
        ),
      ),
      GoRoute(
        path: '/friends',
        pageBuilder: (context, state) => PixelPageTransitions.slideRight(
          key: state.pageKey,
          child: const FriendsScreen(),
        ),
      ),
      GoRoute(
        path: '/lobby',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return PixelPageTransitions.dissolve(
            key: state.pageKey,
            child: LobbyScreen(
              inviteCode: extra?['inviteCode'] as String?,
            ),
          );
        },
      ),
      GoRoute(
        path: '/game',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return PixelPageTransitions.energyBurst(
            key: state.pageKey,
            child: GameScreen(
              zoneId: extra?['zoneId'] as String? ?? 'zone_office',
              mode: extra?['mode'] as String? ?? 'solo',
              heroIds: (extra?['heroIds'] as List?)?.cast<String>() ?? const ['hero_striker'],
              villainIds: (extra?['villainIds'] as List?)?.cast<String>() ?? const [],
            ),
          );
        },
      ),
      GoRoute(
        path: '/villain-lab',
        pageBuilder: (context, state) => PixelPageTransitions.slideRight(
          key: state.pageKey,
          child: const VillainLabScreen(),
        ),
      ),
      GoRoute(
        path: '/villain-lab/create',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final source = extra?['source'] as String?;
          return PixelPageTransitions.slideUp(
            key: state.pageKey,
            child: VillainForgeScreen(
              source: source == 'camera' ? ImageSource.camera : ImageSource.gallery,
              editId: extra?['editId'] as String?,
            ),
          );
        },
      ),
    ],
  );
}
