import 'dart:async';
import 'dart:math';
import 'dart:ui' show Offset, Color, Image;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/flame.dart';
import 'package:flame/game.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart' show Curves, Colors, VoidCallback;

/// Equivalente al `BuddyScene` de SpriteKit.
/// - Pinta un background scrollable
/// - Anima el pet (sprite sheet 4×4)
/// - Anima el player (sprite sheet 10×4) controlado por el joystick
class BuddyScene extends FlameGame with HasCollisionDetection {
  BuddyScene({
    required this.petSheetAsset,
    required this.playerSheetAsset,
    required this.backgroundAsset,
  });

  String petSheetAsset;
  String playerSheetAsset;
  String backgroundAsset;

  static final virtualSize = Vector2(390, 540);
  static const floorY = 90.0;

  late SpriteComponent _background;
  late _PetSprite _pet;
  late _PlayerSprite _player;

  Vector2 _playerVelocity = Vector2.zero();
  bool _playerFacingRight = true;
  bool _wasPlayerNearby = false;

  /// Callbacks para que la HomeView reaccione a interacciones del jugador.
  void Function()? onPetTap;
  void Function()? onPetDoubleTap;
  void Function()? onPetReleased;
  void Function()? onPlayerNearPet;

  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  Future<void> onLoad() async {
    // Flame busca assets bajo `assets/images/` por defecto. Los nuestros están
    // en `assets/sprites/` y `assets/backgrounds/`, así que reseteamos el prefijo
    // y cargamos rutas completas relativas a la raíz del paquete.
    Flame.images.prefix = 'assets/';

    camera.viewfinder.visibleGameSize = virtualSize;
    camera.viewfinder.anchor = Anchor.topLeft;

    final bgImg = await Flame.images.load('backgrounds/$backgroundAsset.png');
    _background = SpriteComponent(
      sprite: Sprite(bgImg),
      size: virtualSize,
      position: Vector2.zero(),
      priority: 0,
    );
    add(_background);

    _pet = _PetSprite(
        onTap: () => onPetTap?.call(),
        onDoubleTap: () => onPetDoubleTap?.call());
    await _pet.loadFromAsset('sprites/$petSheetAsset.png');
    _pet.position = Vector2(virtualSize.x * 0.55, virtualSize.y - floorY);
    add(_pet);

    _player = _PlayerSprite();
    await _player.loadFromAsset('sprites/$playerSheetAsset.png');
    _player.position = Vector2(virtualSize.x * 0.30, virtualSize.y - floorY);
    add(_player);
  }

  // --- Public API (called from HomeView) -------------------------------

  void setPlayerVelocity(Offset v) {
    _playerVelocity = Vector2(v.dx, v.dy);
    _player.setMoving(_playerVelocity.length > 0.05);
    if (_playerVelocity.x > 0.05 && !_playerFacingRight) {
      _playerFacingRight = true;
      _player.scale = Vector2(1, 1);
    } else if (_playerVelocity.x < -0.05 && _playerFacingRight) {
      _playerFacingRight = false;
      _player.scale = Vector2(-1, 1);
    }
  }

  Future<void> setPetCharacter(String asset) async {
    petSheetAsset = asset;
    await _pet.loadFromAsset('sprites/$asset.png');
  }

  Future<void> setBackground(String asset) async {
    if (backgroundAsset == asset) return;
    backgroundAsset = asset;
    final img = await Flame.images.load('backgrounds/$asset.png');
    _background.sprite = Sprite(img);
  }

  void feedItem({String emoji = '🍖'}) {
    _pet.playEatAnimation();
    _spawnFloatingEmoji(emoji,
        target: _pet.position + Vector2(0, _PetSprite.spriteSize.y * 0.3));
  }

  void giveWaterAnimation() => feedItem(emoji: '💧');

  void bathAnimation() {
    final rng = Random();
    for (var i = 0; i < 6; i++) {
      final emoji = ['🫧', '💦', '🧼'][rng.nextInt(3)];
      _spawnFloatingEmoji(
        emoji,
        target: _pet.position +
            Vector2(rng.nextDouble() * 50 - 25, _PetSprite.spriteSize.y * 0.5),
        rise: true,
      );
    }
  }

  void sleepAnimation() {
    _spawnFloatingEmoji('Z',
        target: _pet.position + Vector2(12, -6), rise: true);
  }

  void performTrick() {
    _pet.add(
      MoveByEffect(
          Vector2(0, -30),
          EffectController(
              duration: 0.18, alternate: true, curve: Curves.easeOut)),
    );
    _pet.add(
      RotateEffect.by(2 * pi, EffectController(duration: 0.36)),
    );
  }

  void showNeedBubble(String? emoji) {
    _pet.setNeedBubble(emoji);
  }

  void setAccessory(String? emoji) => _pet.setAccessory(emoji);

  // --- Internals -------------------------------------------------------

