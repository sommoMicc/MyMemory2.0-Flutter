# Full-screen game-world references

Research date: 5 November 2026. Primary publisher pages and their actual published
images were inspected. These are visual references; their characters, artwork,
copy and interfaces are not imported into MyMemory. Static images establish
composition, color and hierarchy; they do not establish animation timing.

## Observed references

| Game and primary source | Images inspected | Visible design pattern |
| --- | --- | --- |
| [Royal Match — Dream Games](https://www.dreamgames.com/games/royal-match), [official App Store listing](https://apps.apple.com/us/app/royal-match/id1482155847) | Publisher world illustration; listing's dungeon puzzle image and dining-room home image. | Scenery fills the frame. In the puzzle image, a small timer/progress strip separates the character scene from a strongly edged board. In the home image, resources float across the top and two substantial buttons sit above the bottom navigation. Colored surfaces, gold edges and shadows separate controls from the world. |
| [Two Dots — official game page](https://www.twodots-game.com/game), [official App Store listing](https://apps.apple.com/us/app/two-dots-connect-the-colors/id880178264) | Publisher's magenta character banner; listing images for the classic board, varied boards and hidden-object map. | The illustrated banner uses oversized characters and structural shapes cropped at the edges, with small stars in the remaining field. The hidden-object mode fills the frame with a detailed world and floating objective cards. **The classic dot board is white**: that particular palette does not fit this user's requested direction. |
| [Monument Valley — creator case study](https://ustwo.com/work/monument-valley/) | Creator's two wide game illustrations/screenshots: mountain/character scene and coral architecture against teal space. | Full-frame color, several layers of distant geometry and a strongly contrasting focal figure create depth. Unoccupied areas remain part of a colored environment. The images show that a rich world can retain quiet areas; every pixel need not contain a decorative object. |
| [memory® — Ravensburger's official Google Play listing](https://play.google.com/store/apps/details?hl=en&id=com.ravensburger.memory) | Publisher gallery images promoting graphic effects and adventure mode. | Large, colorful illustrated cards, patterned blue backs and themed card imagery carry the identity. These inspected gallery images are promotional collages, so they support card-art observations, not conclusions about the live HUD or viewport behavior. |

Royal Match's publisher also describes its world in terms of smooth, curved
forms and a coherent relationship between the setting, characters and matching
pieces. This supports using one visual world per collection rather than a
general-purpose application layout with unrelated decorations.
[Publisher world-design explanation](https://www.dreamgames.com/games/royal-match).

Two Dots' publisher describes a 2026 redesign involving lighting, visual effects,
characters and saga maps. This supports considering the surrounding world as
part of the experience; it does not prove any particular animation loop.
[Zynga's redesign article](https://www.zynga.com/corporate/a-fresh-coat-of-joy-two-dots-reimagines-its-world-for-a-new-era/).

## MyMemory implementation direction

The following are recommendations derived from those observations, not claims
that the reference games implement these exact details.

1. Fill the entire viewport with a collection-specific scene: layered foliage
   and warm sky for Animali, deep-space color and orbital shapes for Spazio,
   layered water and seabed curves for Oceano. Continue the scenery behind the
   top and bottom safe areas.
2. Make the game itself the center of the composition. Put compact scores,
   turn/time indicators and exit controls on colored or translucent floating
   surfaces. Use one strong primary-action color. Avoid a large white outer
   panel enclosing the whole screen.
3. Preserve a quiet zone directly behind the card grid. Contrast comes from
   cards, their edge/shadow and the darker or more saturated world around them.
   Light individual card faces can remain readable without turning the whole
   application into a white sheet.
4. Frame the scene with a few large licensed Noto illustrations or original
   code-drawn foreground shapes, partially cropped at the edges. Decorative
   objects are untappable and excluded from accessibility navigation; they must
   not resemble additional playable cards.
5. Add restrained ambient motion such as drifting particles, slow orbital
   movement or rising bubbles. Keep it outside the grid. A suggested starting
   range is a 6–12 second loop with 4–12 logical pixels of travel; these numbers
   are design proposals to judge in the running app. Preserve the requested
   perspective card flip and use short local feedback for a match.
6. Respect reduced-motion settings: keep the complete illustrated scene while
   stopping ambient movement and replacing unnecessary large transforms with
   immediate or short state transitions.

## Acceptance checks for this revision

- The first frame reads as a game world across the whole display, with a
  visibly different scene for each collection.
- Controls remain readable over scenery, and the illustrated cards remain the
  focus during play.
- Menu, setup, board and results fit one viewport. The grid keeps complete rows;
  decorations do not consume the space needed by the largest board.
- All 54 bundled illustrations and their stable multiplayer mapping remain.
- No slogans or promotional headlines are added. Store-marketing captions in
  reference images are not interface-copy recommendations.
- Verify actual ambient movement and card-flip behavior in the running build,
  plus the static result with reduced motion enabled. Screenshots alone cannot
  validate motion.
