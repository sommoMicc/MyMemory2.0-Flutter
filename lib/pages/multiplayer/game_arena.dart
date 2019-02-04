import 'package:flutter/material.dart';
import 'package:letsmemory/models/online_user.dart';

import '../../models/socket_listener.dart';

import '../../UI/background.dart';
import '../../UI/theme.dart';
import '../../UI/lets_memory_flipable_card.dart';
import '../../UI/lets_memory_static_card.dart';
import '../../UI/lets_memory_card.dart';
import '../../UI/main_button.dart';

import '../../utils/socket_helper.dart';

import 'dart:async';
import 'dart:math';

class LetsMemoryMultiplayerGameArena extends StatefulWidget {
  final List<LetsMemoryFlipableCard> cards;
  final int playerNumber;
  final String adversaryName;

  LetsMemoryMultiplayerGameArena(this.playerNumber,this.adversaryName,this.cards);
  
  final double cardsPadding = LetsMemoryDimensions.standardCard / 2;
  @override
  State<StatefulWidget> createState() {
    return _LetsMemoryMultiplayerGameArenaState();
  }

}

class _LetsMemoryMultiplayerGameArenaState extends State<LetsMemoryMultiplayerGameArena>
implements SocketListener {
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
  bool isMounted() {
    return this.mounted;
  }

  @override
  void onDisconnect() {
    Navigator.pushReplacementNamed(context, "/");
  }

  @override
  void onAdversaryLeft() { }
  @override
  void onBeginGame(int playerNumber, String adversaryName, List<LetsMemoryFlipableCard> cards) { }
  @override
  void onChallengeDenided(String username) {}
  @override
  void onChallengeReceived(String username) {}
  @override
  void onLoginResult(bool success, String username) {}
  @override
  void onSearchResult(List<OnlineUser> users) {}

  @override
  void initState() {
    super.initState();
    cardsFound = 0;
    cardsRevealed = 0;
    secondsToStartGame = 5;
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

    SocketHelper().addSocketListener(this);
  }

  Future<bool> _onWillPop() async {
    bool shoudQuit = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LetsMemoryDimensions.cardRadius)
        ),
        title: new Text("Conferma!"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text("Vuoi veramente sfidare abbandonare la sfida?")
          ],
        ),
        actions: <Widget>[
          LetsMemoryMainButton(
            textColor: Colors.black,
            backgroundColor: Colors.lightGreen[500],
            shadowColor: Colors.lightGreen[900],
            mini: true,
            text: "Si",
            callback: () {
              Navigator.pop(context,true);
            },
          ),
          LetsMemoryMainButton(
            textColor: Colors.white,
            backgroundColor: Colors.red[500],
            shadowColor: Colors.red[900],
            mini: true,
            text: "No",
            callback: () {
              Navigator.pop(context,false);
            },
          )
        ],
      ),
    ) ?? false;

    if(shoudQuit) {
      SocketHelper().leaveGame();
    }

    return shoudQuit;
  }

  @override
  void dispose() {
    super.dispose();
    SocketHelper().removeSocketListener(this);

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

    return WillPopScope(
      onWillPop: _onWillPop,
      child: LetsMemoryBackground(
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
          _StartGameOverlay(widget.adversaryName,secondsToStartGame)
        ]
      )
    );
  }
}

class _StartGameOverlay extends StatelessWidget {
  final int secondsToStartGame;
  final String adversaryName;
  _StartGameOverlay(this.adversaryName,this.secondsToStartGame);

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
                  "La partita contro  ",
                  style: LetsmemoryStyles.smallTitle,
                  textAlign: TextAlign.center,
                ),
                Padding(padding: EdgeInsets.only(top: 10)),
                Text(
                  this.adversaryName,
                  style: LetsmemoryStyles.mediumTitle,
                  textAlign: TextAlign.center,
                ),
                Padding(padding: EdgeInsets.only(top: 10)),
                Text(
                  "inizierà tra ",
                  style: LetsmemoryStyles.smallTitle,
                  textAlign: TextAlign.center,
                ),
                Padding(padding: EdgeInsets.only(top: 10)),
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
                      style: LetsmemoryStyles.smallTitle
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

class _BottomSheetState extends State<_BottomSheet> {  
  bool pressed;
  bool myTurn;

  Color backgroundColor;
  Color shadowColor;

  @override
  void initState() {
    super.initState();
    pressed = false;
    myTurn = false;

    backgroundColor = myTurn ? Colors.green[700] : Colors.deepOrange[700];
    shadowColor = myTurn ? Colors.green[900] : Colors.deepOrange[900];
  }

  void updateBackgroundColor() {
    setState((){
      backgroundColor = myTurn ? Colors.green[700] : Colors.deepOrange[700];
      shadowColor = myTurn ? Colors.green[900] : Colors.deepOrange[900];
    });
  }

  void _onTapDown(TapDownDetails details) {
    setState(()  {
      pressed = true;
    });
  }

  void _onTapUp(TapUpDetails details) {
    setState(() {
      pressed = false;
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
      child: Container(
          constraints: BoxConstraints(
            maxHeight: LetsMemoryDimensions.standardCard * 2,
          ),
          decoration: BoxDecoration(
            boxShadow: [
              new BoxShadow(
                color: shadowColor,
                offset: Offset(0, -10.0),
                blurRadius: 1.0
              )
            ],
            color: pressed ? shadowColor: backgroundColor,
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
              Column(
                children: <Widget>[
                  Text("Io: ",style: _BottomSheet.getTextStyle()),
                  Padding(padding: EdgeInsets.only(left: LetsMemoryDimensions.standardCard/2)),
                  Container(
                    child: LetsMemoryCard(
                      letter: widget._cardsFound.toString(),
                      textColor: Colors.black,
                    ),
                    height: LetsMemoryDimensions.standardCard,
                    width: LetsMemoryDimensions.standardCard,
                  ),
                ],
              ),
              Padding(padding: EdgeInsets.only(left: LetsMemoryDimensions.standardCard)),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Text("Avversario: ",style: _BottomSheet.getTextStyle()),
                  Padding(padding: EdgeInsets.only(left: LetsMemoryDimensions.standardCard/2)),
                  Container(
                    child: LetsMemoryCard(
                      letter: widget._cardsFound.toString(),
                      textColor: Colors.black,
                    ),
                    height: LetsMemoryDimensions.standardCard,
                    width: LetsMemoryDimensions.standardCard,
                  ),
                ],
              ),
            ],
          ),
        ),
    );
  }
}