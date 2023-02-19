import 'dart:math';

import 'package:bullet_hell/bullets.dart';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

class Bullet extends SpriteAnimationComponent with HasGameRef, BulletsMixin {
  final SpriteAnimationComponent boss;
  final double? movingDirection;
  double speed;
  final bool moveLongAngle;
  final bool increaseSpeed;
  final bool randomizeStepTime;
  late int bornTime;

  Bullet(this.boss, this.movingDirection,
      {this.speed = 100,
      this.moveLongAngle = true,
      this.increaseSpeed = false,
      this.randomizeStepTime = false})
      : super() {
    super.angle = movingDirection!;
    bornTime = DateTime.now().millisecondsSinceEpoch;
    if (moveLongAngle && movingDirection == null) {
      throw Error();
    }
  }

  @override
  Future<void>? onLoad() async {
    anchor = Anchor.center;
    animation = await gameRef.loadSpriteAnimation(
        'b1.png',
        SpriteAnimationData.sequenced(
            texturePosition: Vector2.zero(),
            amount: 10,
            stepTime: 0.1,
            textureSize: Vector2(126, 121),
            loop: true));
    size = Vector2(25.2, 24.2);
    add(RectangleHitbox(position: Vector2.zero(), size: size));
    return super.onLoad();
  }

  @override
  void update(double dt) {
    boss.priority = boss.priority++;
    if (moveLongAngle) {
      moveWithAngle(movingDirection!, speed * dt);
    }
    if (DateTime.now().millisecondsSinceEpoch - bornTime > 10000) {
      removeFromParent();
    }
    super.update(dt);
  }
}
