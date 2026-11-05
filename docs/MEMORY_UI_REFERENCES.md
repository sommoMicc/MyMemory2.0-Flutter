# Memory game visual references

Research date: 5 November 2026. These are real mobile memory games, not concept
mockups. Their official store screenshot galleries were inspected visually in
the browser. They inform layout and contrast only; no artwork was copied.

| Game and primary source | Observed in the gameplay screenshots | Useful pattern |
| --- | --- | --- |
| [Memory Match Brain Trainer — Irina Schens, App Store](https://apps.apple.com/us/app/memory-match-brain-trainer/id479656311) | Cyan striped wallpaper covers the whole phone; compact pink controls and timer/score plates sit directly above colorful cards. Unused space below the grid retains the wallpaper. | A colored game surface must continue behind the HUD and through every remaining part of the viewport. A few colored cards inside a white page do not create the same effect. |
| [Memory Match train brain game — Internet Designs, App Store](https://apps.apple.com/us/app/memory-match-train-brain-game/id569490958) | Wood covers the entire screen. A narrow moves/time line and a three-icon bottom toolbar frame a grid occupying the middle, shown with several complete row/column layouts. Results overlay the recognizable board. | Reserve slim control bands; fit the uniform grid into the remaining height. Background and overlays should feel part of the same table. |
| [Memory match game — Konfigurator sounds, Google Play](https://play.google.com/store/apps/details?hl=en&id=matching.pairs.memory.game) | The tablet gameplay image uses a quiet marble table, full rows of cards, and a thin progress strip. Its promotional home screen has a much busier blue dimensional pattern. | Richer scenery works around menus and at the edges; card recognition benefits from a calmer central surface. |

## Application to MyMemory

Use an edge-to-edge, theme-specific world behind the entire screen, including
safe-area margins. Keep the existing complete rows and equally sized cards.
The HUD needs a compact, readable contrasting surface rather than a large white
header or panel. Keep scenic detail strongest at the edges and quieter behind
the cards.

Suggested original backgrounds: a garden with distant hills/leaves, deep space
with stars and orbital arcs, and water with bubbles and a seabed silhouette.
These can be drawn in code; the licensed bundled Noto images remain the card
illustrations.

Slow drifting particles, gentle edge movement, and small reactions to a match
are **our proposed motion treatment**. Static store screenshots do not establish
whether the reference games animate their backgrounds. Motion should honor the
existing animation preference and system reduced-motion setting, pause when
inactive, and avoid moving or obscuring card positions.

The screenshot galleries show complete boards, but they do not prove every
device configuration is non-scrolling. MyMemory's own viewport checks remain
the evidence for its no-scroll requirement.
