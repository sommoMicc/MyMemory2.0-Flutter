import 'package:flutter/material.dart';
import '../pages/game_result.dart';
import '../UI/background.dart';
import '../UI/theme.dart';
import '../UI/lets_memory_flipable_card.dart';
import '../UI/lets_memory_static_card.dart';
import '../utils/game_arena_utils.dart';
import 'dart:async';

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
  Timer startGameTimer;
  //Booleano che indica se c'è un'operazione in corso che sta usando un 
  //timer, in modo tale da evitare problemi di concorrenza
  bool timerGoing;

  LetsMemoryFlipableCard lastCardSelected;
  int cardsRevealed;

  List<LetsMemoryFlipableCard> cards = GameArenaUtils.generateCardList(3*4);

  @override
  void initState() {
    super.initState();
    cardsFound = 0;
    cardsRevealed = 0;
    secondsToStartGame = 3;
    timerGoing = true;

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

  void beginGame() {
    cards.forEach((card) {
      card.reveal();
    });
    
    Timer(Duration(seconds: 3),() {
      cards.forEach((card) {
        card.hide();
      });
      timerGoing = false;
    });
  }

  void endGame() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => LetsMemoryGameResult()),
    );
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
    return LetsMemoryBackground(
      children: <Widget>[
        Padding(
          padding: EdgeInsets.only(
            left: widget.cardsPadding,
            right: widget.cardsPadding,
            bottom: widget.cardsPadding,
            top: 60.0
          ),
          child: GridView.count(
            mainAxisSpacing: widget.cardsPadding,
            crossAxisSpacing: widget.cardsPadding,
            primary: true,
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

class _BottomSheet extends StatelessWidget {
  final int _cardsFound;
  final int _totalCards;

  _BottomSheet(this._cardsFound,this._totalCards);

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
          maxHeight: LetsMemoryDimensions.standardCard * 2,
      ),
      decoration: BoxDecoration(
        boxShadow: [
          new BoxShadow(
            color: Colors.green[900],
            offset: Offset(0, -10.0),
            blurRadius: 1.0
          )
        ],
        color: Colors.green[700],
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(LetsMemoryDimensions.cardRadius),
          topRight: Radius.circular(LetsMemoryDimensions.cardRadius)
        )
      ),
      padding: EdgeInsets.only(
        left: LetsMemoryDimensions.standardCard/8,
        right: LetsMemoryDimensions.standardCard/8,
        top: LetsMemoryDimensions.standardCard/8,
        bottom: LetsMemoryDimensions.standardCard/2,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        
        children: <Widget>[
          Text("Coppie trovate: ",style: _getTextStyle()),
          Padding(padding: EdgeInsets.only(left: LetsMemoryDimensions.standardCard/2)),
          Container(
            child: LetsMemoryStaticCard(
              letter: this._cardsFound.toString(),
              textColor: Colors.black,
            ),
            height: LetsMemoryDimensions.standardCard,
            width: LetsMemoryDimensions.standardCard,
          ),
          Padding(padding: EdgeInsets.only(left: LetsMemoryDimensions.standardCard/4)),
          Text(" / "+this._totalCards.toString(),style: _getTextStyle()),
        ],
      ),
    );
  }

  static TextStyle _getTextStyle() {
    return TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold
    );
  }
}

