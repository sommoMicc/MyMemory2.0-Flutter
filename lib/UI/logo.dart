import 'package:flutter/material.dart';
import './lets_memory_card.dart';
import './theme.dart';

class LetsMemoryLogo extends StatelessWidget {

final Matrix4 leftRotation = Matrix4.rotationZ(-0.174533);
final Matrix4 rightRotation = Matrix4.rotationZ(0.174533);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Column(
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              LetsMemoryCard(letter: "L",textColor: Colors.red, rotation: this.leftRotation),
              LetsMemoryCard(letter: "E",textColor: Colors.orange, rotation: this.rightRotation),
              LetsMemoryCard(letter: "T'",textColor: Colors.yellow, rotation: this.leftRotation),
              Padding(padding: EdgeInsets.only(left: LetsMemoryDimensions.standardCard * 3 / 4)),
              LetsMemoryCard(letter: "S",textColor: Colors.green, rotation: this.rightRotation),
            ],
          ),
          Padding(padding: EdgeInsets.only(top: LetsMemoryDimensions.standardCard/3)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              LetsMemoryCard(letter: "M",textColor: Colors.red, rotation: this.leftRotation),
              LetsMemoryCard(letter: "E",textColor: Colors.orange, rotation: this.rightRotation),
              LetsMemoryCard(letter: "M",textColor: Colors.yellow, rotation: this.leftRotation),
              LetsMemoryCard(letter: "O",textColor: Colors.green, rotation: this.rightRotation),
              LetsMemoryCard(letter: "R",textColor: Colors.indigo, rotation: this.leftRotation),
              LetsMemoryCard(letter: "Y",textColor: Colors.deepPurple, rotation: this.rightRotation),
            ],
          )
        ],
      )
    );
  }

}