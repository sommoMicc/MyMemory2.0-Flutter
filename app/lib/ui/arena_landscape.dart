import 'package:flutter/material.dart';

/// Small vector landscapes, shared by the arena map and the selected arena.
class ArenaLandscape extends StatelessWidget {
  const ArenaLandscape({super.key, required this.arenaId});

  final String arenaId;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: CustomPaint(painter: _LandscapePainter(arenaId)),
      );
}

Color arenaColor(String arenaId) => switch (arenaId) {
      'coral_bay' => const Color(0xFF257FAD),
      'grand_city' => const Color(0xFFB96D45),
      'space_frontier' => const Color(0xFF7361A7),
      _ => const Color(0xFF347A5B),
    };

class _LandscapePainter extends CustomPainter {
  const _LandscapePainter(this.arenaId);
  final String arenaId;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 260, size.height / 180);
    final sky = switch (arenaId) {
      'coral_bay' => const Color(0xFFBDE9ED),
      'grand_city' => const Color(0xFFF6DEB9),
      'space_frontier' => const Color(0xFFDFDCF2),
      _ => const Color(0xFFD8EBD2),
    };
    canvas.drawOval(
      const Rect.fromLTWH(25, 12, 210, 153),
      Paint()..color = sky,
    );
    canvas.drawOval(
      const Rect.fromLTWH(35, 157, 190, 14),
      Paint()
        ..color = const Color(0xFF243C3A).withValues(alpha: .10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    switch (arenaId) {
      case 'coral_bay':
        _bay(canvas);
      case 'grand_city':
        _city(canvas);
      case 'space_frontier':
        _space(canvas);
      default:
        _valley(canvas);
    }
    canvas.restore();
  }

  void _valley(Canvas c) {
    _circle(c, 193, 43, 17, const Color(0xFFF4CB6A));
    _cloud(c, 63, 39);
    _shape(c, const [Offset(27, 120), Offset(81, 43), Offset(147, 123)],
        const Color(0xFF8BB9A0));
    _shape(c, const [Offset(94, 124), Offset(156, 56), Offset(228, 124)],
        const Color(0xFF6D9C87));
    _shape(
        c,
        const [
          Offset(66, 64),
          Offset(81, 43),
          Offset(99, 64),
          Offset(84, 60),
          Offset(77, 66)
        ],
        const Color(0xFFF9F7E9));
    _island(c, const Color(0xFF95BC73), const Color(0xFF517B53));
    final river = Path()
      ..moveTo(150, 102)
      ..cubicTo(107, 112, 110, 128, 147, 133)
      ..cubicTo(179, 140, 152, 146, 120, 155);
    c.drawPath(
        river,
        Paint()
          ..color = const Color(0xFF8DD2CF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 13
          ..strokeCap = StrokeCap.round);
    for (final p in const [
      Offset(55, 108),
      Offset(83, 123),
      Offset(204, 116),
      Offset(180, 101)
    ]) {
      _tree(c, p.dx, p.dy);
    }
    for (final p in const [
      Offset(65, 143),
      Offset(99, 145),
      Offset(184, 143)
    ]) {
      _circle(c, p.dx, p.dy, 3, const Color(0xFFF5D581));
    }
  }

  void _bay(Canvas c) {
    _circle(c, 194, 43, 16, const Color(0xFFF7CE73));
    _cloud(c, 61, 41);
    _island(c, const Color(0xFF6BC2D0), const Color(0xFF3A8EA6));
    final sand = Path()
      ..moveTo(28, 128)
      ..cubicTo(66, 104, 97, 105, 112, 125)
      ..cubicTo(118, 139, 86, 148, 48, 145)
      ..close();
    c.drawPath(sand, Paint()..color = const Color(0xFFF4D496));
    final trunk = Path()
      ..moveTo(72, 129)
      ..quadraticBezierTo(76, 101, 67, 82);
    c.drawPath(
        trunk,
        Paint()
          ..color = const Color(0xFFAA7850)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round);
    for (final end in const [
      Offset(43, 91),
      Offset(50, 72),
      Offset(87, 72),
      Offset(95, 92)
    ]) {
      final leaf = Path()
        ..moveTo(67, 83)
        ..quadraticBezierTo((67 + end.dx) / 2, end.dy - 12, end.dx, end.dy);
      c.drawPath(
          leaf,
          Paint()
            ..color = const Color(0xFF45987A)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 9
            ..strokeCap = StrokeCap.round);
    }
    c.drawLine(
        const Offset(159, 56),
        const Offset(159, 121),
        Paint()
          ..color = const Color(0xFF68777D)
          ..strokeWidth = 3);
    _shape(c, const [Offset(164, 60), Offset(196, 104), Offset(164, 104)],
        const Color(0xFFFFF9E9));
    _shape(c, const [Offset(154, 73), Offset(132, 107), Offset(154, 107)],
        const Color(0xFFF1AB83));
    _shape(
        c,
        const [
          Offset(129, 116),
          Offset(199, 116),
          Offset(186, 130),
          Offset(144, 130)
        ],
        const Color(0xFF5A7890));
    for (final p in const [
      Offset(110, 147),
      Offset(168, 143),
      Offset(209, 135)
    ]) {
      c.drawLine(
          p,
          p + const Offset(14, 0),
          Paint()
            ..color = const Color(0xFFC3F2EC)
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round);
    }
  }

  void _city(Canvas c) {
    _circle(c, 192, 43, 19, const Color(0xFFF2B983));
    _cloud(c, 64, 39);
    _island(c, const Color(0xFFC8B391), const Color(0xFF9E8D78));
    final road = Path()
      ..moveTo(39, 141)
      ..lineTo(211, 141);
    c.drawPath(
        road,
        Paint()
          ..color = const Color(0xFFFAEBCF)
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round);
    _building(c, 51, 75, 35, 56, const Color(0xFFC28B6B));
    _building(c, 92, 43, 39, 88, const Color(0xFF769C9C));
    _building(c, 138, 66, 34, 65, const Color(0xFFE4B56C));
    _building(c, 178, 86, 29, 45, const Color(0xFFA38DAD));
    c.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(105, 25, 11, 20), const Radius.circular(3)),
        Paint()..color = const Color(0xFF769C9C));
    _tree(c, 42, 131, scale: .65);
    _tree(c, 222, 134, scale: .7);
    c.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(148, 136, 23, 10), const Radius.circular(4)),
        Paint()..color = const Color(0xFFE47D62));
    _circle(c, 153, 146, 3, const Color(0xFF59636B));
    _circle(c, 166, 146, 3, const Color(0xFF59636B));
  }

  void _space(Canvas c) {
    for (final p in const [
      Offset(52, 45),
      Offset(84, 27),
      Offset(172, 36),
      Offset(217, 77),
      Offset(46, 101),
      Offset(195, 106)
    ]) {
      _star(c, p.dx, p.dy);
    }
    _circle(c, 199, 51, 20, const Color(0xFFB7AAD9));
    c.save();
    c.translate(199, 51);
    c.rotate(-.35);
    c.drawOval(
        const Rect.fromLTWH(-31, -7, 62, 14),
        Paint()
          ..color = const Color(0xFFD0B6D9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5);
    c.restore();
    _island(c, const Color(0xFFB8B1D2), const Color(0xFF837CA6));
    c.drawOval(const Rect.fromLTWH(56, 133, 28, 10),
        Paint()..color = const Color(0xFF9E96BD));
    c.drawOval(const Rect.fromLTWH(163, 140, 37, 9),
        Paint()..color = const Color(0xFF9E96BD));
    c.save();
    c.translate(124, 86);
    c.rotate(.25);
    _shape(c, const [Offset(-11, 25), Offset(0, 53), Offset(10, 25)],
        const Color(0xFFF4BA75));
    _shape(c, const [Offset(-17, 0), Offset(-29, 28), Offset(-11, 22)],
        const Color(0xFFB78DB8));
    _shape(c, const [Offset(17, 0), Offset(29, 28), Offset(11, 22)],
        const Color(0xFFB78DB8));
    final body = Path()
      ..moveTo(0, -49)
      ..cubicTo(23, -30, 22, 4, 12, 27)
      ..lineTo(-12, 27)
      ..cubicTo(-22, 4, -23, -30, 0, -49)
      ..close();
    c.drawPath(body, Paint()..color = const Color(0xFFFFF9ED));
    _circle(c, 0, -12, 10, const Color(0xFF8B7CB3));
    _circle(c, 0, -12, 6, const Color(0xFFBAD9DC));
    c.restore();
  }

  void _island(Canvas c, Color top, Color side) {
    final body = Path()
      ..moveTo(24, 126)
      ..quadraticBezierTo(38, 174, 132, 171)
      ..quadraticBezierTo(218, 171, 238, 126)
      ..close();
    c.drawPath(body, Paint()..color = side);
    c.drawOval(const Rect.fromLTWH(23, 101, 215, 55), Paint()..color = top);
  }

  void _tree(Canvas c, double x, double y, {double scale = 1}) {
    c.save();
    c.translate(x, y);
    c.scale(scale);
    c.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(-3, -22, 6, 28), const Radius.circular(2)),
        Paint()..color = const Color(0xFF92714D));
    _shape(
        c,
        const [
          Offset(0, -55),
          Offset(-16, -23),
          Offset(-9, -23),
          Offset(-22, -7),
          Offset(22, -7),
          Offset(9, -23),
          Offset(16, -23)
        ],
        const Color(0xFF3C8063));
    c.restore();
  }

  void _building(
      Canvas c, double x, double y, double w, double h, Color color) {
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, w, h), const Radius.circular(3)),
        Paint()..color = color);
    for (var row = 0; row < (h - 12) / 16; row++) {
      for (var column = 0; column < 2; column++) {
        c.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(x + 7 + column * 14, y + 9 + row * 16, 6, 8),
                const Radius.circular(1)),
            Paint()..color = const Color(0xFFF8EBD1));
      }
    }
  }

  void _cloud(Canvas c, double x, double y) {
    const color = Color(0xFFFFFBF1);
    _circle(c, x, y, 8, color);
    _circle(c, x + 10, y - 5, 11, color);
    _circle(c, x + 22, y, 8, color);
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, 23, 8), const Radius.circular(4)),
        Paint()..color = color);
  }

  void _star(Canvas c, double x, double y) {
    final paint = Paint()
      ..color = const Color(0xFFFCF8EF)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    c.drawLine(Offset(x - 3, y), Offset(x + 3, y), paint);
    c.drawLine(Offset(x, y - 3), Offset(x, y + 3), paint);
  }

  void _shape(Canvas c, List<Offset> points, Color color) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    c.drawPath(path..close(), Paint()..color = color);
  }

  void _circle(Canvas c, double x, double y, double radius, Color color) =>
      c.drawCircle(Offset(x, y), radius, Paint()..color = color);

  @override
  bool shouldRepaint(_LandscapePainter oldDelegate) =>
      oldDelegate.arenaId != arenaId;
}
