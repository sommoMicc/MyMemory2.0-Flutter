import 'package:flutter/material.dart';
import '../UI/background.dart';
import '../UI/theme.dart';
import '../UI/lets_memory_static_card.dart';
import '../utils/game_arena_utils.dart';

class LetsMemoryGameArena extends StatefulWidget {
  final double cardsPadding = LetsMemoryDimensions.standardCard / 2;
  @override
  State<StatefulWidget> createState() {
    return _LetsMemoryGameArenaState();
  }

}

class _LetsMemoryGameArenaState extends State<LetsMemoryGameArena> {
  int cardsFound;

  List<Widget> cards = GameArenaUtils.generateCardList(3*4);

  @override
  void initState() {
    super.initState();
    cardsFound = 0;
  }

  @override
  Widget build(BuildContext context) {
    return LetsMemoryBackground(
      children: <Widget>[
        Padding(
          padding: EdgeInsets.all(widget.cardsPadding),
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
        )
      ]
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
      padding: EdgeInsets.all(LetsMemoryDimensions.standardCard/8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        
        children: <Widget>[
          Text("Coppie trovate: ",style: _getTextStyle()),
          Padding(padding: EdgeInsets.only(left: LetsMemoryDimensions.standardCard/2)),
          LetsMemoryStaticCard(
            letter: this._cardsFound.toString(),
            textColor: Colors.black,
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

