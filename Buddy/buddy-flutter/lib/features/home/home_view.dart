import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/persistence/coin_wallet.dart';
import '../../core/persistence/pet_store.dart';
import '../../core/services/pet_service.dart';
import '../../design/theme.dart';
import '../../models/pet.dart';
import '../../models/pet_need.dart';
import '../../widgets/animated_sprite_sheet.dart';
import '../minigames/catch_food_game.dart';
import '../minigames/memory_match_game.dart';
import '../minigames/minigames_hub_sheet.dart';
import '../minigames/rhythm_tap_game.dart';
import '../minigames/tap_reaction_game.dart';
import '../onboarding/pick_character_view.dart';
import '../overlay/overlay_controller.dart';
import 'widgets/ambient_particles.dart';
import 'widgets/day_night_overlay.dart';
import 'widgets/floating_emojis.dart';
import 'widgets/hot_spot.dart';
import 'widgets/pet_stage.dart';
import 'widgets/room.dart';
import 'widgets/stats_hud.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> with TickerProviderStateMixin {
  Pet? _pet;
  PetService? _service;
  final _emojis = FloatingEmojiController();
  final _stageController = PetStageController();
  late final PageController _roomPager;
  int _roomIndex = 0;
  String? _speech;
  Timer? _speechTimer;
  Timer? _saveTimer;
  Timer? _clockTimer;
  int _coins = 0;

  @override
  void initState() {
    super.initState();
    _roomPager = PageController(initialPage: 0)
      ..addListener(() {
        final i = _roomPager.page?.round() ?? 0;
        if (i != _roomIndex) setState(() => _roomIndex = i);
      });
    _bootstrap();
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) => setState(() {}));
  }

  Future<void> _bootstrap() async {
    final pet = await PetStore.load() ?? Pet();
    final coins = await CoinWallet.balance();
    if (!mounted) return;
    final svc = PetService(pet)..start();
    svc.addListener(_onServiceTick);
    pet.addListener(_onPetTick);
    setState(() {
      _pet = pet;
      _service = svc;
      _coins = coins;
    });
    _scheduleSpeech();
  }

  void _onServiceTick() {
    if (!mounted) return;
    setState(() {});
    _saveDebounced();
    _maybeSpeechFromNeeds();
  }

  void _onPetTick() {
    if (!mounted) return;
    setState(() {});
    _saveDebounced();
  }

  void _saveDebounced() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 2), () {
      final p = _pet;
      if (p != null) PetStore.save(p);
    });
  }

  void _scheduleSpeech() {
    _speechTimer?.cancel();
    _speechTimer = Timer(Duration(seconds: 12 + math.Random().nextInt(8)), () {
      _maybeSpeechIdle();
      _scheduleSpeech();
    });
  }

  static const _idlePhrases = [
    '¡Hola!',
    '¿Jugamos?',
    'Te quiero',
    '¿Y la comida?',
    'Mírame',
  ];

  void _maybeSpeechIdle() {
    if (!mounted) return;
    if (_service?.needs.isNotEmpty ?? false) return;
    setState(() => _speech = _idlePhrases[math.Random().nextInt(_idlePhrases.length)]);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _speech = null);
    });
  }

  void _maybeSpeechFromNeeds() {
    final n = _service?.needs.firstOrNull;
    if (n == null) return;
    final msg = switch (n) {
      PetNeed.hungry => 'Tengo hambre…',
      PetNeed.thirsty => 'Tengo sed…',
      PetNeed.dirty => '¡Estoy sucio!',
      PetNeed.sleepy => 'Sueño…',
      PetNeed.bored => 'Aburrido…',
    };
    if (_speech != msg) {
      setState(() => _speech = msg);
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted && _speech == msg) setState(() => _speech = null);
      });
    }
  }

  @override
  void dispose() {
    _service?.removeListener(_onServiceTick);
    _service?.dispose();
    _pet?.removeListener(_onPetTick);
    _emojis.dispose();
    _stageController.dispose();
    _roomPager.dispose();
    _speechTimer?.cancel();
    _saveTimer?.cancel();
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> _toggleOverlay() async {
    final pet = _pet;
    if (pet == null) return;
    final spritePath = 'assets/sprites/${pet.character.spriteSheetAsset}.png';
    await BuddyOverlayController.instance.toggle(sprite: spritePath);
  }

  void _openMinigames() {
    final pet = _pet;
    if (pet == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MinigamesHubSheet(
        onPick: (game) {
          Navigator.of(context).pop();
          _launchGame(game, pet);
        },
      ),
    );
  }

  Future<void> _launchGame(MinigameID game, Pet pet) async {
    Widget gameView(ValueChanged<int> onClose) => switch (game) {
          MinigameID.catchFood => CatchFoodGame(pet: pet, onClose: onClose),
          MinigameID.memoryMatch => MemoryMatchGame(pet: pet, onClose: onClose),
          MinigameID.tapReaction => TapReactionGame(pet: pet, onClose: onClose),
          MinigameID.rhythmTap => RhythmTapGame(pet: pet, onClose: onClose),
        };

    final earned = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => gameView((reward) => Navigator.of(ctx).pop(reward)),
      ),
    );

    if (earned != null && earned > 0) {
      await CoinWallet.add(earned);
      final c = await CoinWallet.balance();
      if (!mounted) return;
      setState(() => _coins = c);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: BuddyTheme.actionPink,
          content: Text(
            '+$earned 🪙',
            style: BuddyTheme.pixel(
              size: 14,
              weight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _doRoomAction(RoomKind kind) {
    final svc = _service;
    if (svc == null) return;
    switch (kind) {
      case RoomKind.kitchen:
        svc.feed();
        _stageController.show(SpriteAction.eat, duration: const Duration(milliseconds: 2800));
        _flashSpeech('¡Yum!');
        break;
      case RoomKind.bedroom:
        svc.sleep();
        _stageController.show(SpriteAction.sleep, duration: const Duration(milliseconds: 3500));
        _flashSpeech('Zzz…');
        break;
      case RoomKind.garden:
        svc.bath();
        _stageController.show(SpriteAction.bath, duration: const Duration(milliseconds: 3000));
        _flashSpeech('¡Limpio!');
        break;
      case RoomKind.livingRoom:
        svc.playWith();
        _stageController.show(SpriteAction.play, duration: const Duration(milliseconds: 2800));
        _flashSpeech('¡Yay!');
        break;
    }
  }

  void _flashSpeech(String s) {
    setState(() => _speech = s);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _speech == s) setState(() => _speech = null);
    });
  }

  bool _isUrgent(RoomKind kind) {
    final stats = _pet?.stats;
    if (stats == null) return false;
    return switch (kind) {
      RoomKind.kitchen => stats.hunger < 30,
      RoomKind.bedroom => stats.energy < 25,
      RoomKind.garden => stats.hygiene < 25,
      RoomKind.livingRoom => stats.happiness < 30,
    };
  }

  @override
  Widget build(BuildContext context) {
    final pet = _pet;
    if (pet == null) {
      return const Scaffold(
        backgroundColor: BuddyTheme.consoleBG,
        body: Center(child: CircularProgressIndicator(color: BuddyTheme.actionPink)),
      );
    }
    final room = Room.all[_roomIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Habitaciones swipeables
          PageView.builder(
            controller: _roomPager,
            itemCount: Room.all.length,
            itemBuilder: (_, i) => Image.asset(
              Room.all[i].background,
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),

          // 2. Capa ambiental (partículas)
          AmbientParticles(room: room.kind),

          // 3. Día/noche
          DayNightOverlay(now: DateTime.now()),

          // 4. Hot spot de la habitación
          Align(
            alignment: room.hotSpotAlignment,
            child: HotSpot(
              icon: room.hotSpotIcon,
              label: room.hotSpotLabel,
              urgent: _isUrgent(room.kind),
              onTap: () => _doRoomAction(room.kind),
            ),
          ),

          // 5. Pet
          Positioned.fill(
            child: PetStage(
              pet: pet,
              controller: _stageController,
              emojis: _emojis,
              speech: _speech,
              onTap: () {
                _service?.caress();
                _flashSpeech('❤');
              },
              onCaressTick: () => _service?.caress(),
            ),
          ),

          // 6. Floating emojis
          Positioned.fill(child: FloatingEmojiLayer(controller: _emojis)),

          // 7. UI overlays
          SafeArea(
            child: Column(
              children: [
                _TopBar(
                  petName: pet.name,
                  ageDays: pet.ageInDays,
                  coins: _coins,
                  roomLabel: room.label,
                  onMenu: _toggleOverlay,
                  onReset: _confirmReset,
                ),
                const SizedBox(height: 8),
                Center(child: StatsHud(stats: pet.stats)),
                const Spacer(),
                _RoomDots(count: Room.all.length, index: _roomIndex),
                const SizedBox(height: 12),
                _ActionBar(
                  onPlay: _openMinigames,
                  onCaress: () {
                    _service?.caress();
                    _stageController.show(SpriteAction.caress,
                        duration: const Duration(milliseconds: 1800));
                    _flashSpeech('❤');
                  },
                ),
                const SizedBox(height: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmReset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFFFFF9E6),
        title: const Text('¿Empezar de cero?'),
        content: const Text('Esto borra tu Buddy actual.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sí')),
        ],
      ),
    );
    if (ok == true && mounted) {
      await PetStore.clear();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeGate()),
        (_) => false,
      );
    }
  }
}

