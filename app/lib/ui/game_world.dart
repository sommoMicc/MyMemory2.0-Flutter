import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../decks.dart';

/// A decorative, non-interactive world underneath the complete app viewport.
class GameWorld extends StatefulWidget {
  const GameWorld({super.key, required this.collection, required this.child});
  final String collection;
  final Widget child;
  @override
  State<GameWorld> createState() => _GameWorldState();
}

class _GameWorldState extends State<GameWorld>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController drift;
  bool motion = true;
  bool active = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    drift = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    motion =
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    syncMotion();
  }

  void syncMotion() {
    if (motion && active) {
      if (!drift.isAnimating) drift.repeat();
    } else {
      drift.stop();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    active = state == AppLifecycleState.resumed;
    syncMotion();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.dark.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
    child: Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: ExcludeSemantics(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: drift,
                  builder: (context, _) => LayoutBuilder(
                    builder: (context, c) {
                      final t = drift.value * math.pi * 2;
                      final artSize = math.min(c.maxWidth * .31, 155.0);
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          CustomPaint(
                            painter: _WorldPainter(
                              widget.collection,
                              drift.value,
                            ),
                          ),
                          Positioned(
                            left: -artSize * .14,
                            top: c.maxHeight * .17,
                            child: Transform.translate(
                              key: const ValueKey('world-float'),
                              offset: Offset(0, math.sin(t) * 9),
                              child: Transform.rotate(
                                angle: -.17 + math.sin(t) * .025,
                                child: Opacity(
                                  opacity: .72,
                                  child: Image.asset(
                                    deckAsset(widget.collection, 0)!,
                                    width: artSize,
                                    height: artSize,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: -artSize * .18,
                            bottom: c.maxHeight * .055,
                            child: Transform.translate(
                              offset: Offset(0, math.cos(t) * 8),
                              child: Transform.rotate(
                                angle: .18,
                                child: Opacity(
                                  opacity: .65,
                                  child: Image.asset(
                                    deckAsset(widget.collection, 2)!,
                                    width: artSize * 1.2,
                                    height: artSize * 1.2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: c.maxWidth * .13,
                            top: c.maxHeight * .12,
                            child: Transform.rotate(
                              angle: .2,
                              child: Opacity(
                                opacity: .50,
                                child: Image.asset(
                                  deckAsset(widget.collection, 5)!,
                                  width: artSize * .47,
                                  height: artSize * .47,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
        widget.child,
      ],
    ),
  );
}

/// An illustrated card scene that uses otherwise empty setup space.
class CollectionScene extends StatefulWidget {
  const CollectionScene({super.key, required this.collection});
  final String collection;
  @override
  State<CollectionScene> createState() => _CollectionSceneState();
}

class _CollectionSceneState extends State<CollectionScene>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController float;
  bool motion = true;
  bool active = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    float = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    motion =
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    syncMotion();
  }

  void syncMotion() {
    if (motion && active) {
      if (!float.isAnimating) float.repeat(reverse: true);
    } else {
      float.stop();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    active = state == AppLifecycleState.resumed;
    syncMotion();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: IgnorePointer(
      child: LayoutBuilder(
        builder: (context, c) {
          final height = math.min(c.maxHeight, 250.0);
          final width = math.min(c.maxWidth, height * 1.6);
          return Center(
            child: SizedBox(
              width: width,
              height: height,
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: float,
                  builder: (context, _) {
                    final bob = math.sin(float.value * math.pi) * 8;
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          bottom: height * .07,
                          child: Container(
                            width: width * .65,
                            height: height * .10,
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF253751,
                              ).withValues(alpha: .14),
                              borderRadius: BorderRadius.circular(100),
                            ),
                          ),
                        ),
                        for (var i = 0; i < 3; i++)
                          Positioned(
                            left: width * (.09 + i * .24),
                            top:
                                height * (i == 1 ? .06 : .18) +
                                (i == 1 ? -bob : bob * .4),
                            child: Transform.rotate(
                              angle: (i - 1) * .22,
                              child: Container(
                                width: width * .34,
                                height: height * .70,
                                padding: EdgeInsets.all(height * .06),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF8E8),
                                  borderRadius: BorderRadius.circular(
                                    height * .09,
                                  ),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: .9),
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF26344E,
                                      ).withValues(alpha: .18),
                                      blurRadius: 12,
                                      offset: const Offset(0, 7),
                                    ),
                                  ],
                                ),
                                child: Image.asset(
                                  deckAsset(widget.collection, i)!,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          right: width * .02,
                          top: height * .04 + bob,
                          child: Icon(
                            Icons.auto_awesome_rounded,
                            color: const Color(0xFFFFF2B6),
                            size: height * .15,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

class _WorldPainter extends CustomPainter {
  const _WorldPainter(this.collection, this.progress);
  final String collection;
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    final space = collection == 'cosmos';
    final ocean = collection == 'ocean';
    final colors = space
        ? const [Color(0xFFA994DE), Color(0xFFB2A4DF), Color(0xFF708BC4)]
        : ocean
        ? const [Color(0xFF86D4E0), Color(0xFF73C4D8), Color(0xFF3E99BD)]
        : const [Color(0xFFB5D991), Color(0xFF9CCCA0), Color(0xFF68AB8E)];
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ).createShader(rect),
    );
    final t = progress * math.pi * 2;
    final w = size.width;
    final h = size.height;
    if (space) {
      final planet = Offset(w * .92, h * .13);
      canvas.drawCircle(
        planet,
        w * .23,
        Paint()..color = const Color(0xFF8066B5).withValues(alpha: .30),
      );
      canvas.save();
      canvas.translate(planet.dx, planet.dy);
      canvas.rotate(-.4);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: w * .65, height: w * .15),
        Paint()
          ..color = const Color(0xFFFFE6B2).withValues(alpha: .42)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8,
      );
      canvas.restore();
      canvas.drawCircle(
        Offset(w * .03, h * .82),
        w * .27,
        Paint()..color = const Color(0xFF685DAB).withValues(alpha: .33),
      );
    } else if (ocean) {
      for (var band = 0; band < 3; band++) {
        final y = h * (.73 + band * .10);
        final path = Path()..moveTo(0, y);
        for (var x = 0.0; x <= w + 8; x += 8) {
          path.lineTo(
            x,
            y + math.sin(x / w * math.pi * 2 + t + band) * (14 + band * 4),
          );
        }
        path
          ..lineTo(w, h)
          ..lineTo(0, h)
          ..close();
        canvas.drawPath(
          path,
          Paint()
            ..color = const [
              Color(0xFF348EAF),
              Color(0xFF277E9F),
              Color(0xFF256C8C),
            ][band].withValues(alpha: .30),
        );
      }
    } else {
      canvas.drawCircle(
        Offset(w * .89, h * .13),
        math.min(w * .25, 155),
        Paint()..color = const Color(0xFFFFD27D).withValues(alpha: .70),
      );
      for (var band = 0; band < 3; band++) {
        final path = Path()
          ..moveTo(-w * .1, h * (.81 + band * .06))
          ..quadraticBezierTo(
            w * .3,
            h * (.66 + band * .09),
            w * 1.1,
            h * (.86 + band * .04),
          )
          ..lineTo(w * 1.1, h)
          ..lineTo(-w * .1, h)
          ..close();
        canvas.drawPath(
          path,
          Paint()
            ..color = const [
              Color(0xFF72A55D),
              Color(0xFF448C6E),
              Color(0xFF327B68),
            ][band].withValues(alpha: .60),
        );
      }
    }
    for (var i = 0; i < 32; i++) {
      final x = ((i * 67 + 23) % 101) / 101 * w + math.sin(t + i) * 5;
      final y = ((i * 43 + 11) % 97) / 97 * h + math.cos(t + i * .7) * 7;
      final radius = 2.0 + (i % 4) * 1.7;
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: space ? .55 : .24);
      if (space && i % 3 == 0) {
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawLine(Offset(x - radius, y), Offset(x + radius, y), paint);
        canvas.drawLine(Offset(x, y - radius), Offset(x, y + radius), paint);
      } else if (ocean) {
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawCircle(Offset(x, y), radius * 2, paint);
      } else {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
    if (!space && !ocean) {
      for (var side in [-1.0, 1.0]) {
        canvas.save();
        canvas.translate(side < 0 ? 0 : w, h * .60);
        canvas.scale(side < 0 ? 1 : -1, 1);
        for (var leaf = 0; leaf < 4; leaf++) {
          canvas.save();
          canvas.translate(8, leaf * 24);
          canvas.rotate(-.5 + leaf * .23 + math.sin(t) * .025);
          canvas.drawOval(
            Rect.fromLTWH(-25, -10, 70, 24),
            Paint()..color = const Color(0xFF3B8C68).withValues(alpha: .30),
          );
          canvas.restore();
        }
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_WorldPainter oldDelegate) =>
      collection != oldDelegate.collection || progress != oldDelegate.progress;
}
