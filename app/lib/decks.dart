import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// IDs and ordering are part of the multiplayer card-value mapping. Do not reorder.
const Map<String, String> deckNames = {
  'garden': 'Animali',
  'cosmos': 'Spazio',
  'ocean': 'Oceano',
};

const Map<String, List<String>> deckAssets = {
  'garden': [
    'assets/decks/garden/fox.png',
    'assets/decks/garden/dog.png',
    'assets/decks/garden/cat.png',
    'assets/decks/garden/lion.png',
    'assets/decks/garden/tiger.png',
    'assets/decks/garden/monkey.png',
    'assets/decks/garden/rabbit.png',
    'assets/decks/garden/bear.png',
    'assets/decks/garden/panda.png',
    'assets/decks/garden/koala.png',
    'assets/decks/garden/mouse.png',
    'assets/decks/garden/pig.png',
    'assets/decks/garden/cow.png',
    'assets/decks/garden/frog.png',
    'assets/decks/garden/chicken.png',
    'assets/decks/garden/penguin.png',
    'assets/decks/garden/owl.png',
    'assets/decks/garden/butterfly.png',
  ],
  'cosmos': [
    'assets/decks/cosmos/rocket.png',
    'assets/decks/cosmos/satellite.png',
    'assets/decks/cosmos/saturn.png',
    'assets/decks/cosmos/crescent.png',
    'assets/decks/cosmos/sun.png',
    'assets/decks/cosmos/star.png',
    'assets/decks/cosmos/comet.png',
    'assets/decks/cosmos/telescope.png',
    'assets/decks/cosmos/alien.png',
    'assets/decks/cosmos/ufo.png',
    'assets/decks/cosmos/astronaut.png',
    'assets/decks/cosmos/galaxy.png',
    'assets/decks/cosmos/earth.png',
    'assets/decks/cosmos/shooting-star.png',
    'assets/decks/cosmos/antenna.png',
    'assets/decks/cosmos/robot.png',
    'assets/decks/cosmos/globe.png',
    'assets/decks/cosmos/full-moon.png',
  ],
  'ocean': [
    'assets/decks/ocean/whale.png',
    'assets/decks/ocean/dolphin.png',
    'assets/decks/ocean/seal.png',
    'assets/decks/ocean/fish.png',
    'assets/decks/ocean/tropical-fish.png',
    'assets/decks/ocean/pufferfish.png',
    'assets/decks/ocean/shark.png',
    'assets/decks/ocean/octopus.png',
    'assets/decks/ocean/squid.png',
    'assets/decks/ocean/crab.png',
    'assets/decks/ocean/lobster.png',
    'assets/decks/ocean/shrimp.png',
    'assets/decks/ocean/jellyfish.png',
    'assets/decks/ocean/coral.png',
    'assets/decks/ocean/shell.png',
    'assets/decks/ocean/turtle.png',
    'assets/decks/ocean/anchor.png',
    'assets/decks/ocean/sailboat.png',
  ],
};

const Map<String, List<String>> deckLabels = {
  'garden': [
    'Volpe',
    'Cane',
    'Gatto',
    'Leone',
    'Tigre',
    'Scimmia',
    'Coniglio',
    'Orso',
    'Panda',
    'Koala',
    'Topo',
    'Maiale',
    'Mucca',
    'Rana',
    'Gallina',
    'Pinguino',
    'Gufo',
    'Farfalla',
  ],
  'cosmos': [
    'Razzo',
    'Satellite',
    'Pianeta con anelli',
    'Luna crescente',
    'Sole',
    'Stella',
    'Cometa',
    'Telescopio',
    'Alieno',
    'Disco volante',
    'Astronauta',
    'Galassia',
    'Terra',
    'Stella cadente',
    'Antenna',
    'Robot',
    'Globo',
    'Luna piena',
  ],
  'ocean': [
    'Balena',
    'Delfino',
    'Foca',
    'Pesce',
    'Pesce tropicale',
    'Pesce palla',
    'Squalo',
    'Polpo',
    'Calamaro',
    'Granchio',
    'Aragosta',
    'Gambero',
    'Medusa',
    'Corallo',
    'Conchiglia',
    'Tartaruga',
    'Ancora',
    'Barca a vela',
  ],
};

String? deckAsset(String theme, int value) {
  final assets = deckAssets[theme];
  return assets != null && value >= 0 && value < assets.length
      ? assets[value]
      : null;
}

String? deckCover(String theme) => deckAsset(theme, 0);

String? deckLabel(String theme, int value) {
  final labels = deckLabels[theme];
  return labels != null && value >= 0 && value < labels.length
      ? labels[value]
      : null;
}

bool _licensesRegistered = false;
Future<void> registerDeckLicenses() async {
  if (_licensesRegistered) return;
  final notice = await rootBundle.loadString('assets/decks/NOTICE.txt');
  final upstream = await rootBundle.loadString(
    'assets/decks/UPSTREAM-NOTICE.txt',
  );
  final license = await rootBundle.loadString(
    'assets/decks/LICENSE-APACHE-2.0.txt',
  );
  LicenseRegistry.addLicense(
    () => Stream.value(
      LicenseEntryWithLineBreaks(const [
        'Noto Emoji 2D — deck illustrations',
      ], '$notice\n$upstream\n$license'),
    ),
  );
  _licensesRegistered = true;
}