class _TopBar extends StatelessWidget {
  final String petName;
  final int ageDays;
  final int coins;
  final String roomLabel;
  final VoidCallback onMenu;
  final VoidCallback onReset;

  const _TopBar({
    required this.petName,
    required this.ageDays,
    required this.coins,
    required this.roomLabel,
    required this.onMenu,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Row(
        children: [
          _Pill(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  petName,
                  style: BuddyTheme.pixel(
                    size: 14,
                    color: const Color(0xFF3E2723),
                    weight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB0457A),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${ageDays}d',
                    style: BuddyTheme.pixel(
                      size: 10,
                      color: Colors.white,
                      weight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          _Pill(
            child: Text(
              roomLabel,
              style: BuddyTheme.pixel(
                size: 12,
                color: const Color(0xFF3E2723),
                weight: FontWeight.bold,
              ),
            ),
          ),
          const Spacer(),
          _Pill(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🪙', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 4),
                Text(
                  '$coins',
                  style: BuddyTheme.pixel(
                    size: 13,
                    color: const Color(0xFF3E2723),
                    weight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onMenu,
            onLongPress: onReset,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF9E6),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF3E2723), width: 3),
                boxShadow: const [
                  BoxShadow(color: Colors.black54, offset: Offset(0, 3), blurRadius: 0),
                ],
              ),
              child: const Icon(Icons.menu, size: 18, color: Color(0xFF3E2723)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final Widget child;
  const _Pill({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9E6),
        border: Border.all(color: const Color(0xFF3E2723), width: 3),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Colors.black45, offset: Offset(0, 3), blurRadius: 0),
        ],
      ),
      child: child,
    );
  }
}

class _RoomDots extends StatelessWidget {
  final int count;
  final int index;
  const _RoomDots({required this.count, required this.index});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 16 : 10,
          height: 8,
          decoration: BoxDecoration(
            color: active ? const Color(0xFFFFF9E6) : Colors.white.withValues(alpha: 0.4),
            border: Border.all(color: const Color(0xFF3E2723), width: 2),
          ),
        );
      }),
    );
  }
}

