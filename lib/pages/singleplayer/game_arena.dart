import 'package:flutter/material.dart';

import '../../UI/background.dart';
import '../../UI/theme.dart';
import '../../UI/lets_memory_flipable_card.dart';
import '../../UI/lets_memory_card.dart';
import '../../UI/lets_memory_static_card.dart';

import '../../UI/overlay.dart';

import '../../utils/game_arena_utils.dart';
import '../../utils/storage_helper.dart';

import 'dart:async';
import 'dart:math';

class LetsMemoryGameArena extends StatefulWidget {
  final double cardsPadding = LetsMemoryDimensions.standardCard / 2;
  @override
  State<StatefulWidget> createState() {
    return _LetsMemoryGameArenaState();
  }

}

class _LetsMemoryGameArenaState extends State<LetsMemoryGameArena> {
  int cardsFound;
  
  int secondsToStartGame;
  Timer startGameTimer, cardsHideTimer;
  //Booleano che indica se c'è un'operazione in corso che sta usando un 
  //timer, in modo tale da evitare problemi di concorrenza
  bool timerGoing;
  bool gamesBegun;
  //Gestisce il tutorial
  bool tutorialMode;
  bool tutorialVisible;
  bool showTutorialOnCardTap;
  String tutorialTitle;
  String tutorialText;
  String tutorialButton;
  VoidCallback tutorialCallback;


  LetsMemoryFlipableCard lastCardSelected;
  int cardsRevealed;

  List<LetsMemoryFlipableCard> cards = GameArenaUtils.generateCardList(3*4);

  @override
  void initState() {
    super.initState();
    cardsFound = 0;
    cardsRevealed = 0;
    secondsToStartGame = 0;
    timerGoing = true;
    gamesBegun = false;

    cards.forEach((card) {
      card.setOnTapCallback(this.onCardTap);
    });
    tutorialVisible = false;
    tutorialMode = false;
    showTutorialOnCardTap = false;
    checkTutorialVisible();
  }

  void checkTutorialVisible() async {
    tutorialVisible = await StorageHelper().getFirstLaunchSingleplayer();
    if(tutorialVisible) {
      setState(() {
        tutorialMode = true;
        tutorialVisible = true;
        tutorialTitle = "Attenzione!";
        tutorialText = "Ci sono 6 coppie di carte. Hai solo 3 secondi per memorizzarne la posizione. Sei pronto?";
        tutorialButton = "Si";
        tutorialCallback = () {
          setState(() {
            tutorialVisible = false;
            startCountdown();
          });
        };
      });
    }
    else {
      startCountdown();
    }
  }

  void startCountdown() {
    setState(() {
      secondsToStartGame = 3;
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
    });
  }

  @override
  void dispose() {
    super.dispose();

    if(startGameTimer != null && startGameTimer.isActive)
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
      gamesBegun = true;
      if(tutorialMode) {
        setState(() {
          tutorialVisible = true;
          tutorialTitle = "Hai memorizzato la disposizione?";
          tutorialText = "Premi una carta col dito per scoprirla";
          tutorialButton = "Va bene";
          tutorialCallback = () {
            setState(() {
              tutorialVisible = false;
              showTutorialOnCardTap = true;
            });
          };
        });
      }
    });
  }

  void endGame() {
    Navigator.pushReplacementNamed(context, "/singleplayer/gameresult");
  }

  void onCardTap(LetsMemoryFlipableCard cardTapped) {
    if(!gamesBegun)
      return;

    if(cardsRevealed < 2) { 
      cardTapped.reveal();
      cardsRevealed++;
            
      if(lastCardSelected != null) {
        if(lastCardSelected == cardTapped) {
          lastCardSelected.makeAsFound();
          cardTapped.makeAsFound();

          if(showTutorialOnCardTap) {
            setState(() {
              tutorialVisible = true;
              tutorialTitle = "Complimenti!";
              tutorialText = "Trova tutte le coppie per terminare il gioco";
              tutorialButton = "Ho capito!";
              tutorialCallback = () {
                setState(() {
                  tutorialVisible = false;
                  showTutorialOnCardTap = false;
                  StorageHelper().setFirstLaunchSingleplayer(false);
                  //Navigator.of(context).pop();
                });
              };
            });
          }

          setState(() {
            cardsFound++;
            if(cardsFound*2 == cards.length) endGame();
            
            lastCardSelected = null;
            cardsRevealed = 0;
          });
        }
        else {
          if(showTutorialOnCardTap) {
            setState(() {
              tutorialVisible = true;
              tutorialTitle = "Oh no!";
              tutorialText = "Non è la carta giusta, riprova!";
              tutorialButton = "Ce la farò";
              tutorialCallback = () {
                setState(() {
                  tutorialVisible = false;
                });
              };
            });
          }

          Timer(Duration(seconds: 1),() {
            lastCardSelected.hide();
            cardTapped.hide();
            
            lastCardSelected = null;
            cardsRevealed = 0;
          });

        }

      }
      else {
        if(showTutorialOnCardTap) {
          setState(() {
            tutorialVisible = true;
            tutorialTitle = "Ben fatto!";
            tutorialText = "Prova a trovare l'altra carta uguale";
            tutorialButton = "Ok, ci provo!";
            tutorialCallback = () {
              setState(() {
                tutorialVisible = false;
                showTutorialOnCardTap = true;
              });
            };
          });

        }
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
        _StartGameOverlay(secondsToStartGame),
        LetsMemoryOverlay.withTitleAndButton(
          visible: this.tutorialVisible,
          title: tutorialTitle,
          body: tutorialText,
          buttonText: tutorialButton,
          onTap: tutorialCallback,
        )

      ]
    );
  }
}

class _StartGameOverlay extends StatelessWidget {
  final int secondsToStartGame;

  _StartGameOverlay(this.secondsToStartGame);

  @override
  Widget build(BuildContext context) {
    return LetsMemoryOverlay(
      visible: secondsToStartGame > 0,
      children: <Widget>[
        Text(
          "Inizio partita in ",
          style: LetsmemoryStyles.mainTitle,
          textAlign: TextAlign.center,
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
              style: LetsmemoryStyles.mainTitle,
              textAlign: TextAlign.center,
            )
          ]
        ),
      ]  
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