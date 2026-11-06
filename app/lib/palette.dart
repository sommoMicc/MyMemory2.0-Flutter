import 'package:flutter/material.dart';

const ink = Color(0xFF172345);
const paper = Color(0xFFFFF4D8);
const popCobalt = Color(0xFF2446D8);
const popYellow = Color(0xFFFFE34C);
const popSky = Color(0xFF93E6ED);
const popNavy = Color(0xFF1B318F);
const teal = popCobalt;
const coral = Color(0xFFFF593B);
const muted = Color(0xFF52617C);
const line = Color(0xFF172345);
String deckWorldTheme(String theme) => switch (theme) {
  'garden' || 'farm' || 'flora' || 'insects' || 'dinosaurs' => 'garden',
  'ocean' || 'beach' || 'navigation' || 'pirates' || 'abyss' => 'ocean',
  'vehicles' ||
  'professions' ||
  'instruments' ||
  'food' ||
  'sports' ||
  'travel' => 'travel',
  'cosmos' || 'laboratory' || 'space_base' || 'aliens' || 'robots' => 'cosmos',
  'paola' => 'paola',
  _ => 'garden',
};

IconData deckBackIcon(String theme) => switch (deckWorldTheme(theme)) {
  'ocean' => Icons.waves_rounded,
  'travel' => Icons.location_city_rounded,
  'cosmos' => Icons.auto_awesome_rounded,
  'paola' => Icons.menu_book_rounded,
  _ => Icons.landscape_rounded,
};

Color deckAccent(String theme) => switch (theme) {
  'farm' => const Color(0xFF8B6A45),
  'flora' => const Color(0xFF73964D),
  'insects' => const Color(0xFFB79A35),
  'dinosaurs' => const Color(0xFF8C6557),
  'beach' => const Color(0xFF2B93B8),
  'navigation' => const Color(0xFF466E93),
  'pirates' => const Color(0xFF9B5C43),
  'abyss' => const Color(0xFF315C88),
  'vehicles' => const Color(0xFF426F8E),
  'professions' => const Color(0xFF597B66),
  'instruments' => const Color(0xFF95649A),
  'laboratory' => const Color(0xFF538D8A),
  'space_base' => const Color(0xFF5569A0),
  'aliens' => const Color(0xFF8466A5),
  'robots' => const Color(0xFF607B95),
  'cosmos' => const Color(0xFF8066B5),
  'ocean' => const Color(0xFF3E99BD),
  'travel' => const Color(0xFF81B3C4),
  _ => teal,
};
const themeNames = {
  'garden': 'Piccolo giardino',
  'cosmos': 'Tra le stelle',
  'ocean': 'Sotto il mare',
};
const themeIcons = {
  'garden': Icons.local_florist_rounded,
  'cosmos': Icons.auto_awesome_rounded,
  'ocean': Icons.water_rounded,
};
const symbols = <String, List<IconData>>{
  'garden': [
    Icons.local_florist_rounded,
    Icons.eco_rounded,
    Icons.park_rounded,
    Icons.wb_sunny_rounded,
    Icons.spa_rounded,
    Icons.bug_report_rounded,
    Icons.grass_rounded,
    Icons.pets_rounded,
    Icons.emoji_nature_rounded,
    Icons.filter_vintage_rounded,
    Icons.forest_rounded,
    Icons.yard_rounded,
    Icons.water_drop_rounded,
    Icons.egg_rounded,
    Icons.nature_rounded,
    Icons.cloud_rounded,
    Icons.landscape_rounded,
    Icons.agriculture_rounded,
  ],
  'cosmos': [
    Icons.auto_awesome_rounded,
    Icons.rocket_launch_rounded,
    Icons.nightlight_round,
    Icons.public_rounded,
    Icons.satellite_alt_rounded,
    Icons.star_rounded,
    Icons.sunny,
    Icons.bolt_rounded,
    Icons.brightness_3_rounded,
    Icons.blur_circular_rounded,
    Icons.flare_rounded,
    Icons.air_rounded,
    Icons.travel_explore_rounded,
    Icons.radar_rounded,
    Icons.science_rounded,
    Icons.flashlight_on_rounded,
    Icons.explore_rounded,
    Icons.all_inclusive_rounded,
  ],
  'ocean': [
    Icons.water_rounded,
    Icons.sailing_rounded,
    Icons.anchor_rounded,
    Icons.beach_access_rounded,
    Icons.set_meal_rounded,
    Icons.waves_rounded,
    Icons.pool_rounded,
    Icons.kayaking_rounded,
    Icons.wb_sunny_rounded,
    Icons.water_drop_rounded,
    Icons.scuba_diving_rounded,
    Icons.surfing_rounded,
    Icons.storm_rounded,
    Icons.umbrella_rounded,
    Icons.directions_boat_rounded,
    Icons.tsunami_rounded,
    Icons.bubble_chart_rounded,
    Icons.star_rounded,
  ],
};
const symbolColors = [
  teal,
  coral,
  Color(0xFFB49A52),
  Color(0xFF7B73A2),
  Color(0xFF6D9971),
  Color(0xFF629DA8),
];
