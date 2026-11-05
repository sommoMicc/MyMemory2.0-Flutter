import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'deck_art.dart';

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
                                  child: SizedBox(
                                    width: artSize,
                                    height: artSize,
                                    child: DeckArtwork(
                                      collection: widget.collection,
                                      value: 0,
                                    ),
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
                                  child: SizedBox(
                                    width: artSize * 1.2,
                                    height: artSize * 1.2,
                                    child: DeckArtwork(
                                      collection: widget.collection,
                                      value: 2,
                                    ),
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
                                child: SizedBox(
                                  width: artSize * .47,
                                  height: artSize * .47,
                                  child: DeckArtwork(
                                    collection: widget.collection,
                                    value: 5,
                                  ),
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
                                child: DeckArtwork(
                                  collection: widget.collection,
                                  value: i,
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
    final paola = collection == 'paola';
    final food = collection == 'food';
    final sports = collection == 'sports';
    final travel = collection == 'travel';
    final colors = switch (collection) {
      'cosmos' => const [
        Color(0xFFA994DE),
        Color(0xFFB2A4DF),
        Color(0xFF708BC4),
      ],
      'ocean' => const [
        Color(0xFF86D4E0),
        Color(0xFF73C4D8),
        Color(0xFF3E99BD),
      ],
      'paola' => const [
        Color(0xFFFFE3DF),
        Color(0xFFF0C6DF),
        Color(0xFFB9A7D8),
      ],
      'food' => const [Color(0xFFFFDFC2), Color(0xFFF5C7AC), Color(0xFFE7A19A)],
      'sports' => const [
        Color(0xFFA8D7BD),
        Color(0xFF7CC5B4),
        Color(0xFF4A9C9E),
      ],
      'travel' => const [
        Color(0xFFBDDDF1),
        Color(0xFFB5DBE2),
        Color(0xFF81B3C4),
      ],
      _ => const [Color(0xFFB5D991), Color(0xFF9CCCA0), Color(0xFF68AB8E)],
    };
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
    } else if (paola) {
      final notebook = RRect.fromRectAndRadius(
        Rect.fromLTWH(w * .07, h * .64, w * .86, h * .40),
        const Radius.circular(26),
      );
      canvas.drawRRect(
        notebook,
        Paint()..color = Colors.white.withValues(alpha: .20),
      );
      final line = Paint()
        ..color = const Color(0xFF8B78AF).withValues(alpha: .20)
        ..strokeWidth = 1.5;
      for (var row = 0; row < 7; row++) {
        final y = h * (.69 + row * .05);
        canvas.drawLine(Offset(w * .12, y), Offset(w * .88, y), line);
      }
      canvas.drawCircle(
        Offset(w * .86, h * .13),
        w * .18,
        Paint()..color = const Color(0xFFFFDCA4).withValues(alpha: .52),
      );
    } else if (food) {
      final table = Rect.fromLTWH(0, h * .77, w, h * .23);
      canvas.drawRect(
        table,
        Paint()..color = const Color(0xFFD8877C).withValues(alpha: .24),
      );
      const square = 34.0;
      for (var row = 0; row < table.height / square; row++) {
        for (var column = 0; column < w / square; column++) {
          if ((row + column).isEven) {
            canvas.drawRect(
              Rect.fromLTWH(
                column * square,
                table.top + row * square,
                square,
                math.min(square, h - table.top - row * square),
              ),
              Paint()..color = const Color(0xFFFFF4DC).withValues(alpha: .22),
            );
          }
        }
      }
      canvas.drawCircle(
        Offset(w * .88, h * .12),
        w * .21,
        Paint()..color = const Color(0xFFFFE9B0).withValues(alpha: .65),
      );
      for (var i = 0; i < 4; i++) {
        final x = w * (.14 + i * .24);
        canvas.drawLine(
          Offset(x, 0),
          Offset(x, h * .055),
          Paint()
            ..color = const Color(0xFFAD6E66).withValues(alpha: .22)
            ..strokeWidth = 2,
        );
        canvas.drawArc(
          Rect.fromCenter(center: Offset(x, h * .068), width: 38, height: 26),
          math.pi,
          math.pi,
          true,
          Paint()..color = const Color(0xFFDA9274).withValues(alpha: .32),
        );
      }
    } else if (sports) {
      final court = RRect.fromRectAndRadius(
        Rect.fromLTWH(w * .08, h * .69, w * .84, h * .36),
        const Radius.circular(24),
      );
      canvas.drawRRect(
        court,
        Paint()..color = const Color(0xFF306E70).withValues(alpha: .20),
      );
      final markings = Paint()
        ..color = Colors.white.withValues(alpha: .38)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawRRect(court.deflate(11), markings);
      canvas.drawLine(
        Offset(w * .08, h * .86),
        Offset(w * .92, h * .86),
        markings,
      );
      canvas.drawCircle(Offset(w * .5, h * .86), w * .16, markings);
      for (var i = 0; i < 5; i++) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(w * .5, -h * .12),
            width: w * (1.1 + i * .13),
            height: h * (.5 + i * .08),
          ),
          Paint()
            ..color = Colors.white.withValues(alpha: .12)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6,
        );
      }
    } else if (travel) {
      final land = Paint()
        ..color = const Color(0xFF8CB79C).withValues(alpha: .38);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-w * .14, h * .06, w * .53, h * .30),
          const Radius.circular(80),
        ),
        land,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * .58, h * .67, w * .62, h * .29),
          const Radius.circular(68),
        ),
        land,
      );
      final route = Path()
        ..moveTo(-w * .08, h * .87)
        ..cubicTo(w * .8, h * .92, -w * .22, h * .40, w * 1.08, h * .18);
      final routePaint = Paint()
        ..color = const Color(0xFFFFE1AA).withValues(alpha: .70)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      for (final metric in route.computeMetrics()) {
        for (var at = 0.0; at < metric.length; at += 21) {
          canvas.drawPath(
            metric.extractPath(at, math.min(at + 9, metric.length)),
            routePaint,
          );
        }
      }
      final center = Offset(w * .86, h * .11);
      canvas.drawCircle(
        center,
        30,
        Paint()..color = Colors.white.withValues(alpha: .26),
      );
      final needle = Path()
        ..moveTo(center.dx, center.dy - 22)
        ..lineTo(center.dx + 8, center.dy + 9)
        ..lineTo(center.dx - 8, center.dy + 9)
        ..close();
      canvas.drawPath(
        needle,
        Paint()..color = const Color(0xFF5C8EAF).withValues(alpha: .55),
      );
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
    if (!space && !ocean && !paola && !food && !sports && !travel) {
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
