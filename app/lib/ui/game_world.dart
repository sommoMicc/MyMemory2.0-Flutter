import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../palette.dart';
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
    value: SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: popCobalt,
    ),
    child: Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: ExcludeSemantics(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const CustomPaint(painter: _PopWorldPainter()),
                    Positioned(
                      right: -18,
                      bottom: 14,
                      child: AnimatedBuilder(
                        animation: drift,
                        child: const SizedBox(
                          width: 116,
                          height: 100,
                          child: CustomPaint(painter: _PairMarkPainter()),
                        ),
                        builder: (context, child) => Transform.translate(
                          key: const ValueKey('world-float'),
                          offset: Offset(
                            0,
                            math.sin(drift.value * math.pi * 2) * 3,
                          ),
                          child: child,
                        ),
                      ),
                    ),
                  ],
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
                        for (var i = 0; i < 2; i++)
                          Positioned(
                            left: width * (.20 + i * .26),
                            top:
                                height * (i == 1 ? .06 : .18) +
                                (i == 1 ? -bob : bob * .4),
                            child: Transform.rotate(
                              angle: i == 0 ? -.15 : .13,
                              child: Container(
                                width: width * .34,
                                height: height * .70,
                                padding: EdgeInsets.all(height * .06),
                                decoration: BoxDecoration(
                                  color: i == 1 ? popYellow : paper,
                                  borderRadius: BorderRadius.circular(
                                    height * .09,
                                  ),
                                  border: Border.all(color: ink, width: 2.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: ink,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: DeckArtwork(
                                  collection: widget.collection,
                                  value: 0,
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
          );
        },
      ),
    ),
  );
}

/// A restrained paired-dot texture leaves the board and controls in focus.
class _PopWorldPainter extends CustomPainter {
  const _PopWorldPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = popCobalt);
    final dot = Paint()..color = paper.withValues(alpha: .18);
    for (var y = 12.0; y < size.height; y += 24) {
      for (var x = 12.0; x < size.width; x += 24) {
        canvas.drawCircle(Offset(x, y), 1.05, dot);
      }
    }
  }

  @override
  bool shouldRepaint(_PopWorldPainter oldDelegate) => false;
}

/// The repeated pair of cards is the decorative signature of the game.
class _PairMarkPainter extends CustomPainter {
  const _PairMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = paper.withValues(alpha: .10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    for (var i = 0; i < 2; i++) {
      canvas.save();
      canvas.translate(36.0 + i * 35, 48.0);
      canvas.rotate(i == 0 ? -.20 : .15);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-24, -34, 48, 68),
          const Radius.circular(9),
        ),
        stroke,
      );
      canvas.drawCircle(Offset.zero, 10, stroke);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_PairMarkPainter oldDelegate) => false;
}
