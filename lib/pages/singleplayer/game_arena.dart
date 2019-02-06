import 'package:flutter/material.dart';

import 'package:letsmemory/UI/background.dart';
import 'package:letsmemory/UI/theme.dart';
import 'package:letsmemory/UI/lets_memory_flipable_card.dart';
import 'package:letsmemory/UI/lets_memory_card.dart';
import 'package:letsmemory/UI/lets_memory_static_card.dart';

import 'package:letsmemory/UI/overlay.dart';
import 'package:letsmemory/UI/main_button.dart';

import 'package:letsmemory/utils/game_arena_utils.dart';
import 'package:letsmemory/utils/storage_helper.dart';

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
  bool gameBegun;
  //Gestisce il tutorial
  bool tutorialMode;
  bool tutorialVisible;
  bool showTutorialOnCardTap;
  bool showBenFattoTutorial;
  String tutorialTitle;
  String tutorialText;
  String tutorialButton;
  String tutorialSecondButton;
  VoidCallback tutorialCallback;
  VoidCallback tutorialSecondCallback;


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
    gameBegun = false;

    cards.forEach((card) {
      card.setOnTapCallback(this.onCardTap);
    });
    tutorialVisible = false;
    tutorialMode = false;
    showTutorialOnCardTap = false;
    showBenFattoTutorial = false;
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
      gameBegun = true;
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
              showBenFattoTutorial = true;
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
    if(!gameBegun)
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
              tutorialText = "Tutorial terminato! Completa la partita (premendo \"Vado avanti\") o  premi il tasto \"termina\" per uscire";
              tutorialButton = "Vado avanti!";
              tutorialCallback = () {
                setState(() {
                  tutorialVisible = false;
                  showTutorialOnCardTap = false;
                  //Navigator.of(context).pop();
                });
              };
              StorageHelper().setFirstLaunchSingleplayer(false);
              tutorialSecondButton = "Termina";
              tutorialSecondCallback = () {
                Navigator.of(context).pop();
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
                  showBenFattoTutorial = false;
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
        if(showTutorialOnCardTap && showBenFattoTutorial) {
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
    return LetsMemoryBackground(
      children: <Widget>[
        Padding(
          padding: EdgeInsets.only(
            left: widget.cardsPadding,
            right: widget.cardsPadding,
            bottom: widget.cardsPadding,
            top: LetsMemoryDimensions.scaleHeight(context,
              LetsMemoryDimensions.standardCard * 
              LetsMemoryDimensions.miniButtonScaleFactor + 11)
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
          child: _BottomSheet(this.cardsFound, (this.cards.length / 2).floor()),
        ),
        LetsMemoryMainButton.getBackButton(context),
        _StartGameOverlay(secondsToStartGame),
        LetsMemoryOverlay.withTitleAndButton(
          visible: this.tutorialVisible,
          title: tutorialTitle,
          body: tutorialText,
          buttonText: tutorialButton,
          onTap: tutorialCallback,
          secondButtonText: tutorialSecondButton,
          secondButtonCallback: tutorialSecondCallback,
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

  _BottomSheet(this._cardsFound,this._totalCards);


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
            bottom: LetsMemoryDimensions.scaleHeight(context, 
                        LetsMemoryDimensions.standardCard/3),
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