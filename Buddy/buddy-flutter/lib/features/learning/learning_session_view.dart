import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/persistence/coin_wallet.dart';
import '../../core/persistence/pet_store.dart';
import '../../core/services/pet_service.dart';
import '../../core/services/tiktok_analysis_service.dart';
import '../../design/theme.dart';
import '../../models/pet.dart';
import '../../models/pet_character.dart';
import '../../widgets/animated_sprite_sheet.dart';
import '../../widgets/live_portrait.dart';
import '../../widgets/pet_visual.dart';

enum _LearningState { loading, healthy, warning, error }

const _coinsForHealthy = 5;
const _happinessBoostHealthy = 8;
const _happinessHitWarning = 6;

const _healthyPhrases = [
  '¡Te ves bien explorando! 💛',
  '¡Sigue descubriendo cosas chidas!',
  '¡Buen ojo, amigo!',
];

const _warningPhrases = [
  'Hmm… prefiero algo más bonito.',
  'Eso no me hace feliz.',
  '¿Y si jugamos algo juntos?',
];

const _loadingPhrases = [
  'Vamos a ver qué viste…',
  'Déjame echar un ojo…',
  'Mmm, viendo…',
];

class LearningSessionView extends StatefulWidget {
  final String tiktokUrl;
  const LearningSessionView({super.key, required this.tiktokUrl});

  @override
  State<LearningSessionView> createState() => _LearningSessionViewState();
}