  void _spawnFloatingEmoji(String emoji,
      {required Vector2 target, bool rise = false}) {
    final node = TextComponent(
      text: emoji,
      anchor: Anchor.center,
      priority: 15,
    );
    node.position = rise ? target : Vector2(target.x, -20);
    add(node);

    final move = rise
        ? MoveByEffect(Vector2(Random().nextDouble() * 40 - 20, -50),
            EffectController(duration: 0.8, curve: Curves.easeOut))
        : MoveToEffect(
            target, EffectController(duration: 0.6, curve: Curves.easeIn));

    node.add(move);
    node.add(OpacityEffect.to(
        0, EffectController(duration: 0.8, startDelay: 0.2),
        onComplete: () => node.removeFromParent()));
  }

  @override
  void update(double dt) {
    super.update(dt);

    const speed = 90.0;
    final dx = _playerVelocity.x * speed * dt;
    _player.position.x =
        (_player.position.x + dx).clamp(30, virtualSize.x - 30);

    final distance = (_pet.position.x - _player.position.x).abs();
    if (distance < 80) {
      final shouldFaceRight = _player.position.x > _pet.position.x;
      _pet.setFacingRight(shouldFaceRight);
      if (!_wasPlayerNearby) {
        _wasPlayerNearby = true;
        onPlayerNearPet?.call();
      }
    } else if (_wasPlayerNearby) {
      _wasPlayerNearby = false;
    }
  }
}

/// Pet con animación idle por defecto + sheet 4×4.
class _PetSprite extends PositionComponent with TapCallbacks {
  static final spriteSize = Vector2(56, 56);

  _PetSprite({this.onTap, this.onDoubleTap})
      : super(size: spriteSize, anchor: Anchor.bottomCenter);

  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;

  late SpriteAnimation _idleAnim;
  late Image _sheetImg;
  TextComponent? _accessory;
  TextComponent? _needBubble;
  double _lastTapTime = 0;

  @override
  void onTapDown(TapDownEvent event) {
    final now = DateTime.now().millisecondsSinceEpoch / 1000.0;
    if (now - _lastTapTime < 0.4) {
      onDoubleTap?.call();
      _lastTapTime = 0;
    } else {
      _lastTapTime = now;
      onTap?.call();
    }
  }

  Future<void> loadFromAsset(String asset) async {
    _sheetImg = await Flame.images.load(asset);
    _idleAnim =
        _animationFromSheet(_sheetImg, row: 0, frameCount: 4, stepTime: 0.4);
    final c = SpriteAnimationComponent(
      animation: _idleAnim,
      size: spriteSize,
    );
    removeAll(children);
    add(c);
  }

  void setFacingRight(bool right) {
    scale = Vector2(right ? 1 : -1, 1);
  }

  void playEatAnimation() {
    final eat = _animationFromSheet(_sheetImg,
        row: 2, frameCount: 4, stepTime: 0.18, loop: false);
    final comp = SpriteAnimationComponent(animation: eat, size: spriteSize)
      ..removeOnFinish = true;
    add(comp);
  }

  void setNeedBubble(String? emoji) {
    _needBubble?.removeFromParent();
    _needBubble = null;
    if (emoji == null) return;
    final t = TextComponent(
      text: emoji,
      anchor: Anchor.center,
      position: Vector2(spriteSize.x / 2 + 18, -10),
      priority: 30,
    );
    add(t);
    _needBubble = t;
  }

  void setAccessory(String? emoji) {
    _accessory?.removeFromParent();
    _accessory = null;
    if (emoji == null) return;
    final t = TextComponent(
      text: emoji,
      anchor: Anchor.center,
      position: Vector2(spriteSize.x / 2, -spriteSize.y - 4),
      priority: 25,
    );
    add(t);
    _accessory = t;
  }
}

class _PlayerSprite extends PositionComponent {
  static final spriteSize = Vector2(48, 72);

  _PlayerSprite() : super(size: spriteSize, anchor: Anchor.bottomCenter);

  late Image _sheetImg;
  SpriteAnimationComponent? _anim;

  bool _moving = false;

  Future<void> loadFromAsset(String asset) async {
    _sheetImg = await Flame.images.load(asset);
    setMoving(false, force: true);
  }

  void setMoving(bool moving, {bool force = false}) {
    if (!force && _moving == moving) return;
    _moving = moving;
    _anim?.removeFromParent();
    final anim = moving
        ? _animationFromSheet(_sheetImg,
            row: 1, frameCount: 6, columns: 10, stepTime: 0.1)
        : _animationFromSheet(_sheetImg,
            row: 0, frameCount: 4, columns: 10, stepTime: 0.5);
    _anim = SpriteAnimationComponent(animation: anim, size: spriteSize);
    add(_anim!);
  }
}

SpriteAnimation _animationFromSheet(
  Image sheet, {
  required int row,
  required int frameCount,
  int columns = 4,
  int rows = 4,
  double stepTime = 0.4,
  bool loop = true,
}) {
  final frameW = sheet.width / columns;
  final frameH = sheet.height / rows;
  final frames = List<Sprite>.generate(
    frameCount,
    (i) => Sprite(
      sheet,
      srcPosition: Vector2(i * frameW, row * frameH),
      srcSize: Vector2(frameW, frameH),
    ),
  );
  return SpriteAnimation.spriteList(frames, stepTime: stepTime, loop: loop);
}
