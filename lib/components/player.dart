import 'dart:async';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/services.dart';
import 'package:pixel_adventure/components/saw.dart';
import 'package:pixel_adventure/components/collision_block.dart';
import 'package:pixel_adventure/components/custom_hitbox.dart';
import 'package:pixel_adventure/components/fruit.dart';
import 'package:pixel_adventure/components/utils.dart';
import 'package:pixel_adventure/pixel_adventure.dart';

enum PlayerState {
  idle,
  running,
  jumping,
  falling,
  hit,
  appearing,
}

enum PlayerDirection {
  left,
  right,
  none,
}

class Player extends SpriteAnimationGroupComponent
    with HasGameRef<PixelAdventure>, KeyboardHandler, CollisionCallbacks {
  late final SpriteAnimation idleAnimation;
  late final SpriteAnimation runningAnimation;
  late final SpriteAnimation jumpingAnimation;
  late final SpriteAnimation fallingAnimation;
  late final SpriteAnimation hitAnimation;
  late final SpriteAnimation appearingAnimation;

  final double stepTime = 0.05;
  final double _gravity = 9.8;
  final double _jumpForce = 260;
  final double _terminalVelocity = 300;

  double horizontalMovement = 0;
  bool gotHit = false;
  String character;
  Player({
    position,
    this.character = 'Ninja Frog',
  }) : super(position: position);

  PlayerDirection playerDirection = PlayerDirection.none;
  double moveSpeed = 100;
  Vector2 startingPosition = Vector2.all(0);

  Vector2 velocity = Vector2.zero();
  bool isFacingRight = true;
  bool isGrounded = false;
  bool hasJumped = false;
  List<CollisionBlock> collisionBlocks = [];
  CustomHitbox hitbox = CustomHitbox(
    offsetX: 10,
    offsetY: 4,
    width: 14,
    height: 28,
  );
  Set<LogicalKeyboardKey> pressedKey = {};
  Set<LogicalKeyboardKey> releasedKey = {};
  Set<LogicalKeyboardKey> holdedKey = {};

  @override
  FutureOr<void> onLoad() {
    _loadAllAnimations();
    startingPosition = Vector2(position.x, position.y);
    // debugMode = true;
    add(
      RectangleHitbox(
          position: Vector2(
            hitbox.offsetX,
            hitbox.offsetY,
          ),
          size: Vector2(
            hitbox.width,
            hitbox.height,
          )),
    );
    return super.onLoad();
  }

  @override
  bool onKeyEvent(RawKeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (event is RawKeyDownEvent) {
      pressedKey.add(event.logicalKey);
      holdedKey.add(event.logicalKey);
    }

    if (event is RawKeyUpEvent) {
      releasedKey.add(event.logicalKey);
      holdedKey.remove(event.logicalKey);
    }
    horizontalMovement = 0;

    final isLeftKeyPressed = holdedKey.contains(LogicalKeyboardKey.keyA) ||
        holdedKey.contains(LogicalKeyboardKey.arrowLeft);

    final isRightKeyPressed = holdedKey.contains(LogicalKeyboardKey.keyD) ||
        holdedKey.contains(LogicalKeyboardKey.arrowRight);

    horizontalMovement += isLeftKeyPressed ? -1 : 0;
    horizontalMovement += isRightKeyPressed ? 1 : 0;

    hasJumped = keysPressed.contains(LogicalKeyboardKey.space);

    return super.onKeyEvent(event, keysPressed);
  }

  @override
  void update(double dt) {
    pressedKey.clear();
    releasedKey.clear();

    if (!gotHit) {
      _updatePlayerState();
      _updatePlayerMovement(dt);
      _checkHorizontalCollisions();
      _applyGravity(dt);
      _checkVerticalCollision();
    } else {}

    super.update(dt);
  }

  void _updatePlayerMovement(double dt) {
    if (hasJumped && isGrounded) {
      _playerJump(dt);
    }

    if (velocity.y > _gravity) {
      isGrounded = false;
    }
    velocity.x = horizontalMovement * moveSpeed;
    position.x += velocity.x * dt;
  }

  void _updatePlayerState() {
    PlayerState playerState = PlayerState.idle;

    if (velocity.x < 0 && scale.x > 0) {
      flipHorizontallyAroundCenter();
    } else if (velocity.x > 0 && scale.x < 0) {
      flipHorizontallyAroundCenter();
    }

    // check if moving, set running
    if (velocity.x > 0 || velocity.x < 0) playerState = PlayerState.running;

    if (velocity.y > 0) playerState = PlayerState.falling;

    if (velocity.y < 0) playerState = PlayerState.jumping;

    current = playerState;
  }

  void _loadAllAnimations() {
    idleAnimation = _spriteAnimation("Idle", 11);
    runningAnimation = _spriteAnimation('Run', 12);
    jumpingAnimation = _spriteAnimation('Jump', 1);
    fallingAnimation = _spriteAnimation('Fall', 1);
    hitAnimation = _spriteAnimation('Hit', 7);
    appearingAnimation = _specialSpriteAnimation('Appearing', 7);

    animations = {
      PlayerState.idle: idleAnimation,
      PlayerState.running: runningAnimation,
      PlayerState.jumping: jumpingAnimation,
      PlayerState.falling: fallingAnimation,
      PlayerState.hit: hitAnimation,
      PlayerState.appearing: appearingAnimation,
    };

    // Set current animation
    current = PlayerState.idle;
  }

  SpriteAnimation _spriteAnimation(String state, int amount) {
    return SpriteAnimation.fromFrameData(
      game.images.fromCache("Main Characters/$character/$state (32x32).png"),
      SpriteAnimationData.sequenced(
        amount: amount,
        stepTime: stepTime,
        textureSize: Vector2.all(32),
      ),
    );
  }

  SpriteAnimation _specialSpriteAnimation(String state, int amount) {
    return SpriteAnimation.fromFrameData(
      game.images.fromCache("Main Characters/$state (96x96).png"),
      SpriteAnimationData.sequenced(
        amount: amount,
        stepTime: stepTime,
        textureSize: Vector2.all(96),
      ),
    );
  }

  void _checkHorizontalCollisions() {
    for (final block in collisionBlocks) {
      if (!block.isPlatform) {
        if (checkCollision(this, block)) {
          if (velocity.x > 0) {
            velocity.x = 0;
            position.x = block.x - hitbox.offsetX - hitbox.width;
            break;
          }

          if (velocity.x < 0) {
            velocity.x = 0;
            position.x = block.x + block.width + hitbox.width + hitbox.offsetX;
            break;
          }
        }
      }
    }
  }

  void _applyGravity(double dt) {
    velocity.y += _gravity;
    velocity.y = velocity.y.clamp(-_jumpForce, _terminalVelocity);
    position.y += velocity.y * dt;
  }

  void _checkVerticalCollision() {
    for (final block in collisionBlocks) {
      if (block.isPlatform) {
        if (checkCollision(this, block)) {
          if (velocity.y > 0) {
            velocity.y = 0;
            position.y = block.y - hitbox.height - hitbox.offsetY;
            isGrounded = true;
            break;
          }
        }
      } else {
        if (checkCollision(this, block)) {
          if (velocity.y > 0) {
            velocity.y = 0;
            position.y = block.y - hitbox.height - hitbox.offsetY;
            isGrounded = true;
            break;
          }

          if (velocity.y < 0) {
            velocity.y = 0;
            position.y = block.y + block.height + hitbox.offsetY;
            break;
          }
        }
      }
    }
  }

  void _playerJump(double dt) {
    velocity.y = -_jumpForce;
    position.y += velocity.y * dt;
    isGrounded = false;
    hasJumped = false;
  }

  @override
  void onCollisionStart(
      Set<Vector2> intersectionPoints, PositionComponent other) {
    print('other is $other and is saw : ${other is Saw}');
    print('other is $other and is fruit : ${other is Fruit}');
    if (other is Fruit) {
      other.collidingWithPlayer();
    }

    if (other is Saw) {
      _respawn();
    }
    super.onCollisionStart(intersectionPoints, other);
  }

  void _respawn() {
    const hitDuration = Duration(milliseconds: 50 * 7);
    const appearingDuration = Duration(milliseconds: 50 * 7);
    const canMoveDuration = Duration(microseconds: 400);
    gotHit = true;
    current = PlayerState.hit;
    Future.delayed(hitDuration, () {
      scale.x = 1;
      position = startingPosition - Vector2.all(32);
      current = PlayerState.appearing;

      Future.delayed(appearingDuration, () {
        velocity = Vector2.zero();
        position = startingPosition;
        _updatePlayerState();
        Future.delayed(canMoveDuration, () => gotHit = false);
      });
    });
  }
}