class _LearningSessionViewState extends State<LearningSessionView>
    with TickerProviderStateMixin {
  _LearningState _state = _LearningState.loading;
  TikTokAnalysis? _result;
  String? _errorMessage;
  Pet? _pet;
  int _coins = 0;
  late final AnimationController _floatCtrl;
  late final AnimationController _bgCtrl;
  late final AnimationController _enterCtrl;
  String _phrase = '';

  @override
  void initState() {
    super.initState();
    _phrase = _loadingPhrases[math.Random().nextInt(_loadingPhrases.length)];
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat(reverse: true);
    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    )..forward();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final pet = await PetStore.load() ?? Pet();
    final coins = await CoinWallet.balance();
    if (!mounted) return;
    setState(() {
      _pet = pet;
      _coins = coins;
    });
    _runAnalysis();
  }

  Future<void> _runAnalysis() async {
    try {
      final svc = TikTokAnalysisService();
      final r = await svc.analyze(widget.tiktokUrl);
      if (!mounted) return;
      await _applyResult(r);
    } on TikTokAnalysisException catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _LearningState.error;
        _errorMessage = e.message;
        _phrase = 'No pude ver el video.';
      });
    }
  }

  Future<void> _applyResult(TikTokAnalysis r) async {
    final pet = _pet;
    if (pet == null) return;
    final rng = math.Random();
    if (r.esNarcocultura) {
      pet.stats.happiness =
          (pet.stats.happiness - _happinessHitWarning).clamp(0, 100);
      pet.notify();
      await PetStore.save(pet);
      setState(() {
        _result = r;
        _state = _LearningState.warning;
        _phrase = _warningPhrases[rng.nextInt(_warningPhrases.length)];
      });
    } else {
      pet.stats.happiness =
          (pet.stats.happiness + _happinessBoostHealthy).clamp(0, 100);
      pet.notify();
      await PetStore.save(pet);
      await CoinWallet.add(_coinsForHealthy);
      final newCoins = await CoinWallet.balance();
      setState(() {
        _result = r;
        _coins = newCoins;
        _state = _LearningState.healthy;
        _phrase = _healthyPhrases[rng.nextInt(_healthyPhrases.length)];
      });
    }
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    _bgCtrl.dispose();
    _enterCtrl.dispose();
    super.dispose();
  }

  SpriteAction _spriteFor() => switch (_state) {
        _LearningState.loading => SpriteAction.idle,
        _LearningState.healthy => SpriteAction.happy,
        _LearningState.warning => SpriteAction.caress,
        _LearningState.error => SpriteAction.idle,
      };

  /// Para Garfield en estado warning, mostramos su retrato triste estático
  /// (con animación procedural de respiración). Para los demás personajes,
  /// caemos al sheet animado regular.
  Widget _buildPet(Pet pet) {
    if (_state == _LearningState.warning &&
        pet.character == PetCharacter.garfield) {
      return LivePortrait(
        asset: 'assets/sprites/garfield_sad.png',
        size: 220,
      );
    }
    return PetVisual(
      character: pet.character,
      size: 220,
      action: _spriteFor(),
    );
  }

  Color _accent() => switch (_state) {
        _LearningState.loading => const Color(0xFFB0457A),
        _LearningState.healthy => const Color(0xFF6B8E23),
        _LearningState.warning => const Color(0xFFD17C2C),
        _LearningState.error => const Color(0xFF7F7F7F),
      };

  void _doCaress() async {
    final pet = _pet;
    if (pet == null) return;
    final svc = PetService(pet);
    svc.caress();
    await PetStore.save(pet);
    if (!mounted) return;
    setState(() => _phrase = '¡Mucho mejor! 💕');
  }

  void _close() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      // Si fue arranque por share intent en cold start, no hay nada para volver.
      // El usuario puede usar el botón home del sistema.
    }
  }

  @override
  Widget build(BuildContext context) {
    final pet = _pet;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _bgCtrl,
            builder: (_, __) => Transform.scale(
              scale: 1.18,
              child: Image.asset(
                _state == _LearningState.warning
                    ? 'assets/backgrounds/background_bedroom.png'
                    : 'assets/sources/fondo_pantalla_inicio.jpg',
                fit: BoxFit.cover,
                alignment: Alignment((_bgCtrl.value * 2) - 1, 0),
              ),
            ),
          ),
          // overlay tinte según estado
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _accent().withValues(alpha: 0.18),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.45),
                  ],
                  stops: const [0, 0.5, 1],
                ),
              ),
            ),
          ),

          if (pet != null)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  children: [
                    _Header(coins: _coins, onClose: _close),
                    const SizedBox(height: 10),
                    Expanded(
                      child: Center(
                        child: AnimatedBuilder(
                          animation: _enterCtrl,
                          builder: (_, child) {
                            final v =
                                Curves.easeOutBack.transform(_enterCtrl.value);
                            return Transform.translate(
                              offset: Offset(0, (1 - v) * 24),
                              child: Opacity(opacity: _enterCtrl.value, child: child),
                            );
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _SpeechBubble(
                                key: ValueKey(_phrase),
                                text: _phrase,
                              ),
                              const SizedBox(height: 8),
                              AnimatedBuilder(
                                animation: _floatCtrl,
                                builder: (_, c) {
                                  final dy = _floatCtrl.value * -10;
                                  return Transform.translate(
                                    offset: Offset(0, dy),
                                    child: c,
                                  );
                                },
                                child: _buildPet(pet),
                              ),
                              Container(
                                width: 130,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                              ),
                              const SizedBox(height: 18),
                              if (_state == _LearningState.loading)
                                const _LoadingDots()
                              else if (_state == _LearningState.healthy)
                                _HealthyCard(
                                  views: _result!.views,
                                  likes: _result!.likes,
                                  reward: _coinsForHealthy,
                                )
                              else if (_state == _LearningState.warning)
                                _WarningCard()
                              else
                                _ErrorCard(message: _errorMessage ?? ''),
                            ],
                          ),
                        ),
                      ),
                    ),
                    _BottomActions(
                      state: _state,
                      onClose: _close,
                      onCaress: _doCaress,
                      onRetry: () {
                        setState(() {
                          _state = _LearningState.loading;
                          _phrase = _loadingPhrases[
                              math.Random().nextInt(_loadingPhrases.length)];
                        });
                        _runAnalysis();
                      },
                    ),
                    const SizedBox(height: 18),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------- subwidgets ----------

class _Header extends StatelessWidget {
  final int coins;
  final VoidCallback onClose;
  const _Header({required this.coins, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          _PixelIconButton(icon: Icons.close_rounded, onTap: onClose),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF9E6),
              border: Border.all(color: const Color(0xFF3E2723), width: 3),
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(color: Colors.black45, offset: Offset(0, 3), blurRadius: 0),
              ],
            ),
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
        ],
      ),
    );
  }
}

class _PixelIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _PixelIconButton({required this.icon, required this.onTap});

  @override
  State<_PixelIconButton> createState() => _PixelIconButtonState();
}