class _ActionBar extends StatelessWidget {
  final VoidCallback onCaress;
  final VoidCallback onPlay;

  const _ActionBar({required this.onCaress, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ActionChip(icon: Icons.pan_tool_alt, label: 'Acariciar', onTap: onCaress),
          _ActionChip(icon: Icons.videogame_asset, label: 'Minijuegos', onTap: onPlay),
        ],
      ),
    );
  }
}

class _ActionChip extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionChip({required this.icon, required this.label, required this.onTap});

  @override
  State<_ActionChip> createState() => _ActionChipState();
}

class _ActionChipState extends State<_ActionChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        transform: Matrix4.translationValues(0, _pressed ? 4 : 0, 0),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFB0457A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF7A2C55), width: 3),
          boxShadow: _pressed
              ? []
              : const [
                  BoxShadow(color: Colors.black54, offset: Offset(0, 4), blurRadius: 0),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              widget.label,
              style: BuddyTheme.pixel(
                size: 14,
                color: Colors.white,
                weight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

// HomeGate — onboarding gate
class HomeGate extends StatefulWidget {
  const HomeGate({super.key});

  @override
  State<HomeGate> createState() => _HomeGateState();
}

class _HomeGateState extends State<HomeGate> {
  bool? _onboarded;

  @override
  void initState() {
    super.initState();
    () async {
      final p = await PetStore.load();
      setState(() => _onboarded = p != null);
    }();
  }

  @override
  Widget build(BuildContext context) {
    if (_onboarded == null) {
      return const Scaffold(
        backgroundColor: BuddyTheme.consoleBG,
        body: Center(child: CircularProgressIndicator(color: BuddyTheme.actionPink)),
      );
    }
    if (_onboarded == false) {
      return PickCharacterView(
        onFinish: (name, character) async {
          final pet = Pet(name: name.isEmpty ? 'Buddy' : name, character: character);
          await PetStore.save(pet);
          if (mounted) setState(() => _onboarded = true);
        },
      );
    }
    return const HomeView();
  }
}
