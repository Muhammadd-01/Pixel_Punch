import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_theme.dart';
import 'app_router.dart';
import '../core/widgets/music_scope.dart';
import '../services/game_state_service.dart';
import '../services/audio_service.dart';
import '../services/local_storage_service.dart';
import '../services/supabase_service.dart';
import '../services/sync_service.dart';
import '../services/friends_service.dart';
import '../services/lobby_service.dart';
import '../services/custom_villain_service.dart';

class PixelPunchApp extends StatelessWidget {
  const PixelPunchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GameStateService()),
        ChangeNotifierProvider(create: (_) => CustomVillainService()),
        Provider(create: (_) => AudioService()),
        Provider(create: (_) => LocalStorageService()),
        Provider(create: (_) => SupabaseService()),
        ChangeNotifierProxyProvider2<LocalStorageService, SupabaseService, SyncService>(
          create: (context) => SyncService(
            localStorage: context.read<LocalStorageService>(),
            supabaseService: context.read<SupabaseService>(),
          ),
          update: (_, localStorage, supabase, previous) =>
              previous ??
              SyncService(
                localStorage: localStorage,
                supabaseService: supabase,
              ),
        ),
        ChangeNotifierProxyProvider<SupabaseService, FriendsService>(
          create: (context) => FriendsService(
            supabaseService: context.read<SupabaseService>(),
          ),
          update: (_, supabase, previous) =>
              previous ?? FriendsService(supabaseService: supabase),
        ),
        ChangeNotifierProxyProvider<SupabaseService, LobbyService>(
          create: (context) => LobbyService(
            supabaseService: context.read<SupabaseService>(),
          ),
          update: (_, supabase, previous) =>
              previous ?? LobbyService(supabaseService: supabase),
        ),
      ],
      child: AudioLifecycle(
        child: MaterialApp.router(
          title: 'PixelPunch',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          routerConfig: AppRouter.router,
        ),
      ),
    );
  }
}
