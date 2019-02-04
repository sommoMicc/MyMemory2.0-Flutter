import 'package:flutter/material.dart';
import './lets_memory_static_card.dart';
import 'dart:math';

class LetsMemoryFlipableCard extends StatefulWidget {
  final String letter;
  final Color textColor;
  final Matrix4 rotation;

  _LetsMemoryFlipableCardState state;
  int index;
  Function onTapCallback;

  LetsMemoryFlipableCard({this.letter, this.textColor = Colors.white, this.rotation});

  @override
  State<LetsMemoryFlipableCard> createState() {
    state = _LetsMemoryFlipableCardState();
    return state;
  }

  void hide() {
    if(state != null)
      state.hide();
    }

  void reveal() {
    if(state != null)
      state.reveal();
  }

  void makeAsFound() {
    if(state != null)
      state.makeAsFound();
  }
    
  bool get found {
    if(state != null)
      return state.found;
    else
      return false;
  }
  bool get revealed {
    if(state != null)
      return state.revealed;
    else
      return false;
  }


  void setOnTapCallback(Function callback) => this.onTapCallback = callback;

  @override
  bool operator==(dynamic card) {
    return card.letter == this.letter;
  } 

  @override
  int get hashCode {
    return letter.hashCode * 3 * textColor.hashCode * Random().nextInt(99999);
  }

  factory LetsMemoryFlipableCard.fromJSON(Map<String, dynamic> json) {
    return LetsMemoryFlipableCard(
      letter: json['letter'],
      textColor: Color(json['color']).withOpacity(1.0)
    );
  }
}

class _LetsMemoryFlipableCardState extends State<LetsMemoryFlipableCard> with TickerProviderStateMixin {
  AnimationController _controller;
  Animation<double> _frontScale;
  Animation<double> _backScale;

  int index;

  bool _pressed;
  bool _found;

  bool get found => _found;
  
  void makeAsFound() {
    if(this.mounted)
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }


  void toggleFlip() {
    if(this.mounted)
      setState(() {
        if (_controller.isCompleted || _controller.velocity > 0)
          _controller.reverse();
        else
          _controller.forward();
      });
  }

  void hide() {
    try {
      if (this.revealed)
        _controller.reverse();
    }
    catch(e) {
      print(e);
    }
  }
  
  void reveal() {
    try {
      if (!this.revealed)
          _controller.forward();
    }
    catch(e) {
      print(e);
    }
  }

  get revealed => (_controller.isCompleted || _controller.velocity > 0);

  void _onTap() {
    if(!_found && !revealed && mounted) {
      //reveal();
      if(widget.onTapCallback != null)
        widget.onTapCallback(widget);
    }
  }

   void _onTapDown(TapDownDetails details) {
     if(!_found && mounted)
      setState(()  {
        _pressed = true;
      });
  }

  void _onTapUp(TapUpDetails details) {
    if(!_found && mounted)
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
