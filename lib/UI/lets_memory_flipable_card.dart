import 'package:flutter/material.dart';
import './lets_memory_static_card.dart';

class LetsMemoryFlipableCard extends StatefulWidget {
  final String letter;
  final Color textColor;
  final Matrix4 rotation;

  final _LetsMemoryFlipableCardState state;

  LetsMemoryFlipableCard({this.letter, this.textColor = Colors.white, this.rotation})
   : state = _LetsMemoryFlipableCardState();

  @override
  State<StatefulWidget> createState() => state;

  void hide() => state.hide();
  void reveal() => state.reveal();

  void makeAsFound() => state.makeAsFound();
  bool get found => state.found;

  void setOnTapCallback(Function callback) => state.onTapCallback = callback;

  @override
  bool operator==(dynamic card) {
    return card.letter == this.letter;
  } 

  @override
  int get hashCode {
    return letter.hashCode * 3 * textColor.hashCode;
  }
}

class _LetsMemoryFlipableCardState extends State<LetsMemoryFlipableCard> with TickerProviderStateMixin {
  AnimationController _controller;
  Animation<double> _frontScale;
  Animation<double> _backScale;

  bool _pressed;
  bool _found;

  Function onTapCallback;

  bool get found => _found;
  
  void makeAsFound() {
    setState(() {
      this._found = true;
    });
  }

  @override
  void initState() {
    super.initState();
    this._pressed = false;
    this._found = false;

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

  void hide() {
    if (this.revealed)
        _controller.reverse();
  }
  
  void reveal() {
    if (!this.revealed)
        _controller.forward();
  }

  get revealed => (_controller.isCompleted || _controller.velocity > 0);

  void _onTap() {
    if(!_found && !revealed) {
      reveal();
      if(this.onTapCallback != null)
        this.onTapCallback(widget);
    }
  }

   void _onTapDown(TapDownDetails details) {
     if(!_found)
      setState(()  {
        _pressed = true;
      });
  }

  void _onTapUp(TapUpDetails details) {
    if(!_found)
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
                pressed:_pressed || found
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