class _PixelIconButtonState extends State<_PixelIconButton> {
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
        width: 44,
        height: 44,
        transform: Matrix4.translationValues(0, _pressed ? 3 : 0, 0),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF9E6),
          border: Border.all(color: const Color(0xFF3E2723), width: 3),
          borderRadius: BorderRadius.circular(12),
          boxShadow: _pressed
              ? []
              : const [
                  BoxShadow(color: Colors.black54, offset: Offset(0, 3), blurRadius: 0),
                ],
        ),
        child: Icon(widget.icon, color: const Color(0xFF3E2723), size: 22),
      ),
    );
  }
}

class _SpeechBubble extends StatelessWidget {
  final String text;
  const _SpeechBubble({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutBack,
      builder: (_, t, child) => Transform.scale(scale: t, child: child),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF9E6),
          border: Border.all(color: const Color(0xFF3E2723), width: 4),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Colors.black54, offset: Offset(0, 4), blurRadius: 0),
          ],
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: BuddyTheme.pixel(
            size: 17,
            color: const Color(0xFF3E2723),
            weight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _LoadingDots extends StatefulWidget {
  const _LoadingDots();

  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final phase = (_c.value + i * 0.15) % 1.0;
            final scale = 0.6 + (math.sin(phase * math.pi * 2) * 0.5 + 0.5) * 0.5;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFF9E6),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _HealthyCard extends StatelessWidget {
  final int views;
  final int likes;
  final int reward;
  const _HealthyCard({
    required this.views,
    required this.likes,
    required this.reward,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF5D8),
        border: Border.all(color: const Color(0xFF3E2723), width: 4),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black45, offset: Offset(0, 4), blurRadius: 0),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Stat(label: 'Vistas', value: _fmt(views)),
          const SizedBox(width: 18),
          _Stat(label: 'Likes', value: _fmt(likes)),
          const SizedBox(width: 18),
          _Stat(label: '+ Monedas', value: '+$reward 🪙'),
        ],
      ),
    );
  }

  static String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: BuddyTheme.pixel(
            size: 16,
            color: const Color(0xFF3E2723),
            weight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: BuddyTheme.pixel(
            size: 10,
            color: const Color(0xFF6D4C41),
          ),
        ),
      ],
    );
  }
}

class _WarningCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1DC),
        border: Border.all(color: const Color(0xFFD17C2C), width: 4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '¿Y si me das una caricia y mejor jugamos?',
        textAlign: TextAlign.center,
        style: BuddyTheme.pixel(
          size: 12,
          color: const Color(0xFF3E2723),
          weight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        border: Border.all(color: const Color(0xFF3E2723), width: 3),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: BuddyTheme.pixel(
          size: 12,
          color: const Color(0xFF3E2723),
        ),
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  final _LearningState state;
  final VoidCallback onClose;
  final VoidCallback onCaress;
  final VoidCallback onRetry;

  const _BottomActions({
    required this.state,
    required this.onClose,
    required this.onCaress,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    switch (state) {
      case _LearningState.loading:
        // Ningún botón mientras carga.
        break;
      case _LearningState.healthy:
        children.add(_BigButton(
          icon: Icons.check_rounded,
          label: 'Volver',
          color: const Color(0xFF6B8E23),
          onTap: onClose,
        ));
        break;
      case _LearningState.warning:
        children.add(_BigButton(
          icon: Icons.pan_tool_alt,
          label: 'Acariciar',
          color: const Color(0xFFB0457A),
          onTap: onCaress,
        ));
        children.add(const SizedBox(width: 12));
        children.add(_BigButton(
          icon: Icons.close_rounded,
          label: 'Cerrar',
          color: const Color(0xFF7F7F7F),
          onTap: onClose,
        ));
        break;
      case _LearningState.error:
        children.add(_BigButton(
          icon: Icons.refresh,
          label: 'Reintentar',
          color: const Color(0xFFB0457A),
          onTap: onRetry,
        ));
        children.add(const SizedBox(width: 12));
        children.add(_BigButton(
          icon: Icons.close_rounded,
          label: 'Cerrar',
          color: const Color(0xFF7F7F7F),
          onTap: onClose,
        ));
        break;
    }
    if (children.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: children,
    );
  }
}

class _BigButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _BigButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<_BigButton> createState() => _BigButtonState();
}

class _BigButtonState extends State<_BigButton> {
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
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.black.withValues(alpha: 0.4),
            width: 3,
          ),
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
