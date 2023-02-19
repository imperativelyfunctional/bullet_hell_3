import 'dart:async' as async;
import 'dart:math';

import 'package:bullet_hell/bullet_base.dart';
import 'package:bullet_hell/game_wall.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/flame.dart';
import 'package:flame/game.dart';
import 'package:flame/parallax.dart';
import 'package:flutter/material.dart';

import 'bullet.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Flame.device.fullScreen();
  await Flame.device.setLandscape();
  var bulletHell = BulletHell();
  runApp(GameWidget(game: bulletHell));
}

late Vector2 viewPortSize;

class BulletHell extends FlameGame with HasCollisionDetection {
  late SpriteAnimationComponent boss;
  late MainEventHandler mainEventHandler;
  late GameWall gameWall;
  async.Timer? bossTimer;
  List<List<BulletBase>> bases = [];
  final List<Color> colors = [
    Colors.amber,
    Colors.tealAccent,
    Colors.green,
    Colors.lightGreenAccent,
    Colors.red,
    Colors.lime,
    Colors.indigo,
    Colors.white70,
    Colors.white10,
  ];

  @override
  Future<void> onLoad() async {
    super.onLoad();
    var viewDimension = Vector2(1920, 1080);
    viewPortSize = viewDimension;
    camera.viewport = FixedResolutionViewport(viewDimension);

    add(SpriteComponent(
      sprite: await Sprite.load("nebula.jpg"),
    ));
    add(SpriteComponent(
      sprite: await Sprite.load("poem.png"),
    )
      ..opacity = 0
      ..add(OpacityEffect.to(0.2, SineEffectController(period: 60))));
    await addParallaxBackground();
    var boss = await addBoss();
    mainEventHandler = MainEventHandler(this, boss);
  }

  Future<SpriteAnimationComponent> addBoss() async {
    var imageSize = Vector2(101, 64);
    final running = await loadSpriteAnimation(
      'boss.png',
      SpriteAnimationData.sequenced(
        amount: 4,
        textureSize: imageSize,
        stepTime: 0.5,
      ),
    );

    boss = SpriteAnimationComponent(
        priority: 1,
        animation: running,
        anchor: Anchor.center,
        size: imageSize,
        angle: pi,
        position: Vector2(size.x / 2.0, -10),
        scale: Vector2(0.5, 0.5));
    boss.add(SequenceEffect(
      [
        MoveEffect.to(
            Vector2(size.x / 2.0, 800),
            EffectController(
                duration: 1, infinite: false, curve: Curves.bounceIn)),
        MoveEffect.to(
            Vector2(size.x / 2.0, 500),
            EffectController(
                duration: 1, infinite: false, curve: Curves.easeInExpo))
      ],
    ));
    gameWall = GameWall();
    add(gameWall);
    add(boss);
    init(boss);
    return boss;
  }

  void _startBoss(SpriteAnimationComponent boss,
      {steps = 72, frequency = 10, clockWise = true}) {
    if (bossTimer != null) {
      bossTimer!.cancel();
    }
    bossTimer =
        async.Timer.periodic(Duration(milliseconds: frequency), (timer) {
      if (clockWise) {
        boss.angle += pi / steps;
      } else {
        boss.angle -= pi / steps;
      }
    });
  }

  void init(SpriteAnimationComponent boss) {
    async.Timer.periodic(const Duration(milliseconds: 5000), (timer) {
      bases
          .add(_layBases(boss.position, 0, 8, 100, color: Colors.yellowAccent));
      bases.add(_layBases(
        boss.position,
        0,
        8,
        120,
      ));
      bases.add(_layBases(boss.position, 0, 8, 140, color: Colors.pink));
      bases.add(
          _layBases(boss.position, 0, 8, 160, color: Colors.lightBlueAccent));
      bases.add(_layBases(boss.position, 0, 8, 180, color: Colors.lightGreen));
      bases.add(
          _layBases(boss.position, 0, 8, 180, color: Colors.deepPurpleAccent));
      timer.cancel();
    });

    int frequency = 400;
    List<async.Timer> timers = [];
    int counter = 0;
    async.Timer.periodic(const Duration(seconds: 1), (timer) {
      cleanTimers(timers);
      timers.addAll(moveBulletBases(bases, boss, frequency: frequency));
      frequency -= 40;
      counter++;
      if (counter > 10) {
        mainEventHandler.handleEvent("one");
        timer.cancel();
      }
    });
  }

