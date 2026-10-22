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
import '../features/auth/auth_transition_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/villain_lab/villain_lab_screen.dart';
import '../features/villain_lab/villain_forge_screen.dart';
import '../features/friends/friends_screen.dart';
import '../features/multiplayer/lobby_screen.dart';
import '../features/royale/royale_lobby_screen.dart';
import '../core/widgets/page_transitions.dart';
import '../core/widgets/music_scope.dart';
import '../services/audio_service.dart';

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
          child: const MusicScope(track: MusicTrack.menuTheme, child: OnboardingScreen()),
        ),
      ),
      GoRoute(
        path: '/welcome',
        pageBuilder: (context, state) => PixelPageTransitions.dissolve(
          key: state.pageKey,
          child: const MusicScope(track: MusicTrack.menuTheme, child: WelcomeScreen()),
        ),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => PixelPageTransitions.slideUp(
          key: state.pageKey,
          child: const MusicScope(track: MusicTrack.menuTheme, child: LoginScreen()),
        ),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (context, state) => PixelPageTransitions.slideUp(
          key: state.pageKey,
          child: const MusicScope(track: MusicTrack.menuTheme, child: RegisterScreen()),
        ),
      ),
      GoRoute(
        path: '/forgot-password',
        pageBuilder: (context, state) => PixelPageTransitions.slideUp(
          key: state.pageKey,
          child: const MusicScope(track: MusicTrack.menuTheme, child: ForgotPasswordScreen()),
        ),
      ),
      GoRoute(
        path: '/transition',
        pageBuilder: (context, state) => PixelPageTransitions.dissolve(
          key: state.pageKey,
          child: AuthTransitionScreen(
            mode: AuthTransitionScreen.parse(
                (state.extra as Map<String, dynamic>?)?['mode'] as String?),
          ),
        ),
      ),
      GoRoute(
        path: '/home',
        pageBuilder: (context, state) => PixelPageTransitions.dissolve(
          key: state.pageKey,
          child: const MusicScope(track: MusicTrack.menuTheme, child: HomeScreen()),
        ),
      ),
      GoRoute(
        path: '/profile',
        pageBuilder: (context, state) => PixelPageTransitions.slideRight(
          key: state.pageKey,
          child: const MusicScope(track: MusicTrack.menuTheme, child: ProfileScreen()),
        ),
      ),
      GoRoute(
        path: '/zones',
        pageBuilder: (context, state) => PixelPageTransitions.slideRight(
          key: state.pageKey,
          child: const MusicScope(track: MusicTrack.menuTheme, child: ZoneSelectionScreen()),
        ),
      ),
      GoRoute(
        path: '/characters',
        pageBuilder: (context, state) => PixelPageTransitions.slideRight(
          key: state.pageKey,
          child: const MusicScope(track: MusicTrack.menuTheme, child: CharacterSelectionScreen()),
        ),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (context, state) => PixelPageTransitions.slideRight(
          key: state.pageKey,
          child: const MusicScope(track: MusicTrack.menuTheme, child: SettingsScreen()),
        ),
      ),
      GoRoute(
        path: '/friends',
        pageBuilder: (context, state) => PixelPageTransitions.slideRight(
          key: state.pageKey,
          child: const MusicScope(track: MusicTrack.menuTheme, child: FriendsScreen()),
        ),
      ),
      GoRoute(
        path: '/lobby',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return PixelPageTransitions.dissolve(
            key: state.pageKey,
            child: MusicScope(
              track: MusicTrack.menuTheme,
              child: LobbyScreen(
                inviteCode: extra?['inviteCode'] as String?,
              ),
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
            child: MusicScope(
              track: MusicTrack.battleTheme1,
              child: GameScreen(
              zoneId: extra?['zoneId'] as String? ?? 'zone_office',
              mode: extra?['mode'] as String? ?? 'solo',
              heroIds: (extra?['heroIds'] as List?)?.cast<String>() ?? const ['hero_striker'],
              villainIds: (extra?['villainIds'] as List?)?.cast<String>() ?? const [],
              ),
            ),
          );
        },
      ),
      GoRoute(
        path: '/royale',
        pageBuilder: (context, state) => PixelPageTransitions.slideRight(
          key: state.pageKey,
          child: const MusicScope(track: MusicTrack.battleTheme2, child: RoyaleLobbyScreen()),
        ),
      ),
      GoRoute(
        path: '/villain-lab',
        pageBuilder: (context, state) => PixelPageTransitions.slideRight(
          key: state.pageKey,
          child: const MusicScope(track: MusicTrack.villainLab, child: VillainLabScreen()),
        ),
      ),
      GoRoute(
        path: '/villain-lab/create',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final source = extra?['source'] as String?;
          return PixelPageTransitions.slideUp(
            key: state.pageKey,
            child: MusicScope(
              track: MusicTrack.villainLab,
              child: VillainForgeScreen(
                source: source == 'camera' ? ImageSource.camera : ImageSource.gallery,
                editId: extra?['editId'] as String?,
              ),
            ),
          );
        },
      ),
    ],
  );
}
