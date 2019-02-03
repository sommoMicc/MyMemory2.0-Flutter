import 'package:flutter/material.dart';

import '../../UI/background.dart';
import '../../UI/theme.dart';
import '../../UI/lets_memory_flipable_card.dart';
import '../../UI/lets_memory_static_card.dart';
import '../../UI/lets_memory_card.dart';

import 'dart:async';
import 'dart:math';

class LetsMemoryMultiplayerGameArena extends StatefulWidget {
  final List<LetsMemoryFlipableCard> cards;
  LetsMemoryMultiplayerGameArena(this.cards);
  
  final double cardsPadding = LetsMemoryDimensions.standardCard / 2;
  @override
  State<StatefulWidget> createState() {
    return _LetsMemoryMultiplayerGameArenaState();
  }

}

class _LetsMemoryMultiplayerGameArenaState extends State<LetsMemoryMultiplayerGameArena> {
  int cardsFound;
  
  int secondsToStartGame;
  Timer startGameTimer, cardsHideTimer;
  //Booleano che indica se c'è un'operazione in corso che sta usando un 
  //timer, in modo tale da evitare problemi di concorrenza
  bool timerGoing;

  LetsMemoryFlipableCard lastCardSelected;
  int cardsRevealed;

  List<LetsMemoryFlipableCard> cards ;

  @override
  void initState() {
    super.initState();
    cardsFound = 0;
    cardsRevealed = 0;
    secondsToStartGame = 3;
    timerGoing = true;
    
    cards = widget.cards;

    startGameTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if(secondsToStartGame == 0) {
        startGameTimer.cancel();
        beginGame();
        return;
      }
      setState(() {
        secondsToStartGame--;      
      });
    });

    cards.forEach((card) {
      card.setOnTapCallback(this.onCardTap);
    });
  }

  @override
  void dispose() {
    super.dispose();

    if(startGameTimer.isActive)
      startGameTimer.cancel();

    if(cardsHideTimer != null && cardsHideTimer.isActive)
      cardsHideTimer.cancel();
    
  }

  void beginGame() {
    cards.forEach((card) {
      card.reveal();
    });
    
    cardsHideTimer = Timer(Duration(seconds: 3),() {
      cards.forEach((card) {
        card.hide();
      });
      timerGoing = false;
    });
  }

  void endGame() {
    Navigator.pushReplacementNamed(context, "/singleplayer/gameresult");
  }

  void onCardTap(LetsMemoryFlipableCard cardTapped) {
    if(cardsRevealed < 2) { 
      cardTapped.reveal();
      cardsRevealed++;
            
      if(lastCardSelected != null) {
        if(lastCardSelected == cardTapped) {
          lastCardSelected.makeAsFound();
          cardTapped.makeAsFound();

          setState(() {
            cardsFound++;
            if(cardsFound*2 == cards.length) endGame();
            
            lastCardSelected = null;
            cardsRevealed = 0;
          });
        }
        else {
          Timer(Duration(seconds: 1),() {
            lastCardSelected.hide();
            cardTapped.hide();
            
            lastCardSelected = null;
            cardsRevealed = 0;
          });

        }

      }
      else {
        lastCardSelected = cardTapped;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    MediaQueryData mediaQuery = MediaQuery.of(context);
    double aspectRatioCorrection = pow(2,mediaQuery.size.height/mediaQuery.size.width) - 3.0;

    return LetsMemoryBackground(
      children: <Widget>[
        Padding(
          padding: EdgeInsets.only(
            left: widget.cardsPadding,
            right: widget.cardsPadding,
            bottom: widget.cardsPadding,
            top: 60.0 * aspectRatioCorrection
          ),
          child: GridView.count(
            mainAxisSpacing: widget.cardsPadding,
            crossAxisSpacing: widget.cardsPadding,
            primary: false,
            crossAxisCount: 3,
            shrinkWrap:false,
            children: cards,
          ),
        ),
          
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _BottomSheet(this.cardsFound, (this.cards.length / 2).floor(), aspectRatioCorrection),
        ),
        _StartGameOverlay(secondsToStartGame)
      ]
    );
  }
}

