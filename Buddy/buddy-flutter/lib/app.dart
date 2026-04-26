import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'core/persistence/pet_store.dart';
import 'core/services/tiktok_analysis_service.dart';
import 'design/theme.dart';
import 'features/home/home_view.dart';
import 'features/home/start_screen.dart';
import 'features/learning/learning_session_view.dart';

final GlobalKey<NavigatorState> buddyNavigatorKey = GlobalKey<NavigatorState>();

class BuddyApp extends StatelessWidget {
  const BuddyApp({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ));

    return MaterialApp(
      title: 'Buddy',
      navigatorKey: buddyNavigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: BuddyTheme.consoleBG,
        textTheme: Typography.blackCupertino.apply(fontFamily: BuddyTheme.pixelMono),
        colorScheme: ColorScheme.fromSeed(
          seedColor: BuddyTheme.actionPink,
          brightness: Brightness.light,
        ),
      ),
      home: const _LaunchGate(),
    );
  }
}

class _LaunchGate extends StatefulWidget {
  const _LaunchGate();
  @override
  State<_LaunchGate> createState() => _LaunchGateState();
}

class _LaunchGateState extends State<_LaunchGate> {
  bool? _hasPet;
  StreamSubscription<List<SharedMediaFile>>? _shareSub;
  String? _pendingTikTokUrl;

  @override
  void initState() {
    super.initState();
    PetStore.load().then((p) {
      if (!mounted) return;
      setState(() => _hasPet = p != null);
      _maybeOpenPending();
    });
    _initShareIntent();
  }

  Future<void> _initShareIntent() async {
    // 1. Cold start: la app fue abierta DESDE un share. Revisar el initial.
    try {
      final initial =
          await ReceiveSharingIntent.instance.getInitialMedia();
      _handleShared(initial);
      // Resetea para que un re-share funcione (siempre).
      ReceiveSharingIntent.instance.reset();
    } catch (_) {/* swallow */}

    // 2. Warm start: la app estaba viva, llega un share.
    _shareSub = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen(_handleShared, onError: (_) {});
  }

  void _handleShared(List<SharedMediaFile> files) {
    for (final f in files) {
      // En texto compartido, `path` contiene el texto/URL.
      final text = f.path;
      final url = TikTokAnalysisService.extractTikTokUrl(text);
      if (url != null) {
        _pendingTikTokUrl = url;
        _maybeOpenPending();
        return;
      }
    }
  }

  void _maybeOpenPending() {
    final url = _pendingTikTokUrl;
    if (url == null) return;
    if (_hasPet != true) return; // espera a que termine de cargar; si no hay pet se ignora
    _pendingTikTokUrl = null;
    // Pushea sobre el navigator global, fuera del build cycle.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      buddyNavigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => LearningSessionView(tiktokUrl: url),
          fullscreenDialog: true,
        ),
      );
    });
  }

  @override
  void dispose() {
    _shareSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasPet == null) {
      return const Scaffold(
        backgroundColor: BuddyTheme.consoleBG,
        body: Center(child: CircularProgressIndicator(color: BuddyTheme.actionPink)),
      );
    }
    return _hasPet! ? const HomeGate() : const StartScreen();
  }
}