  void _commonShootingProcedure(
      SpriteAnimationComponent boss, int periodInMilliseconds, Function shoot,
      {required String next}) {
    bool done = false;
    int frequency = 100;
    var numberOfRounds = periodInMilliseconds ~/ frequency;
    int round = 0;
    var shootingTimer =
        async.Timer.periodic(Duration(milliseconds: frequency), (timer) {
      if (!done) {
        round++;
        shoot();
        if (round >= numberOfRounds) {
          done = true;
          round = 0;
        }
      }
    });
    int coolDown = 0;
    int coolDownTimes = 0;
    async.Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (done) {
        coolDown++;
      }
      if (coolDown >= 20) {
        coolDown = 0;
        done = false;
        coolDownTimes++;
      }
      if (coolDownTimes >= 3) {
        shootingTimer.cancel();
        mainEventHandler.handleEvent(next);
        timer.cancel();
      }
    });
  }

  void cleanTimers(List<async.Timer> timers) {
    for (var element in timers) {
      element.cancel();
    }
    timers.clear();
  }

  List<async.Timer> moveBulletBases(
      List<List<BulletBase>> bases, SpriteAnimationComponent boss,
      {int frequency = 400}) {
    double radius = 100;
    int counter = 0;
    List<async.Timer> timers = [];
    for (var element in bases) {
      for (var element in element) {
        timers.add(element.moveAround(boss.position, radius,
            ((counter % 2 == 1) ? -1 : 1) * pi / 8, frequency));
      }
      counter++;
      radius += 20;
    }
    return timers;
  }

  List<BulletBase> _layBases(
    Vector2 reference,
    double initialAngle,
    int numberOfBases,
    double radius, {
    Color color = Colors.white,
  }) {
    List<BulletBase> bases = [];
    double angleBetweenBases = 2 * pi / numberOfBases;
    for (int i = 0; i < numberOfBases; i++) {
      var angle = initialAngle + i * angleBetweenBases;
      var base = BulletBase(color,
          radius: 5,
          position: reference + Vector2(cos(angle), sin(angle)) * radius,
          autoRemove: false);
      bases.add(base);
      add(base);
    }
    return bases;
  }

  Future<void> addParallaxBackground() async {
    final layerInfo = {
      'background_1.png': 6.0,
      'background_2.png': 8.5,
      'background_3.png': 12.0,
      'background_4.png': 20.5,
    };

    final parallax = ParallaxComponent(
      parallax: Parallax(
        await Future.wait(layerInfo.entries.map(
          (entry) => loadParallaxLayer(
            ParallaxImageData(entry.key),
            fill: LayerFill.width,
            repeat: ImageRepeat.repeat,
            velocityMultiplier: Vector2(entry.value, entry.value),
          ),
        )),
        baseVelocity: Vector2(10, 10),
      ),
    );

    Random().nextBool() ? ImageRepeat.repeatX : ImageRepeat.repeatY;
    async.Timer.periodic(const Duration(seconds: 5), (timer) {
      parallax.parallax?.baseVelocity = Vector2(
        Random().nextBool()
            ? Random().nextInt(20).toDouble()
            : -Random().nextInt(20).toDouble(),
        Random().nextBool()
            ? Random().nextInt(20).toDouble()
            : -Random().nextInt(20).toDouble(),
      );
    });
    add(parallax);
  }

  void patternEight() {
    _startBoss(boss);
    int howManyTimeToRun = 300;
    int counter = 0;
    async.Timer.periodic(const Duration(milliseconds: 20), (timer) {
      counter++;
      add(Bullet(boss, boss.angle, speed: 300)..position = boss.position);
      add(Bullet(boss, boss.angle + pi / 2, speed: 300)
        ..position = boss.position);
      add(Bullet(boss, -boss.angle, speed: 300)..position = boss.position);
      add(Bullet(boss, -boss.angle - pi / 2, speed: 300)
        ..position = boss.position);
      if (counter >= howManyTimeToRun) {
        bossTimer!.cancel();
        mainEventHandler.handleEvent("one");
        boss.angle = pi;
        timer.cancel();
      }
    });
  }

  void patternSeven() {
    _startBoss(boss);
    int howManyTimeToRun = 200;
    int counter = 0;
    async.Timer.periodic(const Duration(milliseconds: 40), (timer) {
      counter++;
      add(Bullet(boss, boss.angle - 3 * pi / 4, speed: 500)
        ..position = boss.position);
      add(Bullet(boss, boss.angle - pi / 2, speed: 500)
        ..position = boss.position);
      add(Bullet(boss, boss.angle - pi / 4, speed: 500)
        ..position = boss.position);
      add(Bullet(boss, boss.angle - pi, speed: 500)..position = boss.position);
      add(Bullet(boss, boss.angle, speed: 500)..position = boss.position);
      add(Bullet(boss, boss.angle + pi / 4, speed: 500)
        ..position = boss.position);
      add(Bullet(boss, boss.angle + pi / 2, speed: 500)
        ..position = boss.position);
      add(Bullet(boss, boss.angle + 3 * pi / 4, speed: 500)
        ..position = boss.position);
      if (counter >= howManyTimeToRun) {
        mainEventHandler.handleEvent("eight");
        boss.angle = pi;
        timer.cancel();
      }
    });
  }

  void patternSix() {
    _startBoss(boss);
    int howManyTimeToRun = 100;
    int counter = 0;
    async.Timer.periodic(const Duration(milliseconds: 50), (timer) {
      counter++;
      add(Bullet(boss, boss.angle, speed: 500)..position = boss.position);
      add(Bullet(boss, boss.angle + pi / 2, speed: 500)
        ..position = boss.position);
      add(Bullet(boss, -boss.angle, speed: 500)..position = boss.position);
      add(Bullet(boss, -boss.angle - pi / 2, speed: 500)
        ..position = boss.position);
      if (counter >= howManyTimeToRun) {
        mainEventHandler.handleEvent("seven");
        boss.angle = pi;
        timer.cancel();
      }
    });
  }

  void patternFive() {
    _startBoss(boss, clockWise: false);
    int howManyTimeToRun = 100;
    int counter = 0;
    async.Timer.periodic(const Duration(milliseconds: 50), (timer) {
      counter++;
      add(Bullet(boss, boss.angle, speed: 500)..position = boss.position);
      add(Bullet(boss, -boss.angle, speed: 500)..position = boss.position);
      if (counter >= howManyTimeToRun) {
        mainEventHandler.handleEvent("six");
        timer.cancel();
      }
    });
  }

  void patternFour() {
    _startBoss(boss);
    int howManyTimeToRun = 100;
    int counter = 0;
    async.Timer.periodic(const Duration(milliseconds: 50), (timer) {
      counter++;
      add(Bullet(boss, boss.angle, speed: 500)..position = boss.position);
      if (counter >= howManyTimeToRun) {
        mainEventHandler.handleEvent("five");
        timer.cancel();
      }
    });
  }

  void patternThree() {
    var random = Random();
    async.Timer.periodic(const Duration(milliseconds: 300), (timer) {
      var additionalAngle = (random.nextBool() ? pi : 0);
      for (var element in bases) {
        for (var element in element) {
          add(Bullet(
              speed: 300,
              boss,
              element.angleTo(boss.position) + additionalAngle)
            ..position = element.position);
        }
      }
      timer.cancel();
    });
  }

  void patternTwo() {
    for (int i = 0; i < 16; i++) {
      add(Bullet(boss, 2 * i * pi / 16, speed: 300)..position = boss.position);
    }
  }

  void patternOne() {
    for (int i = 0; i < 8; i++) {
      add(Bullet(boss, 2 * i * pi / 8, speed: 300)..position = boss.position);
    }
  }
}

abstract class EventHandler {
  void handleEvent(String event);
}

class MainEventHandler extends EventHandler {
  final BulletHell bulletHell;
  final SpriteAnimationComponent boss;

  MainEventHandler(this.bulletHell, this.boss);

  @override
  void handleEvent(String event) {
    switch (event) {
      case "one":
        {
          bulletHell._commonShootingProcedure(
              next: "two", boss, 2000, () => bulletHell.patternOne());
          break;
        }
      case "two":
        {
          bulletHell._commonShootingProcedure(
            next: "three",
            boss,
            2000,
            () => bulletHell.patternTwo(),
          );
          break;
        }
      case "three":
        {
          bulletHell._commonShootingProcedure(
            next: "four",
            boss,
            2000,
            () => bulletHell.patternThree(),
          );
          break;
        }
      case "four":
        {
          bulletHell.patternFour();
          break;
        }
      case "five":
        {
          bulletHell.patternFive();
          break;
        }
      case "six":
        {
          bulletHell.patternSix();
          break;
        }
      case "seven":
        {
          bulletHell.patternSeven();
          break;
        }
      case "eight":
        {
          bulletHell.patternEight();
          break;
        }
    }
  }
}