class _StartGameOverlay extends StatelessWidget {
  final int secondsToStartGame;

  _StartGameOverlay(this.secondsToStartGame);

  @override
  Widget build(BuildContext context) {
    return Visibility(
      visible: secondsToStartGame > 0,
      child: Positioned(
        bottom: 0,
        left: 0,
        right: 0,
        top: 0,
        child: Container(
          color: Color(0xBB000000),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Text(
                  "Inizio partita in ",
                  style: LetsmemoryStyles.mainTitle
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    LetsMemoryStaticCard(
                      letter: secondsToStartGame.toString(),
                      textColor: Colors.black
                    ),
                    Text(
                      " secondi",
                      style: LetsmemoryStyles.mainTitle
                    )
                  ]
                ),
              ]  
            )
          ),
        )
      )
    );
  }
}

class _BottomSheet extends StatefulWidget {
  final int _cardsFound;
  final int _totalCards;
  final double _aspectRatio; 

  _BottomSheet(this._cardsFound,this._totalCards,this._aspectRatio);


  static TextStyle getTextStyle() {
    return TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold
    );
  }

  @override
  State<StatefulWidget> createState() {
    return _BottomSheetState();
  }
}

class _BottomSheetState extends State<_BottomSheet> with SingleTickerProviderStateMixin {
  AnimationController _animationController;
  Animation _backgroundColorTween;
  Animation _shadowColorTween;
  bool pressed;
  
  @override
  void initState() {
    super.initState();
    pressed = false;

    _animationController = AnimationController(
      vsync: this, 
      duration: Duration(milliseconds: 1200),
    );
    _backgroundColorTween = ColorTween(begin: Colors.green[700], end: Colors.deepOrange[700])
      .animate(_animationController);
    _shadowColorTween = ColorTween(begin: Colors.green[900], end: Colors.deepOrange[900])
      .animate(_animationController);

  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    setState(()  {
      pressed = true;
    });
  }

  void _onTapUp(TapUpDetails details) {
    setState(() {
      pressed = false;
      if (_animationController.status == AnimationStatus.completed) {
        _animationController.reverse();
      } else {
        _animationController.forward();
      }
    });
  }

  void _onTapCancel() {
    this._onTapUp(null);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _backgroundColorTween,
        builder: (context, child) => Container(
          constraints: BoxConstraints(
            maxHeight: LetsMemoryDimensions.standardCard * 2,
          ),
          decoration: BoxDecoration(
            boxShadow: [
              new BoxShadow(
                color: _shadowColorTween.value,
                offset: Offset(0, -10.0),
                blurRadius: 1.0
              )
            ],
            color: pressed ? _shadowColorTween.value : _backgroundColorTween.value,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(LetsMemoryDimensions.cardRadius),
              topRight: Radius.circular(LetsMemoryDimensions.cardRadius)
            )
          ),
          padding: EdgeInsets.only(
            left: LetsMemoryDimensions.standardCard/8,
            right: LetsMemoryDimensions.standardCard/8,
            top: LetsMemoryDimensions.standardCard/8,
            bottom: LetsMemoryDimensions.standardCard/2 * max(widget._aspectRatio, 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            
            children: <Widget>[
              Text("Coppie trovate: ",style: _BottomSheet.getTextStyle()),
              Padding(padding: EdgeInsets.only(left: LetsMemoryDimensions.standardCard/2)),
              Container(
                child: LetsMemoryCard(
                  letter: widget._cardsFound.toString(),
                  textColor: Colors.black,
                ),
                height: LetsMemoryDimensions.standardCard,
                width: LetsMemoryDimensions.standardCard,
              ),
              Padding(padding: EdgeInsets.only(left: LetsMemoryDimensions.standardCard/4)),
              Text(" / "+widget._totalCards.toString(),style: _BottomSheet.getTextStyle()),
            ],
          ),
        ),
      ),
    );
  }
}