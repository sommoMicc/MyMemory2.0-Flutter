import '../UI/lets_memory_card.dart';
import 'dart:math';
import 'package:flutter/material.dart';

class GameArenaUtils {
  static final List<String> symbols = [
    "A","B","C","D","E","F","G","H","I","J","K","L",
    "M","N","O","P","Q","R","S","T","U","V","W","X",
    "Y","Z"
  ];
  static List<LetsMemoryCard> generateCardList(int listSize) {
    List<LetsMemoryCard> cardList = [];

    List<String> availableSymbols = [];
    availableSymbols.addAll(GameArenaUtils.symbols);

    Random randomInstance = Random();

    for(int i=0;i<listSize;i++) {
      Color cardColor = Color(
        (randomInstance.nextDouble() * 0xFFFFFF).toInt() << 0)
        .withOpacity(1.0);
      int chosenSymbolIndex = randomInstance.nextInt(availableSymbols.length);
      cardList.add(LetsMemoryCard(
        letter: availableSymbols.removeAt(chosenSymbolIndex),
        textColor: cardColor,
      ));
    }

    return cardList;
  }
}