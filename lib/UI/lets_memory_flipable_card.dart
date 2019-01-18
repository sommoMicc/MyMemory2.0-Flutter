import 'package:flutter/material.dart';
import './lets_memory_static_card.dart';

class LetsMemoryFlipableCard extends StatefulWidget {
  final String letter;
  final Color textColor;
  final Matrix4 rotation;

  LetsMemoryFlipableCard({this.letter, this.textColor = Colors.white, this.rotation});

  @override
  State<StatefulWidget> createState() => _LetsMemoryFlipableCardState();
}

class _LetsMemoryFlipableCardState extends State<LetsMemoryFlipableCard> with TickerProviderStateMixin {
  AnimationController _controller;
  Animation<double> _frontScale;
  Animation<double> _backScale;

  bool _pressed;

  @override
  void initState() {
    super.initState();
    this._pressed = false;

    _controller = new AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _frontScale = new Tween(
      begin: 1.0,
      end: 0.0,
    ).animate(new CurvedAnimation(
      parent: _controller,
      curve: new Interval(0.0, 0.5, curve: Curves.easeIn),
    ));
    _backScale = new CurvedAnimation(
      parent: _controller,
      curve: new Interval(0.5, 1.0, curve: Curves.easeOut),
    );
  }

  void toggleFlip() {
    setState(() {
      if (_controller.isCompleted || _controller.velocity > 0)
        _controller.reverse();
      else
        _controller.forward();
    });

  }

  void _onTap() {
    toggleFlip();
  }

   void _onTapDown(TapDownDetails details) {
    setState(()  {
      _pressed = true;
    });
  }

  void _onTapUp(TapUpDetails details) {
    setState(() {
      _pressed = false;
    });
  }

  void _onTapCancel() {
    this._onTapUp(null);
  }

    @override
  Widget build(BuildContext context) {

    return GestureDetector(
      onTap: _onTap,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,

      child: Center(
        child: new Stack(
          children: <Widget>[
            AnimatedBuilder(
              child: LetsMemoryStaticCard(
                letter: widget.letter,
                textColor: widget.textColor,
                rotation: widget.rotation,
                pressed:_pressed
              ),
              animation: _backScale,
              builder: (BuildContext context, Widget child) {
                final Matrix4 transform = Matrix4.identity()
                  ..scale(1.0, _backScale.value, 1.0);
                return Transform(
                  transform: transform,
                  alignment: FractionalOffset.center,
                  child: child,
                );
              },
            ),
            
            AnimatedBuilder(
              child: LetsMemoryStaticCard(
                letter: "||||",
                textColor: Colors.orange,
                shadowColor: Colors.grey[850],
                backgroundColor: Colors.grey[900],
                pressed: _pressed,
              ),
              animation: _frontScale,
              builder: (BuildContext context, Widget child) {
                final Matrix4 transform = new Matrix4.identity()
                  ..scale(1.0, _frontScale.value, 1.0);
                return Transform(
                  transform: transform,
                  alignment: FractionalOffset.center,
                  child: child,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
